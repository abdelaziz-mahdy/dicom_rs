import 'package:dicom_rs/dicom_rs.dart';
import 'dart:typed_data';

/// Simple DICOM service using the minimal package API
class DicomServiceSimple {
  static final DicomHandler _handler = DicomHandler();

  /// Check if a file is a valid DICOM file
  static Future<bool> isValidDicom(String path) async {
    return await _handler.isDicomFile(path);
  }

  /// Load DICOM metadata only (faster than full load)
  static Future<DicomMetadata> loadMetadata(String path) async {
    return await _handler.getMetadata(path);
  }

  /// Load complete DICOM file with metadata and image
  static Future<DicomFile> loadFile(String path) async {
    return await _handler.loadFile(path);
  }

  /// Get image bytes ready for display (PNG format)
  static Future<Uint8List> getImageBytes(String path) async {
    return await _handler.getImageBytes(path);
  }

  /// Get raw pixel data for custom processing
  static Future<DicomImage> getPixelData(String path) async {
    return await _handler.extractPixelData(path);
  }

  /// Load multiple DICOM files from a list of paths
  static Future<List<DicomFile>> loadMultipleFiles(List<String> paths) async {
    final List<DicomFile> files = [];
    
    for (final path in paths) {
      try {
        if (await isValidDicom(path)) {
          final file = await loadFile(path);
          files.add(file);
        }
      } catch (e) {
        print('Failed to load DICOM file $path: $e');
      }
    }
    
    return files;
  }

  /// Get image bytes for multiple files
  static Future<List<Uint8List>> getMultipleImageBytes(List<String> paths) async {
    final List<Uint8List> images = [];
    
    for (final path in paths) {
      try {
        if (await isValidDicom(path)) {
          final imageBytes = await getImageBytes(path);
          images.add(imageBytes);
        }
      } catch (e) {
        print('Failed to get image bytes for $path: $e');
      }
    }
    
    return images;
  }

  /// Organize files by patient name for simple grouping
  static Map<String, List<DicomFile>> organizeByPatient(List<DicomFile> files) {
    final Map<String, List<DicomFile>> organized = {};
    
    for (final file in files) {
      final patientName = file.metadata.patientName ?? 'Unknown Patient';
      organized.putIfAbsent(patientName, () => []).add(file);
    }
    
    return organized;
  }

  /// Organize files by modality
  static Map<String, List<DicomFile>> organizeByModality(List<DicomFile> files) {
    final Map<String, List<DicomFile>> organized = {};
    
    for (final file in files) {
      final modality = file.metadata.modality ?? 'Unknown';
      organized.putIfAbsent(modality, () => []).add(file);
    }
    
    return organized;
  }

  /// Sort files by instance number
  static List<DicomFile> sortByInstanceNumber(List<DicomFile> files) {
    final sortedFiles = List<DicomFile>.from(files);
    sortedFiles.sort((a, b) {
      // First sort by instance number if available
      final aInstance = a.metadata.instanceNumber ?? 0;
      final bInstance = b.metadata.instanceNumber ?? 0;
      if (aInstance != bInstance) {
        return aInstance.compareTo(bInstance);
      }
      
      // Then by slice location if available
      final aLocation = a.metadata.sliceLocation ?? 0.0;
      final bLocation = b.metadata.sliceLocation ?? 0.0;
      if (aLocation != bLocation) {
        return aLocation.compareTo(bLocation);
      }

      // Finally by filename as fallback
      return a.path.compareTo(b.path);
    });
    return sortedFiles;
  }

  /// Get basic statistics from a list of DICOM files
  static Map<String, dynamic> getBasicStats(List<DicomFile> files) {
    if (files.isEmpty) return {};

    final modalities = <String>{};
    final patients = <String>{};
    int totalImages = 0;
    int imagesWithPixelData = 0;

    for (final file in files) {
      if (file.metadata.modality != null) {
        modalities.add(file.metadata.modality!);
      }
      if (file.metadata.patientName != null) {
        patients.add(file.metadata.patientName!);
      }
      totalImages++;
      if (file.image != null) {
        imagesWithPixelData++;
      }
    }

    return {
      'totalFiles': totalImages,
      'imagesWithPixelData': imagesWithPixelData,
      'uniquePatients': patients.length,
      'uniqueModalities': modalities.length,
      'modalities': modalities.toList(),
      'patients': patients.toList(),
    };
  }
}