import 'dart:typed_data';
import 'package:dicom_rs/dicom_rs.dart';

import '../../core/result.dart';
import '../../domain/entities/dicom_image_entity.dart';
import '../../domain/repositories/dicom_repository.dart';
import '../../services/enhanced_dicom_service.dart';
import '../mappers/dicom_mapper.dart';

/// Implementation of DicomRepository using dicom_rs package
class DicomRepositoryImpl implements DicomRepository {
  DicomRepositoryImpl({DicomHandler? handler}) 
      : _handler = handler ?? DicomHandler();

  final DicomHandler _handler;

  @override
  Future<Result<List<DicomImageEntity>>> loadDirectory({
    required String path,
    bool recursive = false,
  }) async {
    try {
      // Use the optimized enhanced service for fast directory loading
      final service = EnhancedDicomService();
      final entries = await service.loadDirectoryUnified(
        path: path,
        recursive: recursive,
      );

      final entities = entries.map((entry) => 
          DicomMapper.fromDirectoryEntry(entry)).toList();

      return Success(entities);
    } catch (e) {
      return Failure('Failed to load directory: $e');
    }
  }

  @override
  Future<Result<DicomMetadataEntity>> getMetadata(String path) async {
    try {
      final metadata = await _handler.getMetadata(path);
      final entity = DicomMapper.fromMetadata(metadata);
      return Success(entity);
    } catch (e) {
      return Failure('Failed to get metadata: $e');
    }
  }

  @override
  Future<Result<Uint8List>> getImageData(String path) async {
    try {
      final imageBytes = await _handler.getImageBytes(path);
      return Success(imageBytes);
    } catch (e) {
      return Failure('Failed to get image data: $e');
    }
  }

  @override
  Future<Result<bool>> isValidDicom(String path) async {
    try {
      final isValid = await _handler.isDicomFile(path);
      return Success(isValid);
    } catch (e) {
      return Failure('Failed to validate DICOM file: $e');
    }
  }

  @override
  Future<Result<Uint8List>> getProcessedImage({
    required String path,
    double brightness = 0.0,
    double contrast = 1.0,
  }) async {
    try {
      // For now, return raw image data
      // TODO: Implement brightness/contrast processing in Rust
      final imageBytes = await _handler.getImageBytes(path);
      return Success(imageBytes);
    } catch (e) {
      return Failure('Failed to process image: $e');
    }
  }
}