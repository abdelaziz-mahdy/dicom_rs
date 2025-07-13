import 'dart:typed_data';
import 'package:dicom_rs/dicom_rs.dart';
import '../models/complex_types.dart';
import 'file_selector_service.dart';

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
      return a.name.compareTo(b.name);
    });
    return sortedEntries;
  }

  /// Check if bytes represent a valid DICOM file
  Future<bool> isValidDicom({required Uint8List bytes}) async {
    try {
      return await _handler.isDicomFile(bytes);
    } catch (e) {
      return false;
    }
  }

  /// Check if bytes represent a DICOMDIR file
  Future<bool> isDicomdir({required Uint8List bytes, String? filename}) async {
    try {
      // Simple heuristic: check if filename contains DICOMDIR
      return filename?.toLowerCase().contains('dicomdir') ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Get basic metadata from DICOM bytes
  Future<DicomMetadata> getMetadata({required Uint8List bytes}) async {
    return await _handler.getMetadata(bytes);
  }

  /// Get enhanced metadata map (simulated from basic metadata)
  Future<DicomMetadataMap> getAllMetadata({required Uint8List bytes}) async {
    final metadata = await _handler.getMetadata(bytes);
    
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

  /// Get ONLY metadata from DICOM bytes (fast processing)
  Future<DicomMetadata> getMetadataOnly({required Uint8List bytes}) async {
    return await _handler.getMetadata(bytes);
  }

  /// Get ONLY image data from DICOM bytes (separate from metadata)
  Future<Uint8List> getImageDataOnly({required Uint8List dicomBytes}) async {
    return await _handler.getImageBytes(dicomBytes);
  }

  /// Load a DICOM file from bytes
  Future<DicomFile> loadFile({required Uint8List bytes}) async {
    return await _handler.loadFile(bytes);
  }

  /// Get pixel data from DICOM bytes
  Future<DicomImage> getPixelData({required Uint8List bytes}) async {
    return await _handler.extractPixelData(bytes);
  }

  /// Get encoded image bytes from DICOM bytes
  Future<Uint8List> getImageBytes({required Uint8List dicomBytes}) async {
    return await _handler.getImageBytes(dicomBytes);
  }

  /// Load files from DicomFileData list (FAST - metadata only)
  Future<List<DicomDirectoryEntry>> loadFromFileDataList(List<DicomFileData> fileDataList) async {
    final entries = <DicomDirectoryEntry>[];

    for (final fileData in fileDataList) {
      try {
        if (await _handler.isDicomFile(fileData.bytes)) {
          // OPTIMIZED: Use metadata-only function for fast scanning
          final metadata = await getMetadataOnly(bytes: fileData.bytes);
          entries.add(DicomDirectoryEntry(
            bytes: fileData.bytes,
            name: fileData.name,
            metadata: metadata,
            isValid: true,
            // Image data will be loaded separately when needed
            image: null,
          ));
        }
      } catch (e) {
        // Skip invalid files
      }
    }

    return _sortDicomEntries(entries);
  }

  /// Load files from DicomFileData list recursively (FAST - metadata only)
  /// This method is now a wrapper around loadFromFileDataList for API compatibility
  Future<List<DicomDirectoryEntry>> loadFromFileDataListRecursive(List<DicomFileData> fileDataList) async {
    // Since we already have all files in the list, recursive behavior is handled by FileSelectorService
    return await loadFromFileDataList(fileDataList);
  }

  /// Load directory organized by patients from file data
  Future<List<DicomPatient>> loadOrganizedFromFileData(List<DicomFileData> fileDataList) async {
    final entries = await loadFromFileDataList(fileDataList);
    return _organizeEntriesByPatient(entries);
  }

  /// Load with unified structure from file data
  Future<List<DicomDirectoryEntry>> loadUnifiedFromFileData({
    required List<DicomFileData> fileDataList,
    bool recursive = false, // Ignored - file data list already contains all files
  }) async {
    return await loadFromFileDataList(fileDataList);
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

/// Bytes-only API functions
Future<bool> isDicomFile({required Uint8List bytes}) async {
  final handler = DicomHandler();
  return await handler.isDicomFile(bytes);
}

Future<bool> isDicomdirFile({required Uint8List bytes, String? filename}) async {
  try {
    return filename?.toLowerCase().contains('dicomdir') ?? false;
  } catch (e) {
    return false;
  }
}

Future<DicomImage> extractPixelData({required Uint8List bytes}) async {
  final handler = DicomHandler();
  return await handler.extractPixelData(bytes);
}

Future<DicomFile> loadDicomFile({required Uint8List bytes}) async {
  final handler = DicomHandler();
  return await handler.loadFile(bytes);
}

Future<DicomMetadataMap> extractAllMetadata({required Uint8List bytes}) async {
  final service = EnhancedDicomService();
  return await service.getAllMetadata(bytes: bytes);
}

// Directory operations moved to file selector service
// Use DicomFileData with bytes for cleaner API