use anyhow::Result;
use dicom::{
    core::value::{PrimitiveValue, Value},
    dictionary_std::{self, tags},
    object::{FileDicomObject, InMemDicomObject, mem::InMemElement},
};
use dicom::core::DataDictionary;
use std::{fs, io::Cursor, path::Path, collections::HashMap};
use std::cmp::Ordering;

// Add dicom-pixeldata for better image handling
use dicom_pixeldata::{image, PixelDecoder, ConvertOptions, VoiLutOption, BitDepthOption};

// #[frb(dart_metadata=("freezed"))]
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

// #[frb(dart_metadata=("freezed"))]
#[derive(Clone, Debug)]
pub struct DicomTag {
    pub tag: String,
    pub vr: String,
    pub name: String,
    pub value: DicomValueType,
}

// Enhanced metadata structure with spatial information
// #[frb(dart_metadata=("freezed"))]
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
    
    // Important UIDs for proper organization
    pub study_instance_uid: Option<String>,
    pub series_instance_uid: Option<String>,
    pub sop_instance_uid: Option<String>,
    
    // Spatial information for proper slice ordering
    pub image_position: Option<Vec<f64>>,      // Image Position (Patient)
    pub image_orientation: Option<Vec<f64>>,   // Image Orientation (Patient)
    pub slice_location: Option<f64>,           // Slice Location
    pub slice_thickness: Option<f64>,          // Slice Thickness
    pub spacing_between_slices: Option<f64>,   // Spacing Between Slices
    pub pixel_spacing: Option<Vec<f64>>,       // Pixel Spacing
}

// #[frb(dart_metadata=("freezed"))]
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

// #[frb(dart_metadata=("freezed"))]
#[derive(Clone, Debug)]
pub struct DicomFile {
    pub path: String,
    pub metadata: DicomMetadata,
    pub all_tags: Vec<DicomTag>,
}

// Individual DICOM instance (file) with path and validity
// #[frb(dart_metadata=("freezed"))]
#[derive(Clone, Debug)]
pub struct DicomInstance {
    pub path: String,
    pub sop_instance_uid: Option<String>,
    pub instance_number: Option<i32>,
    pub image_position: Option<Vec<f64>>,      // For proper slice ordering
    pub slice_location: Option<f64>,           // Alternative for ordering
    pub is_valid: bool,
}

// Series containing instances
// #[frb(dart_metadata=("freezed"))]
#[derive(Clone, Debug)]
pub struct DicomSeries {
    pub series_instance_uid: Option<String>,
    pub series_number: Option<i32>,
    pub series_description: Option<String>,
    pub modality: Option<String>,
    pub instances: Vec<DicomInstance>,
}

// Study containing series
// #[frb(dart_metadata=("freezed"))]
#[derive(Clone, Debug)]
pub struct DicomStudy {
    pub study_instance_uid: Option<String>,
    pub study_date: Option<String>,
    pub study_description: Option<String>,
    pub accession_number: Option<String>,
    pub series: Vec<DicomSeries>,
}

// Patient containing studies
// #[frb(dart_metadata=("freezed"))]
#[derive(Clone, Debug)]
pub struct DicomPatient {
    pub patient_id: Option<String>,
    pub patient_name: Option<String>,
    pub studies: Vec<DicomStudy>,
}

// Legacy structure for backward compatibility
// #[frb(dart_metadata=("freezed"))]
#[derive(Clone, Debug)]
pub struct DicomDirectoryEntry {
    pub path: String,
    pub metadata: DicomMetadata,
    pub is_valid: bool,
}

// New DicomHandler struct to provide a cleaner interface
// #[frb(dart_metadata=("freezed"))]
#[derive(Clone, Debug, Default)]
pub struct DicomHandler {}

// Helper functions for working with SmallVec values

// Get a string from a DICOM element
fn element_to_string(elem: &InMemElement) -> Option<String> {
    match elem.value() {
        Value::Primitive(prim) => match prim {
            PrimitiveValue::Str(s) => Some(s.to_string()),
            PrimitiveValue::F32(v) => {
                if v.len() > 0 {
                    Some(v[0].to_string())
                } else {
                    None
                }
            },
            PrimitiveValue::I32(v) => {
                if v.len() > 0 {
                    Some(v[0].to_string())
                } else {
                    None
                }
            },
            PrimitiveValue::F64(v) => {
                if v.len() > 0 {
                    Some(v[0].to_string())
                } else {
                    None
                }
            },
            PrimitiveValue::I16(v) => {
                if v.len() > 0 {
                    Some(v[0].to_string())
                } else {
                    None
                }
            },
            PrimitiveValue::U16(v) => {
                if v.len() > 0 {
                    Some(v[0].to_string())
                } else {
                    None
                }
            },
            PrimitiveValue::I64(v) => {
                if v.len() > 0 {
                    Some(v[0].to_string())
                } else {
                    None
                }
            },
            PrimitiveValue::U32(v) => {
                if v.len() > 0 {
                    Some(v[0].to_string())
                } else {
                    None
                }
            },
            PrimitiveValue::U8(v) => {
                if v.len() > 0 {
                    Some(v[0].to_string())
                } else {
                    None
                }
            },
            _ => None,
        },
        _ => None,
    }
}

// Get an integer from a DICOM element
fn element_to_int(elem: &InMemElement) -> Option<i32> {
    match elem.value() {
        Value::Primitive(prim) => match prim {
            PrimitiveValue::I32(v) => {
                if v.len() > 0 {
                    Some(v[0])
                } else {
                    None
                }
            },
            PrimitiveValue::I16(v) => {
                if v.len() > 0 {
                    Some(v[0] as i32)
                } else {
                    None
                }
            },
            PrimitiveValue::U16(v) => {
                if v.len() > 0 {
                    Some(v[0] as i32)
                } else {
                    None
                }
            },
            PrimitiveValue::U8(v) => {
                if v.len() > 0 {
                    Some(v[0] as i32)
                } else {
                    None
                }
            },
            _ => None,
        },
        _ => None,
    }
}

// Get a u16 from a DICOM element
fn element_to_u16(elem: &InMemElement) -> Option<u16> {
    match elem.value() {
        Value::Primitive(prim) => match prim {
            PrimitiveValue::U16(v) => {
                if v.len() > 0 {
                    Some(v[0])
                } else {
                    None
                }
            },
            PrimitiveValue::I16(v) => {
                if v.len() > 0 && v[0] >= 0 {
                    Some(v[0] as u16)
                } else {
                    None
                }
            },
            PrimitiveValue::U8(v) => {
                if v.len() > 0 {
                    Some(v[0] as u16)
                } else {
                    None
                }
            },
            PrimitiveValue::I32(v) => {
                if v.len() > 0 && v[0] >= 0 && v[0] <= 65535 {
                    Some(v[0] as u16)
                } else {
                    None
                }
            },
            _ => None,
        },
        _ => None,
    }
}

// Get a u32 from a DICOM element
fn element_to_u32(elem: &InMemElement) -> Option<u32> {
    match elem.value() {
        Value::Primitive(prim) => match prim {
            PrimitiveValue::U32(v) => {
                if v.len() > 0 {
                    Some(v[0])
                } else {
                    None
                }
            },
            PrimitiveValue::I32(v) => {
                if v.len() > 0 && v[0] >= 0 {
                    Some(v[0] as u32)
                } else {
                    None
                }
            },
            PrimitiveValue::U16(v) => {
                if v.len() > 0 {
                    Some(v[0] as u32)
                } else {
                    None
                }
            },
            PrimitiveValue::I16(v) => {
                if v.len() > 0 && v[0] >= 0 {
                    Some(v[0] as u32)
                } else {
                    None
                }
            },
            PrimitiveValue::U8(v) => {
                if v.len() > 0 {
                    Some(v[0] as u32)
                } else {
                    None
                }
            },
            _ => None,
        },
        _ => None,
    }
}

// Convert DICOM value to our DicomValueType
fn convert_value_to_dicom_type(value: &Value<InMemDicomObject>) -> DicomValueType {
    match value {
        Value::Primitive(prim) => match prim {
            PrimitiveValue::Str(val) => DicomValueType::Str(val.to_string()),
            PrimitiveValue::I32(vals) => {
                if !vals.is_empty() {
                    DicomValueType::Int(vals[0])
                } else {
                    DicomValueType::Unknown
                }
            },
            PrimitiveValue::F32(vals) => {
                if !vals.is_empty() {
                    DicomValueType::Float(vals[0])
                } else {
                    DicomValueType::Unknown
                }
            },
            PrimitiveValue::F64(vals) => {
                if !vals.is_empty() {
                    DicomValueType::Float(vals[0] as f32)
                } else {
                    DicomValueType::Unknown
                }
            },
            PrimitiveValue::I16(vals) => {
                if !vals.is_empty() {
                    DicomValueType::Int(vals[0] as i32)
                } else {
                    DicomValueType::Unknown
                }
            },
            PrimitiveValue::U16(vals) => {
                if !vals.is_empty() {
                    DicomValueType::Int(vals[0] as i32)
                } else {
                    DicomValueType::Unknown
                }
            },
            PrimitiveValue::I64(vals) => {
                if !vals.is_empty() {
                    DicomValueType::Int(vals[0] as i32)
                } else {
                    DicomValueType::Unknown
                }
            },
            PrimitiveValue::U32(vals) => {
                if !vals.is_empty() {
                    DicomValueType::Int(vals[0] as i32)
                } else {
                    DicomValueType::Unknown
                }
            },
            PrimitiveValue::U8(vals) => {
                if !vals.is_empty() {
                    DicomValueType::Int(vals[0] as i32)
                } else {
                    DicomValueType::Unknown
                }
            },
            _ => DicomValueType::Unknown,
        },
        _ => DicomValueType::Unknown,
    }
}

// Implementation of DicomHandler methods
impl DicomHandler {
    /// Creates a new DicomHandler instance
    pub fn new() -> Self {
        Self {}
    }

    /// Loads a DICOM file and returns detailed information
    pub fn load_file(&self, path: String) -> Result<DicomFile, String> {
        load_dicom_file(path)
    }
    
    /// Checks if a file is a valid DICOM file
    pub fn is_valid_dicom(&self, path: String) -> bool {
        is_dicom_file(path)
    }
    
    /// Gets all metadata from a DICOM file
    pub fn get_metadata(&self, path: String) -> Result<DicomMetadata, String> {
        let file_path = Path::new(&path);

        let obj = match FileDicomObject::<InMemDicomObject>::open_file(file_path) {
            Ok(obj) => obj,
            Err(e) => return Err(format!("Failed to open DICOM file: {}", e)),
        };

        extract_metadata(&obj).map_err(|e| e.to_string())
    }
    
    /// Gets a list of all tags in a DICOM file
    pub fn get_all_tags(&self, path: String) -> Result<Vec<DicomTag>, String> {
        let file_path = Path::new(&path);

        let obj = match FileDicomObject::<InMemDicomObject>::open_file(file_path) {
            Ok(obj) => obj,
            Err(e) => return Err(format!("Failed to open DICOM file: {}", e)),
        };

        extract_all_tags(&obj).map_err(|e| e.to_string())
    }
    
    /// Gets the value of a specific tag
    pub fn get_tag_value(&self, path: String, tag_name: String) -> Result<DicomValueType, String> {
        get_tag_value(path, tag_name)
    }
    
    /// Extracts raw pixel data from a DICOM file
    pub fn get_pixel_data(&self, path: String) -> Result<DicomImage, String> {
        extract_pixel_data(path)
    }
    
    /// Gets image bytes encoded as PNG from a DICOM file
    pub fn get_image_bytes(&self, path: String) -> Result<Vec<u8>, String> {
        get_encoded_image(path)
    }
    
    /// Loads all DICOM files from a directory (non-recursive)
    pub fn load_directory(&self, path: String) -> Result<Vec<DicomDirectoryEntry>, String> {
        load_dicom_directory(path)
    }
    
    /// Loads all DICOM files from a directory recursively
    pub fn load_directory_recursive(&self, path: String) -> Result<Vec<DicomDirectoryEntry>, String> {
        load_dicom_directory_recursive(path)
    }

    /// Gets a list of all tag names in a DICOM file
    pub fn list_tags(&self, path: String) -> Result<Vec<String>, String> {
        list_all_tags(path)
    }

    /// Loads all DICOM files from a directory (non-recursive) and groups by patient/study/series
    pub fn load_directory_organized(&self, path: String) -> Result<Vec<DicomPatient>, String> {
        load_dicom_directory_organized(path, false)
    }
    
    /// Loads all DICOM files from a directory recursively and groups by patient/study/series
    pub fn load_directory_recursive_organized(&self, path: String) -> Result<Vec<DicomPatient>, String> {
        load_dicom_directory_organized(path, true)
    }
    
    /// Loads a directory and returns a complete study with metadata propagated to all slices
    pub fn load_complete_study(&self, path: String) -> Result<DicomStudy, String> {
        load_complete_study(path, false)
    }
    
    /// Loads a directory recursively and returns a complete study with metadata propagated to all slices
    pub fn load_complete_study_recursive(&self, path: String) -> Result<DicomStudy, String> {
        load_complete_study(path, true)
    }
}

/// Loads a DICOM file from the given path
pub fn load_dicom_file(path: String) -> Result<DicomFile, String> {
    let file_path = Path::new(&path);

    let obj = match FileDicomObject::<InMemDicomObject>::open_file(file_path) {
        Ok(obj) => obj,
        Err(e) => return Err(format!("Failed to open DICOM file: {}", e)),
    };

    // Extract metadata
    let metadata = extract_metadata(&obj).map_err(|e| e.to_string())?;

    // Extract all tags
    let all_tags = extract_all_tags(&obj).map_err(|e| e.to_string())?;

    Ok(DicomFile {
        path,
        metadata,
        all_tags,
    })
}

/// Extracts common metadata from a DICOM object
fn extract_metadata(obj: &FileDicomObject<InMemDicomObject>) -> Result<DicomMetadata> {
    let patient_name = obj.element(tags::PATIENT_NAME)
        .ok()
        .and_then(|e| element_to_string(e));

    let patient_id = obj.element(tags::PATIENT_ID)
        .ok()
        .and_then(|e| element_to_string(e));

    let study_date = obj.element(tags::STUDY_DATE)
        .ok()
        .and_then(|e| element_to_string(e));
    

    let accession_number = obj.element(tags::ACCESSION_NUMBER)
        .ok()
        .and_then(|e| element_to_string(e));
 
    let modality = obj.element(
        tags::MODALITY
    )
        .ok()
        .and_then(|e| element_to_string(e));

    let study_description = obj.element(tags::STUDY_DESCRIPTION)
        .ok()
        .and_then(|e| element_to_string(e));

    let series_description = obj.element(tags::SERIES_DESCRIPTION)
        .ok()
        .and_then(|e| element_to_string(e));

    let instance_number = obj.element(tags::INSTANCE_NUMBER)
        .ok()
        .and_then(|e| element_to_int(e));

    let series_number = obj.element(tags::SERIES_NUMBER)
        .ok()
        .and_then(|e| element_to_int(e));
    
    // Extract UIDs
    let study_instance_uid = obj.element(tags::STUDY_INSTANCE_UID)
        .ok()
        .and_then(|e| element_to_string(e));
        
    let series_instance_uid = obj.element(tags::SERIES_INSTANCE_UID)
        .ok()
        .and_then(|e| element_to_string(e));
        
    let sop_instance_uid = obj.element(tags::SOP_INSTANCE_UID)
        .ok()
        .and_then(|e| element_to_string(e));

    // Extract spatial information
    let image_position = obj.element(tags::IMAGE_POSITION_PATIENT)
        .ok()
        .and_then(|e| element_to_float64_vector(e));
        
    let image_orientation = obj.element(tags::IMAGE_ORIENTATION_PATIENT)
        .ok()
        .and_then(|e| element_to_float64_vector(e));
        
    let slice_location = obj.element(tags::SLICE_LOCATION)
        .ok()
        .and_then(|e| element_to_float64(e));
        
    let slice_thickness = obj.element(tags::SLICE_THICKNESS)
        .ok()
        .and_then(|e| element_to_float64(e));
        
    let spacing_between_slices = obj.element(tags::SPACING_BETWEEN_SLICES)
        .ok()
        .and_then(|e| element_to_float64(e));
        
    let pixel_spacing = obj.element(tags::PIXEL_SPACING)
        .ok()
        .and_then(|e| element_to_float64_vector(e));

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

/// Extracts all tags from a DICOM object
fn extract_all_tags(obj: &FileDicomObject<InMemDicomObject>) -> Result<Vec<DicomTag>> {
    let mut tags = Vec::new();
    let dict = dictionary_std::StandardDataDictionary;

    for elem in obj.iter() {
        let tag_value = elem.header().tag;
        let tag = format!("{:04X}{:04X}", tag_value.group(), tag_value.element());
        let vr = elem.header().vr.to_string();

        let name = dict
            .by_tag(elem.header().tag)
            .map(|entry| entry.alias.to_string())  // Access alias instead of name
            .unwrap_or_else(|| format!("Unknown ({:04X},{:04X})", tag_value.group(), tag_value.element()));

        let value = convert_value_to_dicom_type(elem.value());

        tags.push(DicomTag {
            tag,
            vr: vr.to_string(),  // Convert to String explicitly
            name,
            value,
        });
    }

    Ok(tags)
}

/// Extracts pixel data from a DICOM file
pub fn extract_pixel_data(path: String) -> Result<DicomImage, String> {
    let file_path = Path::new(&path);

    let obj = match FileDicomObject::<InMemDicomObject>::open_file(file_path) {
        Ok(obj) => obj,
        Err(e) => return Err(format!("Failed to open DICOM file: {}", e)),
    };

    // Use PixelDecoder trait to properly decode the pixel data
    let decoded = match obj.decode_pixel_data() {
        Ok(decoded) => decoded,
        Err(e) => return Err(format!("Failed to decode pixel data: {}", e)),
    };

    // Get image dimensions
    let height = decoded.rows() as u32;
    let width = decoded.columns() as u32;

    // Get image parameters from the decoded data
    let bits_allocated = obj.element(tags::BITS_ALLOCATED)
        .map_err(|e| format!("Failed to get bits allocated: {}", e))?;
    let bits_allocated = element_to_u16(bits_allocated)
        .ok_or_else(|| "Invalid bits allocated format".to_string())?;

    let bits_stored = obj.element(tags::BITS_STORED)
        .map_err(|e| format!("Failed to get bits stored: {}", e))?;
    let bits_stored = element_to_u16(bits_stored)
        .ok_or_else(|| "Invalid bits stored format".to_string())?;

    let high_bit = obj.element(tags::HIGH_BIT)
        .map_err(|e| format!("Failed to get high bit: {}", e))?;
    let high_bit = element_to_u16(high_bit)
        .ok_or_else(|| "Invalid high bit format".to_string())?;

    let pixel_representation = obj.element(tags::PIXEL_REPRESENTATION)
        .map_err(|e| format!("Failed to get pixel representation: {}", e))?;
    let pixel_representation = element_to_u16(pixel_representation)
        .ok_or_else(|| "Invalid pixel representation format".to_string())?;

    let photometric_interpretation = obj.element(tags::PHOTOMETRIC_INTERPRETATION)
        .map_err(|e| format!("Failed to get photometric interpretation: {}", e))?;
    let photometric_interpretation = element_to_string(photometric_interpretation)
        .ok_or_else(|| "Invalid photometric interpretation format".to_string())?;

    let samples_per_pixel = obj.element(tags::SAMPLES_PER_PIXEL)
        .map_err(|e| format!("Failed to get samples per pixel: {}", e))?;
    let samples_per_pixel = element_to_u16(samples_per_pixel)
        .ok_or_else(|| "Invalid samples per pixel format".to_string())?;

    // Planar configuration is optional
    let planar_configuration = obj.element(tags::PLANAR_CONFIGURATION)
        .ok()
        .and_then(|e| element_to_u16(e));

    // Extract raw pixel data bytes using the native conversion method
    let pixel_data_bytes = match decoded.to_vec() {
        Ok(data) => data,
        Err(e) => return Err(format!("Failed to convert pixel data to vector: {}", e)),
    };

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
        pixel_data: pixel_data_bytes,
    })
}

/// Gets a specific tag value from a DICOM file
pub fn get_tag_value(path: String, tag_name: String) -> Result<DicomValueType, String> {
    let file_path = Path::new(&path);

    let obj = match FileDicomObject::<InMemDicomObject>::open_file(file_path) {
        Ok(obj) => obj,
        Err(e) => return Err(format!("Failed to open DICOM file: {}", e)),
    };

    let element = obj
        .element_by_name(&tag_name)
        .map_err(|e| format!("Failed to find tag '{}': {}", tag_name, e))?;

    Ok(convert_value_to_dicom_type(element.value()))
}

/// Check if a file is a valid DICOM file
pub fn is_dicom_file(path: String) -> bool {
    let file_path = Path::new(&path);
    FileDicomObject::<InMemDicomObject>::open_file(file_path).is_ok()
}

/// Get a list of all DICOM tags in a file
pub fn list_all_tags(path: String) -> Result<Vec<String>, String> {
    let file_path = Path::new(&path);

    let obj = match FileDicomObject::<InMemDicomObject>::open_file(file_path) {
        Ok(obj) => obj,
        Err(e) => return Err(format!("Failed to open DICOM file: {}", e)),
    };

    let dict = dictionary_std::StandardDataDictionary;
    let tags: Vec<String> = obj
        .iter()
        .map(|elem| {
            let tag = elem.header().tag;
            let name = dict
                .by_tag(tag)
                .map(|entry| entry.alias.to_string())  // Use alias instead of name
                .unwrap_or_else(|| format!("Unknown ({:04X},{:04X})", tag.group(), tag.element()));
            name
        })
        .collect();

    Ok(tags)
}

/// Get encoded image bytes (PNG format) from a DICOM file
pub fn get_encoded_image(path: String) -> Result<Vec<u8>, String> {
    let file_path = Path::new(&path);

    let obj = match FileDicomObject::<InMemDicomObject>::open_file(file_path) {
        Ok(obj) => obj,
        Err(e) => return Err(format!("Failed to open DICOM file: {}", e)),
    };

    // Use PixelDecoder trait to properly decode the pixel data
    let decoded = match obj.decode_pixel_data() {
        Ok(decoded) => decoded,
        Err(e) => return Err(format!("Failed to decode pixel data: {}", e)),
    };

    // Set up conversion options with automatic windowing
    let options = ConvertOptions::new()
        .with_voi_lut(VoiLutOption::Default) // Auto window leveling
        .with_bit_depth(BitDepthOption::Auto); // Force 8-bit output

    // Convert to dynamic image with appropriate options
    let dynamic_image = match decoded.to_dynamic_image_with_options(0, &options) {
        Ok(img) => img,
        Err(e) => return Err(format!("Failed to convert to image: {}", e)),
    };

    // Encode to PNG
    let mut encoded_bytes: Vec<u8> = Vec::new();
    let mut cursor = Cursor::new(&mut encoded_bytes);

    if let Err(e) = dynamic_image.write_to(&mut cursor, image::ImageFormat::Png) {
        return Err(format!("Failed to encode image: {}", e));
    }

    Ok(encoded_bytes)
}

/// Load all DICOM files from a directory
pub fn load_dicom_directory(dir_path: String) -> Result<Vec<DicomDirectoryEntry>, String> {
    let path = Path::new(&dir_path);

    if !path.exists() || !path.is_dir() {
        return Err(format!("Invalid directory path: {}", dir_path));
    }

    let dir_entries = match fs::read_dir(path) {
        Ok(entries) => entries,
        Err(e) => return Err(format!("Failed to read directory: {}", e)),
    };

    let mut result = Vec::new();

    for entry in dir_entries {
        if let Ok(entry) = entry {
            let file_path = entry.path();

            // Skip directories
            if file_path.is_dir() {
                continue;
            }

            let path_str = match file_path.to_str() {
                Some(s) => s.to_string(),
                None => continue, // Skip paths that can't be converted to string
            };

            // Check if it's a DICOM file
            let is_valid = is_dicom_file(path_str.clone());

            if is_valid {
                // Try to extract metadata
                match FileDicomObject::<InMemDicomObject>::open_file(&file_path) {
                    Ok(obj) => {
                        match extract_metadata(&obj) {
                            Ok(metadata) => {
                                result.push(DicomDirectoryEntry {
                                    path: path_str,
                                    metadata,
                                    is_valid: true,
                                });
                            }
                            Err(_) => {
                                // Include file with empty metadata if metadata extraction fails
                                result.push(DicomDirectoryEntry {
                                    path: path_str,
                                    metadata: DicomMetadata {
                                        patient_name: None,
                                        patient_id: None,
                                        study_date: None,
                                        accession_number: None,
                                        modality: None,
                                        study_description: None,
                                        series_description: None,
                                        instance_number: None,
                                        series_number: None,
                                        study_instance_uid: None,
                                        series_instance_uid: None,
                                        sop_instance_uid: None,
                                        image_position: None,
                                        image_orientation: None,
                                        slice_location: None,
                                        slice_thickness: None,
                                        spacing_between_slices: None,
                                        pixel_spacing: None,
                                    },
                                    is_valid: true,
                                });
                            }
                        }
                    }
                    Err(_) => {
                        // Include file but mark as invalid if we can't open it
                        result.push(DicomDirectoryEntry {
                            path: path_str,
                            metadata: DicomMetadata {
                                patient_name: None,
                                patient_id: None,
                                study_date: None,
                                accession_number: None,
                                modality: None,
                                study_description: None,
                                series_description: None,
                                instance_number: None,
                                series_number: None,
                                study_instance_uid: None,
                                series_instance_uid: None,
                                sop_instance_uid: None,
                                image_position: None,
                                image_orientation: None,
                                slice_location: None,
                                slice_thickness: None,
                                spacing_between_slices: None,
                                pixel_spacing: None,
                            },
                            is_valid: false,
                        });
                    }
                }
            }
        }
    }

    // Sort the results by series number and then instance number
    sort_dicom_entries(&mut result);

    Ok(result)
}

/// Load all DICOM files recursively from a directory
pub fn load_dicom_directory_recursive(
    dir_path: String,
) -> Result<Vec<DicomDirectoryEntry>, String> {
    let path = Path::new(&dir_path);

    if !path.exists() || !path.is_dir() {
        return Err(format!("Invalid directory path: {}", dir_path));
    }

    let mut result = Vec::new();

    // Process directory recursively
    process_directory_recursive(path, &mut result)?;

    // Sort the results by series number and then instance number
    sort_dicom_entries(&mut result);

    Ok(result)
}

/// Load all DICOM files from a directory and organize them hierarchically
pub fn load_dicom_directory_organized(dir_path: String, recursive: bool) -> Result<Vec<DicomPatient>, String> {
    // First collect all DICOM files
    let entries = if recursive {
        load_dicom_directory_recursive(dir_path)?
    } else {
        load_dicom_directory(dir_path)?
    };
    
    // Organize them hierarchically
    organize_dicom_entries(entries)
}

/// Organize flat list of DICOM entries into a hierarchical structure
fn organize_dicom_entries(entries: Vec<DicomDirectoryEntry>) -> Result<Vec<DicomPatient>, String> {
    // Maps to keep track of unique patients, studies, and series
    let mut patients_map: HashMap<String, DicomPatient> = HashMap::new();
    
    for entry in entries {
        if !entry.is_valid {
            continue; // Skip invalid entries
        }
        
        let meta = &entry.metadata;
        
        // Use defaults for missing identifiers
        let patient_id = meta.patient_id.clone().unwrap_or_else(|| "UNKNOWN".to_string());
        let study_uid = meta.study_instance_uid.clone().unwrap_or_else(|| "UNKNOWN".to_string());
        let series_uid = meta.series_instance_uid.clone().unwrap_or_else(|| "UNKNOWN".to_string());
        
        // Create a new DICOM instance with spatial information
        let instance = DicomInstance {
            path: entry.path,
            sop_instance_uid: meta.sop_instance_uid.clone(),
            instance_number: meta.instance_number,
            image_position: meta.image_position.clone(),
            slice_location: meta.slice_location,
            is_valid: entry.is_valid,
        };
        
        // Get or create the patient
        let patient = patients_map.entry(patient_id.clone()).or_insert_with(|| {
            DicomPatient {
                patient_id: Some(patient_id.clone()),
                patient_name: meta.patient_name.clone(),
                studies: Vec::new(),
            }
        });
        
        // Find the study for this patient
        let mut found_study = false;
        for study in &mut patient.studies {
            if let Some(existing_uid) = &study.study_instance_uid {
                if *existing_uid == study_uid {
                    found_study = true;
                    
                    // Find the series for this study
                    let mut found_series = false;
                    for series in &mut study.series {
                        if let Some(existing_series_uid) = &series.series_instance_uid {
                            if *existing_series_uid == series_uid {
                                found_series = true;
                                
                                // Add the instance to this series
                                series.instances.push(instance.clone());
                                break;
                            }
                        }
                    }
                    
                    // If series not found, create a new one
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
        
        // If study not found, create a new one
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
    
    // Convert the HashMap to a Vec and sort
    let mut patients: Vec<DicomPatient> = patients_map.into_values().collect();
    
    // Sort everything appropriately with enhanced sorting
    sort_dicom_hierarchy(&mut patients);
    
    Ok(patients)
}

/// Sort the entire DICOM hierarchy with improved spatial ordering
fn sort_dicom_hierarchy(patients: &mut Vec<DicomPatient>) {
    // Sort patients by name (alphabetically)
    patients.sort_by(|a, b| {
        let name_a = &a.patient_name.as_deref().unwrap_or("Unknown");
        let name_b = &b.patient_name.as_deref().unwrap_or("Unknown");
        name_a.cmp(name_b)
    });
    
    // Sort each patient's studies
    for patient in patients {
        // Sort studies by date (newest first)
        patient.studies.sort_by(|a, b| {
            let date_a = &a.study_date.as_deref().unwrap_or("");
            let date_b = &b.study_date.as_deref().unwrap_or("");
            // Reverse comparison to get newest first
            date_b.cmp(date_a)
        });
        
        // Sort each study's series
        for study in &mut patient.studies {
            // Sort series by series number
            study.series.sort_by(|a, b| {
                match (&a.series_number, &b.series_number) {
                    (Some(a_num), Some(b_num)) => a_num.cmp(b_num),
                    (Some(_), None) => Ordering::Less,
                    (None, Some(_)) => Ordering::Greater,
                    (None, None) => Ordering::Equal,
                }
            });
            
            // Sort instances within each series using spatial information
            for series in &mut study.series {
                sort_instances_by_position(&mut series.instances);
            }
        }
    }
}

/// Sort instances based on spatial information - similar to how vtkDICOMImageReader does it
fn sort_instances_by_position(instances: &mut Vec<DicomInstance>) {
    // First, try to sort by slice location if available
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
    
    // If no slice locations, try to sort by image position
    let has_positions = instances.iter().any(|i| i.image_position.is_some() && i.image_position.as_ref().unwrap().len() >= 3);
    
    if has_positions {
        // Determine the primary direction (usually the Z component for axial slices)
        // This is similar to how VTK determines the proper sorting order
        
        // First instance position
        if let Some(first_instance) = instances.first() {
            if let Some(pos0) = &first_instance.image_position {
                if pos0.len() >= 3 {
                    // Sort primarily by the z-position (index 2)
                    instances.sort_by(|a, b| {
                        if let (Some(pos_a), Some(pos_b)) = (&a.image_position, &b.image_position) {
                            if pos_a.len() >= 3 && pos_b.len() >= 3 {
                                return pos_a[2].partial_cmp(&pos_b[2]).unwrap_or(Ordering::Equal);
                            }
                        }
                        // Fall back to instance number as before
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
    
    // Fall back to instance number if neither spatial information is available
    instances.sort_by(|a, b| {
        match (a.instance_number, b.instance_number) {
            (Some(a_num), Some(b_num)) => a_num.cmp(&b_num),
            (Some(_), None) => Ordering::Less,
            (None, Some(_)) => Ordering::Greater,
            (None, None) => Ordering::Equal,
        }
    });
}

// Helper function to sort DICOM directory entries
fn sort_dicom_entries(entries: &mut Vec<DicomDirectoryEntry>) {
    entries.sort_by(|a, b| {
        // First sort by series number
        let series_cmp = match (&a.metadata.series_number, &b.metadata.series_number) {
            (Some(a_series), Some(b_series)) => a_series.cmp(b_series),
            (Some(_), None) => std::cmp::Ordering::Less,
            (None, Some(_)) => std::cmp::Ordering::Greater,
            (None, None) => std::cmp::Ordering::Equal,
        };

        // If series numbers are equal, sort by instance number
        if series_cmp == std::cmp::Ordering::Equal {
            match (&a.metadata.instance_number, &b.metadata.instance_number) {
                (Some(a_instance), Some(b_instance)) => a_instance.cmp(b_instance),
                (Some(_), None) => std::cmp::Ordering::Less,
                (None, Some(_)) => std::cmp::Ordering::Greater,
                (None, None) => std::cmp::Ordering::Equal,
            }
        } else {
            series_cmp
        }
    });
}

// Helper function to recursively process directories
fn process_directory_recursive(
    dir_path: &Path,
    result: &mut Vec<DicomDirectoryEntry>,
) -> Result<(), String> {
    let dir_entries = match fs::read_dir(dir_path) {
        Ok(entries) => entries,
        Err(e) => return Err(format!("Failed to read directory: {}", e)),
    };

    for entry in dir_entries {
        if let Ok(entry) = entry {
            let file_path = entry.path();

            if file_path.is_dir() {
                // Recursively process subdirectory
                process_directory_recursive(&file_path, result)?;
            } else {
                let path_str = match file_path.to_str() {
                    Some(s) => s.to_string(),
                    None => continue, // Skip paths that can't be converted to string
                };

                // Check if it's a DICOM file
                if is_dicom_file(path_str.clone()) {
                    // Try to extract metadata
                    match FileDicomObject::<InMemDicomObject>::open_file(&file_path) {
                        Ok(obj) => {
                            match extract_metadata(&obj) {
                                Ok(metadata) => {
                                    result.push(DicomDirectoryEntry {
                                        path: path_str,
                                        metadata,
                                        is_valid: true,
                                    });
                                }
                                Err(_) => {
                                    // Include file with empty metadata
                                    result.push(DicomDirectoryEntry {
                                        path: path_str,
                                        metadata: DicomMetadata {
                                            patient_name: None,
                                            patient_id: None,
                                            study_date: None,
                                            accession_number: None,
                                            modality: None,
                                            study_description: None,
                                            series_description: None,
                                            instance_number: None,
                                            series_number: None,
                                            study_instance_uid: None,
                                            series_instance_uid: None,
                                            sop_instance_uid: None,
                                            image_position: None,
                                            image_orientation: None,
                                            slice_location: None,
                                            slice_thickness: None,
                                            spacing_between_slices: None,
                                            pixel_spacing: None,
                                        },
                                        is_valid: true,
                                    });
                                }
                            }
                        }
                        Err(_) => {
                            // Include file but mark as invalid
                            result.push(DicomDirectoryEntry {
                                path: path_str,
                                metadata: DicomMetadata {
                                    patient_name: None,
                                    patient_id: None,
                                    study_date: None,
                                    accession_number: None,
                                    modality: None,
                                    study_description: None,
                                    series_description: None,
                                    instance_number: None,
                                    series_number: None,
                                    study_instance_uid: None,
                                    series_instance_uid: None,
                                    sop_instance_uid: None,
                                    image_position: None,
                                    image_orientation: None,
                                    slice_location: None,
                                    slice_thickness: None,
                                    spacing_between_slices: None,
                                    pixel_spacing: None,
                                },
                                is_valid: false,
                            });
                        }
                    }
                }
            }
        }
    }

    Ok(())
}

// New helper function to extract float64 vectors
fn element_to_float64_vector(elem: &InMemElement) -> Option<Vec<f64>> {
    match elem.value() {
        Value::Primitive(prim) => match prim {
            PrimitiveValue::F64(v) => Some(v.iter().map(|&x| x).collect()),
            PrimitiveValue::F32(v) => Some(v.iter().map(|&x| x as f64).collect()),
            // Also handle decimal strings that represent coordinates
            PrimitiveValue::Str(s) => {
                let parts: Vec<f64> = s.split('\\')
                    .filter_map(|part| part.trim().parse::<f64>().ok())
                    .collect();
                if parts.is_empty() { None } else { Some(parts) }
            },
            _ => None,
        },
        _ => None,
    }
}

// Helper function to extract a single float64 value
fn element_to_float64(elem: &InMemElement) -> Option<f64> {
    match elem.value() {
        Value::Primitive(prim) => match prim {
            PrimitiveValue::F64(v) => {
                if v.len() > 0 {
                    Some(v[0])
                } else {
                    None
                }
            },
            PrimitiveValue::F32(v) => {
                if v.len() > 0 {
                    Some(v[0] as f64)
                } else {
                    None
                }
            },
            PrimitiveValue::Str(s) => s.trim().parse::<f64>().ok(),
            _ => None,
        },
        _ => None,
    }
}

/// Loads a complete study with propagated metadata
pub fn load_complete_study(dir_path: String, recursive: bool) -> Result<DicomStudy, String> {
    // First collect all DICOM files
    let entries = if recursive {
        load_dicom_directory_recursive(dir_path)?
    } else {
        load_dicom_directory(dir_path)?
    };
    
    // Early return if no valid DICOM files found
    if entries.is_empty() {
        return Err("No valid DICOM files found in directory".to_string());
    }
    
    // Organize files and extract study information
    let patients = organize_dicom_entries(entries)?;
    
    // Check if any patients were found
    if patients.is_empty() {
        return Err("No valid patient information found in DICOM files".to_string());
    }
    
    // Get the first patient (assuming single patient per directory)
    let patient = &patients[0];
    
    // Check if this patient has any studies
    if patient.studies.is_empty() {
        return Err("No valid studies found for patient".to_string());
    }
    
    // Get the first study (assuming single study per directory)
    let study = patient.studies[0].clone();
    
    // Propagate metadata across all series and instances
    let propagated_study = propagate_study_metadata(study)?;
    
    Ok(propagated_study)
}

/// Propagates metadata across all series and instances in a study
fn propagate_study_metadata(study: DicomStudy) -> Result<DicomStudy, String> {
    let mut propagated_study = study.clone();
    
    // Collect and merge metadata across all series instances
    let common_metadata = collect_common_study_metadata(&study);
    
    // Update series with propagated metadata
    for series in &mut propagated_study.series {
        let series_metadata = collect_common_series_metadata(&series);
        
        // Propagate metadata to each instance
        for instance in &mut series.instances {
            // If this is a valid DICOM file with missing metadata, we'll update it
            if instance.is_valid {
                // Load the file to get instance-specific metadata
                if let Ok(file_obj) = FileDicomObject::<InMemDicomObject>::open_file(&instance.path) {
                    if let Ok(mut instance_metadata) = extract_metadata(&file_obj) {
                        // Apply study-level metadata if missing
                        if instance_metadata.patient_name.is_none() {
                            instance_metadata.patient_name = common_metadata.patient_name.clone();
                        }
                        if instance_metadata.patient_id.is_none() {
                            instance_metadata.patient_id = common_metadata.patient_id.clone();
                        }
                        if instance_metadata.study_date.is_none() {
                            instance_metadata.study_date = common_metadata.study_date.clone();
                        }
                        if instance_metadata.study_description.is_none() {
                            instance_metadata.study_description = common_metadata.study_description.clone();
                        }
                        if instance_metadata.accession_number.is_none() {
                            instance_metadata.accession_number = common_metadata.accession_number.clone();
                        }
                        if instance_metadata.study_instance_uid.is_none() {
                            instance_metadata.study_instance_uid = common_metadata.study_instance_uid.clone();
                        }
                        
                        // Apply series-level metadata if missing
                        if instance_metadata.series_description.is_none() {
                            instance_metadata.series_description = series_metadata.series_description.clone();
                        }
                        if instance_metadata.modality.is_none() {
                            instance_metadata.modality = series_metadata.modality.clone();
                        }
                        if instance_metadata.series_number.is_none() {
                            instance_metadata.series_number = series_metadata.series_number;
                        }
                        if instance_metadata.series_instance_uid.is_none() {
                            instance_metadata.series_instance_uid = series_metadata.series_instance_uid.clone();
                        }
                        
                        // Update instance with propagated metadata
                        if instance.sop_instance_uid.is_none() {
                            instance.sop_instance_uid = instance_metadata.sop_instance_uid.clone();
                        }
                        if instance.instance_number.is_none() {
                            instance.instance_number = instance_metadata.instance_number;
                        }
                    }
                }
            }
        }
    }
    
    Ok(propagated_study)
}

/// Collects common metadata across a study
fn collect_common_study_metadata(study: &DicomStudy) -> DicomMetadata {
    let mut common_metadata = DicomMetadata {
        patient_name: None,
        patient_id: None,
        study_date: None,
        accession_number: None,
        modality: None,
        study_description: None,
        series_description: None,
        instance_number: None,
        series_number: None,
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
    
    // Set study-level metadata
    common_metadata.study_instance_uid = study.study_instance_uid.clone();
    common_metadata.study_date = study.study_date.clone();
    common_metadata.study_description = study.study_description.clone();
    common_metadata.accession_number = study.accession_number.clone();
    
    // Collect patient information from series if available
    for series in &study.series {
        for instance in &series.instances {
            if instance.is_valid {
                if let Ok(file_obj) = FileDicomObject::<InMemDicomObject>::open_file(&instance.path) {
                    if let Ok(metadata) = extract_metadata(&file_obj) {
                        // Set patient information if not already set
                        if common_metadata.patient_name.is_none() {
                            common_metadata.patient_name = metadata.patient_name;
                        }
                        if common_metadata.patient_id.is_none() {
                            common_metadata.patient_id = metadata.patient_id;
                        }
                        // Once we have all the metadata we need, we can break
                        if common_metadata.patient_name.is_some() && common_metadata.patient_id.is_some() {
                            break;
                        }
                    }
                }
            }
        }
        // Break the outer loop if we have all metadata
        if common_metadata.patient_name.is_some() && common_metadata.patient_id.is_some() {
            break;
        }
    }
    
    common_metadata
}

/// Collects common metadata across a series
fn collect_common_series_metadata(series: &DicomSeries) -> DicomMetadata {
    let mut common_metadata = DicomMetadata {
        patient_name: None,
        patient_id: None,
        study_date: None,
        accession_number: None,
        modality: None,
        study_description: None,
        series_description: None,
        instance_number: None,
        series_number: None,
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
    
    // Set series-level metadata
    common_metadata.series_instance_uid = series.series_instance_uid.clone();
    common_metadata.series_number = series.series_number;
    common_metadata.series_description = series.series_description.clone();
    common_metadata.modality = series.modality.clone();
    
    // Try to get additional metadata from instances
    for instance in &series.instances {
        if instance.is_valid {
            if let Ok(file_obj) = FileDicomObject::<InMemDicomObject>::open_file(&instance.path) {
                if let Ok(metadata) = extract_metadata(&file_obj) {
                    // Fill in missing values
                    if common_metadata.modality.is_none() {
                        common_metadata.modality = metadata.modality;
                    }
                    if common_metadata.series_description.is_none() {
                        common_metadata.series_description = metadata.series_description;
                    }
                    if common_metadata.series_instance_uid.is_none() {
                        common_metadata.series_instance_uid = metadata.series_instance_uid;
                    }
                    if common_metadata.series_number.is_none() {
                        common_metadata.series_number = metadata.series_number;
                    }
                    
                    // Get spacing information
                    if common_metadata.slice_thickness.is_none() {
                        common_metadata.slice_thickness = metadata.slice_thickness;
                    }
                    if common_metadata.spacing_between_slices.is_none() {
                        common_metadata.spacing_between_slices = metadata.spacing_between_slices;
                    }
                    if common_metadata.pixel_spacing.is_none() {
                        common_metadata.pixel_spacing = metadata.pixel_spacing;
                    }
                    
                    // Once we have all the metadata we need, we can break
                    if common_metadata.modality.is_some() && 
                       common_metadata.series_description.is_some() &&
                       common_metadata.series_number.is_some() {
                        break;
                    }
                }
            }
        }
    }
    
    common_metadata
}
