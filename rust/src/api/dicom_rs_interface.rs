use anyhow::Result;
use dicom::{
    core::{value::{DataSetSequence, PrimitiveValue, Value}, DataDictionary},
    dictionary_std::{self, tags, StandardDataDictionary},
    object::{mem::InMemElement, open_file, AccessError, FileDicomObject, InMemDicomObject, Tag},
};
use dicom_pixeldata::{image, PixelDecoder, ConvertOptions, VoiLutOption, BitDepthOption};
use std::{fs, io::Cursor, path::Path, collections::HashMap};
use std::cmp::Ordering;
use dicom_pixeldata::Error;
use flutter_rust_bridge::DartFnFuture;
use futures::{stream::{self, StreamExt}, future::join_all};
use std::sync::atomic::{AtomicU32, Ordering as AtomicOrdering};
use std::sync::{Arc, Mutex};
use rayon::prelude::*;
// -----------------------------------------------------------------------------
// Unified element conversion using to_el
// -----------------------------------------------------------------------------

#[derive(Debug)]
pub struct El {
    /// DICOM tag as an 8-digit hex string (e.g., "00100010")
    pub tag: String,
    /// Friendly alias from the standard dictionary
    pub alias: &'static str,
    /// Value representation (VR) as string
    pub vr: String,
    /// The element’s value, converted to a string
    pub value: String,
}

/// Converts an InMemElement into our simplified El structure.
/// This function formats the tag as an 8-digit hex string.
fn to_el(e: &InMemElement) -> Result<El> {
    let tag = e.header().tag;
    let tag_str = format!("{:04X}{:04X}", tag.group(), tag.element());

    let alias = StandardDataDictionary
        .by_tag(tag)
        .map(|entry| entry.alias)
        .unwrap_or("«unknown attribute»");
    
    let vr = e.header().vr().to_string().to_owned();

    let value = if tag == tags::PIXEL_DATA {
        "«pixel data»".to_string()
    } else {
        e.value().to_str()?.to_string()
    };

    Ok(El {
        tag: tag_str,
        alias,
        vr,
        value,
    })
}


/// Extracts all primitive elements from a DICOM object and converts them to El structs.
fn extract_metadata_elements(obj: &FileDicomObject<InMemDicomObject>) -> Result<HashMap<String, El>> {
    let filtered_iter = obj.iter().filter(|e| !e.header().is_non_primitive());

    // Pre-allocate the HashMap with estimated capacity to reduce rehashing
    // Adjust this number based on your typical DICOM file size
    let mut hashmap = HashMap::with_capacity(100);
    
    for element in filtered_iter {
        match to_el(element) {
            Ok(el) => { hashmap.insert(el.tag.clone(), el); },
            Err(e) => return Err(e),
        }
    }

    Ok(hashmap)
}
/// Helper to search the converted elements for a given tag.
fn get_value_from_elements(elements: &HashMap<String, El>, tag: Tag) -> Option<String> {
    let tag_str = format!("{:04X}{:04X}", tag.group(), tag.element());
    elements.get(&tag_str).map(|el| el.value.clone())
}

// -----------------------------------------------------------------------------
// DICOM metadata types
// -----------------------------------------------------------------------------

/// Represents different types of DICOM values.
#[derive(Clone, Debug)]
pub enum DicomValueType {
    Str(String),
    Int(i32),
    Float(f32),
    IntList(Vec<i32>),
    FloatList(Vec<f32>),
    StrList(Vec<String>),
    Unknown,
}

/// Represents a single DICOM tag with its value and metadata.
#[derive(Clone, Debug)]
pub struct DicomTag {
    pub tag: String,
    pub vr: String,
    pub name: String,
    pub value: DicomValueType,
}

/// Complete mapping of all DICOM metadata in a file.
#[derive(Clone, Debug)]
pub struct DicomMetadataMap {
    pub tags: HashMap<String, DicomTag>,
    pub group_elements: HashMap<String, HashMap<String, DicomTag>>,
}

/// Core metadata extracted from a DICOM file.
#[derive(Clone, Debug)]
pub struct DicomMetadata {
    pub patient_name: Option<String>,
    pub patient_id: Option<String>,
    pub study_date: Option<String>,
    pub accession_number: Option<String>,
    pub modality: Option<String>,
    pub study_description: Option<String>,
    pub series_description: Option<String>,
    pub instance_number: Option<i32>,
    pub series_number: Option<i32>,
    pub study_id: Option<String>,
    pub study_instance_uid: Option<String>,
    pub series_instance_uid: Option<String>,
    pub sop_instance_uid: Option<String>,
    pub image_position: Option<Vec<f64>>,
    pub image_orientation: Option<Vec<f64>>,
    pub slice_location: Option<f64>,
    pub slice_thickness: Option<f64>,
    pub spacing_between_slices: Option<f64>,
    pub pixel_spacing: Option<Vec<f64>>,
}

/// Represents a DICOM image’s pixel data and associated parameters.
#[derive(Clone, Debug)]
pub struct DicomImage {
    pub width: u32,
    pub height: u32,
    pub bits_allocated: u16,
    pub bits_stored: u16,
    pub high_bit: u16,
    pub pixel_representation: u16,
    pub photometric_interpretation: String,
    pub samples_per_pixel: u16,
    pub planar_configuration: Option<u16>,
    pub pixel_data: Vec<u8>,
}

/// Complete representation of a DICOM file.
#[derive(Clone, Debug)]
pub struct DicomFile {
    pub path: String,
    pub metadata: DicomMetadata,
    pub all_tags: Vec<DicomTag>,
    pub slices: Vec<DicomSlice>,
    pub is_multiframe: bool,
    pub num_frames: u32,
}

/// Represents a single DICOM instance (file) with spatial information.
#[derive(Clone, Debug)]
pub struct DicomInstance {
    pub path: String,
    pub sop_instance_uid: Option<String>,
    pub instance_number: Option<i32>,
    pub image_position: Option<Vec<f64>>,
    pub slice_location: Option<f64>,
    pub is_valid: bool,
}

/// Represents a DICOM series containing multiple image instances.
#[derive(Clone, Debug)]
pub struct DicomSeries {
    pub series_instance_uid: Option<String>,
    pub series_number: Option<i32>,
    pub series_description: Option<String>,
    pub modality: Option<String>,
    pub instances: Vec<DicomInstance>,
}

/// Represents a DICOM study containing multiple series.
#[derive(Clone, Debug)]
pub struct DicomStudy {
    pub study_instance_uid: Option<String>,
    pub study_date: Option<String>,
    pub study_description: Option<String>,
    pub accession_number: Option<String>,
    pub series: Vec<DicomSeries>,
}

/// Represents a patient with associated DICOM studies.
#[derive(Clone, Debug)]
pub struct DicomPatient {
    pub patient_id: Option<String>,
    pub patient_name: Option<String>,
    pub studies: Vec<DicomStudy>,
}

/// Legacy structure for backward compatibility.
#[derive(Clone, Debug)]
pub struct DicomDirectoryEntry {
    pub path: String,
    pub metadata: DicomMetadata,
    pub is_valid: bool,
}

/// Represents an entry in a DICOMDIR file.
#[derive(Clone, Debug)]
pub struct DicomDirEntry {
    pub path: String,
    pub type_name: String,
    pub metadata: HashMap<String, DicomValueType>,
    pub children: Vec<DicomDirEntry>,
}

/// Main interface for interacting with DICOM files and directories.
#[derive(Clone, Debug, Default)]
pub struct DicomHandler {}

/// Represents a single slice from a DICOM volume.
#[derive(Clone, Debug)]
pub struct DicomSlice {
    pub path: String,
    pub data: Vec<u8>,
}

/// Represents a 3D volume constructed from 2D DICOM slices.
#[derive(Clone, Debug)]
pub struct DicomVolume {
    pub width: u32,
    pub height: u32,
    pub depth: u32,
    pub spacing: (f64, f64, f64),
    pub data_type: String,
    pub num_components: u32,
    pub slices: Vec<DicomSlice>,
    pub metadata: DicomMetadata,
}

// -----------------------------------------------------------------------------
// DicomHandler implementation
// -----------------------------------------------------------------------------

impl DicomHandler {
    pub fn new() -> Self {
        Self {}
    }

    pub fn load_file(&self, path: String) -> Result<DicomFile, String> {
        load_dicom_file(path)
    }
    
    pub fn is_valid_dicom(&self, path: String) -> bool {
        is_dicom_file(path)
    }
    
    pub fn get_metadata(&self, path: String) -> Result<DicomMetadata, String> {
        let file_path = Path::new(&path);
        let obj = open_file(file_path).map_err(|e| format!("Failed to open DICOM file: {}", e))?;
        extract_metadata(&obj).map_err(|e| e.to_string())
    }
    
    pub fn get_all_tags(&self, path: String) -> Result<Vec<DicomTag>, String> {
        let file_path = Path::new(&path);
        let obj = open_file(file_path).map_err(|e| format!("Failed to open DICOM file: {}", e))?;
        extract_all_tags(&obj).map_err(|e| e.to_string())
    }
    
    pub fn get_tag_value(&self, path: String, tag_name: String) -> Result<DicomValueType, String> {
        get_tag_value(path, tag_name)
    }
    
    pub fn get_pixel_data(&self, path: String) -> Result<DicomImage, String> {
        extract_pixel_data(path)
    }
    
    pub fn get_image_bytes(&self, path: String) -> Result<Vec<u8>, String> {
        get_encoded_image(path)
    }
    
    pub fn load_directory(&self, path: String) -> Result<Vec<DicomDirectoryEntry>, String> {
        load_dicom_directory(path)
    }
    
    pub fn load_directory_recursive(&self, path: String) -> Result<Vec<DicomDirectoryEntry>, String> {
        load_dicom_directory_recursive(path)
    }
    
    pub fn list_tags(&self, path: String) -> Result<Vec<String>, String> {
        list_all_tags(path)
    }
    
    pub fn load_directory_organized(&self, path: String) -> Result<Vec<DicomPatient>, String> {
        load_dicom_directory_organized(path, false)
    }
    
    pub fn load_directory_recursive_organized(&self, path: String) -> Result<Vec<DicomPatient>, String> {
        load_dicom_directory_organized(path, true)
    }
    
    
    pub fn get_all_metadata(&self, path: String) -> Result<DicomMetadataMap, String> {
        extract_all_metadata(&path)
    }
    
    pub fn load_directory_unified(&self, path: String, recursive: bool) -> Result<Vec<DicomDirectoryEntry>, String> {
        load_dicom_directory_unified(path, recursive)
    }
    
    pub fn is_dicomdir(&self, path: String) -> bool {
        is_dicomdir_file(&path)
    }
    
    pub fn parse_dicomdir(&self, path: String) -> Result<DicomDirEntry, String> {
        parse_dicomdir_file(path)
    }
    
    pub async fn load_volume(&self, path: String, progress_callback: impl Fn(u32, u32) -> DartFnFuture<()> + Send + Sync + 'static,
) -> Result<DicomVolume, String> {
        load_volume_from_directory(path, progress_callback).await
    }
}

// -----------------------------------------------------------------------------
// File-level functions using the new extraction method (to_el)
// -----------------------------------------------------------------------------

/// Loads a DICOM file from the given path.
pub fn load_dicom_file(path: String) -> Result<DicomFile, String> {
    let file_path = Path::new(&path);
    let obj = open_file(file_path).map_err(|e| format!("Failed to open DICOM file: {}", e))?;

    // // Print all non-sequence elements using our new to_el method.
    // println!(
    //     "Elements:{:?}",
    //     obj.iter()
    //         .filter(|e| !e.header().is_non_primitive())
    //         .map(to_el)
    //         .collect::<Result<Vec<_>>>()
    // );
    
    // Log complete metadata map (using the updated extraction)
    let all_metadata = extract_all_metadata(&path).map_err(|e| e.to_string())?;
    // println!("All metadata: {:?}", all_metadata);
    
    // Extract common metadata for our DicomFile
    let metadata = extract_metadata(&obj).map_err(|e| e.to_string())?;
    // println!("Metadata: {:?}", metadata);
    
    // Extract all tags
    let all_tags = extract_all_tags(&obj).map_err(|e| e.to_string())?;

    // Check if this is a multi-frame DICOM
    let is_multiframe = is_multiframe_dicom(&obj);
    let num_frames = get_number_of_frames(&obj).unwrap_or(1);
    
    // Extract slices/frames
    let slices = extract_dicom_slices(& path)?;
    

    Ok(DicomFile { 
        path, 
        metadata, 
        all_tags, 
        slices,
        is_multiframe,
        num_frames, 
    })
}
/// Extracts common metadata from a DICOM object.
fn extract_metadata(obj: &FileDicomObject<InMemDicomObject>) -> Result<DicomMetadata> {

    // Extract and convert elements using our new function
    let elements = extract_metadata_elements(obj)?;
    
    let patient_name = get_value_from_elements(&elements, tags::PATIENT_NAME);
    let patient_id = get_value_from_elements(&elements, tags::PATIENT_ID);
    let study_date = get_value_from_elements(&elements, tags::STUDY_DATE);
    let accession_number = get_value_from_elements(&elements, tags::ACCESSION_NUMBER);
    let modality = get_value_from_elements(&elements, tags::MODALITY);
    let study_description = get_value_from_elements(&elements, tags::STUDY_DESCRIPTION);
    let series_description = get_value_from_elements(&elements, tags::SERIES_DESCRIPTION);
    let instance_number = get_value_from_elements(&elements, tags::INSTANCE_NUMBER).and_then(|s| s.parse::<i32>().ok());
    let series_number = get_value_from_elements(&elements, tags::SERIES_NUMBER).and_then(|s| s.parse::<i32>().ok());
    let study_id = get_value_from_elements(&elements, tags::STUDY_ID);
    let study_instance_uid = get_value_from_elements(&elements, tags::STUDY_INSTANCE_UID);
    let series_instance_uid = get_value_from_elements(&elements, tags::SERIES_INSTANCE_UID);
    let sop_instance_uid = get_value_from_elements(&elements, tags::SOP_INSTANCE_UID);

    // Helper closures to parse float values from backslash-separated strings.
    let parse_f64_vec = |s: Option<String>| -> Option<Vec<f64>> {
        s.and_then(|s| {
            let parts: Vec<f64> = s.split('\\')
                .filter_map(|p| p.trim().parse::<f64>().ok())
                .collect();
            if parts.is_empty() { None } else { Some(parts) }
        })
    };
    let parse_f64 = |s: Option<String>| -> Option<f64> {
        s.and_then(|s| s.trim().parse::<f64>().ok())
    };

    let image_position = parse_f64_vec(get_value_from_elements(&elements, tags::IMAGE_POSITION_PATIENT));
    let image_orientation = parse_f64_vec(get_value_from_elements(&elements, tags::IMAGE_ORIENTATION_PATIENT));
    let slice_location = parse_f64(get_value_from_elements(&elements, tags::SLICE_LOCATION));
    let slice_thickness = parse_f64(get_value_from_elements(&elements, tags::SLICE_THICKNESS));
    let spacing_between_slices = parse_f64(get_value_from_elements(&elements, tags::SPACING_BETWEEN_SLICES));
    let pixel_spacing = parse_f64_vec(get_value_from_elements(&elements, tags::PIXEL_SPACING));


    Ok(DicomMetadata {
        patient_name,
        patient_id,
        study_date,
        accession_number,
        modality,
        study_description,
        series_description,
        instance_number,
        series_number,
        study_id,
        study_instance_uid,
        series_instance_uid,
        sop_instance_uid,
        image_position,
        image_orientation,
        slice_location,
        slice_thickness,
        spacing_between_slices,
        pixel_spacing,
    })
}

/// Extracts all tags from a DICOM object.
fn extract_all_tags(obj: &FileDicomObject<InMemDicomObject>) -> Result<Vec<DicomTag>> {
    let elements = extract_metadata_elements(obj)?;
    let tags = elements.into_iter().map(|(_key, el)| {
        DicomTag {
            tag: el.tag.clone(),
            vr: el.vr.clone(),
            name: el.alias.to_string(),
            value: DicomValueType::Str(el.value.clone()),
        }
    }).collect();
    Ok(tags)
}

/// Extracts pixel data from a DICOM file.
pub fn extract_pixel_data(path: String) -> Result<DicomImage, String> {
    let file_path = Path::new(&path);
    let obj = open_file(file_path).map_err(|e| format!("Failed to open DICOM file: {}", e))?;

    let decoded = obj.decode_pixel_data().map_err(|e| format!("Failed to decode pixel data: {}", e))?;
    let height = decoded.rows() as u32;
    let width = decoded.columns() as u32;

    let bits_allocated = obj.element(tags::BITS_ALLOCATED)
        .map_err(|e| format!("Failed to get bits allocated: {}", e))?;
    let bits_allocated = bits_allocated.value().to_str().ok().and_then(|s| s.parse::<u16>().ok())
        .ok_or_else(|| "Invalid bits allocated format".to_string())?;

    let bits_stored = obj.element(tags::BITS_STORED)
        .map_err(|e| format!("Failed to get bits stored: {}", e))?;
    let bits_stored = bits_stored.value().to_str().ok().and_then(|s| s.parse::<u16>().ok())
        .ok_or_else(|| "Invalid bits stored format".to_string())?;

    let high_bit = obj.element(tags::HIGH_BIT)
        .map_err(|e| format!("Failed to get high bit: {}", e))?;
    let high_bit = high_bit.value().to_str().ok().and_then(|s| s.parse::<u16>().ok())
        .ok_or_else(|| "Invalid high bit format".to_string())?;

    let pixel_representation = obj.element(tags::PIXEL_REPRESENTATION)
        .map_err(|e| format!("Failed to get pixel representation: {}", e))?;
    let pixel_representation = pixel_representation.value().to_str().ok().and_then(|s| s.parse::<u16>().ok())
        .ok_or_else(|| "Invalid pixel representation format".to_string())?;

    let photometric_interpretation = obj.element(tags::PHOTOMETRIC_INTERPRETATION)
        .map_err(|e| format!("Failed to get photometric interpretation: {}", e))?
        .value().to_str().unwrap_or(std::borrow::Cow::Borrowed("MONOCHROME2")).to_string();

    let samples_per_pixel = obj.element(tags::SAMPLES_PER_PIXEL)
        .map_err(|e| format!("Failed to get samples per pixel: {}", e))?;
    let samples_per_pixel = samples_per_pixel.value().to_str().ok().and_then(|s| s.parse::<u16>().ok())
        .ok_or_else(|| "Invalid samples per pixel format".to_string())?;

    let planar_configuration = obj.element(tags::PLANAR_CONFIGURATION).ok()
        .and_then(|e| e.value().to_str().ok().and_then(|s| s.parse::<u16>().ok()));
    let options = ConvertOptions::new()
    .with_voi_lut(VoiLutOption::Default)  // Bypass LUT creation
    .with_bit_depth(BitDepthOption::Auto);
let dynamic_image = decoded.to_dynamic_image_with_options(0, &options)
    .map_err(|e| format!("Failed to convert to image: {}", e))?;


    Ok(DicomImage {
        width,
        height,
        bits_allocated,
        bits_stored,
        high_bit,
        pixel_representation,
        photometric_interpretation,
        samples_per_pixel,
        planar_configuration,
        pixel_data: dynamic_image.as_bytes().to_vec(),
    })
}

/// Gets a specific tag value from a DICOM file.
pub fn get_tag_value(path: String, tag_name: String) -> Result<DicomValueType, String> {
    let file_path = Path::new(&path);
    let obj = open_file(file_path).map_err(|e| format!("Failed to open DICOM file: {}", e))?;
    let element = obj.element_by_name(&tag_name)
        .map_err(|e| format!("Failed to find tag '{}': {}", tag_name, e))?;
    Ok(DicomValueType::Str(element.value().to_str().unwrap_or_default().to_string()))
}

/// Check if a file is a valid DICOM file.
pub fn is_dicom_file(path: String) -> bool {
    let file_path = Path::new(&path);
    open_file(file_path).is_ok()
}

/// Get a list of all DICOM tags in a file.
pub fn list_all_tags(path: String) -> Result<Vec<String>, String> {
    let file_path = Path::new(&path);
    let obj = open_file(file_path).map_err(|e| format!("Failed to open DICOM file: {}", e))?;
    let elements: Vec<El> = obj.iter()
        .filter(|e| !e.header().is_non_primitive())
        .map(to_el)
        .collect::<Result<Vec<_>>>().map_err(|e| e.to_string())?;
    let tag_names: Vec<String> = elements.iter().map(|el| el.alias.to_string()).collect();
    Ok(tag_names)
}

/// Get encoded image bytes (PNG) from a DICOM file.
pub fn get_encoded_image(path: String) -> Result<Vec<u8>, String> {
    let file_path = Path::new(&path);
    let obj = open_file(file_path).map_err(|e| format!("Failed to open DICOM file: {}", e))?;
    let decoded = obj.decode_pixel_data().map_err(|e| format!("Failed to decode pixel data: {}", e))?;
    let options = ConvertOptions::new()
        .with_voi_lut(VoiLutOption::Default)
        .with_bit_depth(BitDepthOption::Auto);
    let dynamic_image = decoded.to_dynamic_image_with_options(0, &options)
        .map_err(|e| format!("Failed to convert to image: {}", e))?;
    let mut encoded_bytes: Vec<u8> = Vec::new();
    let mut cursor = Cursor::new(&mut encoded_bytes);
    dynamic_image.write_to(&mut cursor, image::ImageFormat::Png)
        .map_err(|e| format!("Failed to encode image: {}", e))?;
    Ok(encoded_bytes)
}

/// Loads all DICOM files from a directory.
pub fn load_dicom_directory(dir_path: String) -> Result<Vec<DicomDirectoryEntry>, String> {
    let path = Path::new(&dir_path);
    if !path.exists() || !path.is_dir() {
        return Err(format!("Invalid directory path: {}", dir_path));
    }
    let dir_entries = fs::read_dir(path).map_err(|e| format!("Failed to read directory: {}", e))?;
    let mut result = Vec::new();
    let mut first_error = None;
    
    for entry in dir_entries {
        if let Ok(entry) = entry {
            let file_path = entry.path();
            if file_path.is_dir() {
                continue;
            }
            let path_str = file_path.to_str().unwrap_or("").to_string();
            if is_dicom_file(path_str.clone()) {
                match open_file(&file_path) {
                    Ok(obj) => {
                        match extract_metadata(&obj) {
                            Ok(metadata) => {
                                result.push(DicomDirectoryEntry {
                                    path: path_str,
                                    metadata,
                                    is_valid: true,
                                });
                            }
                            Err(e) => {
                                if first_error.is_none() {
                                    first_error = Some(format!("Failed to extract metadata from DICOM file: {}", path_str));
                                }
                            }
                        }
                    }
                    Err(e) => {
                        if first_error.is_none() {
                            first_error = Some(format!("Failed to open DICOM file: {}", path_str));
                        }
                    }
                }
            }
        }
    }
    
    if result.is_empty() && first_error.is_some() {
        return Err(first_error.unwrap());
    }
    
    sort_dicom_entries(&mut result);
    Ok(result)
}

/// Loads all DICOM files recursively from a directory.
pub fn load_dicom_directory_recursive(dir_path: String) -> Result<Vec<DicomDirectoryEntry>, String> {
    let path = Path::new(&dir_path);
    if !path.exists() || !path.is_dir() {
        return Err(format!("Invalid directory path: {}", dir_path));
    }
    let mut result = Vec::new();
    process_directory_recursive(path, &mut result)?;
    sort_dicom_entries(&mut result);
    Ok(result)
}

/// Loads all DICOM files from a directory and organizes them hierarchically.
pub fn load_dicom_directory_organized(dir_path: String, recursive: bool) -> Result<Vec<DicomPatient>, String> {
    let entries = if recursive {
        load_dicom_directory_recursive(dir_path)?
    } else {
        load_dicom_directory(dir_path)?
    };
    organize_dicom_entries(entries)
}

/// Organizes a flat list of DICOM entries into a hierarchical structure.
fn organize_dicom_entries(entries: Vec<DicomDirectoryEntry>) -> Result<Vec<DicomPatient>, String> {
    let mut patients_map: HashMap<String, DicomPatient> = HashMap::new();
    for entry in entries {
        if !entry.is_valid {
            continue;
        }
        let meta = &entry.metadata;
        let patient_id = meta.patient_id.clone().unwrap_or_else(|| "UNKNOWN".to_string());
        let study_uid = meta.study_instance_uid.clone().unwrap_or_else(|| "UNKNOWN".to_string());
        let series_uid = meta.series_instance_uid.clone().unwrap_or_else(|| "UNKNOWN".to_string());
        let instance = DicomInstance {
            path: entry.path,
            sop_instance_uid: meta.sop_instance_uid.clone(),
            instance_number: meta.instance_number,
            image_position: meta.image_position.clone(),
            slice_location: meta.slice_location,
            is_valid: entry.is_valid,
        };
        let patient = patients_map.entry(patient_id.clone()).or_insert_with(|| DicomPatient {
            patient_id: Some(patient_id.clone()),
            patient_name: meta.patient_name.clone(),
            studies: Vec::new(),
        });
        let mut found_study = false;
        for study in &mut patient.studies {
            if let Some(existing_uid) = &study.study_instance_uid {
                if *existing_uid == study_uid {
                    found_study = true;
                    let mut found_series = false;
                    for series in &mut study.series {
                        if let Some(existing_series_uid) = &series.series_instance_uid {
                            if *existing_series_uid == series_uid {
                                found_series = true;
                                series.instances.push(instance.clone());
                                break;
                            }
                        }
                    }
                    if !found_series {
                        let new_series = DicomSeries {
                            series_instance_uid: Some(series_uid.clone()),
                            series_number: meta.series_number,
                            series_description: meta.series_description.clone(),
                            modality: meta.modality.clone(),
                            instances: vec![instance.clone()],
                        };
                        study.series.push(new_series);
                    }
                    break;
                }
            }
        }
        if !found_study {
            let new_study = DicomStudy {
                study_instance_uid: Some(study_uid),
                study_date: meta.study_date.clone(),
                study_description: meta.study_description.clone(),
                accession_number: meta.accession_number.clone(),
                series: vec![DicomSeries {
                    series_instance_uid: Some(series_uid),
                    series_number: meta.series_number,
                    series_description: meta.series_description.clone(),
                    modality: meta.modality.clone(),
                    instances: vec![instance],
                }],
            };
            patient.studies.push(new_study);
        }
    }
    let mut patients: Vec<DicomPatient> = patients_map.into_values().collect();
    sort_dicom_hierarchy(&mut patients);
    Ok(patients)
}

/// Sorts the entire DICOM hierarchy.
fn sort_dicom_hierarchy(patients: &mut Vec<DicomPatient>) {
    patients.sort_by(|a, b| {
        let name_a = a.patient_name.as_deref().unwrap_or("Unknown");
        let name_b = b.patient_name.as_deref().unwrap_or("Unknown");
        name_a.cmp(name_b)
    });
    for patient in patients {
        patient.studies.sort_by(|a, b| {
            let date_a = a.study_date.as_deref().unwrap_or("");
            let date_b = b.study_date.as_deref().unwrap_or("");
            date_b.cmp(date_a)
        });
        for study in &mut patient.studies {
            study.series.sort_by(|a, b| {
                match (&a.series_number, &b.series_number) {
                    (Some(a_num), Some(b_num)) => a_num.cmp(b_num),
                    (Some(_), None) => Ordering::Less,
                    (None, Some(_)) => Ordering::Greater,
                    (None, None) => Ordering::Equal,
                }
            });
            for series in &mut study.series {
                sort_instances_by_position(&mut series.instances);
            }
        }
    }
}

/// Sorts DICOM instances based on spatial information.
fn sort_instances_by_position(instances: &mut Vec<DicomInstance>) {
    let has_slice_locations = instances.iter().any(|i| i.slice_location.is_some());
    if has_slice_locations {
        instances.sort_by(|a, b| {
            match (a.slice_location, b.slice_location) {
                (Some(loc_a), Some(loc_b)) => loc_a.partial_cmp(&loc_b).unwrap_or(Ordering::Equal),
                (Some(_), None) => Ordering::Less,
                (None, Some(_)) => Ordering::Greater,
                (None, None) => Ordering::Equal,
            }
        });
        return;
    }
    let has_positions = instances.iter().any(|i| i.image_position.as_ref().map(|v| v.len() >= 3).unwrap_or(false));
    if has_positions {
        if let Some(first_instance) = instances.first() {
            if let Some(pos0) = &first_instance.image_position {
                if pos0.len() >= 3 {
                    instances.sort_by(|a, b| {
                        if let (Some(pos_a), Some(pos_b)) = (&a.image_position, &b.image_position) {
                            if pos_a.len() >= 3 && pos_b.len() >= 3 {
                                return pos_a[2].partial_cmp(&pos_b[2]).unwrap_or(Ordering::Equal);
                            }
                        }
                        match (a.instance_number, b.instance_number) {
                            (Some(a_num), Some(b_num)) => a_num.cmp(&b_num),
                            (Some(_), None) => Ordering::Less,
                            (None, Some(_)) => Ordering::Greater,
                            (None, None) => Ordering::Equal,
                        }
                    });
                    return;
                }
            }
        }
    }
    instances.sort_by(|a, b| {
        match (a.instance_number, b.instance_number) {
            (Some(a_num), Some(b_num)) => a_num.cmp(&b_num),
            (Some(_), None) => Ordering::Less,
            (None, Some(_)) => Ordering::Greater,
            (None, None) => Ordering::Equal,
        }
    });
}

/// Helper function to sort DICOM directory entries.
fn sort_dicom_entries(entries: &mut Vec<DicomDirectoryEntry>) {
    entries.sort_by(|a, b| {
        let series_cmp = match (&a.metadata.series_number, &b.metadata.series_number) {
            (Some(a_series), Some(b_series)) => a_series.cmp(b_series),
            (Some(_), None) => Ordering::Less,
            (None, Some(_)) => Ordering::Greater,
            (None, None) => Ordering::Equal,
        };
        if series_cmp == Ordering::Equal {
            match (&a.metadata.instance_number, &b.metadata.instance_number) {
                (Some(a_instance), Some(b_instance)) => a_instance.cmp(b_instance),
                (Some(_), None) => Ordering::Less,
                (None, Some(_)) => Ordering::Greater,
                (None, None) => Ordering::Equal,
            }
        } else {
            series_cmp
        }
    });
}

/// Recursively processes directories.
fn process_directory_recursive(dir_path: &Path, result: &mut Vec<DicomDirectoryEntry>) -> Result<(), String> {
    let dir_entries = fs::read_dir(dir_path).map_err(|e| format!("Failed to read directory: {}", e))?;
    for entry in dir_entries {
        if let Ok(entry) = entry {
            let file_path = entry.path();
            if file_path.is_dir() {
                process_directory_recursive(&file_path, result)?;
            } else {
                let path_str = file_path.to_str().unwrap_or("").to_string();
                if is_dicom_file(path_str.clone()) {
                    match open_file(&file_path) {
                        Ok(obj) => {
                            match extract_metadata(&obj) {
                                Ok(metadata) => {
                                    result.push(DicomDirectoryEntry {
                                        path: path_str,
                                        metadata,
                                        is_valid: true,
                                    });
                                }
                                Err(e) => return Err(format!("Failed to extract metadata from '{}': {}", path_str, e)),
                            }
                        }
                        Err(e) => return Err(format!("Failed to open DICOM file '{}': {}", path_str, e)),
                    }
                }
            }
        }
    }
    Ok(())
}

/// Extracts all metadata from a DICOM file as a complete map.
pub fn extract_all_metadata(path: &str) -> Result<DicomMetadataMap, String> {
    let file_path = Path::new(path);
    let obj = open_file(file_path).map_err(|e| format!("Failed to open DICOM file: {}", e))?;
    
    let elements = extract_metadata_elements(&obj).map_err(|e| e.to_string())?;
    let mut tags = HashMap::new();
    let mut group_elements = HashMap::new();
    
    for (_key, el) in elements {
        let tag_str = el.tag.clone();
        let group = &tag_str[0..4];
        let element_str = &tag_str[4..8];
        let dicom_tag = DicomTag {
            tag: tag_str.clone(),
            vr: el.vr.clone(),
            name: el.alias.to_string(),
            value: DicomValueType::Str(el.value.clone()),
        };
        tags.insert(tag_str.clone(), dicom_tag.clone());
        group_elements.entry(group.to_string()).or_insert_with(HashMap::new).insert(element_str.to_string(), dicom_tag);
    }
    
    Ok(DicomMetadataMap { tags, group_elements })
}

/// Checks if a file is a DICOMDIR file.
pub fn is_dicomdir_file(path: &str) -> bool {
    let file_path = Path::new(path);
    if (!file_path.exists()) {
        return false;
    }
    if (!is_dicom_file(path.to_string())) {
        return false;
    }
    if let Ok(obj) = open_file(file_path) {
        if let Ok(elem) = obj.element(tags::MEDIA_STORAGE_SOP_CLASS_UID) {
            if let Some(sop_class) = elem.value().to_str().ok() {
                return sop_class == "1.2.840.10008.1.3.10";
            }
        }
    }
    false
}

/// Parses a DICOMDIR file.
pub fn parse_dicomdir_file(path: String) -> Result<DicomDirEntry, String> {
    let file_path = Path::new(&path);
    if (!file_path.exists()) {
        return Err(format!("File not found: {}", path));
    }
    if (!is_dicomdir_file(&path)) {
        return Err(format!("Not a valid DICOMDIR file: {}", path));
    }
    let obj = open_file(file_path).map_err(|e| format!("Failed to open DICOMDIR file: {}", e))?;
    let dir_record_sequence = obj.element(tags::DIRECTORY_RECORD_SEQUENCE)
        .map_err(|e| format!("Failed to find directory record sequence: {}", e))?;
    let mut root = DicomDirEntry {
        path: path.clone(),
        type_name: "ROOT".to_string(),
        metadata: HashMap::new(),
        children: Vec::new(),
    };
    if let Ok(elem) = obj.element(tags::MEDIA_STORAGE_SOP_INSTANCE_UID) {
        if let Some(uid) = elem.value().to_str().ok() {
            root.metadata.insert("MediaStorageSOPInstanceUID".to_string(), DicomValueType::Str(uid.to_string()));
        }
    }
    if let Value::Sequence(seq) = dir_record_sequence.value() {
        parse_dicomdir_records(seq, &mut root, file_path.parent().unwrap_or(Path::new("")));
    }
    Ok(root)
}

/// Recursively parses DICOMDIR records.
fn parse_dicomdir_records(seq: &DataSetSequence<InMemDicomObject>, parent: &mut DicomDirEntry, base_path: &Path) {
    for record in seq.items() {
        let record_type = record.element(tags::DIRECTORY_RECORD_TYPE)
            .ok()
            .and_then(|e| e.value().to_str().ok())
            .unwrap_or_else(|| "UNKNOWN".to_string().into());
        let mut entry = DicomDirEntry {
            path: "".to_string(),
            type_name: record_type.to_string(),
            metadata: HashMap::new(),
            children: Vec::new(),
        };
        extract_dicomdir_record_metadata(record, &mut entry);
        if record_type == "IMAGE" {
            if let Ok(elem) = record.element(tags::REFERENCED_FILE_ID) {
                if let Some(file_path) = elem.value().to_str().ok() {
                    let path_parts: Vec<&str> = file_path.split('\\').collect();
                    let file_path = path_parts.join(std::path::MAIN_SEPARATOR.to_string().as_str());
                    let full_path = base_path.join(file_path);
                    if let Some(path_str) = full_path.to_str() {
                        entry.path = path_str.to_string();
                    }
                }
            }
        }
        let lower_level_tag = Tag::from((0x0004, 0x1420));
        if let Ok(elem) = record.element(lower_level_tag) {
            if let Value::Sequence(ref lower_seq) = elem.value() {
                parse_dicomdir_records(lower_seq, &mut entry, base_path);
            }
        }
        parent.children.push(entry);
    }
}

/// Extracts metadata from a DICOMDIR record.
fn extract_dicomdir_record_metadata(record: &InMemDicomObject, entry: &mut DicomDirEntry) {
    let tags_to_extract = [
        (tags::SPECIFIC_CHARACTER_SET, "SpecificCharacterSet"),
        (tags::PATIENT_ID, "PatientID"),
        (tags::PATIENT_NAME, "PatientName"),
        (tags::PATIENT_BIRTH_DATE, "PatientBirthDate"),
        (tags::PATIENT_SEX, "PatientSex"),
        (tags::STUDY_DATE, "StudyDate"),
        (tags::STUDY_TIME, "StudyTime"),
        (tags::STUDY_DESCRIPTION, "StudyDescription"),
        (tags::STUDY_INSTANCE_UID, "StudyInstanceUID"),
        (tags::SERIES_DESCRIPTION, "SeriesDescription"),
        (tags::SERIES_NUMBER, "SeriesNumber"),
        (tags::MODALITY, "Modality"),
        (tags::SERIES_INSTANCE_UID, "SeriesInstanceUID"),
        (tags::INSTANCE_NUMBER, "InstanceNumber"),
        (tags::SOP_INSTANCE_UID, "SOPInstanceUID"),
    ];
    for (tag, name) in tags_to_extract.iter() {
        if let Ok(elem) = record.element(*tag) {
            if let Some(text) = elem.value().to_str().ok() {
                entry.metadata.insert(name.to_string(), DicomValueType::Str(text.to_string()));
            }
        }
    }
}

/// Unified function to load DICOM files from a directory.
pub fn load_dicom_directory_unified(dir_path: String, recursive: bool) -> Result<Vec<DicomDirectoryEntry>, String> {
    let path = Path::new(&dir_path);
    if (!path.exists() || !path.is_dir()) {
        return Err(format!("Invalid directory path: {}", dir_path));
    }
    let potential_dicomdir = path.join("DICOMDIR");
    let potential_dicomdir_lower = path.join("dicomdir");
    if (potential_dicomdir.exists() && is_dicomdir_file(potential_dicomdir.to_str().unwrap_or(""))) {
        return load_from_dicomdir(potential_dicomdir.to_str().unwrap_or("").to_string());
    } else if (potential_dicomdir_lower.exists() && is_dicomdir_file(potential_dicomdir_lower.to_str().unwrap_or(""))) {
        return load_from_dicomdir(potential_dicomdir_lower.to_str().unwrap_or("").to_string());
    }
    if (recursive) {
        load_dicom_directory_recursive(dir_path)
    } else {
        load_dicom_directory(dir_path)
    }
}

/// Loads DICOM files from a DICOMDIR catalog.
fn load_from_dicomdir(dicomdir_path: String) -> Result<Vec<DicomDirectoryEntry>, String> {
    let dicomdir = parse_dicomdir_file(dicomdir_path.clone())?;
    let mut result = Vec::new();
    process_dicomdir_entries(&dicomdir, &mut result);
    if (result.is_empty()) {
        return Err(format!("No valid DICOM images found in DICOMDIR: {}", dicomdir_path));
    }
    sort_dicom_entries_by_position(&mut result)?;
    Ok(result)
}

/// Processes DICOMDIR entries recursively.
fn process_dicomdir_entries(entry: &DicomDirEntry, result: &mut Vec<DicomDirectoryEntry>) {
    if (entry.type_name == "IMAGE" && !entry.path.is_empty() && Path::new(&entry.path).exists()) {
        let metadata = create_metadata_from_dicomdir_entry(entry);
        let mut dicom_entry = DicomDirectoryEntry {
            path: entry.path.clone(),
            metadata,
            is_valid: true,
        };
        if let Ok(obj) = open_file(&entry.path) {
            if let Ok(full_metadata) = extract_metadata(&obj) {
                dicom_entry.metadata = full_metadata;
            }
        }
        result.push(dicom_entry);
    }
    for child in &entry.children {
        process_dicomdir_entries(child, result);
    }
}

/// Creates basic metadata from a DICOMDIR entry.
fn create_metadata_from_dicomdir_entry(entry: &DicomDirEntry) -> DicomMetadata {
    let mut metadata = DicomMetadata {
        patient_name: None,
        patient_id: None,
        study_date: None,
        accession_number: None,
        modality: None,
        study_description: None,
        series_description: None,
        instance_number: None,
        series_number: None,
        study_id: None,
        study_instance_uid: None,
        series_instance_uid: None,
        sop_instance_uid: None,
        image_position: None,
        image_orientation: None,
        slice_location: None,
        slice_thickness: None,
        spacing_between_slices: None,
        pixel_spacing: None,
    };
    for (key, value) in &entry.metadata {
        match key.as_str() {
            "PatientName" => {
                if let DicomValueType::Str(name) = value {
                    metadata.patient_name = Some(name.clone());
                }
            },
            "PatientID" => {
                if let DicomValueType::Str(id) = value {
                    metadata.patient_id = Some(id.clone());
                }
            },
            "StudyDate" => {
                if let DicomValueType::Str(date) = value {
                    metadata.study_date = Some(date.clone());
                }
            },
            "StudyDescription" => {
                if let DicomValueType::Str(desc) = value {
                    metadata.study_description = Some(desc.clone());
                }
            },
            "SeriesDescription" => {
                if let DicomValueType::Str(desc) = value {
                    metadata.series_description = Some(desc.clone());
                }
            },
            "StudyInstanceUID" => {
                if let DicomValueType::Str(uid) = value {
                    metadata.study_instance_uid = Some(uid.clone());
                }
            },
            "SeriesInstanceUID" => {
                if let DicomValueType::Str(uid) = value {
                    metadata.series_instance_uid = Some(uid.clone());
                }
            },
            "SOPInstanceUID" => {
                if let DicomValueType::Str(uid) = value {
                    metadata.sop_instance_uid = Some(uid.clone());
                }
            },
            "InstanceNumber" => {
                if let DicomValueType::Int(num) = value {
                    metadata.instance_number = Some(*num);
                }
            },
            "SeriesNumber" => {
                if let DicomValueType::Int(num) = value {
                    metadata.series_number = Some(*num);
                }
            },
            "Modality" => {
                if let DicomValueType::Str(modality) = value {
                    metadata.modality = Some(modality.clone());
                }
            },
            _ => {}
        }
    }
    metadata
}

/// Sorts DICOM entries based on spatial information.
fn sort_dicom_entries_by_position(entries: &mut Vec<DicomDirectoryEntry>) -> Result<(), String> {
    if let Some(first_with_orientation) = entries.iter().find(|e| {
        e.metadata.image_orientation.as_ref().map(|v| v.len() >= 6).unwrap_or(false) &&
        e.metadata.image_position.as_ref().map(|v| v.len() >= 3).unwrap_or(false)
    }) {
        let orient = first_with_orientation.metadata.image_orientation.as_ref().ok_or("Missing image orientation")?;
        if orient.len() < 6 {
            return Err("Image orientation must have at least 6 values".to_string());
        }
        let mut normal = [0.0, 0.0, 1.0];
        normal[0] = (orient[1] * orient[5]) - (orient[2] * orient[4]);
        normal[1] = (orient[2] * orient[3]) - (orient[0] * orient[5]);
        normal[2] = (orient[0] * orient[4]) - (orient[1] * orient[3]);
        let mut proj_vals = Vec::new();
        for entry in entries.iter() {
            if let Some(pos) = &entry.metadata.image_position {
                if pos.len() >= 3 {
                    let proj = normal[0] * pos[0] + normal[1] * pos[1] + normal[2] * pos[2];
                    proj_vals.push(proj);
                    if proj_vals.len() == 2 {
                        break;
                    }
                }
            }
        }
        if proj_vals.len() >= 2 {
            let reverse = proj_vals[0] > proj_vals[1];
            entries.sort_by(|a, b| {
                let default_pos = vec![0.0, 0.0, 0.0];
                let pos_a = a.metadata.image_position.as_ref().unwrap_or(&default_pos);
                let pos_b = b.metadata.image_position.as_ref().unwrap_or(&default_pos);
                let proj_a = if pos_a.len() >= 3 { normal[0] * pos_a[0] + normal[1] * pos_a[1] + normal[2] * pos_a[2] } else { 0.0 };
                let proj_b = if pos_b.len() >= 3 { normal[0] * pos_b[0] + normal[1] * pos_b[1] + normal[2] * pos_b[2] } else { 0.0 };
                if reverse {
                    proj_b.partial_cmp(&proj_a).unwrap_or(Ordering::Equal)
                } else {
                    proj_a.partial_cmp(&proj_b).unwrap_or(Ordering::Equal)
                }
            });
            return Ok(());
        }
    }
    let has_slice_loc = entries.iter().any(|e| e.metadata.slice_location.is_some());
    if has_slice_loc {
        entries.sort_by(|a, b| {
            match (a.metadata.slice_location, b.metadata.slice_location) {
                (Some(loc_a), Some(loc_b)) => loc_a.partial_cmp(&loc_b).unwrap_or(Ordering::Equal),
                (Some(_), None) => Ordering::Less,
                (None, Some(_)) => Ordering::Greater,
                (None, None) => Ordering::Equal,
            }
        });
        return Ok(());
    }
    sort_dicom_entries(entries);
    Ok(())
}

/// Computes slice spacing based on consecutive slices.
pub fn compute_slice_spacing(entries: &Vec<DicomDirectoryEntry>) -> Option<f64> {
    if entries.len() < 2 {
        return None;
    }
    let has_positions = entries.iter().any(|e| e.metadata.image_position.is_some() && e.metadata.image_position.as_ref().unwrap().len() >= 3);
    if has_positions {
        for i in 0..entries.len()-1 {
            if let (Some(pos1), Some(pos2)) = (&entries[i].metadata.image_position, &entries[i+1].metadata.image_position) {
                if pos1.len() >= 3 && pos2.len() >= 3 {
                    let dx = pos2[0] - pos1[0];
                    let dy = pos2[1] - pos1[1];
                    let dz = pos2[2] - pos1[2];
                    return Some((dx*dx + dy*dy + dz*dz).sqrt());
                }
            }
        }
    }
    let has_slice_loc = entries.iter().any(|e| e.metadata.slice_location.is_some());
    if has_slice_loc {
        for i in 0..entries.len()-1 {
            if let (Some(loc1), Some(loc2)) = (entries[i].metadata.slice_location, entries[i+1].metadata.slice_location) {
                return Some((loc2 - loc1).abs());
            }
        }
    }
    entries.iter().find_map(|e| e.metadata.slice_thickness)
}

/// Flips the image data vertically.
pub fn flip_vertically(pixel_data: &[u8], height: u32, row_length: usize) -> Vec<u8> {
    let height_usize = height as usize;
    let mut flipped = Vec::with_capacity(pixel_data.len());
    for row in 0..height_usize {
        let start = (height_usize - 1 - row) * row_length;
        let end = start + row_length;
        flipped.extend_from_slice(&pixel_data[start..end]);
    }
    flipped
}

/// Computes the row length for an image slice.
fn compute_row_length(width: u32, bits_allocated: u16, samples_per_pixel: u16) -> usize {
    let bytes_per_sample = ((bits_allocated as usize) + 7) / 8;
    (width as usize) * bytes_per_sample * (samples_per_pixel as usize)
}

/// Loads a multi-slice volume from a directory of DICOM files.
pub async fn load_volume_from_directory(
    dir_path: String,
    progress_callback: impl Fn(u32, u32) -> DartFnFuture<()> + Send + Sync + 'static,
) -> Result<DicomVolume, String> {
    let mut entries = load_dicom_directory(dir_path.clone())?;
    if entries.is_empty() {
        return Err("No valid DICOM files found in directory".to_string());
    }
    sort_dicom_entries_by_position(&mut entries)?;
    
    let first_entry = &entries[0];
    let first_image = extract_pixel_data(first_entry.path.clone())?;
    let width = first_image.width;
    let height = first_image.height;
    let bits_allocated = first_image.bits_allocated;
    let samples_per_pixel = first_image.samples_per_pixel;
    
    // Extract metadata from the first image
    let obj = open_file(Path::new(&first_entry.path)).map_err(|e| format!("Failed to open DICOM file: {}", e))?;
    let metadata = extract_metadata(&obj).map_err(|e| e.to_string())?;

    // Extract all slices using our new parallel extraction function
    let slices = extract_slices_from_directory(&dir_path, progress_callback).await?;
    
    let depth = slices.len() as u32;
    let spacing_xy = match &first_entry.metadata.pixel_spacing {
        Some(ps) if ps.len() >= 2 => (ps[0], ps[1]),
        _ => return Err("Pixel spacing not found".to_string()),
    };
    let spacing_z = match compute_slice_spacing(&entries) {
        Some(spacing) => spacing,
        None => return Err("Slice spacing not found".to_string()),
    };
    let data_type = if bits_allocated <= 8 { "unsigned char".to_string() } else { "unsigned short".to_string() };
    
    Ok(DicomVolume {
        width,
        height,
        depth,
        spacing: (spacing_xy.0, spacing_xy.1, spacing_z),
        data_type,
        num_components: samples_per_pixel as u32,
        slices,
        metadata,
    })
}

/// Checks if a DICOM object is multi-frame.
fn is_multiframe_dicom(obj: &FileDicomObject<InMemDicomObject>) -> bool {
    // Check for Number of Frames tag
    if let Ok(elem) = obj.element(tags::NUMBER_OF_FRAMES) {
        if let Some(frames_str) = elem.value().to_str().ok() {
            if let Ok(frames) = frames_str.parse::<u32>() {
                return frames > 1;
            }
        }
    }
    false
}

/// Gets the number of frames in a DICOM object.
fn get_number_of_frames(obj: &FileDicomObject<InMemDicomObject>) -> Option<u32> {
    if let Ok(elem) = obj.element(tags::NUMBER_OF_FRAMES) {
        if let Some(frames_str) = elem.value().to_str().ok() {
            return frames_str.parse::<u32>().ok();
        }
    }
    None
}

/// Extracts data for a specific frame from a multi-frame DICOM.
fn extract_frame_data(obj: &FileDicomObject<InMemDicomObject>, frame_index: u32) -> Result<Vec<u8>, String> {
    let decoded = obj.decode_pixel_data()
        .map_err(|e| format!("Failed to decode pixel data: {}", e))?;
    
    let options = ConvertOptions::new()
        .with_voi_lut(VoiLutOption::Default)
        .with_bit_depth(BitDepthOption::Auto);
    
    // Get the specified frame
    let frame_idx = frame_index as usize;
    
    // Check if the frame index is valid
    if frame_idx >= decoded.number_of_frames().try_into().unwrap() {
        return Err(format!("Frame index {} out of bounds (max: {})", 
            frame_idx, decoded.number_of_frames() - 1));
    }
    
    let dynamic_image = decoded.to_dynamic_image_with_options(frame_idx.try_into().unwrap(), &options)
        .map_err(|e| format!("Failed to convert frame {} to image: {}", frame_idx, e))?;
    
    let mut encoded_bytes: Vec<u8> = Vec::new();
    let mut cursor = Cursor::new(&mut encoded_bytes);
    dynamic_image.write_to(&mut cursor, image::ImageFormat::Png)
        .map_err(|e| format!("Failed to encode frame {} as PNG: {}", frame_idx, e))?;
    
    Ok(encoded_bytes)
}

/// Extracts a single slice (or frame) from a DICOM file
pub fn extract_dicom_slice(path: &str, frame_index: Option<u32>) -> Result<DicomSlice, String> {
    let file_path = Path::new(path);
    let obj = open_file(file_path).map_err(|e| format!("Failed to open DICOM file: {}", e))?;
    
    if let Some(frame_idx) = frame_index {
        // Extract specific frame from multiframe DICOM
        let frame_data = extract_frame_data(&obj, frame_idx)?;
        Ok(DicomSlice {
            path: path.to_string(),
            data: frame_data,
        })
    } else {
        // Extract image data from regular DICOM
        let image_data = get_encoded_image(path.to_string())?;
        Ok(DicomSlice {
            path: path.to_string(),
            data: image_data,
        })
    }
}

/// Extracts all slices from a DICOM file (handles both multiframe and regular DICOMs)
pub fn extract_dicom_slices(path: &str) -> Result<Vec<DicomSlice>, String> {
    let file_path = Path::new(path);
    let obj = open_file(file_path).map_err(|e| format!("Failed to open DICOM file: {}", e))?;
    
    let is_multiframe = is_multiframe_dicom(&obj);
    let mut slices = Vec::new();
    
    if is_multiframe {
        // Handle multi-frame DICOM
        let num_frames = get_number_of_frames(&obj).unwrap_or(1);
        for frame_index in 0..num_frames {
            match extract_dicom_slice(path, Some(frame_index)) {
                Ok(slice) => slices.push(slice),
                Err(e) => return Err(format!("Failed to extract frame {}: {}", frame_index, e)),
            }
        }
    } else {
        // Handle single-frame DICOM
        match extract_dicom_slice(path, None) {
            Ok(slice) => slices.push(slice),
            Err(e) => return Err(format!("Failed to extract slice: {}", e)),
        }
    }
    
    Ok(slices)
}

/// Extracts slices from multiple DICOM files in a directory with parallel processing
pub async fn extract_slices_from_directory(
    dir_path: &str,
    progress_callback: impl Fn(u32, u32) -> DartFnFuture<()> + Send + Sync + 'static,
) -> Result<Vec<DicomSlice>, String> {
    let entries = load_dicom_directory(dir_path.to_string())?;
    if entries.is_empty() {
        return Err("No valid DICOM files found in directory".to_string());
    }
    
    let total_files = entries.len() as u32;
    
    // Report initial progress if callback provided
    progress_callback(0, total_files).await;
    
    
    // Prepare data structures to hold results and track progress
    let results: Arc<Mutex<Vec<Option<DicomSlice>>>> = Arc::new(Mutex::new(vec![None; entries.len()]));
    let errors: Arc<Mutex<Vec<String>>> = Arc::new(Mutex::new(Vec::new()));
    let processed_count = Arc::new(AtomicU32::new(0));
    
    // Process files in parallel using rayon
    entries.par_iter().enumerate().for_each(|(i, entry)| {
        let path = entry.path.clone();
        
        // Process this file
        match get_encoded_image(path.clone()) {
            Ok(encoded) => {
                let slice = DicomSlice { path, data: encoded };
                
                // Store the result in the correct position
                if let Ok(mut results_guard) = results.lock() {
                    results_guard[i] = Some(slice);
                }
            },
            Err(e) => {
                // Record the error
                if let Ok(mut errors_guard) = errors.lock() {
                    errors_guard.push(format!("Error processing file {}: {}", path, e));
                }
            }
        };
        
        // Update progress
        let completed = processed_count.fetch_add(1, AtomicOrdering::SeqCst) + 1;
        
        // Call progress callback if provided
        // Call progress callback if provided
        futures::executor::block_on(progress_callback(completed, total_files));
    });
    
    // Check for errors
    let error_messages = errors.lock().unwrap();
    if !error_messages.is_empty() {
        return Err(format!("Errors during parallel processing: {}", error_messages.join("; ")));
    }
    
    // Collect results in order
    let slices_result = results.lock().unwrap();
    let slices = slices_result.iter()
        .filter_map(|slice| slice.clone())
        .collect::<Vec<_>>();
    
    // Ensure we have all slices
    if slices.len() != entries.len() {
        return Err("Some slices failed to load".to_string());
    }
    
    Ok(slices)
}
