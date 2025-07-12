import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../core/result.dart';
import '../../domain/entities/dicom_image_entity.dart';
import '../../domain/usecases/load_dicom_directory_usecase.dart';
import '../../data/repositories/dicom_repository_impl.dart';

/// Main controller for DICOM viewer with clean state management
class DicomViewerController extends ChangeNotifier {
  DicomViewerController({
    LoadDicomDirectoryUseCase? loadDirectoryUseCase,
    DicomRepositoryImpl? repository,
  }) : _loadDirectoryUseCase = loadDirectoryUseCase ?? 
         LoadDicomDirectoryUseCase(repository ?? DicomRepositoryImpl()),
       _repository = repository ?? DicomRepositoryImpl();

  final LoadDicomDirectoryUseCase _loadDirectoryUseCase;
  final DicomRepositoryImpl _repository;

  // State
  DicomViewerState _state = const DicomViewerState();
  DicomViewerState get state => _state;

  // Image caching with buffer zone for smooth navigation
  final Map<String, Uint8List> _imageCache = {};
  final Map<int, Uint8List> _bufferCache = {}; // Index-based buffer
  Timer? _cacheCleanupTimer;
  static const int _bufferSize = 3; // Load 3 images around current

  @override
  void dispose() {
    _cacheCleanupTimer?.cancel();
    _imageCache.clear();
    super.dispose();
  }

  /// Load DICOM directory
  Future<void> loadDirectory(String path, {bool recursive = false}) async {
    _updateState(_state.copyWith(
      isLoading: true,
      error: null,
    ));

    final result = await _loadDirectoryUseCase(
      path: path,
      recursive: recursive,
    );

    result.fold(
      (images) {
        _updateState(_state.copyWith(
          isLoading: false,
          images: images,
          currentIndex: 0,
          directoryPath: path,
        ));
        _preloadBuffer(0);
      },
      (error) {
        _updateState(_state.copyWith(
          isLoading: false,
          error: error,
        ));
      },
    );
  }

  /// Load single DICOM file
  Future<void> loadSingleFile(String filePath) async {
    _updateState(_state.copyWith(
      isLoading: true,
      error: null,
    ));

    try {
      // Check if it's a valid DICOM file
      final validationResult = await _repository.isValidDicom(filePath);
      final isValid = validationResult.fold((valid) => valid, (error) => false);
      
      if (!isValid) {
        _updateState(_state.copyWith(
          isLoading: false,
          error: 'Selected file is not a valid DICOM file',
        ));
        return;
      }

      // Get metadata for the file
      final metadataResult = await _repository.getMetadata(filePath);
      
      metadataResult.fold(
        (metadata) {
          // Create a single image entity
          final image = DicomImageEntity(
            id: filePath.hashCode.toString(),
            path: filePath,
            metadata: metadata,
          );
          
          _updateState(_state.copyWith(
            images: [image],
            currentIndex: 0,
            isLoading: false,
            directoryPath: filePath,
          ));
          
          // Preload the single image
          _preloadBuffer(0);
        },
        (error) {
          _updateState(_state.copyWith(
            isLoading: false,
            error: 'Failed to load DICOM file: $error',
          ));
        },
      );
    } catch (e) {
      _updateState(_state.copyWith(
        isLoading: false,
        error: 'Error loading DICOM file: $e',
      ));
    }
  }

  /// Navigate to specific image index
  void goToImage(int index) {
    if (index < 0 || index >= _state.images.length) return;
    
    _updateState(_state.copyWith(currentIndex: index));
    _preloadBuffer(index);
  }

  /// Navigate to next image
  void nextImage() {
    if (_state.images.isEmpty) return;
    final nextIndex = (_state.currentIndex + 1) % _state.images.length;
    goToImage(nextIndex);
  }

  /// Navigate to previous image
  void previousImage() {
    if (_state.images.isEmpty) return;
    final prevIndex = (_state.currentIndex - 1 + _state.images.length) % _state.images.length;
    goToImage(prevIndex);
  }

  /// Get current image data with buffer caching and brightness/contrast processing
  Future<Uint8List?> getCurrentImageData() async {
    if (!_state.hasImages) return null;

    final currentIndex = _state.currentIndex;
    
    // Check if we have processed image with current adjustments
    final adjustmentKey = '${currentIndex}_${_state.brightness}_${_state.contrast}';
    if (_imageCache.containsKey(adjustmentKey)) {
      return _imageCache[adjustmentKey];
    }

    // Get raw image data from buffer
    Uint8List? rawImageData;
    if (_bufferCache.containsKey(currentIndex)) {
      rawImageData = _bufferCache[currentIndex];
    } else {
      await _preloadBuffer(currentIndex);
      rawImageData = _bufferCache[currentIndex];
    }

    if (rawImageData == null) return null;

    // Apply brightness/contrast processing if adjustments are not default
    if (_state.brightness != 0.0 || _state.contrast != 1.0) {
      try {
        final processedImage = await _repository.getProcessedImage(
          path: _state.currentImage!.path,
          brightness: _state.brightness,
          contrast: _state.contrast,
        );
        
        return processedImage.fold(
          (data) {
            _imageCache[adjustmentKey] = data;
            return data;
          },
          (error) {
            debugPrint('Failed to process image: $error');
            return rawImageData;
          },
        );
      } catch (e) {
        debugPrint('Error processing image: $e');
        return rawImageData;
      }
    }

    return rawImageData;
  }

  /// Preload images in buffer zone around current index
  Future<void> _preloadBuffer(int centerIndex) async {
    final totalImages = _state.images.length;
    
    // Calculate buffer range
    final startIndex = (centerIndex - _bufferSize).clamp(0, totalImages - 1);
    final endIndex = (centerIndex + _bufferSize).clamp(0, totalImages - 1);
    
    // Load images in parallel for buffer
    final futures = <Future<void>>[];
    
    for (int i = startIndex; i <= endIndex; i++) {
      if (!_bufferCache.containsKey(i)) {
        futures.add(_loadImageAtIndex(i));
      }
    }
    
    await Future.wait(futures);
    
    // Clean up old buffer entries to manage memory
    _cleanupBuffer(startIndex, endIndex);
  }

  /// Load image at specific index into buffer
  Future<void> _loadImageAtIndex(int index) async {
    if (index < 0 || index >= _state.images.length) return;
    
    final image = _state.images[index];
    final cacheKey = image.path;

    try {
      // Check file cache first
      Uint8List? imageData = _imageCache[cacheKey];
      
      if (imageData == null) {
        final result = await _repository.getImageData(image.path);
        imageData = result.fold(
          (data) {
            _imageCache[cacheKey] = data;
            return data;
          },
          (error) {
            debugPrint('Failed to load image at index $index: $error');
            return null;
          },
        );
      }
      
      if (imageData != null) {
        _bufferCache[index] = imageData;
      }
    } catch (e) {
      debugPrint('Error loading image at index $index: $e');
    }
  }

  /// Clean up buffer cache to manage memory usage
  void _cleanupBuffer(int keepStart, int keepEnd) {
    final toRemove = <int>[];
    
    for (final index in _bufferCache.keys) {
      if (index < keepStart || index > keepEnd) {
        toRemove.add(index);
      }
    }
    
    for (final index in toRemove) {
      _bufferCache.remove(index);
    }
  }

  /// Clear processed image cache entries (brightness/contrast adjustments)
  void _clearProcessedImageCache() {
    final currentIndex = _state.currentIndex;
    final keysToRemove = <String>[];
    
    // Find all cached processed images for current index
    for (final key in _imageCache.keys) {
      if (key.startsWith('${currentIndex}_')) {
        keysToRemove.add(key);
      }
    }
    
    // Remove processed image cache entries
    for (final key in keysToRemove) {
      _imageCache.remove(key);
    }
  }

  /// Update brightness and contrast
  void updateImageAdjustments({
    required double brightness,
    required double contrast,
  }) {
    // Clear cached processed images to force regeneration
    _clearProcessedImageCache();
    
    _updateState(_state.copyWith(
      brightness: brightness,
      contrast: contrast,
    ));
  }

  /// Reset image adjustments
  void resetImageAdjustments() {
    _updateState(_state.copyWith(
      brightness: 0.0,
      contrast: 1.0,
      scale: 1.0,
    ));
  }

  /// Update zoom scale
  void updateScale(double scale) {
    _updateState(_state.copyWith(
      scale: scale.clamp(0.1, 10.0),
    ));
  }

  /// Reset viewer state
  void reset() {
    _imageCache.clear();
    _cacheCleanupTimer?.cancel();
    _updateState(const DicomViewerState());
  }

  // Private methods
  void _updateState(DicomViewerState newState) {
    _state = newState;
    notifyListeners();
  }

  /// Preload nearby images for smooth navigation
}

/// Immutable state class for DICOM viewer
class DicomViewerState {
  const DicomViewerState({
    this.isLoading = false,
    this.images = const [],
    this.currentIndex = 0,
    this.directoryPath,
    this.error,
    this.brightness = 0.0,
    this.contrast = 1.0,
    this.scale = 1.0,
  });

  final bool isLoading;
  final List<DicomImageEntity> images;
  final int currentIndex;
  final String? directoryPath;
  final String? error;
  final double brightness;
  final double contrast;
  final double scale;

  DicomImageEntity? get currentImage => 
      images.isNotEmpty && currentIndex < images.length 
          ? images[currentIndex] 
          : null;

  bool get hasImages => images.isNotEmpty;
  int get totalImages => images.length;

  DicomViewerState copyWith({
    bool? isLoading,
    List<DicomImageEntity>? images,
    int? currentIndex,
    String? directoryPath,
    String? error,
    double? brightness,
    double? contrast,
    double? scale,
  }) {
    return DicomViewerState(
      isLoading: isLoading ?? this.isLoading,
      images: images ?? this.images,
      currentIndex: currentIndex ?? this.currentIndex,
      directoryPath: directoryPath ?? this.directoryPath,
      error: error ?? this.error,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      scale: scale ?? this.scale,
    );
  }
}