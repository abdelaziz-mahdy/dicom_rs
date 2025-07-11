import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:dicom_rs/dicom_rs.dart';
import '../models/load_method.dart';
import '../models/complex_types.dart';
import 'enhanced_dicom_service.dart';

class DicomService {
  final EnhancedDicomService _enhancedService = EnhancedDicomService();

  /// Load DICOM data using the selected method
  Future<DicomLoadResult> loadDicomData({
    required String path,
    required DicomLoadMethod method,
    Function(int current, int total)? onProgress,
  }) async {
    switch (method) {
      case DicomLoadMethod.directory:
        final entries = await _enhancedService.loadDirectory(path: path);
        return DirectoryLoadResult(entries: entries);

      case DicomLoadMethod.directoryRecursive:
        final entries = await _enhancedService.loadDirectoryRecursive(path: path);
        return DirectoryLoadResult(entries: entries);

      case DicomLoadMethod.loadDicomFile:
        final dicomFile = await _enhancedService.loadFile(path: path);
        return DicomFileLoadResult(file: dicomFile);
        
      case DicomLoadMethod.volume:
        // For volume loading, first get all entries then create volume
        final entries = await _enhancedService.loadDirectoryRecursive(path: path);
        if (entries.isEmpty) {
          throw Exception('No DICOM files found for volume creation');
        }
        final volume = await _enhancedService.createVolumeFromSeries(entries);
        return VolumeLoadResult(volume: volume);
    }
  }

  /// Get DICOM metadata
  Future<DicomMetadata> getMetadata({required String path}) async {
    return await _enhancedService.getMetadata(path: path);
  }

  /// Get enhanced metadata map
  Future<DicomMetadataMap> getAllMetadata({required String path}) async {
    return await _enhancedService.getAllMetadata(path: path);
  }

  /// Extract patient ID from study
  Future<String?> extractPatientIdFromStudy(DicomStudy study) async {
    return await _enhancedService.extractPatientIdFromStudy(study);
  }

  /// Extract patient name from study
  Future<String?> extractPatientNameFromStudy(DicomStudy study) async {
    return await _enhancedService.extractPatientNameFromStudy(study);
  }

  /// Load volume from series
  Future<DicomVolume> loadVolumeFromSeries(List<DicomDirectoryEntry> entries) async {
    return await _enhancedService.createVolumeFromSeries(entries);
  }

  /// Check if file is valid DICOM
  Future<bool> isValidDicom(String path) async {
    return await _enhancedService.isValidDicom(path: path);
  }

  /// Get pixel data from DICOM file
  Future<DicomImage> getPixelData(String path) async {
    return await _enhancedService.getPixelData(path: path);
  }

  /// Get image bytes (PNG) from DICOM file
  Future<Uint8List> getImageBytes(String path) async {
    return await _enhancedService.getImageBytes(path: path);
  }
}

/// Base class for load results
abstract class DicomLoadResult {}

/// Result for directory loading
class DirectoryLoadResult extends DicomLoadResult {
  final List<DicomDirectoryEntry> entries;
  
  DirectoryLoadResult({required this.entries});
}

/// Result for organized directory loading
class OrganizedLoadResult extends DicomLoadResult {
  final List<DicomPatient> patients;
  
  OrganizedLoadResult({required this.patients});
}

/// Result for single file loading
class DicomFileLoadResult extends DicomLoadResult {
  final DicomFile file;
  
  DicomFileLoadResult({required this.file});
}

/// Result for study loading
class StudyLoadResult extends DicomLoadResult {
  final DicomStudy study;
  
  StudyLoadResult({required this.study});
}

/// Result for volume loading
class VolumeLoadResult extends DicomLoadResult {
  final DicomVolume volume;
  
  VolumeLoadResult({required this.volume});
}