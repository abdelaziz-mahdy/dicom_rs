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

  /// ULTRA-OPTIMIZED: Immediate loading with parallel processing and instant first image
  Future<void> loadFromFileDataList(List<DicomFileData> fileDataList, {bool recursive = false}) async {
    // Prevent duplicate loading
    if (_isCurrentlyLoading) {
      debugPrint('⚠️ Already loading files, ignoring duplicate request');
      return;
    }

    // Check if loading the same directory path
    final directoryPath = fileDataList.isNotEmpty ? fileDataList.first.fullPath?.split('/').take(5).join('/') : null;
    if (directoryPath != null && directoryPath == _lastLoadedDirectoryPath && _state.hasImages) {
      debugPrint('⚠️ Same directory already loaded, ignoring duplicate request: $directoryPath');
      return;
    }

    _isCurrentlyLoading = true;
    _lastLoadedDirectoryPath = directoryPath;
    _updateState(_state.copyWith(isLoading: true, error: null));

    try {
      // Notify start of loading
      DicomLoadingProgressNotifier.notify(
        DicomLoadingProgressEvent.processing(
          fileName: 'OPTIMIZED: Loading metadata in parallel...',
          processed: 0,
          total: fileDataList.length,
        ),
      );

      // STEP 1: ULTRA-FAST parallel metadata extraction 
      debugPrint('🚀 ULTRA-OPTIMIZED: Starting parallel metadata extraction...');
      
      final entries = await _enhancedService.loadFromFileDataList(fileDataList);
      final processedImages = entries.map((entry) => 
        DicomImageEntity(
          id: entry.name.hashCode.toString(),
          name: entry.name,
          bytes: entry.bytes,
          metadata: DicomMapper.fromMetadata(entry.metadata),
        )
      ).toList();
      
      debugPrint('✅ ULTRA-OPTIMIZED: Parallel metadata extraction complete: ${processedImages.length} files');

      if (processedImages.isNotEmpty) {
        // Sort images properly
        processedImages.sort(_compareImages);

        // CRITICAL FIX: Update state with images first
        _updateState(
          _state.copyWith(
            images: processedImages,
            currentIndex: 0,
            isLoading: false, // Loading complete after metadata
          ),
        );
        
        // STEP 2: INSTANT first image loading - load immediately for display
        debugPrint('⚡ INSTANT: Loading first image immediately for display...');
        await _loadImageAtIndex(0); // Load first image synchronously
        debugPrint('✅ INSTANT: First image loaded and ready for display');
        
        // CRITICAL: Notify listeners that first image is ready
        notifyListeners();
        
        // STEP 3: Background buffer loading (non-blocking)
        debugPrint('🔄 BACKGROUND: Starting buffer preload for smooth navigation...');
        unawaited(_preloadBufferOptimizedAsync(0)); // Non-blocking background loading
        
        // Final completion notification
        DicomLoadingProgressNotifier.notify(
          DicomLoadingProgressEvent.completed(totalLoaded: processedImages.length),
        );
        
      } else {
        final error = 'No valid DICOM files found';
        _updateState(_state.copyWith(isLoading: false, error: error));
        DicomLoadingProgressNotifier.notify(DicomLoadingProgressEvent.error(error));
      }

    } catch (e) {
      final error = 'Failed to load DICOM files: $e';
      _updateState(_state.copyWith(isLoading: false, error: error));
      DicomLoadingProgressNotifier.notify(DicomLoadingProgressEvent.error(error));
    } finally {
      _isCurrentlyLoading = false;
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
    final prevIndex =
        (_state.currentIndex - 1 + _state.images.length) % _state.images.length;
    goToImage(prevIndex);
  }

  /// OPTIMIZED: Get current image data with immediate cache check
  Future<Uint8List?> getCurrentImageData() async {
    if (!_state.hasImages) return null;

    final currentIndex = _state.currentIndex;

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
          imageBytes: rawImageData,
          brightness: _state.brightness,
          contrast: _state.contrast,
        );

        return processedImage.fold((data) => data, (error) {
          debugPrint('Failed to process image: $error');
          return rawImageData;
        });
      } catch (e) {
        debugPrint('Error processing image: $e');
        return rawImageData;
      }
    }

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

  
  /// OPTIMIZED: Async buffer preload for background loading (non-blocking)
  Future<void> _preloadBufferOptimizedAsync(int startIndex) async {
    try {
      final totalImages = _state.images.length;
      final endIndex = (startIndex + _bufferSize - 1).clamp(0, totalImages - 1);

      debugPrint('🔄 BACKGROUND: Async buffer preload for indices $startIndex-$endIndex');
      
      // Load remaining images in parallel (skip index 0 as it's already loaded)
      final futures = <Future<void>>[];
      for (int i = startIndex + 1; i <= endIndex; i++) {
        futures.add(_loadImageAtIndex(i));
      }

      await Future.wait(futures);
      debugPrint('✅ BACKGROUND: Async buffer preload complete');
    } catch (e) {
      debugPrint('❌ BACKGROUND: Error in async buffer preload: $e');
    }
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
    final cacheKey = image.name; // Use name instead of path

    try {
      // Check persistent cache first - never reload if already cached
      Uint8List? imageData = _persistentImageCache[cacheKey];

      if (imageData == null) {
        // Load from repository only if not in persistent cache
        final result = await _repository.getImageDataFromBytes(image.bytes);
        imageData = result.fold(
          (data) {
            // Store in persistent cache - never cleared
            _persistentImageCache[cacheKey] = data;
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

  /// Update brightness and contrast
  void updateImageAdjustments({
    required double brightness,
    required double contrast,
  }) {
    _updateState(_state.copyWith(brightness: brightness, contrast: contrast));
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
