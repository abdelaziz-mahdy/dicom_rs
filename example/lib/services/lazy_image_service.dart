import 'dart:typed_data';
import 'dart:async';
import '../models/complex_types.dart';
import 'dicom_service.dart';

/// Service for lazy loading DICOM images with configurable preload buffer
class LazyImageService {
  final DicomService _dicomService;
  final int _preloadBuffer;
  
  // Cache for loaded images
  final Map<int, Uint8List?> _imageCache = {};
  final Map<int, Future<Uint8List?>> _loadingFutures = {};
  
  // DICOM file paths
  List<DicomDirectoryEntry> _dicomFiles = [];
  
  // Current viewing index
  int _currentIndex = 0;
  
  LazyImageService({
    DicomService? dicomService,
    int preloadBuffer = 3, // Load 3 images ahead/behind by default
  }) : _dicomService = dicomService ?? DicomService(),
       _preloadBuffer = preloadBuffer;

  /// Initialize with DICOM files
  void initialize(List<DicomDirectoryEntry> dicomFiles) {
    _dicomFiles = dicomFiles;
    _imageCache.clear();
    _loadingFutures.clear();
    _currentIndex = 0;
  }

  /// Get image at specific index, loading if necessary
  Future<Uint8List?> getImageAt(int index) async {
    if (index < 0 || index >= _dicomFiles.length) {
      return null;
    }

    // Return cached image if available
    if (_imageCache.containsKey(index)) {
      return _imageCache[index];
    }

    // Return existing loading future if in progress
    if (_loadingFutures.containsKey(index)) {
      return await _loadingFutures[index];
    }

    // Start loading the image
    final future = _loadImage(index);
    _loadingFutures[index] = future;
    
    final result = await future;
    _loadingFutures.remove(index);
    
    return result;
  }

  /// Update current viewing index and preload surrounding images
  Future<void> updateCurrentIndex(int newIndex) async {
    if (newIndex < 0 || newIndex >= _dicomFiles.length) {
      return;
    }

    _currentIndex = newIndex;
    
    // Preload current image first (highest priority)
    await getImageAt(_currentIndex);
    
    // Preload buffer around current index
    _preloadSurroundingImages();
    
    // Clean up old cache entries that are far from current index
    _cleanupDistantCache();
  }

  /// Get cached image at index (returns null if not loaded)
  Uint8List? getCachedImageAt(int index) {
    return _imageCache[index];
  }

  /// Check if image is loaded at index
  bool isImageLoaded(int index) {
    return _imageCache.containsKey(index) && _imageCache[index] != null;
  }

  /// Check if image is currently loading
  bool isImageLoading(int index) {
    return _loadingFutures.containsKey(index);
  }

  /// Get loading progress (0.0 to 1.0)
  double getLoadingProgress() {
    final totalImagesInBuffer = (_preloadBuffer * 2 + 1).clamp(1, _dicomFiles.length);
    final startIndex = (_currentIndex - _preloadBuffer).clamp(0, _dicomFiles.length - 1);
    final endIndex = (_currentIndex + _preloadBuffer).clamp(0, _dicomFiles.length - 1);
    
    int loadedCount = 0;
    for (int i = startIndex; i <= endIndex; i++) {
      if (isImageLoaded(i)) {
        loadedCount++;
      }
    }
    
    return loadedCount / totalImagesInBuffer;
  }

  /// Get total number of images
  int get totalImages => _dicomFiles.length;

  /// Get current preload buffer size
  int get preloadBuffer => _preloadBuffer;

  /// Clear all cached images
  void clearCache() {
    _imageCache.clear();
    _loadingFutures.clear();
  }

  /// Preload images around current index
  void _preloadSurroundingImages() {
    final startIndex = (_currentIndex - _preloadBuffer).clamp(0, _dicomFiles.length - 1);
    final endIndex = (_currentIndex + _preloadBuffer).clamp(0, _dicomFiles.length - 1);
    
    // Load images in order of priority (closest to current index first)
    for (int distance = 0; distance <= _preloadBuffer; distance++) {
      // Load forward
      final forwardIndex = _currentIndex + distance;
      if (forwardIndex <= endIndex && !isImageLoaded(forwardIndex) && !isImageLoading(forwardIndex)) {
        _startBackgroundLoad(forwardIndex);
      }
      
      // Load backward (skip distance 0 since it's already done)
      if (distance > 0) {
        final backwardIndex = _currentIndex - distance;
        if (backwardIndex >= startIndex && !isImageLoaded(backwardIndex) && !isImageLoading(backwardIndex)) {
          _startBackgroundLoad(backwardIndex);
        }
      }
    }
  }

  /// Start loading an image in the background
  void _startBackgroundLoad(int index) {
    if (_loadingFutures.containsKey(index)) {
      return; // Already loading
    }
    
    final future = _loadImage(index);
    _loadingFutures[index] = future;
    
    // Don't await - let it load in background
    future.then((_) {
      _loadingFutures.remove(index);
    }).catchError((error) {
      _loadingFutures.remove(index);
      print('Error loading image at index $index: $error');
    });
  }

  /// Load a single image
  Future<Uint8List?> _loadImage(int index) async {
    try {
      final bytes = await _dicomService.getImageBytes(_dicomFiles[index].path);
      _imageCache[index] = bytes;
      return bytes;
    } catch (error) {
      print('Error loading image at index $index: $error');
      _imageCache[index] = null;
      return null;
    }
  }

  /// Clean up cache entries that are far from current index
  void _cleanupDistantCache() {
    final maxDistance = _preloadBuffer * 2; // Keep images 2x buffer size away
    final keysToRemove = <int>[];
    
    for (final index in _imageCache.keys) {
      final distance = (index - _currentIndex).abs();
      if (distance > maxDistance) {
        keysToRemove.add(index);
      }
    }
    
    for (final key in keysToRemove) {
      _imageCache.remove(key);
    }
  }

  /// Dispose resources
  void dispose() {
    clearCache();
  }
}