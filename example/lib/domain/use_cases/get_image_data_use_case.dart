import 'dart:io';
import 'dart:typed_data';
import '../../core/result.dart';
import '../repositories/dicom_repository.dart';

/// Use case for getting image data from a DICOM file
class GetImageDataUseCase {
  const GetImageDataUseCase(this._repository);

  final DicomRepository _repository;

  Future<Result<Uint8List>> call(String path) async {
    // Convert path to bytes first, then get image data
    // Note: This is a legacy interface - prefer using bytes directly
    try {
      final bytes = await File(path).readAsBytes();
      return await _repository.getImageDataFromBytes(bytes);
    } catch (e) {
      return Failure('Failed to read file: $e');
    }
  }
}
