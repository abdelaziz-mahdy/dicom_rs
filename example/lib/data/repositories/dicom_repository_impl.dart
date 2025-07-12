import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:dicom_rs/dicom_rs.dart';
import 'package:flutter/services.dart';

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
      // Decode the image
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      
      // Get pixel data
      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return imageBytes;
      
      final pixels = byteData.buffer.asUint8List();
      final processedPixels = Uint8List(pixels.length);
      
      // Apply brightness and contrast to each pixel
      for (int i = 0; i < pixels.length; i += 4) {
        // Process RGB channels (skip alpha)
        for (int j = 0; j < 3; j++) {
          final pixel = pixels[i + j];
          
          // Apply contrast then brightness
          // Formula: new_pixel = (pixel * contrast) + brightness
          double newPixel = (pixel * contrast) + (brightness * 255);
          
          // Clamp to valid range [0, 255]
          newPixel = newPixel.clamp(0, 255);
          
          processedPixels[i + j] = newPixel.round();
        }
        
        // Keep alpha channel unchanged
        processedPixels[i + 3] = pixels[i + 3];
      }
      
      // Create new image from processed pixels
      final processedImage = await _createImageFromPixels(
        processedPixels,
        image.width,
        image.height,
      );
      
      // Encode back to bytes
      final processedByteData = await processedImage.toByteData(
        format: ui.ImageByteFormat.png
      );
      
      return processedByteData?.buffer.asUint8List() ?? imageBytes;
    } catch (e) {
      // If processing fails, return original image
      return imageBytes;
    }
  }

  /// Create an image from RGBA pixel data
  Future<ui.Image> _createImageFromPixels(
    Uint8List pixels,
    int width,
    int height,
  ) async {
    final completer = Completer<ui.Image>();
    
    ui.decodeImageFromPixels(
      pixels,
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    
    return completer.future;
  }
}