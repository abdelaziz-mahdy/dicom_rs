import 'dart:typed_data';
import 'package:dicom_rs/dicom_rs.dart';
import '../services/file_selector_service.dart';

/// Complex types that build on top of the minimal API
/// These provide the rich functionality needed for the complex example app

/// Enhanced directory entry that includes validation and metadata
class DicomDirectoryEntry {
  final Uint8List bytes; // Required - the actual DICOM data
  final String name; // Required - filename for display
  final DicomMetadata metadata;
  final bool isValid;
  final DicomImage? image;

  const DicomDirectoryEntry({
    required this.bytes,
    required this.name,
    required this.metadata,
    required this.isValid,
    this.image,
  });

  factory DicomDirectoryEntry.fromDicomFile(DicomFile file, {
    required Uint8List bytes,
    required String name,
  }) {
    return DicomDirectoryEntry(
      bytes: bytes,
      name: name,
      metadata: file.metadata,
      isValid: file.isValid,
      image: file.image,
    );
  }

  /// Create from DicomFileData (preferred constructor)
  factory DicomDirectoryEntry.fromDicomFileData(DicomFileData fileData, DicomFile dicomFile) {
    return DicomDirectoryEntry(
      bytes: fileData.bytes,
      name: fileData.name,
      metadata: dicomFile.metadata,
      isValid: dicomFile.isValid,
      image: dicomFile.image,
    );
  }

  // Convenience getters for compatibility
  int? get instanceNumber => metadata.instanceNumber;
  String? get sopInstanceUid => metadata.sopInstanceUid;
  List<double>? get imagePosition => metadata.imagePosition;
  double? get sliceLocation => metadata.sliceLocation;
  
  // For volume viewer compatibility - simulated pixel data
  Uint8List? get data => image?.pixelData;
  
  // For sorting and display compatibility
  String get displayName => name;
  String get sortKey => name; // Use name instead of path for sorting
}

/// Enhanced metadata map with grouped elements and tag access
class DicomMetadataMap {
  final Map<String, DicomTag> tags;
  final Map<String, Map<String, DicomTag>> groupElements;

  const DicomMetadataMap({
    required this.tags,
    required this.groupElements,
  });
}

/// DICOM tag representation
class DicomTag {
  final String tag;
  final String vr;
  final String name;
  final DicomValueType value;

  const DicomTag({
    required this.tag,
    required this.vr,
    required this.name,
    required this.value,
  });
}

/// DICOM value types
abstract class DicomValueType {
  const DicomValueType();
  
  factory DicomValueType.str(String value) = DicomValueTypeStr;
  factory DicomValueType.int(int value) = DicomValueTypeInt;
  factory DicomValueType.float(double value) = DicomValueTypeFloat;
  factory DicomValueType.strList(List<String> value) = DicomValueTypeStrList;
  factory DicomValueType.intList(List<int> value) = DicomValueTypeIntList;
  factory DicomValueType.floatList(List<double> value) = DicomValueTypeFloatList;
  factory DicomValueType.unknown() = DicomValueTypeUnknown;

  @override
  String toString() {
    if (this is DicomValueTypeStr) {
      return (this as DicomValueTypeStr).field0;
    } else if (this is DicomValueTypeInt) {
      return (this as DicomValueTypeInt).field0.toString();
    } else if (this is DicomValueTypeFloat) {
      return (this as DicomValueTypeFloat).field0.toString();
    } else if (this is DicomValueTypeStrList) {
      return (this as DicomValueTypeStrList).field0.join(', ');
    } else if (this is DicomValueTypeIntList) {
      return (this as DicomValueTypeIntList).field0.map((e) => e.toString()).join(', ');
    } else if (this is DicomValueTypeFloatList) {
      return (this as DicomValueTypeFloatList).field0.map((e) => e.toString()).join(', ');
    } else {
      return 'Unknown';
    }
  }
}

/// Specific value type classes for pattern matching
class DicomValueTypeStr extends DicomValueType {
  final String field0;
  const DicomValueTypeStr(this.field0);
}

class DicomValueTypeInt extends DicomValueType {
  final int field0;
  const DicomValueTypeInt(this.field0);
}

class DicomValueTypeFloat extends DicomValueType {
  final double field0;
  const DicomValueTypeFloat(this.field0);
}

class DicomValueTypeStrList extends DicomValueType {
  final List<String> field0;
  const DicomValueTypeStrList(this.field0);
}

class DicomValueTypeIntList extends DicomValueType {
  final List<int> field0;
  const DicomValueTypeIntList(this.field0);
}

class DicomValueTypeFloatList extends DicomValueType {
  final List<double> field0;
  const DicomValueTypeFloatList(this.field0);
}

class DicomValueTypeUnknown extends DicomValueType {
  const DicomValueTypeUnknown();
}

// Legacy type aliases for compatibility
typedef DicomValueType_Str = DicomValueTypeStr;
typedef DicomValueType_Int = DicomValueTypeInt;
typedef DicomValueType_Float = DicomValueTypeFloat;
typedef DicomValueType_StrList = DicomValueTypeStrList;
typedef DicomValueType_IntList = DicomValueTypeIntList;
typedef DicomValueType_FloatList = DicomValueTypeFloatList;
typedef DicomValueType_Unknown = DicomValueTypeUnknown;

/// DICOM series representation
class DicomSeries {
  final String? seriesInstanceUID;
  final String? seriesDescription;
  final int? seriesNumber;
  final String? modality;
  final List<DicomDirectoryEntry> instances;

  const DicomSeries({
    this.seriesInstanceUID,
    this.seriesDescription,
    this.seriesNumber,
    this.modality,
    required this.instances,
  });

  // Compatibility getters
  String? get seriesInstanceUid => seriesInstanceUID;
}

/// DICOM study representation
class DicomStudy {
  final String? studyInstanceUID;
  final String? studyDescription;
  final String? studyDate;
  final String? studyTime;
  final String? accessionNumber;
  final List<DicomSeries> series;

  const DicomStudy({
    this.studyInstanceUID,
    this.studyDescription,
    this.studyDate,
    this.studyTime,
    this.accessionNumber,
    required this.series,
  });

  // Compatibility getters
  String? get studyInstanceUid => studyInstanceUID;
}

/// DICOM patient representation
class DicomPatient {
  final String? patientId;
  final String? patientName;
  final String? patientBirthDate;
  final String? patientSex;
  final List<DicomStudy> studies;

  const DicomPatient({
    this.patientId,
    this.patientName,
    this.patientBirthDate,
    this.patientSex,
    required this.studies,
  });
}

/// DICOM volume representation for 3D reconstruction
class DicomVolume {
  final List<DicomDirectoryEntry> slices;
  final String? patientId;
  final String? patientName;
  final String? studyDescription;
  final String? seriesDescription;
  final String? modality;
  final int width;
  final int height;
  final int depth;
  final List<double>? pixelSpacing;
  final double? sliceThickness;
  final double? sliceSpacing;
  final List<double>? imagePosition;
  final List<double>? imageOrientation;

  const DicomVolume({
    required this.slices,
    this.patientId,
    this.patientName,
    this.studyDescription,
    this.seriesDescription,
    this.modality,
    required this.width,
    required this.height,
    required this.depth,
    this.pixelSpacing,
    this.sliceThickness,
    this.sliceSpacing,
    this.imagePosition,
    this.imageOrientation,
  });

  // Convenience getters for compatibility  
  String get dataType => 'Volume';
  int get numComponents => 1;
  List<double>? get spacing => pixelSpacing;
  DicomMetadata? get metadata => slices.isNotEmpty ? slices.first.metadata : null;
}