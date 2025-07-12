import 'package:dicom_rs/dicom_rs.dart';
import '../../domain/entities/dicom_image_entity.dart';
import '../../models/complex_types.dart';

/// Mapper to convert between data layer and domain entities
class DicomMapper {
  const DicomMapper._();

  /// Convert DicomDirectoryEntry to DicomImageEntity
  static DicomImageEntity fromDirectoryEntry(DicomDirectoryEntry entry) {
    return DicomImageEntity(
      id: _generateId(entry.path, entry.metadata),
      path: entry.path,
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

  /// Convert DicomFile to DicomImageEntity
  static DicomImageEntity fromDicomFile(DicomFile file) {
    return DicomImageEntity(
      id: _generateId(file.path, file.metadata),
      path: file.path,
      metadata: fromMetadata(file.metadata),
      imageData: file.image?.pixelData,
      isLoaded: file.isValid,
    );
  }

  /// Generate unique ID for image
  static String _generateId(String path, DicomMetadata metadata) {
    final sopUid = metadata.sopInstanceUid;
    if (sopUid != null && sopUid.isNotEmpty) {
      return sopUid;
    }
    
    // Fallback to path-based ID
    return path.hashCode.toString();
  }
}