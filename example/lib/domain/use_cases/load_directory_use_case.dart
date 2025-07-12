import '../../core/result.dart';
import '../entities/dicom_image_entity.dart';
import '../repositories/dicom_repository.dart';

/// Use case for loading DICOM files from a directory
class LoadDirectoryUseCase {
  const LoadDirectoryUseCase(this._repository);

  final DicomRepository _repository;

  Future<Result<List<DicomImageEntity>>> call({
    required String path,
    bool recursive = false,
  }) async {
    return await _repository.loadDirectory(
      path: path,
      recursive: recursive,
    );
  }
}
