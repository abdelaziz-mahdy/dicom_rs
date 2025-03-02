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
    Function(int current, int total)? onProgress,
  }) async {
    switch (method) {
      case DicomLoadMethod.directory:
        final entries = await _handler.loadDirectory(path: path);
        return DirectoryLoadResult(entries: entries);

      case DicomLoadMethod.directoryRecursive:
        final entries = await _handler.loadDirectoryRecursive(path: path);
        return DirectoryLoadResult(entries: entries);

      case DicomLoadMethod.LoadDicomFile:
        final metadata = await _handler.loadFile(path: path);
        metadata;
        return StudyLoadResult(study: DicomStudy(series: []));

      case DicomLoadMethod.volume:
        final volume = await _handler.loadVolume(
          path: path,
          progressCallback:
              onProgress != null
                  ? (current, total) async {
                    onProgress(current, total);
                  }
                  : (current, total) {},
        );

        volume.spacing;
        for (final instance in volume.slices) {
          if (instance.path.isNotEmpty) {
            try {
              final metadata = await getAllMetadata(path: instance.path);
              metadata;
            } catch (_) {}
          }
        }
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
