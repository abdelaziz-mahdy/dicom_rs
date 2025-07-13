import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../core/result.dart';
import '../../domain/entities/dicom_image_entity.dart';
import '../../domain/usecases/load_dicom_directory_usecase.dart';
import '../../data/repositories/dicom_repository_impl.dart';
import '../../services/file_selector_service.dart';
import '../../services/enhanced_dicom_service.dart';
import '../../screens/dicom_loading_screen.dart';
import '../../data/mappers/dicom_mapper.dart';

/// Main controller for DICOM viewer with clean state management
class DicomViewerController extends ChangeNotifier {
  DicomViewerController({
    LoadDicomDirectoryUseCase? loadDirectoryUseCase,
    DicomRepositoryImpl? repository,
  }) : _repository = repository ?? DicomRepositoryImpl();

  final DicomRepositoryImpl _repository;
  final EnhancedDicomService _enhancedService = EnhancedDicomService();

  // State
  DicomViewerState _state = const DicomViewerState();
  DicomViewerState get state => _state;

  // Duplicate loading prevention
  bool _isCurrentlyLoading = false;
  String? _lastLoadedDirectoryPath;

  // Image caching with buffer zone for smooth navigation
  final Map<String, Uint8List> _persistentImageCache =
      {}; // Never cleared - keeps all loaded images
  final Map<int, Uint8List> _bufferCache =
      {}; // Index-based buffer for quick access
  Timer? _cacheCleanupTimer;
  static const int _bufferSize =
      5; // Load 5 images around current for smoother navigation

  @override
  void dispose() {
    _cacheCleanupTimer?.cancel();
    _persistentImageCache.clear();
    _bufferCache.clear();
    super.dispose();
  }

  /// STREAMLINED: Fast loading with minimal checks for maximum performance
  Future<void> loadFromFileDataList(List<DicomFileData> fileDataList, {bool recursive = false}) async {
    final totalStartTime = DateTime.now();
    debugPrint('⏱️ [TIMING] loadFromFileDataList START - ${fileDataList.length} files');
    
    // Single early validation - fail fast if no files
    if (fileDataList.isEmpty) {
      _updateState(_state.copyWith(error: 'No files provided'));
      return;
    }

    // Simple duplicate loading prevention
    if (_isCurrentlyLoading) return;
    _isCurrentlyLoading = true;
    
    final stateUpdateTime = DateTime.now();
    _updateState(_state.copyWith(isLoading: true, error: null));
    debugPrint('⏱️ [TIMING] Initial state update: ${DateTime.now().difference(stateUpdateTime).inMilliseconds}ms');

    try {
      // ULTRA-OPTIMIZED: Use pre-extracted metadata directly (no redundant processing)
      final metadataStartTime = DateTime.now();
      final processedImages = <DicomImageEntity>[];
      
      debugPrint('⏱️ [TIMING] Creating ${fileDataList.length} entities from pre-extracted metadata...');
      
      // Process all files at once - metadata is already extracted by file selector
      for (int i = 0; i < fileDataList.length; i++) {
        final file = fileDataList[i];
        
        // OPTIMIZATION: Files should ALWAYS have pre-extracted metadata from file selector
        if (file.metadata != null) {
          processedImages.add(DicomImageEntity(
            id: file.name.hashCode.toString(),
            name: file.name,
            bytes: file.bytes,
            metadata: DicomMapper.fromMetadata(file.metadata!),
          ));
        } else {
          // This should NOT happen if file selector worked correctly
          debugPrint('⚠️ WARNING: File ${file.name} missing pre-extracted metadata - this indicates a bug in file selector');
          // Only fallback if absolutely necessary
          final metadata = await _extractMetadataFallback(file);
          if (metadata != null) {
            processedImages.add(DicomImageEntity(
              id: file.name.hashCode.toString(),
              name: file.name,
              bytes: file.bytes,
              metadata: DicomMapper.fromMetadata(metadata),
            ));
          }
        }
      }
      
      debugPrint('⏱️ [TIMING] Entity creation from pre-extracted metadata: ${DateTime.now().difference(metadataStartTime).inMilliseconds}ms');

      if (processedImages.isEmpty) {
        _updateState(_state.copyWith(isLoading: false, error: 'No valid DICOM files'));
        return;
      }

      // Sort and set images
      final sortStartTime = DateTime.now();
      processedImages.sort(_compareImages);
      debugPrint('⏱️ [TIMING] Sorting ${processedImages.length} images: ${DateTime.now().difference(sortStartTime).inMilliseconds}ms');
      
      // Set images but keep loading true until first image is ready
      final stateTime = DateTime.now();
      _updateState(_state.copyWith(
        images: processedImages,
        currentIndex: 0,
        isLoading: true, // Keep loading until first image is ready
      ));
      debugPrint('⏱️ [TIMING] Images state update: ${DateTime.now().difference(stateTime).inMilliseconds}ms');

      // Load first image immediately and wait for it to be ready
      final firstImageStartTime = DateTime.now();
      await _loadImageAtIndex(0);
      debugPrint('⏱️ [TIMING] First image load: ${DateTime.now().difference(firstImageStartTime).inMilliseconds}ms');
      
      // NOW set loading complete since first image is ready
      final finalStateTime = DateTime.now();
      _updateState(_state.copyWith(isLoading: false));
      debugPrint('⏱️ [TIMING] Final loading complete: ${DateTime.now().difference(finalStateTime).inMilliseconds}ms');
      
      // Preload small buffer around first image for smooth navigation
      unawaited(_preloadBuffer(0));
      
      DicomLoadingProgressNotifier.notify(
        DicomLoadingProgressEvent.completed(totalLoaded: processedImages.length),
      );
      
      debugPrint('⏱️ [TIMING] loadFromFileDataList TOTAL: ${DateTime.now().difference(totalStartTime).inMilliseconds}ms');

    } catch (e) {
      debugPrint('⏱️ [TIMING] loadFromFileDataList ERROR after: ${DateTime.now().difference(totalStartTime).inMilliseconds}ms - $e');
      _updateState(_state.copyWith(isLoading: false, error: 'Failed to load: $e'));
    } finally {
      _isCurrentlyLoading = false;
    }
  }

  /// Fallback metadata extraction if not pre-extracted
  Future<dynamic> _extractMetadataFallback(DicomFileData file) async {
    final startTime = DateTime.now();
    try {
      debugPrint('⏱️ [TIMING] Fallback metadata extraction for ${file.name}...');
      final entries = await _enhancedService.loadFromFileDataList([file]);
      final extractTime = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint('⏱️ [TIMING] Fallback extraction ${file.name}: ${extractTime}ms');
      return entries.isNotEmpty ? entries.first.metadata : null;
    } catch (e) {
      debugPrint('⏱️ [TIMING] Fallback extraction FAILED ${file.name}: ${DateTime.now().difference(startTime).inMilliseconds}ms - $e');
      return null;
    }
  }

  /// Compare images for sorting (helper method extracted from use case)
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

    // Finally by name
    return a.name.compareTo(b.name);
  }

  /// Load single DICOM file from DicomFileData (bytes-based) with progress tracking
  Future<void> loadSingleFileFromData(DicomFileData fileData) async {
    _updateState(_state.copyWith(isLoading: true, error: null));

    try {
      // Notify start of single file loading
      DicomLoadingProgressNotifier.notify(
        DicomLoadingProgressEvent.processing(
          fileName: fileData.name,
          processed: 0,
          total: 1,
        ),
      );

      // Validate DICOM content
      DicomLoadingProgressNotifier.notify(
        DicomLoadingProgressEvent.validating(
          fileName: fileData.name,
          processed: 0,
          total: 1,
        ),
      );

      final validationResult = await _repository.isValidDicomFromBytes(fileData.bytes);
      final isValid = validationResult.fold((valid) => valid, (error) => false);

      if (!isValid) {
        final error = 'Selected file is not a valid DICOM file';
        _updateState(_state.copyWith(isLoading: false, error: error));
        DicomLoadingProgressNotifier.notify(DicomLoadingProgressEvent.error(error));
        return;
      }

      // Get metadata for the file
      final metadataResult = await _repository.getMetadataFromBytes(fileData.bytes);

      metadataResult.fold(
        (metadata) {
          // Create a single image entity
          final image = DicomImageEntity(
            id: fileData.name.hashCode.toString(),
            name: fileData.name,
            bytes: fileData.bytes,
            metadata: metadata,
          );

          _updateState(
            _state.copyWith(
              images: [image],
              currentIndex: 0,
              isLoading: false,
            ),
          );

          // Notify completion
          DicomLoadingProgressNotifier.notify(
            DicomLoadingProgressEvent.completed(totalLoaded: 1),
          );

          // Preload the single image
          _preloadBuffer(0);
        },
        (error) {
          final errorMsg = 'Failed to load DICOM file: $error';
          _updateState(_state.copyWith(isLoading: false, error: errorMsg));
          DicomLoadingProgressNotifier.notify(DicomLoadingProgressEvent.error(errorMsg));
        },
      );
    } catch (e) {
      final errorMsg = 'Error loading DICOM file: $e';
      _updateState(_state.copyWith(isLoading: false, error: errorMsg));
      DicomLoadingProgressNotifier.notify(DicomLoadingProgressEvent.error(errorMsg));
    }
  }

  /// Navigate to specific image index
  void goToImage(int index) {
    if (index < 0 || index >= _state.images.length) return;

    // Store current brightness/contrast before changing image
    final currentBrightness = _state.brightness;
    final currentContrast = _state.contrast;

    _updateState(_state.copyWith(currentIndex: index));
    _preloadBuffer(index);
    
    // Force brightness/contrast to persist after image change
    // This ensures the adjusted values are applied to the new image
    if (currentBrightness != 0.0 || currentContrast != 1.0) {
      // Small delay to ensure state update is complete
      Future.microtask(() {
        _updateState(_state.copyWith(
          brightness: currentBrightness,
          contrast: currentContrast,
        ));
        notifyListeners();
      });
    }
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
    final prevIndex =
        (_state.currentIndex - 1 + _state.images.length) % _state.images.length;
    goToImage(prevIndex);
  }

  /// OPTIMIZED: Get current image data with immediate cache check and comprehensive error handling
  Future<Uint8List?> getCurrentImageData() async {
    final startTime = DateTime.now();
    
    if (!_state.hasImages) {
      debugPrint('⚠️ No images available for display');
      return null;
    }

    if (_state.currentIndex < 0 || _state.currentIndex >= _state.images.length) {
      debugPrint('⚠️ Invalid current index: ${_state.currentIndex} (total: ${_state.images.length})');
      return null;
    }

    final currentIndex = _state.currentIndex;

    // Get raw image data from buffer with error handling
    final bufferStartTime = DateTime.now();
    Uint8List? rawImageData;
    try {
      if (_bufferCache.containsKey(currentIndex)) {
        rawImageData = _bufferCache[currentIndex];
        debugPrint('⏱️ [TIMING] Buffer cache hit for index $currentIndex: ${DateTime.now().difference(bufferStartTime).inMilliseconds}ms');
      } else {
        debugPrint('⏱️ [TIMING] Buffer cache miss for index $currentIndex, preloading...');
        await _preloadBuffer(currentIndex);
        rawImageData = _bufferCache[currentIndex];
        debugPrint('⏱️ [TIMING] Buffer preload for index $currentIndex: ${DateTime.now().difference(bufferStartTime).inMilliseconds}ms');
      }
    } catch (e) {
      debugPrint('❌ Error loading image data from buffer: $e');
      return null;
    }

    if (rawImageData == null) {
      debugPrint('⚠️ No image data available in buffer for index $currentIndex');
      return null;
    }

    // Validate image data integrity
    if (rawImageData.isEmpty) {
      debugPrint('⚠️ Image data is empty for index $currentIndex');
      return null;
    }

    // Apply brightness/contrast processing if adjustments are not default
    if (_state.brightness != 0.0 || _state.contrast != 1.0) {
      try {
        final processingStartTime = DateTime.now();
        debugPrint('⏱️ [TIMING] Image processing B:${_state.brightness} C:${_state.contrast}...');
        
        final processedImage = await _repository.getProcessedImage(
          imageBytes: rawImageData,
          brightness: _state.brightness,
          contrast: _state.contrast,
        );

        final processingTime = DateTime.now().difference(processingStartTime).inMilliseconds;
        debugPrint('⏱️ [TIMING] Image processing: ${processingTime}ms');

        final result = processedImage.fold(
          (data) {
            if (data.isEmpty) {
              debugPrint('⚠️ Processed image data is empty, returning original');
              return rawImageData;
            }
            return data;
          },
          (error) {
            debugPrint('⚠️ Failed to process image with adjustments: $error');
            return rawImageData;
          }
        );
        
        final totalTime = DateTime.now().difference(startTime).inMilliseconds;
        debugPrint('⏱️ [TIMING] getCurrentImageData TOTAL: ${totalTime}ms');
        return result;
      } catch (e) {
        debugPrint('❌ Exception during image processing: $e');
        return rawImageData;
      }
    }

    final totalTime = DateTime.now().difference(startTime).inMilliseconds;
    debugPrint('⏱️ [TIMING] getCurrentImageData TOTAL (no processing): ${totalTime}ms');
    return rawImageData;
  }

  /// OPTIMIZED: Check if current image is immediately available (no async loading)
  bool get isCurrentImageReady {
    if (!_state.hasImages) return false;
    return _bufferCache.containsKey(_state.currentIndex);
  }

  /// OPTIMIZED: Get current image data synchronously if available
  Uint8List? getCurrentImageDataSync() {
    if (!_state.hasImages || !isCurrentImageReady) return null;
    return _bufferCache[_state.currentIndex];
  }

  


  /// OPTIMIZED: Preload images in buffer zone around current index (on-demand only)
  Future<void> _preloadBuffer(int centerIndex) async {
    final totalImages = _state.images.length;

    // Calculate buffer range
    final startIndex = (centerIndex - _bufferSize).clamp(0, totalImages - 1);
    final endIndex = (centerIndex + _bufferSize).clamp(0, totalImages - 1);

    // Check what's already loaded to avoid duplicate work
    final futures = <Future<void>>[];
    final toLoad = <int>[];

    for (int i = startIndex; i <= endIndex; i++) {
      if (!_bufferCache.containsKey(i)) {
        toLoad.add(i);
        futures.add(_loadImageAtIndex(i));
      }
    }

    if (toLoad.isNotEmpty) {
      debugPrint('🔄 BUFFER: Loading ${toLoad.length} images around index $centerIndex (${toLoad.join(", ")})');
      await Future.wait(futures);
    }

    // Clean up old buffer entries to manage memory
    _cleanupBuffer(startIndex, endIndex);
  }

  /// Load image at specific index into buffer with comprehensive error handling
  Future<void> _loadImageAtIndex(int index) async {
    final startTime = DateTime.now();
    
    if (index < 0 || index >= _state.images.length) {
      debugPrint('⚠️ Invalid image index: $index (valid range: 0-${_state.images.length - 1})');
      return;
    }

    final image = _state.images[index];
    final cacheKey = image.name;

    // Validate image data before processing
    if (image.bytes.isEmpty) {
      debugPrint('⚠️ Empty image bytes for index $index (${image.name})');
      return;
    }

    try {
      // Check persistent cache first - never reload if already cached
      final cacheCheckTime = DateTime.now();
      Uint8List? imageData = _persistentImageCache[cacheKey];
      debugPrint('⏱️ [TIMING] Cache check for ${image.name}: ${DateTime.now().difference(cacheCheckTime).inMilliseconds}ms');

      if (imageData == null) {
        // Load from repository only if not in persistent cache
        try {
          final repositoryStartTime = DateTime.now();
          debugPrint('⏱️ [TIMING] Repository loading for ${image.name}...');
          final result = await _repository.getImageDataFromBytes(image.bytes);
          final repositoryTime = DateTime.now().difference(repositoryStartTime).inMilliseconds;
          debugPrint('⏱️ [TIMING] Repository load ${image.name}: ${repositoryTime}ms');
          
          imageData = result.fold(
            (data) {
              if (data.isEmpty) {
                debugPrint('⚠️ Repository returned empty image data for index $index');
                return null;
              }
              // Store in persistent cache - never cleared
              _persistentImageCache[cacheKey] = data;
              return data;
            },
            (error) {
              debugPrint('❌ Repository failed to load image at index $index: $error');
              return null;
            },
          );
        } catch (e) {
          debugPrint('❌ Exception calling repository for index $index: $e');
          return;
        }
      }

      if (imageData != null && imageData.isNotEmpty) {
        _bufferCache[index] = imageData;
        final totalTime = DateTime.now().difference(startTime).inMilliseconds;
        debugPrint('⏱️ [TIMING] ✅ Image ${index} (${image.name}) loaded: ${totalTime}ms (${imageData.length} bytes)');
      } else {
        debugPrint('⚠️ No valid image data obtained for index $index');
      }
    } catch (e) {
      debugPrint('❌ Unexpected error loading image at index $index: $e');
      
      // Try to recover by removing corrupted cache entries
      _persistentImageCache.remove(cacheKey);
      _bufferCache.remove(index);
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

  /// Update brightness and contrast
  void updateImageAdjustments({
    required double brightness,
    required double contrast,
  }) {
    _updateState(_state.copyWith(brightness: brightness, contrast: contrast));
    // Force notification to ensure UI updates immediately
    notifyListeners();
  }

  /// Reset image adjustments
  void resetImageAdjustments() {
    _updateState(_state.copyWith(brightness: 0.0, contrast: 1.0, scale: 1.0));
  }

  /// Update zoom scale
  void updateScale(double scale) {
    _updateState(_state.copyWith(scale: scale.clamp(0.1, 10.0)));
  }

  /// Reset viewer state
  void reset() {
    // Clear buffer, but keep persistent cache
    _bufferCache.clear();
    _cacheCleanupTimer?.cancel();
    _updateState(const DicomViewerState());
  }

  // Private methods
  void _updateState(DicomViewerState newState) {
    _state = newState;
    notifyListeners();
  }

  /// Get cache statistics for monitoring memory usage
  Map<String, int> get cacheStatistics => {
    'persistentImages': _persistentImageCache.length,
    'bufferImages': _bufferCache.length,
  };

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
