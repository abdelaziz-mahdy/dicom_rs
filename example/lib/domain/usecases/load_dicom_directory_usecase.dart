import '../../core/result.dart';
import '../entities/dicom_image_entity.dart';
import '../repositories/dicom_repository.dart';

/// Use case for loading DICOM directory with proper error handling
class LoadDicomDirectoryUseCase {
  const LoadDicomDirectoryUseCase(this._repository);

  final DicomRepository _repository;

  Future<Result<List<DicomImageEntity>>> call({
    required String path,
    bool recursive = false,
  }) async {
    try {
      if (path.trim().isEmpty) {
        return const Failure('Directory path cannot be empty');
      }

      final result = await _repository.loadDirectory(
        path: path,
        recursive: recursive,
      );

      return result.fold(
        (images) {
          if (images.isEmpty) {
            return const Failure('No valid DICOM files found in directory');
          }
          
          // Sort by instance number and slice location for proper ordering
          final sortedImages = List<DicomImageEntity>.from(images);
          sortedImages.sort(_compareImages);
          
          return Success(sortedImages);
        },
        (error) => Failure('Failed to load directory: $error'),
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

    // Finally by path
    return a.path.compareTo(b.path);
  }
}