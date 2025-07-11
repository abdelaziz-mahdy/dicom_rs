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
