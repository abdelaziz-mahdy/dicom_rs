import 'dart:typed_data';

/// Clean domain entity for DICOM image data (bytes-based)
class DicomImageEntity {
  const DicomImageEntity({
    required this.id,
    required this.name,
    required this.bytes,
    required this.metadata,
    this.imageData,
    this.isLoaded = false,
    this.loadError,
  });

  final String id;
  final String name; // Required - filename for display
  final Uint8List bytes; // Required - actual DICOM data
  final DicomMetadataEntity metadata;
  final Uint8List? imageData;
  final bool isLoaded;
  final String? loadError;

  DicomImageEntity copyWith({
    String? id,
    String? name,
    Uint8List? bytes,
    DicomMetadataEntity? metadata,
    Uint8List? imageData,
    bool? isLoaded,
    String? loadError,
  }) {
    return DicomImageEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      bytes: bytes ?? this.bytes,
      metadata: metadata ?? this.metadata,
      imageData: imageData ?? this.imageData,
      isLoaded: isLoaded ?? this.isLoaded,
      loadError: loadError ?? this.loadError,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DicomImageEntity && 
      other.id == id && 
      other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

/// Clean domain entity for DICOM metadata
class DicomMetadataEntity {
  const DicomMetadataEntity({
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

  DicomMetadataEntity copyWith({
    String? patientName,
    String? patientId,
    String? studyDate,
    String? modality,
    String? studyDescription,
    String? seriesDescription,
    int? instanceNumber,
    int? seriesNumber,
    String? studyInstanceUid,
    String? seriesInstanceUid,
    String? sopInstanceUid,
    List<double>? imagePosition,
    List<double>? pixelSpacing,
    double? sliceLocation,
    double? sliceThickness,
  }) {
    return DicomMetadataEntity(
      patientName: patientName ?? this.patientName,
      patientId: patientId ?? this.patientId,
      studyDate: studyDate ?? this.studyDate,
      modality: modality ?? this.modality,
      studyDescription: studyDescription ?? this.studyDescription,
      seriesDescription: seriesDescription ?? this.seriesDescription,
      instanceNumber: instanceNumber ?? this.instanceNumber,
      seriesNumber: seriesNumber ?? this.seriesNumber,
      studyInstanceUid: studyInstanceUid ?? this.studyInstanceUid,
      seriesInstanceUid: seriesInstanceUid ?? this.seriesInstanceUid,
      sopInstanceUid: sopInstanceUid ?? this.sopInstanceUid,
      imagePosition: imagePosition ?? this.imagePosition,
      pixelSpacing: pixelSpacing ?? this.pixelSpacing,
      sliceLocation: sliceLocation ?? this.sliceLocation,
      sliceThickness: sliceThickness ?? this.sliceThickness,
    );
  }
}