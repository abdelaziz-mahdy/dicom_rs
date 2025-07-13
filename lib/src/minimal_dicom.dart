// Minimal DICOM package interface
// This file contains only the essential DICOM functionality for the package
// Complex features are demonstrated in the example app

library;

import 'dart:typed_data';
import '../src/rust/api/dicom_rs_interface.dart' as rust;

/// Core metadata extracted from a DICOM file
class DicomMetadata {
  final String? patientName;
  final String? patientId;
  final String? studyDate;
  final String? modality;
  final String? studyDescription;
  final String? seriesDescription;
  final int? instanceNumber;
  final int? seriesNumber;
  final String? studyInstanceUid;
  final String? seriesInstanceUid;
  final String? sopInstanceUid;
  final List<double>? imagePosition;
  final List<double>? pixelSpacing;
  final double? sliceLocation;
  final double? sliceThickness;

  const DicomMetadata({
    this.patientName,
    this.patientId,
    this.studyDate,
    this.modality,
    this.studyDescription,
    this.seriesDescription,
    this.instanceNumber,
    this.seriesNumber,
    this.studyInstanceUid,
    this.seriesInstanceUid,
    this.sopInstanceUid,
    this.imagePosition,
    this.pixelSpacing,
    this.sliceLocation,
    this.sliceThickness,
  });

  // Compatibility getters for legacy code
  String? get studyInstanceUID => studyInstanceUid;
  String? get seriesInstanceUID => seriesInstanceUid;
  String? get sopInstanceUID => sopInstanceUid;
  String? get accessionNumber => null; // Not available in minimal API

  @override
  String toString() {
    return 'DicomMetadata(patientName: $patientName, modality: $modality, studyDate: $studyDate)';
  }
}

/// DICOM image pixel data and basic parameters
class DicomImage {
  final int width;
  final int height;
  final int bitsAllocated;
  final int bitsStored;
  final int pixelRepresentation;
  final String photometricInterpretation;
  final int samplesPerPixel;
  final Uint8List pixelData;

  const DicomImage({
    required this.width,
    required this.height,
    required this.bitsAllocated,
    required this.bitsStored,
    required this.pixelRepresentation,
    required this.photometricInterpretation,
    required this.samplesPerPixel,
    required this.pixelData,
  });

  @override
  String toString() {
    return 'DicomImage(${width}x$height, $bitsAllocated bits, $photometricInterpretation)';
  }
}

/// Complete DICOM file representation
class DicomFile {
  final DicomMetadata metadata;
  final DicomImage? image;
  final bool isValid;

  const DicomFile({
    required this.metadata,
    this.image,
    required this.isValid,
  });

  // Compatibility getters for legacy code  
  bool get isMultiframe => false; // Not available in minimal API
  int get numFrames => 1; // Default for minimal API
  List<dynamic> get allTags => []; // Not available in minimal API

  @override
  String toString() {
    return 'DicomFile(isValid: $isValid, hasImage: ${image != null})';
  }
}

/// Main interface for DICOM operations (minimal package API)
class DicomHandler {
  static const DicomHandler _instance = DicomHandler._internal();
  static rust.DicomHandler? _rustHandler;
  
  const DicomHandler._internal();
  
  /// Get the singleton instance
  factory DicomHandler() => _instance;
  
  /// Initialize the Rust handler (called automatically)
  static Future<rust.DicomHandler> _getRustHandler() async {
    _rustHandler ??= await rust.DicomHandler.newInstance();
    return _rustHandler!;
  }

  /// Check if bytes represent a valid DICOM file
  /// 
  /// This is the fastest way to validate DICOM data without parsing the entire content.
  /// 
  /// Example:
  /// ```dart
  /// final handler = DicomHandler();
  /// final bytes = await File('/path/to/file.dcm').readAsBytes();
  /// bool isValid = await handler.isDicomFile(bytes);
  /// ```
  Future<bool> isDicomFile(List<int> bytes) async {
    try {
      final rustHandler = await _getRustHandler();
      return await rustHandler.isDicomFile(bytes: bytes);
    } catch (e) {
      return false;
    }
  }
  

  /// Load a complete DICOM from bytes with metadata and image data
  /// 
  /// This loads both the metadata and pixel data (if available).
  /// Use [getMetadata] if you only need metadata for better performance.
  /// 
  /// Example:
  /// ```dart
  /// final handler = DicomHandler();
  /// final bytes = await File('/path/to/file.dcm').readAsBytes();
  /// try {
  ///   DicomFile file = await handler.loadFile(bytes);
  ///   print('Patient: ${file.metadata.patientName}');
  ///   if (file.image != null) {
  ///     print('Image size: ${file.image!.width}x${file.image!.height}');
  ///   }
  /// } catch (e) {
  ///   print('Failed to load DICOM file: $e');
  /// }
  /// ```
  Future<DicomFile> loadFile(List<int> bytes) async {
    final rustHandler = await _getRustHandler();
    final rustFile = await rustHandler.loadFileWithImage(bytes: bytes);
    
    return DicomFile(
      metadata: _convertMetadata(rustFile.metadata),
      image: rustFile.image != null ? _convertImage(rustFile.image!) : null,
      isValid: rustFile.isValid,
    );
  }
  

  /// Extract only metadata from DICOM bytes (faster than full load)
  /// 
  /// This is more efficient than [loadFile] when you only need metadata
  /// and don't need the pixel data.
  /// 
  /// Example:
  /// ```dart
  /// final handler = DicomHandler();
  /// final bytes = await File('/path/to/file.dcm').readAsBytes();
  /// try {
  ///   DicomMetadata metadata = await handler.getMetadata(bytes);
  ///   print('Study: ${metadata.studyDescription}');
  ///   print('Series: ${metadata.seriesDescription}');
  /// } catch (e) {
  ///   print('Failed to extract metadata: $e');
  /// }
  /// ```
  Future<DicomMetadata> getMetadata(List<int> bytes) async {
    final rustHandler = await _getRustHandler();
    final rustMetadata = await rustHandler.getMetadata(bytes: bytes);
    return _convertMetadata(rustMetadata);
  }
  

  /// Get encoded image bytes (PNG format) ready for display
  /// 
  /// This returns the image data as PNG bytes that can be directly displayed
  /// in Flutter widgets like Image.memory().
  /// 
  /// Example:
  /// ```dart
  /// final handler = DicomHandler();
  /// final bytes = await File('/path/to/file.dcm').readAsBytes();
  /// try {
  ///   Uint8List imageBytes = await handler.getImageBytes(bytes);
  ///   // Display in Flutter
  ///   Image.memory(imageBytes)
  /// } catch (e) {
  ///   print('Failed to get image bytes: $e');
  /// }
  /// ```
  Future<Uint8List> getImageBytes(List<int> bytes) async {
    final rustHandler = await _getRustHandler();
    return await rustHandler.getImageBytes(bytes: bytes);
  }
  

  /// Extract raw pixel data and image parameters
  /// 
  /// Use this when you need access to the raw pixel data and detailed
  /// image parameters for custom processing.
  /// 
  /// Example:
  /// ```dart
  /// final handler = DicomHandler();
  /// final bytes = await File('/path/to/file.dcm').readAsBytes();
  /// try {
  ///   DicomImage image = await handler.extractPixelData(bytes);
  ///   print('Bits allocated: ${image.bitsAllocated}');
  ///   print('Photometric interpretation: ${image.photometricInterpretation}');
  ///   // Access raw pixel data: image.pixelData
  /// } catch (e) {
  ///   print('Failed to extract pixel data: $e');
  /// }
  /// ```
  Future<DicomImage> extractPixelData(List<int> bytes) async {
    final rustHandler = await _getRustHandler();
    final rustImage = await rustHandler.extractPixelData(bytes: bytes);
    return _convertImage(rustImage);
  }
  

  // Helper methods to convert from Rust types to our simplified types
  DicomMetadata _convertMetadata(rust.DicomMetadata rustMeta) {
    return DicomMetadata(
      patientName: rustMeta.patientName,
      patientId: rustMeta.patientId,
      studyDate: rustMeta.studyDate,
      modality: rustMeta.modality,
      studyDescription: rustMeta.studyDescription,
      seriesDescription: rustMeta.seriesDescription,
      instanceNumber: rustMeta.instanceNumber,
      seriesNumber: rustMeta.seriesNumber,
      studyInstanceUid: rustMeta.studyInstanceUid,
      seriesInstanceUid: rustMeta.seriesInstanceUid,
      sopInstanceUid: rustMeta.sopInstanceUid,
      imagePosition: rustMeta.imagePosition?.toList(),
      pixelSpacing: rustMeta.pixelSpacing?.toList(),
      sliceLocation: rustMeta.sliceLocation,
      sliceThickness: rustMeta.sliceThickness,
    );
  }

  DicomImage _convertImage(rust.DicomImage rustImage) {
    return DicomImage(
      width: rustImage.width,
      height: rustImage.height,
      bitsAllocated: rustImage.bitsAllocated,
      bitsStored: rustImage.bitsStored,
      pixelRepresentation: rustImage.pixelRepresentation,
      photometricInterpretation: rustImage.photometricInterpretation,
      samplesPerPixel: rustImage.samplesPerPixel,
      pixelData: rustImage.pixelData,
    );
  }
}

// Helper function to get a DicomHandler instance (backward compatibility)
DicomHandler getDicomHandler() => DicomHandler();