import 'dart:typed_data';
import '../../core/result.dart';
import '../entities/dicom_image_entity.dart';
import '../../services/file_selector_service.dart';

/// Repository interface for DICOM operations (bytes-based only)
abstract interface class DicomRepository {
  /// Load DICOM files from DicomFileData list (metadata only for fast scanning)
  Future<Result<List<DicomImageEntity>>> loadFromFileDataList({
    required List<DicomFileData> fileDataList,
    bool recursive = false,
  });

  /// Load single DICOM file metadata from bytes
  Future<Result<DicomMetadataEntity>> getMetadataFromBytes(Uint8List bytes);

  /// Load image data from DICOM bytes
  Future<Result<Uint8List>> getImageDataFromBytes(Uint8List dicomBytes);

  /// Check if bytes represent valid DICOM
  Future<Result<bool>> isValidDicomFromBytes(Uint8List bytes);

  /// Get processed image with brightness/contrast adjustments
  Future<Result<Uint8List>> getProcessedImage({
    required Uint8List imageBytes,
    double brightness = 0.0,
    double contrast = 1.0,
  });
}

/// Progress callback for operations
typedef ProgressCallback = void Function(int current, int total);

/// Repository for volume operations
abstract interface class VolumeRepository {
  /// Create 3D volume from series
  Future<Result<DicomVolumeEntity>> createVolume({
    required List<DicomImageEntity> images,
    ProgressCallback? onProgress,
  });
}

/// Volume entity
class DicomVolumeEntity {
  const DicomVolumeEntity({
    required this.id,
    required this.images,
    required this.width,
    required this.height,
    required this.depth,
    this.pixelSpacing,
    this.sliceThickness,
  });

  final String id;
  final List<DicomImageEntity> images;
  final int width;
  final int height;
  final int depth;
  final List<double>? pixelSpacing;
  final double? sliceThickness;
}