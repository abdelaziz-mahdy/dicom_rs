import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Clean, configurable controller for all image interactions
class ImageInteractionController extends ChangeNotifier {
  ImageInteractionController({
    this.enableScrollNavigation = true,
    this.enableKeyboardNavigation = true,
    this.enableBrightnessContrast = true,
    this.enableZoom = true,
    this.enableMeasurements = true,
    this.scrollThreshold = 5.0,
    this.brightnessContrastSensitivity = 0.001,
    this.zoomSensitivity = 0.1,
  });

  // Feature toggles
  final bool enableScrollNavigation;
  final bool enableKeyboardNavigation;
  final bool enableBrightnessContrast;
  final bool enableZoom;
  final bool enableMeasurements;

  // Sensitivity settings
  final double scrollThreshold;
  final double brightnessContrastSensitivity;
  final double zoomSensitivity;

  // Current state
  bool _isRightClickDragging = false;
  Offset? _lastPanPosition;

  // Callbacks
  VoidCallback? onNextImage;
  VoidCallback? onPreviousImage;
  void Function(double brightness, double contrast)? onBrightnessContrastChanged;
  void Function(double scale)? onScaleChanged;
  void Function(Offset position, Size imageSize)? onImageTapped;
  void Function(Offset position)? onMeasurementPointDragged;
  void Function(dynamic measurement, int pointIndex, Offset newPosition)? onPointDrag;

  // Brightness/contrast state
  double _currentBrightness = 0.0;
  double _currentContrast = 1.0;

  // Fast navigation state
  Timer? _fastNavigationTimer;
  bool _isFastNavigating = false;
  LogicalKeyboardKey? _activeKey;
  static const Duration _fastNavigationDelay = Duration(milliseconds: 150);
  static const Duration _fastNavigationInterval = Duration(milliseconds: 100);

  bool get isInteracting => _isRightClickDragging;

  @override
  void dispose() {
    _fastNavigationTimer?.cancel();
    super.dispose();
  }

  /// Handle pointer signal events (scroll wheel and trackpad)
  void handlePointerSignal(PointerSignalEvent event) {
    if (!enableScrollNavigation) return;
    
    if (event is PointerScrollEvent) {
      final scrollDelta = event.scrollDelta;
      
      // Use very low threshold for maximum trackpad sensitivity
      // Most trackpads send small delta values (0.1 - 3.0)
      final effectiveThreshold = 0.1;
      
      // Prioritize vertical scrolling (most common)
      if (scrollDelta.dy.abs() > effectiveThreshold) {
        if (scrollDelta.dy > 0) {
          onNextImage?.call();
        } else {
          onPreviousImage?.call();
        }
      } else if (scrollDelta.dx.abs() > effectiveThreshold) {
        // Horizontal scroll as fallback
        if (scrollDelta.dx > 0) {
          onNextImage?.call();
        } else {
          onPreviousImage?.call();
        }
      }
    }
  }

  /// Handle keyboard events with fast navigation support
  void handleKeyEvent(KeyEvent event) {
    if (!enableKeyboardNavigation) return;
    
    final key = event.logicalKey;
    final isNavigationKey = key == LogicalKeyboardKey.arrowLeft ||
                          key == LogicalKeyboardKey.arrowRight ||
                          key == LogicalKeyboardKey.arrowUp ||
                          key == LogicalKeyboardKey.arrowDown;
    
    if (!isNavigationKey) return;
    
    if (event is KeyDownEvent) {
      _handleKeyDown(key);
    } else if (event is KeyUpEvent) {
      _handleKeyUp(key);
    }
  }

  void _handleKeyDown(LogicalKeyboardKey key) {
    // Cancel any existing timer
    _fastNavigationTimer?.cancel();
    
    // Immediate navigation on first press
    _navigateWithKey(key);
    
    // Start fast navigation timer if this is a new key or continuing same key
    if (_activeKey != key) {
      _activeKey = key;
      _isFastNavigating = false;
    }
    
    // Start timer for fast navigation
    _fastNavigationTimer = Timer(_fastNavigationDelay, () {
      _isFastNavigating = true;
      _startFastNavigation(key);
    });
  }

  void _handleKeyUp(LogicalKeyboardKey key) {
    if (_activeKey == key) {
      _fastNavigationTimer?.cancel();
      _fastNavigationTimer = null;
      _activeKey = null;
      _isFastNavigating = false;
    }
  }

  void _navigateWithKey(LogicalKeyboardKey key) {
    switch (key) {
      case LogicalKeyboardKey.arrowLeft:
      case LogicalKeyboardKey.arrowUp:
        onPreviousImage?.call();
        break;
      case LogicalKeyboardKey.arrowRight:
      case LogicalKeyboardKey.arrowDown:
        onNextImage?.call();
        break;
    }
  }

  void _startFastNavigation(LogicalKeyboardKey key) {
    if (!_isFastNavigating || _activeKey != key) return;
    
    _navigateWithKey(key);
    
    // Schedule next fast navigation
    _fastNavigationTimer = Timer(_fastNavigationInterval, () {
      _startFastNavigation(key);
    });
  }

  /// Handle pointer down events (start of interactions)
  void handlePointerDown(PointerDownEvent event) {
    if (!enableBrightnessContrast) return;
    
    // Right-click starts brightness/contrast adjustment
    if (event.buttons == kSecondaryMouseButton) {
      _isRightClickDragging = true;
      _lastPanPosition = event.localPosition;
      notifyListeners();
    }
  }

  /// Handle pointer move events (during interactions)
  void handlePointerMove(PointerMoveEvent event) {
    if (!enableBrightnessContrast || !_isRightClickDragging) return;
    
    if (_lastPanPosition != null) {
      final delta = event.localPosition - _lastPanPosition!;
      
      // Convert movement to brightness/contrast adjustments
      final brightnessChange = delta.dx * brightnessContrastSensitivity;
      final contrastChange = -delta.dy * brightnessContrastSensitivity; // Negative for intuitive up/down
      
      // Update internal state
      _currentBrightness += brightnessChange;
      _currentContrast += contrastChange;
      
      // Clamp values to reasonable ranges
      _currentBrightness = _currentBrightness.clamp(-1.0, 1.0);
      _currentContrast = _currentContrast.clamp(0.1, 3.0);
      
      onBrightnessContrastChanged?.call(_currentBrightness, _currentContrast);
      _lastPanPosition = event.localPosition;
    }
  }

  /// Handle pointer up events (end of interactions)
  void handlePointerUp(PointerUpEvent event) {
    if (_isRightClickDragging) {
      _isRightClickDragging = false;
      _lastPanPosition = null;
      notifyListeners();
    }
  }

  /// Handle tap events for measurements
  void handleTap(TapUpDetails details, Size imageSize) {
    if (!enableMeasurements) return;
    
    onImageTapped?.call(details.localPosition, imageSize);
  }

  /// Handle scale start (zoom/pan gestures)
  void handleScaleStart(ScaleStartDetails details) {
    if (!enableZoom || _isRightClickDragging) return;
    
    // Only handle multi-touch zoom gestures
    if (details.pointerCount >= 2) {
      // Prepare for zoom
    }
  }

  /// Handle scale update (zoom/pan gestures)
  void handleScaleUpdate(ScaleUpdateDetails details) {
    // Priority 1: Measurement point dragging
    if (enableMeasurements && details.scale == 1.0 && details.pointerCount == 1) {
      // Check if we're dragging a measurement point
      onMeasurementPointDragged?.call(details.localFocalPoint);
      return;
    }
    
    // Priority 2: Brightness/contrast (only during right-click drag)
    if (enableBrightnessContrast && _isRightClickDragging) {
      // Already handled in handlePointerMove
      return;
    }
    
    // Priority 3: Zoom (only for multi-touch or explicit zoom gestures)
    if (enableZoom && details.scale != 1.0 && details.pointerCount >= 2) {
      onScaleChanged?.call(details.scale);
    }
  }

  /// Handle scale end (zoom/pan gestures)
  void handleScaleEnd(ScaleEndDetails details) {
    // Cleanup any ongoing interactions
  }

  /// Reset interaction state
  void reset() {
    _isRightClickDragging = false;
    _lastPanPosition = null;
    _currentBrightness = 0.0;
    _currentContrast = 1.0;
    
    // Reset fast navigation state
    _fastNavigationTimer?.cancel();
    _fastNavigationTimer = null;
    _activeKey = null;
    _isFastNavigating = false;
    
    notifyListeners();
  }

  /// Synchronize brightness/contrast values with external state
  void syncBrightnessContrast(double brightness, double contrast) {
    _currentBrightness = brightness;
    _currentContrast = contrast;
  }

  /// Update feature toggles
  ImageInteractionController copyWith({
    bool? enableScrollNavigation,
    bool? enableKeyboardNavigation,
    bool? enableBrightnessContrast,
    bool? enableZoom,
    bool? enableMeasurements,
    double? scrollThreshold,
    double? brightnessContrastSensitivity,
    double? zoomSensitivity,
  }) {
    return ImageInteractionController(
      enableScrollNavigation: enableScrollNavigation ?? this.enableScrollNavigation,
      enableKeyboardNavigation: enableKeyboardNavigation ?? this.enableKeyboardNavigation,
      enableBrightnessContrast: enableBrightnessContrast ?? this.enableBrightnessContrast,
      enableZoom: enableZoom ?? this.enableZoom,
      enableMeasurements: enableMeasurements ?? this.enableMeasurements,
      scrollThreshold: scrollThreshold ?? this.scrollThreshold,
      brightnessContrastSensitivity: brightnessContrastSensitivity ?? this.brightnessContrastSensitivity,
      zoomSensitivity: zoomSensitivity ?? this.zoomSensitivity,
    );
  }
}