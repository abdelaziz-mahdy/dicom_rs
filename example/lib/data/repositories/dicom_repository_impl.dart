import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:dicom_rs/dicom_rs.dart';

import '../../core/result.dart';
import '../../domain/entities/dicom_image_entity.dart';
import '../../domain/repositories/dicom_repository.dart';
import '../../services/enhanced_dicom_service.dart';
import '../../services/file_selector_service.dart';
import '../mappers/dicom_mapper.dart';

/// Implementation of DicomRepository using dicom_rs package
class DicomRepositoryImpl implements DicomRepository {
  DicomRepositoryImpl({DicomHandler? handler}) 
      : _handler = handler ?? DicomHandler();

  final DicomHandler _handler;

  /// Load DICOM files from DicomFileData list (bytes-based)
  @override
  Future<Result<List<DicomImageEntity>>> loadFromFileDataList({
    required List<DicomFileData> fileDataList,
    bool recursive = false, // Ignored - file data already contains all files
  }) async {
    try {
      // Use the optimized enhanced service for fast loading
      final service = EnhancedDicomService();
      final entries = await service.loadUnifiedFromFileData(
        fileDataList: fileDataList,
        recursive: recursive,
      );

      final entities = entries.map((entry) => 
          DicomMapper.fromDirectoryEntry(entry)).toList();

      return Success(entities);
    } catch (e) {
      return Failure('Failed to load files: $e');
    }
  }

  /// Get metadata from bytes directly (preferred method)
  @override
  Future<Result<DicomMetadataEntity>> getMetadataFromBytes(Uint8List bytes) async {
    try {
      final metadata = await _handler.getMetadata(bytes);
      final entity = DicomMapper.fromMetadata(metadata);
      return Success(entity);
    } catch (e) {
      return Failure('Failed to get metadata: $e');
    }
  }
  

  /// Get image data from bytes directly (preferred method)
  @override
  Future<Result<Uint8List>> getImageDataFromBytes(Uint8List dicomBytes) async {
    try {
      final imageBytes = await _handler.getImageBytes(dicomBytes);
      return Success(imageBytes);
    } catch (e) {
      return Failure('Failed to get image data: $e');
    }
  }
  

  /// Validate DICOM from bytes directly (preferred method)
  @override
  Future<Result<bool>> isValidDicomFromBytes(Uint8List bytes) async {
    try {
      final isValid = await _handler.isDicomFile(bytes);
      return Success(isValid);
    } catch (e) {
      return Failure('Failed to validate DICOM file: $e');
    }
  }
  

  @override
  Future<Result<Uint8List>> getProcessedImage({
    required Uint8List imageBytes,
    double brightness = 0.0,
    double contrast = 1.0,
  }) async {
    try {
      // If no adjustments needed, return original
      if (brightness == 0.0 && contrast == 1.0) {
        return Success(imageBytes);
      }
      
      // Apply brightness and contrast adjustments
      final processedBytes = await _applyBrightnessContrast(
        imageBytes, 
        brightness, 
        contrast
      );
      
      return Success(processedBytes);
    } catch (e) {
      return Failure('Failed to process image: $e');
    }
  }

  /// Apply brightness and contrast adjustments to image data
  Future<Uint8List> _applyBrightnessContrast(
    Uint8List imageBytes,
    double brightness,
    double contrast,
  ) async {
    try {
      // Use ColorFilter matrix approach on all platforms for hardware acceleration
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      
      // Create a picture recorder to apply transformations
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      
      // Apply color transformations using ColorFilter matrix
      final paint = ui.Paint()
        ..colorFilter = ui.ColorFilter.matrix(_createBrightnessContrastMatrix(brightness, contrast));
      
      canvas.drawImage(image, ui.Offset.zero, paint);
      
      final picture = recorder.endRecording();
      final processedImage = await picture.toImage(image.width, image.height);
      
      // Encode back to bytes
      final byteData = await processedImage.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List() ?? imageBytes;
    } catch (e) {
      // If processing fails, return original image
      return imageBytes;
    }
  }

  /// Create a color matrix for brightness and contrast adjustments
  List<double> _createBrightnessContrastMatrix(double brightness, double contrast) {
    // Standard color matrix for brightness/contrast
    // Matrix format: [R, G, B, A, offset] for each channel
    // Reduce brightness scaling for finer control
    final brightnessOffset = brightness * 127.5; // Reduced from 255 to 127.5 for finer control
    
    return [
      contrast, 0, 0, 0, brightnessOffset, // Red
      0, contrast, 0, 0, brightnessOffset, // Green  
      0, 0, contrast, 0, brightnessOffset, // Blue
      0, 0, 0, 1, 0, // Alpha (unchanged)
    ];
  }

}