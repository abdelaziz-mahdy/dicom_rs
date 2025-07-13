use anyhow::Result;
use dicom::{
    core::DataDictionary,
    dictionary_std::{tags, StandardDataDictionary},
    object::{mem::InMemElement, from_reader, FileDicomObject, InMemDicomObject, Tag},
};
use dicom_pixeldata::{image, PixelDecoder, ConvertOptions, VoiLutOption, BitDepthOption};
use std::{io::Cursor, collections::HashMap};

// -----------------------------------------------------------------------------
// Minimal Data Types for Package
// -----------------------------------------------------------------------------

/// Simplified element representation
#[derive(Debug, Clone)]
pub struct DicomElement {
    pub tag: String,
    pub alias: &'static str,
    pub vr: String,
    pub value: String,
}

/// Core metadata extracted from a DICOM file
#[derive(Clone, Debug)]
pub struct DicomMetadata {
    pub patient_name: Option<String>,
    pub patient_id: Option<String>,
    pub study_date: Option<String>,
    pub modality: Option<String>,
    pub study_description: Option<String>,
    pub series_description: Option<String>,
    pub instance_number: Option<i32>,
    pub series_number: Option<i32>,
    pub study_instance_uid: Option<String>,
    pub series_instance_uid: Option<String>,
    pub sop_instance_uid: Option<String>,
    pub image_position: Option<Vec<f64>>,
    pub pixel_spacing: Option<Vec<f64>>,
    pub slice_location: Option<f64>,
    pub slice_thickness: Option<f64>,
}

/// DICOM image pixel data and basic parameters
#[derive(Clone, Debug)]
pub struct DicomImage {
    pub width: u32,
    pub height: u32,
    pub bits_allocated: u16,
    pub bits_stored: u16,
    pub pixel_representation: u16,
    pub photometric_interpretation: String,
    pub samples_per_pixel: u16,
    pub pixel_data: Vec<u8>,
}

/// Complete DICOM file representation
#[derive(Clone, Debug)]
pub struct DicomFile {
    pub metadata: DicomMetadata,
    pub image: Option<DicomImage>,
    pub is_valid: bool,
}

/// Main handler for DICOM operations
#[derive(Clone, Debug, Default)]
pub struct DicomHandler {}

// -----------------------------------------------------------------------------
// Helper Functions
// -----------------------------------------------------------------------------

/// Converts an InMemElement into our simplified structure
fn to_element(e: &InMemElement) -> Result<DicomElement> {
    let tag = e.header().tag;
    let tag_str = format!("{:04X}{:04X}", tag.group(), tag.element());

    let alias = StandardDataDictionary
        .by_tag(tag)
        .map(|entry| entry.alias)
        .unwrap_or("«unknown attribute»");
    
    let vr = e.header().vr().to_string();

    let value = if tag == tags::PIXEL_DATA {
        "«pixel data»".to_string()
    } else {
        e.value().to_str()?.to_string()
    };

    Ok(DicomElement {
        tag: tag_str,
        alias,
        vr: vr.to_string(),
        value,
    })
}

/// Extracts metadata elements from a DICOM object
fn extract_elements(obj: &FileDicomObject<InMemDicomObject>) -> Result<HashMap<String, DicomElement>> {
    let mut elements = HashMap::new();
    
    for element in obj.iter().filter(|e| !e.header().is_non_primitive()) {
        let el = to_element(element)?;
        elements.insert(el.tag.clone(), el);
    }
    
    Ok(elements)
}

/// Gets a value from extracted elements by tag
fn get_element_value(elements: &HashMap<String, DicomElement>, tag: Tag) -> Option<String> {
    let tag_str = format!("{:04X}{:04X}", tag.group(), tag.element());
    elements.get(&tag_str).map(|el| el.value.clone())
}

/// Extracts core metadata from a DICOM object
fn extract_metadata(obj: &FileDicomObject<InMemDicomObject>) -> Result<DicomMetadata> {
    let elements = extract_elements(obj)?;
    
    let patient_name = get_element_value(&elements, tags::PATIENT_NAME);
    let patient_id = get_element_value(&elements, tags::PATIENT_ID);
    let study_date = get_element_value(&elements, tags::STUDY_DATE);
    let modality = get_element_value(&elements, tags::MODALITY);
    let study_description = get_element_value(&elements, tags::STUDY_DESCRIPTION);
    let series_description = get_element_value(&elements, tags::SERIES_DESCRIPTION);
    let study_instance_uid = get_element_value(&elements, tags::STUDY_INSTANCE_UID);
    let series_instance_uid = get_element_value(&elements, tags::SERIES_INSTANCE_UID);
    let sop_instance_uid = get_element_value(&elements, tags::SOP_INSTANCE_UID);

    let instance_number = get_element_value(&elements, tags::INSTANCE_NUMBER)
        .and_then(|s| s.parse::<i32>().ok());
    let series_number = get_element_value(&elements, tags::SERIES_NUMBER)
        .and_then(|s| s.parse::<i32>().ok());

    // Parse floating point arrays
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

    let image_position = parse_f64_vec(get_element_value(&elements, tags::IMAGE_POSITION_PATIENT));
    let pixel_spacing = parse_f64_vec(get_element_value(&elements, tags::PIXEL_SPACING));
    let slice_location = parse_f64(get_element_value(&elements, tags::SLICE_LOCATION));
    let slice_thickness = parse_f64(get_element_value(&elements, tags::SLICE_THICKNESS));

    Ok(DicomMetadata {
        patient_name,
        patient_id,
        study_date,
        modality,
        study_description,
        series_description,
        instance_number,
        series_number,
        study_instance_uid,
        series_instance_uid,
        sop_instance_uid,
        image_position,
        pixel_spacing,
        slice_location,
        slice_thickness,
    })
}

// -----------------------------------------------------------------------------
// Core API Functions (Minimal Package Interface)
// -----------------------------------------------------------------------------

impl DicomHandler {
    pub fn new() -> Self {
        Self {}
    }

    /// Check if bytes represent a valid DICOM file
    pub fn is_dicom_file(&self, bytes: Vec<u8>) -> bool {
        let cursor = Cursor::new(bytes);
        from_reader(cursor).is_ok()
    }

    /// Load DICOM from bytes with metadata only (fast for scanning)
    pub fn load_file(&self, bytes: Vec<u8>) -> Result<DicomFile, String> {
        let cursor = Cursor::new(bytes);
        let obj = from_reader(cursor).map_err(|e| format!("Failed to parse DICOM bytes: {}", e))?;
        let metadata = extract_metadata(&obj).map_err(|e| e.to_string())?;
        
        Ok(DicomFile {
            metadata,
            image: None,
            is_valid: true,
        })
    }

    /// Load complete DICOM from bytes with metadata and image data
    pub fn load_file_with_image(&self, bytes: Vec<u8>) -> Result<DicomFile, String> {
        let cursor = Cursor::new(&bytes);
        let obj = from_reader(cursor).map_err(|e| format!("Failed to parse DICOM bytes: {}", e))?;
        let metadata = extract_metadata(&obj).map_err(|e| e.to_string())?;
        
        let image = match self.extract_pixel_data(bytes) {
            Ok(img) => Some(img),
            Err(_) => None,
        };

        Ok(DicomFile {
            metadata,
            image,
            is_valid: true,
        })
    }

    /// Extract only metadata from DICOM bytes
    pub fn get_metadata(&self, bytes: Vec<u8>) -> Result<DicomMetadata, String> {
        let cursor = Cursor::new(bytes);
        let obj = from_reader(cursor).map_err(|e| format!("Failed to parse DICOM bytes: {}", e))?;
        extract_metadata(&obj).map_err(|e| e.to_string())
    }

    /// Get encoded image bytes (PNG format) from DICOM bytes
    pub fn get_image_bytes(&self, bytes: Vec<u8>) -> Result<Vec<u8>, String> {
        let cursor = Cursor::new(bytes);
        let obj = from_reader(cursor).map_err(|e| format!("Failed to parse DICOM bytes: {}", e))?;
        
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

    /// Extract raw pixel data and image parameters from DICOM bytes
    pub fn extract_pixel_data(&self, bytes: Vec<u8>) -> Result<DicomImage, String> {
        let cursor = Cursor::new(bytes);
        let obj = from_reader(cursor).map_err(|e| format!("Failed to parse DICOM bytes: {}", e))?;

        let decoded = obj.decode_pixel_data().map_err(|e| format!("Failed to decode pixel data: {}", e))?;
        let height = decoded.rows() as u32;
        let width = decoded.columns() as u32;

        // Extract image parameters
        let bits_allocated = obj.element(tags::BITS_ALLOCATED)
            .map_err(|e| format!("Failed to get bits allocated: {}", e))?
            .value().to_str().ok().and_then(|s| s.parse::<u16>().ok())
            .ok_or_else(|| "Invalid bits allocated format".to_string())?;

        let bits_stored = obj.element(tags::BITS_STORED)
            .map_err(|e| format!("Failed to get bits stored: {}", e))?
            .value().to_str().ok().and_then(|s| s.parse::<u16>().ok())
            .ok_or_else(|| "Invalid bits stored format".to_string())?;

        let pixel_representation = obj.element(tags::PIXEL_REPRESENTATION)
            .map_err(|e| format!("Failed to get pixel representation: {}", e))?
            .value().to_str().ok().and_then(|s| s.parse::<u16>().ok())
            .ok_or_else(|| "Invalid pixel representation format".to_string())?;

        let photometric_interpretation = obj.element(tags::PHOTOMETRIC_INTERPRETATION)
            .map_err(|e| format!("Failed to get photometric interpretation: {}", e))?
            .value().to_str().unwrap_or(std::borrow::Cow::Borrowed("MONOCHROME2")).to_string();

        let samples_per_pixel = obj.element(tags::SAMPLES_PER_PIXEL)
            .map_err(|e| format!("Failed to get samples per pixel: {}", e))?
            .value().to_str().ok().and_then(|s| s.parse::<u16>().ok())
            .ok_or_else(|| "Invalid samples per pixel format".to_string())?;

        let options = ConvertOptions::new()
            .with_voi_lut(VoiLutOption::Default)
            .with_bit_depth(BitDepthOption::Auto);
        
        let dynamic_image = decoded.to_dynamic_image_with_options(0, &options)
            .map_err(|e| format!("Failed to convert to image: {}", e))?;

        Ok(DicomImage {
            width,
            height,
            bits_allocated,
            bits_stored,
            pixel_representation,
            photometric_interpretation,
            samples_per_pixel,
            pixel_data: dynamic_image.as_bytes().to_vec(),
        })
    }
}


