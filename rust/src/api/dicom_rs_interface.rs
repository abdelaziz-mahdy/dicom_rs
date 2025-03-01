use anyhow::Result;
use dicom::{
    core::value::{PrimitiveValue, Value, DataSetSequence},
    dictionary_std::{self, tags},
    object::{FileDicomObject, InMemDicomObject, mem::InMemElement},
};
use dicom::core::DataDictionary;
// Import Tag correctly from dicom object module
use dicom::object::Tag;
use std::{fs, io::Cursor, path::Path, collections::HashMap};
use std::cmp::Ordering;

// Add dicom-pixeldata for better image handling
use dicom_pixeldata::{image, PixelDecoder, ConvertOptions, VoiLutOption, BitDepthOption};

// Add this at the top of the file with other tag definitions


// #[frb(dart_metadata=("freezed"))]
/// Represents different types of DICOM values that can be extracted from a DICOM file.
/// 
/// DICOM data can be stored in various formats, and this enum provides a convenient
/// way to represent these different value types in a unified manner.
#[derive(Clone, Debug)]
pub enum DicomValueType {
    /// String value (e.g., patient name, study description)
    Str(String),
    /// Integer value (e.g., series number, instance number)
    Int(i32),
    /// Floating point value (e.g., slice thickness)
    Float(f32),
    /// List of integers (e.g., image dimensions)
    IntList(Vec<i32>),
    /// List of floating point values (e.g., image position, orientation)
    FloatList(Vec<f32>),
    /// List of strings (e.g., referenced study sequence)
    StrList(Vec<String>),
    /// Represents an unknown or unsupported value type
    Unknown,
}

// #[frb(dart_metadata=("freezed"))]
/// Represents a single DICOM tag with its value and metadata.
/// 
/// A DICOM tag consists of a unique identifier (tag), a value representation (VR),
/// a descriptive name, and the actual data value.
#[derive(Clone, Debug)]
pub struct DicomTag {
    /// The tag identifier in format 'GGGGEEEE' where G=group and E=element
    pub tag: String,
    /// Value Representation - the DICOM data type (e.g., "CS", "DS", "UI")
    pub vr: String,
    /// Human-readable name of the tag (e.g., "Patient Name", "Study Date")
    pub name: String,
    /// The actual value of the tag
    pub value: DicomValueType,
}

// New structure to hold complete DICOM metadata map
// #[frb(dart_metadata=("freezed"))]
/// Complete mapping of all DICOM metadata in a file, organized both as a flat map
/// and hierarchically by group.
/// 
/// This provides two different ways to access the same data:
/// 1. By direct tag lookup using the full tag identifier
/// 2. By group and element lookup for hierarchical navigation
#[derive(Clone, Debug)]
pub struct DicomMetadataMap {
    /// Flat map of all tags indexed by their full tag identifier
    pub tags: HashMap<String, DicomTag>,
    /// Hierarchical map organized by group (first 4 digits of tag) and then by element
    pub group_elements: HashMap<String, HashMap<String, DicomTag>>,
}

// Enhanced metadata structure with spatial information
// #[frb(dart_metadata=("freezed"))]
/// Core metadata extracted from a DICOM file with focus on patient, study, and spatial information.
/// 
/// This structure contains the most commonly used DICOM metadata for organizing and
/// displaying medical images, including patient demographics, study information,
/// and spatial positioning data needed for proper 3D reconstruction.
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
/// Represents a DICOM image's pixel data and associated parameters.
/// 
/// Contains the raw pixel data along with all the necessary information to
/// properly interpret and display the image, including dimensions, bit depth,
/// photometric interpretation, etc.
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
/// Complete representation of a DICOM file including its path, metadata, and all tags.
/// 
/// This structure provides access to both the commonly used metadata and the
/// complete set of DICOM tags found in a file.
#[derive(Clone, Debug)]
pub struct DicomFile {
    pub path: String,
    pub metadata: DicomMetadata,
    pub all_tags: Vec<DicomTag>,
}

// Individual DICOM instance (file) with path and validity
// #[frb(dart_metadata=("freezed"))]
/// Represents a single DICOM instance (file) with spatial information for proper ordering.
/// 
/// Contains the minimal information needed to identify and spatially locate a DICOM
/// instance within a series, which is essential for proper 3D reconstruction.
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
/// Represents a DICOM series containing multiple image instances.
/// 
/// A series typically represents a single acquisition of images with the same
/// imaging parameters, such as a CT scan or MRI sequence.
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
/// Represents a DICOM study containing multiple series.
/// 
/// A study represents a collection of image series acquired during a single
/// patient visit, often including different types of image acquisitions.
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
/// Represents a patient with associated DICOM studies.
/// 
/// The top level of the DICOM information hierarchy, containing all studies
/// associated with a particular patient.
#[derive(Clone, Debug)]
pub struct DicomPatient {
    pub patient_id: Option<String>,
    pub patient_name: Option<String>,
    pub studies: Vec<DicomStudy>,
}

// Legacy structure for backward compatibility
// #[frb(dart_metadata=("freezed"))]
/// Legacy structure for backward compatibility, representing a single DICOM file
/// found in a directory scan.
/// 
/// This structure provides a simpler, flat representation of DICOM data
/// for scenarios where the hierarchical organization isn't needed.
#[derive(Clone, Debug)]
pub struct DicomDirectoryEntry {
    pub path: String,
    pub metadata: DicomMetadata,
    pub is_valid: bool,
}

// DICOMDIR related structures
// #[frb(dart_metadata=("freezed"))]
/// Represents an entry in a DICOMDIR file, which can be a PATIENT, STUDY, SERIES, or IMAGE record.
/// 
/// DICOMDIR files are special DICOM files that serve as directories or catalogs of other
/// DICOM files, typically found on removable media like CDs/DVDs or in PACS archives.
#[derive(Clone, Debug)]
pub struct DicomDirEntry {
    pub path: String,
    pub type_name: String,  // PATIENT, STUDY, SERIES, IMAGE, etc.
    pub metadata: HashMap<String, DicomValueType>,
    pub children: Vec<DicomDirEntry>,
}

// New DicomHandler struct to provide a cleaner interface
// #[frb(dart_metadata=("freezed"))]
/// Main interface for interacting with DICOM files and directories.
/// 
/// This handler provides a comprehensive set of methods for working with DICOM data,
/// including loading files, extracting metadata, organizing files into proper patient/study/series
/// hierarchies, and handling specialized formats like DICOMDIR.
#[derive(Clone, Debug, Default)]
pub struct DicomHandler {}

// New struct to represent a 3D image volume.
/// Represents a 3D volume constructed from a series of 2D DICOM slices.
/// 
/// This structure contains the assembled volumetric data from multiple DICOM slices,
/// along with spatial information needed for proper 3D visualization and processing.
/// The pixel_data is organized as a contiguous 3D array with dimensions width × height × depth.
#[derive(Clone, Debug)]
pub struct DicomVolume {
    pub width: u32,
    pub height: u32,
    pub depth: u32,
    pub spacing: (f64, f64, f64),    // (spacing_x, spacing_y, spacing_z)
    pub data_type: String,         // e.g., "unsigned char" or "unsigned short"
    pub num_components: u32,
    /// New field: PNG‑encoded image for each slice
    pub slices: Vec<Vec<u8>>,
}

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
    /// Creates a new DicomHandler instance.
    /// 
    /// # Returns
    /// 
    /// A new DicomHandler object ready to use for DICOM operations.
    /// 
    /// # Examples
    /// 
    /// ```
    /// let handler = DicomHandler::new();
    /// ```
    pub fn new() -> Self {
        Self {}
    }

    /// Loads a DICOM file and returns detailed information including all metadata and tags.
    /// 
    /// # Arguments
    /// 
    /// * `path` - The path to the DICOM file to load
    /// 
    /// # Returns
    /// 
    /// A DicomFile containing the file path, metadata, and all tags, or an error if the file
    /// cannot be loaded or is not a valid DICOM file.
    /// 
    /// # Examples
    /// 
    /// ```
    /// let dicom_file = handler.load_file("/path/to/file.dcm")?;
    /// println!("Patient name: {:?}", dicom_file.metadata.patient_name);
    /// ```
    pub fn load_file(&self, path: String) -> Result<DicomFile, String> {
        load_dicom_file(path)
    }
    
    /// Checks if a file is a valid DICOM file.
    /// 
    /// This is a lightweight check that only verifies the DICOM file header and doesn't
    /// load the entire file or parse its contents.
    /// 
    /// # Arguments
    /// 
    /// * `path` - The path to the file to check
    /// 
    /// # Returns
    /// 
    /// `true` if the file is a valid DICOM file, `false` otherwise.
    /// 
    /// # Examples
    /// 
    /// ```
    /// if handler.is_valid_dicom("/path/to/file.dcm") {
    ///     println!("This is a valid DICOM file");
    /// }
    /// ```
    pub fn is_valid_dicom(&self, path: String) -> bool {
        is_dicom_file(path)
    }
    
    /// Gets common metadata from a DICOM file.
    /// 
    /// Extracts frequently used metadata like patient information, study details,
    /// and spatial data, without loading all tags.
    /// 
    /// # Arguments
    /// 
    /// * `path` - The path to the DICOM file
    /// 
    /// # Returns
    /// 
    /// A DicomMetadata structure containing the extracted metadata, or an error if
    /// the file cannot be loaded or parsed.
    /// 
    /// # Examples
    /// 
    /// ```
    /// let metadata = handler.get_metadata("/path/to/file.dcm")?;
    /// println!("Patient: {:?}, Study: {:?}", metadata.patient_name, metadata.study_description);
    /// ```
    pub fn get_metadata(&self, path: String) -> Result<DicomMetadata, String> {
        let file_path = Path::new(&path);

        let obj = match FileDicomObject::<InMemDicomObject>::open_file(file_path) {
            Ok(obj) => obj,
            Err(e) => return Err(format!("Failed to open DICOM file: {}", e)),
        };

        extract_metadata(&obj).map_err(|e| e.to_string())
    }
    
    /// Gets a complete list of all tags present in a DICOM file.
    /// 
    /// # Arguments
    /// 
    /// * `path` - The path to the DICOM file
    /// 
    /// # Returns
    /// 
    /// A vector of DicomTag structures containing all tags found in the file,
    /// or an error if the file cannot be loaded or parsed.
    /// 
    /// # Examples
    /// 
    /// ```
    /// let tags = handler.get_all_tags("/path/to/file.dcm")?;
    /// for tag in tags {
    ///     println!("{}: {:?}", tag.name, tag.value);
    /// }
    /// ```
    pub fn get_all_tags(&self, path: String) -> Result<Vec<DicomTag>, String> {
        let file_path = Path::new(&path);

        let obj = match FileDicomObject::<InMemDicomObject>::open_file(file_path) {
            Ok(obj) => obj,
            Err(e) => return Err(format!("Failed to open DICOM file: {}", e)),
        };

        extract_all_tags(&obj).map_err(|e| e.to_string())
    }
    
    /// Gets the value of a specific tag identified by its name.
    /// 
    /// # Arguments
    /// 
    /// * `path` - The path to the DICOM file
    /// * `tag_name` - The name of the tag to retrieve (e.g., "PatientName")
    /// 
    /// # Returns
    /// 
    /// The value of the requested tag as a DicomValueType, or an error if the file
    /// cannot be loaded or the tag is not found.
    /// 
    /// # Examples
    /// 
    /// ```
    /// let value = handler.get_tag_value("/path/to/file.dcm", "PatientName")?;
    /// if let DicomValueType::Str(name) = value {
    ///     println!("Patient name: {}", name);
    /// }
    /// ```
    pub fn get_tag_value(&self, path: String, tag_name: String) -> Result<DicomValueType, String> {
        get_tag_value(path, tag_name)
    }
    
    /// Extracts raw pixel data and image parameters from a DICOM file.
    /// 
    /// # Arguments
    /// 
    /// * `path` - The path to the DICOM file
    /// 
    /// # Returns
    /// 
    /// A DicomImage structure containing the pixel data and associated parameters,
    /// or an error if the file cannot be loaded or the pixel data cannot be decoded.
    /// 
    /// # Examples
    /// 
    /// ```
    /// let image = handler.get_pixel_data("/path/to/file.dcm")?;
    /// println!("Image dimensions: {}x{}, {} bits", image.width, image.height, image.bits_allocated);
    /// ```
    pub fn get_pixel_data(&self, path: String) -> Result<DicomImage, String> {
        extract_pixel_data(path)
    }
    
    /// Gets image bytes encoded as PNG from a DICOM file for easy display.
    /// 
    /// This function handles windowing (contrast/brightness) automatically and
    /// converts the DICOM pixel data to a standard PNG format suitable for display
    /// in image viewers or web browsers.
    /// 
    /// # Arguments
    /// 
    /// * `path` - The path to the DICOM file
    /// 
    /// # Returns
    /// 
    /// A vector of bytes containing the PNG-encoded image, or an error if the file
    /// cannot be loaded or encoded.
    /// 
    /// # Examples
    /// 
    /// ```
    /// let png_bytes = handler.get_image_bytes("/path/to/file.dcm")?;
    /// std::fs::write("output.png", &png_bytes)?;
    /// ```
    pub fn get_image_bytes(&self, path: String) -> Result<Vec<u8>, String> {
        get_encoded_image(path)
    }
    
    /// Loads all DICOM files from a directory (non-recursive).
    /// 
    /// # Arguments
    /// 
    /// * `path` - The path to the directory to scan
    /// 
    /// # Returns
    /// 
    /// A vector of DicomDirectoryEntry structures, each representing one DICOM file
    /// found in the directory, or an error if the directory cannot be accessed.
    /// 
    /// # Examples
    /// 
    /// ```
    /// let entries = handler.load_directory("/path/to/dicom/folder")?;
    /// println!("Found {} DICOM files", entries.len());
    /// ```
    pub fn load_directory(&self, path: String) -> Result<Vec<DicomDirectoryEntry>, String> {
        load_dicom_directory(path)
    }
    
    /// Loads all DICOM files from a directory and its subdirectories recursively.
    /// 
    /// # Arguments
    /// 
    /// * `path` - The path to the root directory to scan
    /// 
    /// # Returns
    /// 
    /// A vector of DicomDirectoryEntry structures representing all DICOM files
    /// found in the directory tree, or an error if directories cannot be accessed.
    /// 
    /// # Examples
    /// 
    /// ```
    /// let entries = handler.load_directory_recursive("/path/to/root/folder")?;
    /// println!("Found {} DICOM files in all subdirectories", entries.len());
    /// ```
    pub fn load_directory_recursive(&self, path: String) -> Result<Vec<DicomDirectoryEntry>, String> {
        load_dicom_directory_recursive(path)
    }

    /// Gets a list of all tag names present in a DICOM file.
    /// 
    /// This is a simpler alternative to get_all_tags() that returns only the names
    /// of the tags without their values, useful for UI dropdowns or tag selection.
    /// 
    /// # Arguments
    /// 
    /// * `path` - The path to the DICOM file
    /// 
    /// # Returns
    /// 
    /// A vector of strings containing the names of all tags found in the file,
    /// or an error if the file cannot be loaded or parsed.
    /// 
    /// # Examples
    /// 
    /// ```
    /// let tag_names = handler.list_tags("/path/to/file.dcm")?;
    /// for name in tag_names {
    ///     println!("Available tag: {}", name);
    /// }
    /// ```
    pub fn list_tags(&self, path: String) -> Result<Vec<String>, String> {
        list_all_tags(path)
    }

    /// Loads all DICOM files from a directory (non-recursive) and organizes them into a 
    /// patient-study-series hierarchy.
    /// 
    /// # Arguments
    /// 
    /// * `path` - The path to the directory to scan
    /// 
    /// # Returns
    /// 
    /// A vector of DicomPatient structures, each containing the hierarchical organization
    /// of studies, series, and instances, or an error if the directory cannot be accessed.
    /// 
    /// # Examples
    /// 
    /// ```
    /// let patients = handler.load_directory_organized("/path/to/dicom/folder")?;
    /// for patient in patients {
    ///     println!("Patient: {:?}, Studies: {}", patient.patient_name, patient.studies.len());
    /// }
    /// ```
    pub fn load_directory_organized(&self, path: String) -> Result<Vec<DicomPatient>, String> {
        load_dicom_directory_organized(path, false)
    }
    
    /// Loads all DICOM files from a directory and its subdirectories recursively, 
    /// and organizes them into a patient-study-series hierarchy.
    /// 
    /// # Arguments
    /// 
    /// * `path` - The path to the root directory to scan
    /// 
    /// # Returns
    /// 
    /// A vector of DicomPatient structures containing the hierarchical organization
    /// of all DICOM files found in the directory tree, or an error if directories
    /// cannot be accessed.
    /// 
    /// # Examples
    /// 
    /// ```
    /// let patients = handler.load_directory_recursive_organized("/path/to/root/folder")?;
    /// println!("Found {} patients across all subdirectories", patients.len());
    /// ```
    pub fn load_directory_recursive_organized(&self, path: String) -> Result<Vec<DicomPatient>, String> {
        load_dicom_directory_organized(path, true)
    }
    
    /// Loads a directory and returns a complete study with metadata propagated to all slices.
    /// 
    /// This method is optimized for loading a single study from a directory, ensuring that
    /// missing metadata is properly filled in across all slices for consistent display.
    /// 
    /// # Arguments
    /// 
    /// * `path` - The path to the directory containing the study
    /// 
    /// # Returns
    /// 
    /// A DicomStudy structure containing the complete study information with consistent
    /// metadata across all series and instances, or an error if the directory cannot
    /// be accessed or does not contain a valid study.
    /// 
    /// # Examples
    /// 
    /// ```
    /// let study = handler.load_complete_study("/path/to/study/folder")?;
    /// println!("Study: {:?}, Series: {}", study.study_description, study.series.len());
    /// ```
    pub fn load_complete_study(&self, path: String) -> Result<DicomStudy, String> {
        load_complete_study(path, false)
    }
    
    /// Loads a directory recursively and returns a complete study with metadata propagated to all slices.
    /// 
    /// Similar to load_complete_study(), but searches through subdirectories as well,
    /// useful when studies are organized in a deeper folder structure.
    /// 
    /// # Arguments
    /// 
    /// * `path` - The path to the root directory to scan
    /// 
    /// # Returns
    /// 
    /// A DicomStudy structure containing the complete study information with consistent
    /// metadata across all series and instances, or an error if directories cannot be
    /// accessed or do not contain a valid study.
    /// 
    /// # Examples
    /// 
    /// ```
    /// let study = handler.load_complete_study_recursive("/path/to/root/folder")?;
    /// println!("Found study: {:?} with {} series", study.study_description, study.series.len());
    /// ```
    pub fn load_complete_study_recursive(&self, path: String) -> Result<DicomStudy, String> {
        load_complete_study(path, true)
    }

    /// Extracts all metadata from a DICOM file as a complete metadata map.
    /// 
    /// This provides both a flat and hierarchical representation of all metadata in the file,
    /// allowing for more advanced navigation and lookup of DICOM attributes.
    /// 
    /// # Arguments
    /// 
    /// * `path` - The path to the DICOM file
    /// 
    /// # Returns
    /// 
    /// A DicomMetadataMap containing both flat and hierarchical representations of all
    /// metadata in the file, or an error if the file cannot be loaded or parsed.
    /// 
    /// # Examples
    /// 
    /// ```
    /// let metadata_map = handler.get_all_metadata("/path/to/file.dcm")?;
    /// // Access by direct tag
    /// let patient_name = metadata_map.tags.get("00100010");
    /// // Access by group and element
    /// let patient_id = metadata_map.group_elements.get("0010").and_then(|g| g.get("0020"));
    /// ```
    pub fn get_all_metadata(&self, path: String) -> Result<DicomMetadataMap, String> {
        extract_all_metadata(&path)
    }

    /// Unified function to load DICOM files from a directory, handling both regular DICOM files and DICOMDIR.
    /// 
    /// This method automatically detects if a DICOMDIR file is present in the directory and uses it
    /// for more efficient loading if available, otherwise falls back to scanning for individual DICOM files.
    /// 
    /// # Arguments
    /// 
    /// * `path` - The path to the directory to scan
    /// * `recursive` - Whether to scan subdirectories recursively
    /// 
    /// # Returns
    /// 
    /// A vector of DicomDirectoryEntry structures representing all DICOM files found,
    /// or an error if directories cannot be accessed.
    /// 
    /// # Examples
    /// 
    /// ```
    /// // Will automatically use DICOMDIR if present
    /// let entries = handler.load_directory_unified("/path/to/dicom/folder", false)?;
    /// println!("Loaded {} DICOM files", entries.len());
    /// ```
    pub fn load_directory_unified(&self, path: String, recursive: bool) -> Result<Vec<DicomDirectoryEntry>, String> {
        load_dicom_directory_unified(path, recursive)
    }
    
    /// Check if a file is a DICOMDIR file.
    /// 
    /// DICOMDIR files are special DICOM files that serve as a directory or catalog of other DICOM files,
    /// typically found on removable media like CDs/DVDs or in PACS archives.
    /// 
    /// # Arguments
    /// 
    /// * `path` - The path to the file to check
    /// 
    /// # Returns
    /// 
    /// `true` if the file is a DICOMDIR file, `false` otherwise
    /// 
    /// # Examples
    /// 
    /// ```
    /// if handler.is_dicomdir("/path/to/DICOMDIR") {
    ///     println!("This is a DICOMDIR catalog file");
    /// }
    /// ```
    pub fn is_dicomdir(&self, path: String) -> bool {
        is_dicomdir_file(&path)
    }
    
    /// Parse a DICOMDIR file and return its hierarchical structure.
    /// 
    /// # Arguments
    /// 
    /// * `path` - The path to the DICOMDIR file
    /// 
    /// # Returns
    /// 
    /// A DicomDirEntry structure representing the root of the DICOMDIR hierarchy,
    /// or an error if the file cannot be loaded or is not a valid DICOMDIR file.
    /// 
    /// # Examples
    /// 
    /// ```
    /// let dicomdir = handler.parse_dicomdir("/path/to/DICOMDIR")?;
    /// println!("DICOMDIR contains {} top-level entries", dicomdir.children.len());
    /// ```
    pub fn parse_dicomdir(&self, path: String) -> Result<DicomDirEntry, String> {
        parse_dicomdir_file(path)
    }

    /// Loads a multi-slice volume from a directory of DICOM files.
    /// 
    /// This function loads all DICOM files in a directory, sorts them by spatial position,
    /// and assembles them into a single 3D volume suitable for 3D visualization or processing.
    /// 
    /// # Arguments
    /// 
    /// * `path` - The path to the directory containing the DICOM slices
    /// 
    /// # Returns
    /// 
    /// A DicomVolume structure containing the assembled 3D volume data and associated
    /// spatial information, or an error if the directory cannot be accessed or does not
    /// contain a valid set of DICOM slices.
    /// 
    /// # Examples
    /// 
    /// ```
    /// let volume = handler.load_volume("/path/to/slice/folder")?;
    /// println!("Volume dimensions: {}x{}x{}", volume.width, volume.height, volume.depth);
    /// println!("Voxel spacing: {:?}", volume.spacing);
    /// ```
    pub fn load_volume(&self, path: String) -> Result<DicomVolume, String> {
        load_volume_from_directory(path)
    }
}

/// Loads a DICOM file from the given path and extracts all its data.
/// 
/// # Arguments
/// 
/// * `path` - The path to the DICOM file to load
/// 
/// # Returns
/// 
/// A DicomFile containing the file path, metadata, and all tags, or an error if the file
/// cannot be loaded or is not a valid DICOM file.
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
        .unwrap_or_else(|| "MONOCHROME2".to_string()); // Default to MONOCHROME2 if missing or invalid

    let samples_per_pixel = obj.element(tags::SAMPLES_PER_PIXEL)
        .map_err(|e| format!("Failed to get samples per pixel: {}", e))?;
    let samples_per_pixel = element_to_u16(samples_per_pixel)
        .ok_or_else(|| "Invalid samples per pixel format".to_string())?;

    // Planar configuration is optional
    let planar_configuration = obj.element(tags::PLANAR_CONFIGURATION)
        .ok()
        .and_then(|e| element_to_u16(e));

    // Extract raw pixel data bytes using a more robust approach with error handling
    let pixel_data_bytes = match decoded.to_vec() {
        Ok(data) => data,
        Err(e) => {
            // Try an alternative approach with direct frame access
            let frames_count = decoded.number_of_frames();
            
            if frames_count > 0 {
                let mut buffer = Vec::new();
                
                // Try to get raw frame data
                let frame_bytes = match decoded.frame_data(0) {
                    Ok(data) => data.to_vec(),
                    Err(_) => {
                        // Last resort: try to access the raw pixel data directly
                        match obj.element(tags::PIXEL_DATA) {
                            Ok(pixel_data_elem) => {
                                if let Value::Primitive(PrimitiveValue::U8(bytes)) = pixel_data_elem.value() {
                                    bytes.to_vec()
                                } else {
                                    return Err(format!("Cannot extract raw pixel data: unsupported format"));
                                }
                            },
                            Err(_) => return Err(format!("Failed to access pixel data element"))
                        }
                    }
                };
                
                buffer.extend_from_slice(&frame_bytes);
                buffer
            } else {
                return Err(format!("Failed to convert pixel data to vector: {}", e));
            }
        }
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

/// Extract all metadata from a DICOM file as a complete map
pub fn extract_all_metadata(path: &str) -> Result<DicomMetadataMap, String> {
    let file_path = Path::new(path);

    let obj = match FileDicomObject::<InMemDicomObject>::open_file(file_path) {
        Ok(obj) => obj,
        Err(e) => return Err(format!("Failed to open DICOM file: {}", e)),
    };

    let mut tags = HashMap::new();
    let mut group_elements = HashMap::new();
    let dict = dictionary_std::StandardDataDictionary;

    for elem in obj.iter() {
        let tag_value = elem.header().tag;
        let group = format!("{:04X}", tag_value.group());
        let element = format!("{:04X}", tag_value.element());
        let tag_str = format!("{}{}", group, element);
        let vr = elem.header().vr.to_string();

        let name = dict
            .by_tag(elem.header().tag)
            .map(|entry| entry.alias.to_string())
            .unwrap_or_else(|| format!("Unknown ({},{}) Group", group, element));

        let value = convert_value_to_dicom_type(elem.value());

        let dicom_tag = DicomTag {
            tag: tag_str.clone(),
            vr: vr.to_string(),
            name: name.clone(),
            value: value.clone(),
        };

        // Add to flat map
        tags.insert(tag_str.clone(), dicom_tag.clone());

        // Add to grouped map
        let group_map = group_elements.entry(group).or_insert_with(HashMap::new);
        group_map.insert(element, dicom_tag);
    }

    Ok(DicomMetadataMap {
        tags,
        group_elements,
    })
}

/// Check if a file is a DICOMDIR file
pub fn is_dicomdir_file(path: &str) -> bool {
    let file_path = Path::new(path);
    
    if !file_path.exists() || file_path.is_dir() {
        return false;
    }
    
    // First check if it's a valid DICOM file
    if !is_dicom_file(path.to_string()) {
        return false;
    }
    
    // Then check if it has the correct Media Storage SOP Class UID for DICOMDIR
    if let Ok(obj) = FileDicomObject::<InMemDicomObject>::open_file(file_path) {
        if let Ok(elem) = obj.element(tags::MEDIA_STORAGE_SOP_CLASS_UID) {
            if let Some(sop_class) = element_to_string(elem) {
                // DICOMDIR has this specific SOP class UID
                return sop_class == "1.2.840.10008.1.3.10"; // Media Storage Directory Storage
            }
        }
    }
    
    false
}

/// Parse a DICOMDIR file and return its structure
pub fn parse_dicomdir_file(path: String) -> Result<DicomDirEntry, String> {
    let file_path = Path::new(&path);
    
    if (!file_path.exists()) {
        return Err(format!("File not found: {}", path));
    }
    
    if (!is_dicomdir_file(&path)) {
        return Err(format!("Not a valid DICOMDIR file: {}", path));
    }
    
    let obj = match FileDicomObject::<InMemDicomObject>::open_file(file_path) {
        Ok(obj) => obj,
        Err(e) => return Err(format!("Failed to open DICOMDIR file: {}", e)),
    };
    
    // DICOMDIR contains a directory record sequence
    let dir_record_sequence = match obj.element(tags::DIRECTORY_RECORD_SEQUENCE) {
        Ok(elem) => elem,
        Err(e) => return Err(format!("Failed to find directory record sequence: {}", e)),
    };
    
    let mut root = DicomDirEntry {
        path: path.clone(),
        type_name: "ROOT".to_string(),
        metadata: HashMap::new(),
        children: Vec::new(),
    };
    
    // Add basic metadata to the root
    if let Ok(elem) = obj.element(tags::MEDIA_STORAGE_SOP_INSTANCE_UID) {
        if let Some(uid) = element_to_string(elem) {
            root.metadata.insert("MediaStorageSOPInstanceUID".to_string(), DicomValueType::Str(uid));
        }
    }
    
    // Parse the directory records into a hierarchical structure
    if let Value::Sequence(seq) = dir_record_sequence.value() {
        parse_dicomdir_records(seq, &mut root, file_path.parent().unwrap_or(Path::new("")));
    }
    
    // Return the root directory entry
    Ok(root)
}

/// Parse the directory records into a hierarchical structure
fn parse_dicomdir_records(seq: &DataSetSequence<InMemDicomObject>, parent: &mut DicomDirEntry, base_path: &Path) {
    // DataSetSequence is not an iterator, we need to use its .items() method to get access to records
    for record in seq.items() {
        // Get record type
        let record_type = record.element(tags::DIRECTORY_RECORD_TYPE)
            .ok()
            .and_then(|e| element_to_string(e))
            .unwrap_or_else(|| "UNKNOWN".to_string());
            
        let mut entry = DicomDirEntry {
            path: "".to_string(),
            type_name: record_type.clone(),
            metadata: HashMap::new(),
            children: Vec::new(),
        };
        
        // Extract common metadata
        extract_dicomdir_record_metadata(record, &mut entry);
        
        // Handle file references for IMAGE records
        if record_type == "IMAGE" {
            if let Ok(elem) = record.element(tags::REFERENCED_FILE_ID) {
                if let Some(file_path) = element_to_string(elem) {
                    // Convert backslash-separated path to proper path
                    let path_parts: Vec<&str> = file_path.split('\\').collect();
                    let file_path = path_parts.join(std::path::MAIN_SEPARATOR.to_string().as_str());
                    let full_path = base_path.join(file_path);
                    
                    if let Some(path_str) = full_path.to_str() {
                        entry.path = path_str.to_string();
                    }
                }
            }
        }
        
        // Handle lower-level directory records (recursive)
        // Using Tag::from for the Lower Level Directory Record Sequence (0004,1420)
        let lower_level_tag = Tag::from((0x0004, 0x1420));
        if let Ok(elem) = record.element(lower_level_tag) {
            if let Value::Sequence(ref lower_seq) = elem.value() {
                // Pass a reference to lower_seq to match the expected type
                parse_dicomdir_records(lower_seq, &mut entry, base_path);
            }
        }
        
        // Add this entry to parent's children
        parent.children.push(entry);
    }
}

/// Extract metadata from a DICOMDIR record
fn extract_dicomdir_record_metadata(record: &InMemDicomObject, entry: &mut DicomDirEntry) {
    // Common DICOMDIR record elements to extract
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
        // Add more tags as needed
    ];
    
    for (tag, name) in tags_to_extract.iter() {
        if let Ok(elem) = record.element(*tag) {
            let value = convert_value_to_dicom_type(elem.value());
            entry.metadata.insert(name.to_string(), value);
        }
    }
}

/// Unified function to load DICOM files from a directory, handling both regular DICOM files and DICOMDIR
pub fn load_dicom_directory_unified(dir_path: String, recursive: bool) -> Result<Vec<DicomDirectoryEntry>, String> {
    let path = Path::new(&dir_path);
    
    if !path.exists() || !path.is_dir() {
        return Err(format!("Invalid directory path: {}", dir_path));
    }
    
    // First, check for DICOMDIR file in the directory
    let potential_dicomdir = path.join("DICOMDIR");
    let potential_dicomdir_lower = path.join("dicomdir");
    
    if potential_dicomdir.exists() && is_dicomdir_file(potential_dicomdir.to_str().unwrap_or("")) {
        return load_from_dicomdir(potential_dicomdir.to_str().unwrap_or("").to_string());
    } else if potential_dicomdir_lower.exists() && is_dicomdir_file(potential_dicomdir_lower.to_str().unwrap_or("")) {
        return load_from_dicomdir(potential_dicomdir_lower.to_str().unwrap_or("").to_string());
    }
    
    // If no DICOMDIR found, use the regular directory loading functions
    if recursive {
        load_dicom_directory_recursive(dir_path)
    } else {
        load_dicom_directory(dir_path)
    }
}

/// Load DICOM files from a DICOMDIR catalog
fn load_from_dicomdir(dicomdir_path: String) -> Result<Vec<DicomDirectoryEntry>, String> {
    // Parse the DICOMDIR file
    let dicomdir = parse_dicomdir_file(dicomdir_path.clone())?;
    
    let mut result = Vec::new();
    
    // Process the directory structure recursively
    process_dicomdir_entries(&dicomdir, &mut result);
    
    if result.is_empty() {
        return Err(format!("No valid DICOM images found in DICOMDIR: {}", dicomdir_path));
    }
    
    // Sort the results using proper sorting algorithm for 3D space
    sort_dicom_entries_by_position(&mut result);
    
    Ok(result)
}

/// Process DICOMDIR entries recursively to extract file paths and metadata
fn process_dicomdir_entries(entry: &DicomDirEntry, result: &mut Vec<DicomDirectoryEntry>) {
    // If this is an IMAGE entry with a valid path, add it to our results
    if entry.type_name == "IMAGE" && !entry.path.is_empty() && Path::new(&entry.path).exists() {
        // Create metadata from the available DICOMDIR information
        let metadata = create_metadata_from_dicomdir_entry(entry);
        
        // Augment with full metadata if possible by loading the actual file
        let mut dicom_entry = DicomDirectoryEntry {
            path: entry.path.clone(),
            metadata,
            is_valid: true,
        };
        
        // Try to load the actual file to get complete metadata
        if let Ok(obj) = FileDicomObject::<InMemDicomObject>::open_file(&entry.path) {
            if let Ok(full_metadata) = extract_metadata(&obj) {
                dicom_entry.metadata = full_metadata;
            }
        }
        
        result.push(dicom_entry);
    }
    
    // Process children recursively
    for child in &entry.children {
        process_dicomdir_entries(child, result);
    }
}

/// Create basic metadata from a DICOMDIR entry
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
    
    // Extract metadata from the DICOMDIR entry
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

fn sort_dicom_entries_by_position(entries: &mut Vec<DicomDirectoryEntry>) {
    // Check if any entry has valid Image Position and Orientation Patient data.
    if let Some(first_with_orientation) = entries.iter().find(|e| {
        e.metadata.image_orientation.as_ref().map(|v| v.len() >= 6).unwrap_or(false) &&
        e.metadata.image_position.as_ref().map(|v| v.len() >= 3).unwrap_or(false)
    }) {
        // Use the orientation from the first entry with valid orientation.
        let orient = first_with_orientation.metadata.image_orientation.as_ref().unwrap();
        let mut normal = [0.0, 0.0, 1.0];
        normal[0] = (orient[1] * orient[5]) - (orient[2] * orient[4]);
        normal[1] = (orient[2] * orient[3]) - (orient[0] * orient[5]);
        normal[2] = (orient[0] * orient[4]) - (orient[1] * orient[3]);

        // Look for the first two entries with valid image position.
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

        // If we found at least two slices, determine sort order.
        if proj_vals.len() >= 2 {
            // If the first slice's projection is greater than the second, we need descending order.
            let reverse = proj_vals[0] > proj_vals[1];

            entries.sort_by(|a, b| {
                let default_pos = vec![0.0, 0.0, 0.0];
                let pos_a = a.metadata.image_position.as_ref().unwrap_or(&default_pos);
                let pos_b = b.metadata.image_position.as_ref().unwrap_or(&default_pos);
                let proj_a = if pos_a.len() >= 3 {
                    normal[0] * pos_a[0] + normal[1] * pos_a[1] + normal[2] * pos_a[2]
                } else {
                    0.0
                };
                let proj_b = if pos_b.len() >= 3 {
                    normal[0] * pos_b[0] + normal[1] * pos_b[1] + normal[2] * pos_b[2]
                } else {
                    0.0
                };

                if reverse {
                    // Sort in descending order.
                    proj_b.partial_cmp(&proj_a).unwrap_or(Ordering::Equal)
                } else {
                    // Sort in ascending order.
                    proj_a.partial_cmp(&proj_b).unwrap_or(Ordering::Equal)
                }
            });
            return;
        }
    }

    // Fallback if no valid image position/orientation is available:
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
        return;
    }

    // Last resort: sort by instance number.
    sort_dicom_entries(entries);
}

/// Compute correct slice spacing based on consecutive slices
pub fn compute_slice_spacing(entries: &Vec<DicomDirectoryEntry>) -> Option<f64> {
    if entries.len() < 2 {
        return None;
    }

    // Try using image position patient
    let has_positions = entries.iter().any(|e| e.metadata.image_position.is_some() && 
                                            e.metadata.image_position.as_ref().unwrap().len() >= 3);
    if has_positions {
        // Find two consecutive slices with valid positions
        for i in 0..entries.len()-1 {
            if let (Some(pos1), Some(pos2)) = (&entries[i].metadata.image_position, &entries[i+1].metadata.image_position) {
                if pos1.len() >= 3 && pos2.len() >= 3 {
                    // Compute Euclidean distance between positions
                    let dx = pos2[0] - pos1[0];
                    let dy = pos2[1] - pos1[1];
                    let dz = pos2[2] - pos1[2];
                    return Some((dx*dx + dy*dy + dz*dz).sqrt());
                }
            }
        }
    }
    
    // Try using slice location
    let has_slice_loc = entries.iter().any(|e| e.metadata.slice_location.is_some());
    if has_slice_loc {
        for i in 0..entries.len()-1 {
            if let (Some(loc1), Some(loc2)) = (entries[i].metadata.slice_location, entries[i+1].metadata.slice_location) {
                return Some((loc2 - loc1).abs());
            }
        }
    }
    
    // Fall back to slice thickness if available
    entries.iter()
        .find_map(|e| e.metadata.slice_thickness)
}

/// Flip the image data vertically. This function assumes that pixel_data is
/// organized as a contiguous array with each row of length `row_length` bytes.
/// It creates a new Vec<u8> with the rows in reverse order.
/// This mimics the VTK logic where the image's first row (top-left) is moved to the bottom.
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

/// Compute the row length (in bytes) for an image slice.
/// Assumes row_length = width * (bits_allocated/8) * samples_per_pixel.
fn compute_row_length(width: u32, bits_allocated: u16, samples_per_pixel: u16) -> usize {
    let bytes_per_sample = ((bits_allocated as usize) + 7) / 8;
    (width as usize) * bytes_per_sample * (samples_per_pixel as usize)
}

/// Loads a multi-slice volume from a directory of DICOM files using VTK-like logic.
/// 1. It lists all DICOM files (using your existing load_dicom_directory function).
/// 2. It sorts the files using spatial information (image position and/or slice location).
/// 3. It reads and vertically flips each slice's pixel data.
/// 4. It assembles all slices into one contiguous buffer.
pub fn load_volume_from_directory(dir_path: String) -> Result<DicomVolume, String> {
    // Load directory entries (non-recursive for simplicity)
    let mut entries = load_dicom_directory(dir_path.clone())?;
    if entries.is_empty() {
        return Err("No valid DICOM files found in directory".to_string());
    }
    
    // Sort entries using spatial information (e.g. image position, slice location)
    sort_dicom_entries_by_position(&mut entries);

    // Use the first entry to determine common image parameters.
    let first_entry = &entries[0];
    let first_image = extract_pixel_data(first_entry.path.clone())?;
    let width = first_image.width;
    let height = first_image.height;
    let bits_allocated = first_image.bits_allocated;
    let samples_per_pixel = first_image.samples_per_pixel;

    // Instead of concatenating pixel data directly, generate PNG-encoded images for each slice.
    let mut slice_images = Vec::new();
    for entry in entries.iter() {
        let encoded = get_encoded_image(entry.path.clone())?;
        slice_images.push(encoded);
    }
    
    let depth = slice_images.len() as u32;

    // Compute spacing:
    // Use pixel spacing from the first slice (usually [spacing_x, spacing_y])
    let spacing_xy = match &first_entry.metadata.pixel_spacing {
        Some(ps) if ps.len() >= 2 => (ps[0], ps[1]),
        _ => (1.0, 1.0)
    };
    // Compute slice spacing (z) using your helper function
    let spacing_z = compute_slice_spacing(&entries).unwrap_or(1.0);

    
    // Determine data type string based on bits allocated
    let data_type = if bits_allocated <= 8 {
        "unsigned char".to_string()
    } else {
        "unsigned short".to_string()
    };

    Ok(DicomVolume {
        width,
        height,
        depth,
        spacing: (spacing_xy.0, spacing_xy.1, spacing_z),
        data_type,
        num_components: samples_per_pixel as u32,
        slices: slice_images, // The vector of PNG-encoded slice images
    })
}
