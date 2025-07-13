import 'dart:typed_data';
import 'package:dicom_rs/dicom_rs.dart';
import '../../domain/entities/dicom_image_entity.dart';
import '../../models/complex_types.dart';

/// Mapper to convert between data layer and domain entities
class DicomMapper {
  const DicomMapper._();

  /// Convert DicomDirectoryEntry to DicomImageEntity
  static DicomImageEntity fromDirectoryEntry(DicomDirectoryEntry entry) {
    return DicomImageEntity(
      id: _generateId(entry.name, entry.metadata),
      name: entry.name,
      bytes: entry.bytes,
      metadata: fromMetadata(entry.metadata),
      isLoaded: entry.isValid,
    );
  }

  /// Convert DicomMetadata to DicomMetadataEntity
  static DicomMetadataEntity fromMetadata(DicomMetadata metadata) {
    return DicomMetadataEntity(
      patientName: metadata.patientName,
      patientId: metadata.patientId,
      studyDate: metadata.studyDate,
      modality: metadata.modality,
      studyDescription: metadata.studyDescription,
      seriesDescription: metadata.seriesDescription,
      instanceNumber: metadata.instanceNumber,
      seriesNumber: metadata.seriesNumber,
      studyInstanceUid: metadata.studyInstanceUID,
      seriesInstanceUid: metadata.seriesInstanceUID,
      sopInstanceUid: metadata.sopInstanceUid,
      imagePosition: metadata.imagePosition,
      pixelSpacing: metadata.pixelSpacing,
      sliceLocation: metadata.sliceLocation,
      sliceThickness: metadata.sliceThickness,
    );
  }

  /// Convert DicomFile to DicomImageEntity (bytes-based)
  static DicomImageEntity fromDicomFile(DicomFile file, {
    required Uint8List bytes,
    required String name,
    String? path,
  }) {
    return DicomImageEntity(
      id: _generateIdFromMetadata(file.metadata),
      name: name,
      bytes: bytes,
      metadata: fromMetadata(file.metadata),
      imageData: file.image?.pixelData,
      isLoaded: file.isValid,
    );
  }

  /// Generate unique ID for image from name and metadata
  static String _generateId(String name, DicomMetadata metadata) {
    final sopUid = metadata.sopInstanceUid;
    if (sopUid != null && sopUid.isNotEmpty) {
      return sopUid;
    }
    
    // Fallback to name-based ID
    return name.hashCode.toString();
  }
  
  /// Generate unique ID for image from metadata only
  static String _generateIdFromMetadata(DicomMetadata metadata) {
    final sopUid = metadata.sopInstanceUid;
    if (sopUid != null && sopUid.isNotEmpty) {
      return sopUid;
    }
    
    // Fallback to combination of available metadata
    final patientId = metadata.patientId ?? 'unknown';
    final instanceNumber = metadata.instanceNumber ?? 0;
    final seriesUid = metadata.seriesInstanceUid ?? 'unknown';
    return '${patientId}_${seriesUid}_$instanceNumber'.hashCode.toString();
  }
}