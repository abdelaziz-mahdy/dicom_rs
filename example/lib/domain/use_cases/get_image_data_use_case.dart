import 'dart:typed_data';
import '../../core/result.dart';
import '../repositories/dicom_repository.dart';

/// Use case for getting image data from a DICOM file
class GetImageDataUseCase {
  const GetImageDataUseCase(this._repository);

  final DicomRepository _repository;

  Future<Result<Uint8List>> call(String path) async {
    return await _repository.getImageData(path);
  }
}
