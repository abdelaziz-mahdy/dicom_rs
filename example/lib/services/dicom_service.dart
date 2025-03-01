import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:dicom_rs/dicom_rs.dart';
import '../models/load_method.dart';

class DicomService {
  final DicomHandler _handler = DicomHandler();

  /// Load DICOM data using the selected method
  Future<DicomLoadResult> loadDicomData({
    required String path,
    required DicomLoadMethod method,
  }) async {
    switch (method) {
      case DicomLoadMethod.directory:
        final entries = await _handler.loadDirectory(path: path);
        return DirectoryLoadResult(entries: entries);

      case DicomLoadMethod.directoryRecursive:
        final entries = await _handler.loadDirectoryRecursive(path: path);
        return DirectoryLoadResult(entries: entries);

      case DicomLoadMethod.completeStudy:
        final study = await _handler.loadCompleteStudy(path: path);
        return StudyLoadResult(study: study);

      case DicomLoadMethod.completeStudyRecursive:
        final study = await _handler.loadCompleteStudyRecursive(path: path);
        return StudyLoadResult(study: study);

      case DicomLoadMethod.volume:
        final volume = await _handler.loadVolume(path: path);
        return VolumeLoadResult(volume: volume);
    }
  }

  /// Get image bytes for display
  Future<Uint8List> getImageBytes({required String path}) {
    return _handler.getImageBytes(path: path);
  }

  /// Get metadata for a specific DICOM file
  Future<DicomMetadata> getMetadata({required String path}) {
    return _handler.getMetadata(path: path);
  }

  /// Get all metadata for a specific DICOM file
  Future<DicomMetadataMap> getAllMetadata({required String path}) {
    return _handler.getAllMetadata(path: path);
  }

  /// Extract patient ID from a study by checking for valid instances
  Future<String?> extractPatientIdFromStudy(DicomStudy study) async {
    for (final series in study.series) {
      for (final instance in series.instances) {
        if (instance.isValid) {
          try {
            final metadata = await getMetadata(path: instance.path);
            return metadata.patientId;
          } catch (_) {}
        }
      }
    }
    return null;
  }

  /// Extract patient name from a study by checking for valid instances
  Future<String?> extractPatientNameFromStudy(DicomStudy study) async {
    for (final series in study.series) {
      for (final instance in series.instances) {
        if (instance.isValid) {
          try {
            final metadata = await getMetadata(path: instance.path);
            return metadata.patientName;
          } catch (_) {}
        }
      }
    }
    return null;
  }
}

/// Base class for all DICOM load results
abstract class DicomLoadResult {}

/// Result for directory loading methods
class DirectoryLoadResult extends DicomLoadResult {
  final List<DicomDirectoryEntry> entries;
  DirectoryLoadResult({required this.entries});
}

/// Result for study loading methods
class StudyLoadResult extends DicomLoadResult {
  final DicomStudy study;
  StudyLoadResult({required this.study});
}

/// Result for volume loading methods
class VolumeLoadResult extends DicomLoadResult {
  final DicomVolume volume;
  VolumeLoadResult({required this.volume});
}
