import 'dart:io';
import 'dart:typed_data';
import 'package:dicom_rs/dicom_rs.dart';
import '../models/complex_types.dart';

/// Enhanced DICOM service that provides complex functionality
/// while using the minimal API underneath
class EnhancedDicomService {
  final DicomHandler _handler = DicomHandler();

  /// Sort DICOM entries by instance number and slice location
  List<DicomDirectoryEntry> _sortDicomEntries(List<DicomDirectoryEntry> entries) {
    final sortedEntries = List<DicomDirectoryEntry>.from(entries);
    sortedEntries.sort((a, b) {
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
    return sortedEntries;
  }

  /// Check if a file is a valid DICOM file
  Future<bool> isValidDicom({required String path}) async {
    try {
      return await _handler.isDicomFile(path);
    } catch (e) {
      return false;
    }
  }

  /// Check if a file is a DICOMDIR file
  Future<bool> isDicomdir({required String path}) async {
    try {
      final file = await _handler.loadFile(path);
      // Simple heuristic: check if filename contains DICOMDIR
      return path.toLowerCase().contains('dicomdir');
    } catch (e) {
      return false;
    }
  }

  /// Get basic metadata from a DICOM file
  Future<DicomMetadata> getMetadata({required String path}) async {
    return await _handler.getMetadata(path);
  }

  /// Get enhanced metadata map (simulated from basic metadata)
  Future<DicomMetadataMap> getAllMetadata({required String path}) async {
    final metadata = await _handler.getMetadata(path);
    
    // Create mock tags from metadata
    final tags = <String, DicomTag>{};
    final groupElements = <String, Map<String, DicomTag>>{};

    if (metadata.patientName != null) {
      tags['PatientName'] = DicomTag(
        tag: '00100010',
        vr: 'PN',
        name: 'PatientName',
        value: DicomValueType.str(metadata.patientName!),
      );
    }

    if (metadata.modality != null) {
      tags['Modality'] = DicomTag(
        tag: '00080060',
        vr: 'CS',
        name: 'Modality',
        value: DicomValueType.str(metadata.modality!),
      );
    }

    if (metadata.studyDate != null) {
      tags['StudyDate'] = DicomTag(
        tag: '00080020',
        vr: 'DA',
        name: 'StudyDate',
        value: DicomValueType.str(metadata.studyDate!),
      );
    }

    return DicomMetadataMap(tags: tags, groupElements: groupElements);
  }

  /// Load a DICOM file
  Future<DicomFile> loadFile({required String path}) async {
    return await _handler.loadFile(path);
  }

  /// Get pixel data from a DICOM file
  Future<DicomImage> getPixelData({required String path}) async {
    return await _handler.extractPixelData(path);
  }

  /// Get encoded image bytes (PNG)
  Future<Uint8List> getImageBytes({required String path}) async {
    return await _handler.getImageBytes(path);
  }

  /// Load a directory and return directory entries
  Future<List<DicomDirectoryEntry>> loadDirectory({required String path}) async {
    final directory = Directory(path);
    final entries = <DicomDirectoryEntry>[];

    if (!await directory.exists()) {
      return _sortDicomEntries(entries);
    }

    final files = directory
        .listSync()
        .whereType<File>()
        .where((file) => !file.path.toLowerCase().endsWith('.ds_store'))
        .toList();

    for (final file in files) {
      try {
        if (await _handler.isDicomFile(file.path)) {
          // FAST: Only load metadata, not the full file with image data
          final metadata = await _handler.getMetadata(file.path);
          entries.add(DicomDirectoryEntry(
            path: file.path,
            metadata: metadata,
            isValid: true,
            // Don't load image data during directory scan - will be loaded lazily
            image: null,
          ));
        }
      } catch (e) {
        // Skip invalid files
      }
    }

    return _sortDicomEntries(entries);
  }

  /// Load a directory recursively
  Future<List<DicomDirectoryEntry>> loadDirectoryRecursive({required String path}) async {
    final directory = Directory(path);
    final entries = <DicomDirectoryEntry>[];

    if (!await directory.exists()) {
      return _sortDicomEntries(entries);
    }

    final files = directory
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => !file.path.toLowerCase().endsWith('.ds_store'))
        .toList();

    for (final file in files) {
      try {
        if (await _handler.isDicomFile(file.path)) {
          // FAST: Only load metadata, not the full file with image data
          final metadata = await _handler.getMetadata(file.path);
          entries.add(DicomDirectoryEntry(
            path: file.path,
            metadata: metadata,
            isValid: true,
            // Don't load image data during directory scan - will be loaded lazily
            image: null,
          ));
        }
      } catch (e) {
        // Skip invalid files
      }
    }

    return _sortDicomEntries(entries);
  }

  /// Load directory organized by patients
  Future<List<DicomPatient>> loadDirectoryOrganized({required String path}) async {
    final entries = await loadDirectoryRecursive(path: path);
    return _organizeEntriesByPatient(entries);
  }

  /// Load directory with unified structure
  Future<List<DicomDirectoryEntry>> loadDirectoryUnified({
    required String path,
    bool recursive = false,
  }) async {
    if (recursive) {
      return await loadDirectoryRecursive(path: path);
    } else {
      return await loadDirectory(path: path);
    }
  }

  /// Extract patient ID from study
  Future<String?> extractPatientIdFromStudy(DicomStudy study) async {
    if (study.series.isNotEmpty && study.series.first.instances.isNotEmpty) {
      return study.series.first.instances.first.metadata.patientId;
    }
    return null;
  }

  /// Extract patient name from study
  Future<String?> extractPatientNameFromStudy(DicomStudy study) async {
    if (study.series.isNotEmpty && study.series.first.instances.isNotEmpty) {
      return study.series.first.instances.first.metadata.patientName;
    }
    return null;
  }

  /// Create a volume from a series of DICOM files
  Future<DicomVolume> createVolumeFromSeries(List<DicomDirectoryEntry> entries) async {
    if (entries.isEmpty) {
      throw Exception('No entries provided for volume creation');
    }

    // Sort entries by instance number or slice location
    final sortedEntries = _sortDicomEntries(entries);

    // Get dimensions from first slice
    final firstEntry = sortedEntries.first;
    int width = 512, height = 512; // defaults
    
    if (firstEntry.image != null) {
      width = firstEntry.image!.width.toInt();
      height = firstEntry.image!.height.toInt();
    }

    return DicomVolume(
      slices: sortedEntries,
      patientId: firstEntry.metadata.patientId,
      patientName: firstEntry.metadata.patientName,
      studyDescription: firstEntry.metadata.studyDescription,
      seriesDescription: firstEntry.metadata.seriesDescription,
      modality: firstEntry.metadata.modality,
      width: width,
      height: height,
      depth: sortedEntries.length,
      pixelSpacing: firstEntry.metadata.pixelSpacing,
      sliceThickness: firstEntry.metadata.sliceThickness,
    );
  }

  /// Organize directory entries by patient
  List<DicomPatient> _organizeEntriesByPatient(List<DicomDirectoryEntry> entries) {
    final patientMap = <String, List<DicomDirectoryEntry>>{};

    // Group by patient
    for (final entry in entries) {
      final patientKey = entry.metadata.patientId ?? 
                        entry.metadata.patientName ?? 
                        'Unknown Patient';
      patientMap.putIfAbsent(patientKey, () => []).add(entry);
    }

    return patientMap.entries.map((patientEntry) {
      final patientEntries = patientEntry.value;
      final firstEntry = patientEntries.first;

      // Group by study
      final studyMap = <String, List<DicomDirectoryEntry>>{};
      for (final entry in patientEntries) {
        final studyKey = entry.metadata.studyInstanceUID ?? 
                        entry.metadata.studyDescription ?? 
                        'Unknown Study';
        studyMap.putIfAbsent(studyKey, () => []).add(entry);
      }

      final studies = studyMap.entries.map((studyEntry) {
        final studyEntries = studyEntry.value;
        final firstStudyEntry = studyEntries.first;

        // Group by series
        final seriesMap = <String, List<DicomDirectoryEntry>>{};
        for (final entry in studyEntries) {
          final seriesKey = entry.metadata.seriesInstanceUID ?? 
                           entry.metadata.seriesDescription ?? 
                           'Unknown Series';
          seriesMap.putIfAbsent(seriesKey, () => []).add(entry);
        }

        final series = seriesMap.entries.map((seriesEntry) {
          final seriesEntries = seriesEntry.value;
          final firstSeriesEntry = seriesEntries.first;

          return DicomSeries(
            seriesInstanceUID: firstSeriesEntry.metadata.seriesInstanceUID,
            seriesDescription: firstSeriesEntry.metadata.seriesDescription,
            seriesNumber: firstSeriesEntry.metadata.seriesNumber,
            modality: firstSeriesEntry.metadata.modality,
            instances: seriesEntries,
          );
        }).toList();

        return DicomStudy(
          studyInstanceUID: firstStudyEntry.metadata.studyInstanceUID,
          studyDescription: firstStudyEntry.metadata.studyDescription,
          studyDate: firstStudyEntry.metadata.studyDate,
          series: series,
        );
      }).toList();

      return DicomPatient(
        patientId: firstEntry.metadata.patientId,
        patientName: firstEntry.metadata.patientName,
        studies: studies,
      );
    }).toList();
  }
}

/// Compute slice spacing for a series
Future<double?> computeSliceSpacing({required List<DicomDirectoryEntry> entries}) async {
  if (entries.length < 2) return null;

  final positions = entries
      .map((e) => e.metadata.sliceLocation)
      .where((loc) => loc != null)
      .cast<double>()
      .toList();

  if (positions.length < 2) return null;

  positions.sort();
  
  // Calculate average spacing between consecutive slices
  double totalSpacing = 0;
  int count = 0;
  
  for (int i = 1; i < positions.length; i++) {
    totalSpacing += (positions[i] - positions[i - 1]).abs();
    count++;
  }

  return count > 0 ? totalSpacing / count : null;
}

/// Legacy function compatibility
Future<bool> isDicomFile({required String path}) async {
  final handler = DicomHandler();
  return await handler.isDicomFile(path);
}

Future<bool> isDicomdirFile({required String path}) async {
  try {
    return path.toLowerCase().contains('dicomdir');
  } catch (e) {
    return false;
  }
}

Future<DicomImage> extractPixelData({required String path}) async {
  final handler = DicomHandler();
  return await handler.extractPixelData(path);
}

Future<DicomFile> loadDicomFile({required String path}) async {
  final handler = DicomHandler();
  return await handler.loadFile(path);
}

Future<DicomMetadataMap> extractAllMetadata({required String path}) async {
  final service = EnhancedDicomService();
  return await service.getAllMetadata(path: path);
}

Future<List<DicomDirectoryEntry>> loadDicomDirectory({required String dirPath}) async {
  final service = EnhancedDicomService();
  return await service.loadDirectory(path: dirPath);
}

Future<List<DicomDirectoryEntry>> loadDicomDirectoryRecursive({required String dirPath}) async {
  final service = EnhancedDicomService();
  return await service.loadDirectoryRecursive(path: dirPath);
}

Future<List<DicomPatient>> loadDicomDirectoryOrganized({
  required String dirPath,
  bool recursive = false,
}) async {
  final service = EnhancedDicomService();
  return await service.loadDirectoryOrganized(path: dirPath);
}