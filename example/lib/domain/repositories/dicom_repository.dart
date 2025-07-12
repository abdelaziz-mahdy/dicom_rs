import 'dart:typed_data';
import '../../core/result.dart';
import '../entities/dicom_image_entity.dart';

/// Repository interface for DICOM operations
abstract interface class DicomRepository {
  /// Load DICOM files from directory (metadata only for fast scanning)
  Future<Result<List<DicomImageEntity>>> loadDirectory({
    required String path,
    bool recursive = false,
  });

  /// Load single DICOM file metadata
  Future<Result<DicomMetadataEntity>> getMetadata(String path);

  /// Load image data for specific DICOM file
  Future<Result<Uint8List>> getImageData(String path);

  /// Check if file is valid DICOM
  Future<Result<bool>> isValidDicom(String path);

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