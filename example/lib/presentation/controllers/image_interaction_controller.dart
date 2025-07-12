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
    this.brightnessContrastSensitivity = 0.01,
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

  // Brightness/contrast state
  double _currentBrightness = 0.0;
  double _currentContrast = 1.0;

  bool get isInteracting => _isRightClickDragging;

  /// Handle pointer signal events (scroll wheel and trackpad)
  void handlePointerSignal(PointerSignalEvent event) {
    if (!enableScrollNavigation) return;
    
    if (event is PointerScrollEvent) {
      final scrollDelta = event.scrollDelta;
      
      // Handle trackpad and mouse wheel scrolling
      // Use smaller threshold for better trackpad sensitivity
      final effectiveThreshold = scrollThreshold * 0.3;
      
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

  /// Handle keyboard events
  void handleKeyEvent(KeyEvent event) {
    if (!enableKeyboardNavigation) return;
    
    if (event is KeyDownEvent) {
      switch (event.logicalKey) {
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
    notifyListeners();
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