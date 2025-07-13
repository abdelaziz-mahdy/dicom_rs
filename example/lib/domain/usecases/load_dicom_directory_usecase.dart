import '../../core/result.dart';
import '../entities/dicom_image_entity.dart';
import '../repositories/dicom_repository.dart';
import '../../services/file_selector_service.dart';

/// Use case for loading DICOM files with proper error handling (bytes-based)
class LoadDicomDirectoryUseCase {
  const LoadDicomDirectoryUseCase(this._repository);

  final DicomRepository _repository;

  /// Load DICOM files from DicomFileData list (preferred method)
  Future<Result<List<DicomImageEntity>>> loadFromFileDataList({
    required List<DicomFileData> fileDataList,
    bool recursive = false,
  }) async {
    try {
      if (fileDataList.isEmpty) {
        return const Failure('No files provided');
      }

      final result = await _repository.loadFromFileDataList(
        fileDataList: fileDataList,
        recursive: recursive,
      );

      return result.fold(
        (images) {
          if (images.isEmpty) {
            return const Failure('No valid DICOM files found');
          }
          
          // Sort by instance number and slice location for proper ordering
          final sortedImages = List<DicomImageEntity>.from(images);
          sortedImages.sort(_compareImages);
          
          return Success(sortedImages);
        },
        (error) => Failure('Failed to load files: $error'),
      );
    } catch (e, stackTrace) {
      return Failure('Unexpected error: $e', stackTrace);
    }
  }

  /// Compare images for sorting
  int _compareImages(DicomImageEntity a, DicomImageEntity b) {
    // First by instance number
    final aInstance = a.metadata.instanceNumber ?? 0;
    final bInstance = b.metadata.instanceNumber ?? 0;
    if (aInstance != bInstance) {
      return aInstance.compareTo(bInstance);
    }

    // Then by slice location
    final aLocation = a.metadata.sliceLocation ?? 0.0;
    final bLocation = b.metadata.sliceLocation ?? 0.0;
    if (aLocation != bLocation) {
      return aLocation.compareTo(bLocation);
    }

    // Finally by name (remove null-aware operators since name is required)
    return a.name.compareTo(b.name);
  }
}