import 'package:dicom_rs/dicom_rs.dart';
import 'dart:typed_data';

/// Simple DICOM service using the minimal package API
class DicomServiceSimple {
  static final DicomHandler _handler = DicomHandler();

  /// Check if bytes represent a valid DICOM file
  static Future<bool> isValidDicom(Uint8List bytes) async {
    return await _handler.isDicomFile(bytes);
  }

  /// Load DICOM metadata only (faster than full load)
  static Future<DicomMetadata> loadMetadata(Uint8List bytes) async {
    return await _handler.getMetadata(bytes);
  }

  /// Load complete DICOM file with metadata and image
  static Future<DicomFile> loadFile(Uint8List bytes) async {
    return await _handler.loadFile(bytes);
  }

  /// Get image bytes ready for display (PNG format)
  static Future<Uint8List> getImageBytes(Uint8List dicomBytes) async {
    return await _handler.getImageBytes(dicomBytes);
  }

  /// Get raw pixel data for custom processing
  static Future<DicomImage> getPixelData(Uint8List bytes) async {
    return await _handler.extractPixelData(bytes);
  }

  /// Load multiple DICOM files from bytes
  static Future<List<DicomFile>> loadMultipleFiles(List<Uint8List> dicomBytesLit) async {
    final List<DicomFile> files = [];
    
    for (final bytes in dicomBytesLit) {
      try {
        if (await isValidDicom(bytes)) {
          final file = await loadFile(bytes);
          files.add(file);
        }
      } catch (e) {
        // Skip invalid files
      }
    }
    
    return files;
  }

  /// Get image bytes for multiple DICOM files
  static Future<List<Uint8List>> getMultipleImageBytes(List<Uint8List> dicomBytesLit) async {
    final List<Uint8List> images = [];
    
    for (final dicomBytes in dicomBytesLit) {
      try {
        if (await isValidDicom(dicomBytes)) {
          final imageBytes = await getImageBytes(dicomBytes);
          images.add(imageBytes);
        }
      } catch (e) {
        // Skip invalid files
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

      // Finally by SOP Instance UID as fallback
      final aUid = a.metadata.sopInstanceUid ?? '';
      final bUid = b.metadata.sopInstanceUid ?? '';
      return aUid.compareTo(bUid);
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