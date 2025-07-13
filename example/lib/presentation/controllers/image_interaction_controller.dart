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
  
  // Selected measurement tracking for highlighting
  dynamic _selectedMeasurement;
  int? _selectedPointIndex;

  // Callbacks
  VoidCallback? onNextImage;
  VoidCallback? onPreviousImage;
  void Function(double brightness, double contrast)? onBrightnessContrastChanged;
  void Function(double scale)? onScaleChanged;
  void Function(Offset position, Size imageSize)? onImageTapped;
  void Function(Offset position)? onMeasurementPointDragged;
  void Function(dynamic measurement, int pointIndex, Offset newPosition)? onPointDrag;

  // Brightness/contrast state with debouncing
  double _currentBrightness = 0.0;
  double _currentContrast = 1.0;
  Timer? _brightnessContrastDebounceTimer;
  static const Duration _brightnessContrastDebounce = Duration(milliseconds: 16); // ~60fps

  // Enhanced navigation state - simplified and more reliable
  Timer? _navigationTimer;
  LogicalKeyboardKey? _activeKey;
  DateTime? _lastNavigationTime;
  static const Duration _navigationDelay = Duration(milliseconds: 150);
  static const Duration _navigationInterval = Duration(milliseconds: 120);
  static const Duration _navigationDebounce = Duration(milliseconds: 50);

  bool get isInteracting => _isRightClickDragging;
  dynamic get selectedMeasurement => _selectedMeasurement;
  int? get selectedPointIndex => _selectedPointIndex;

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _brightnessContrastDebounceTimer?.cancel();
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

  /// Handle keyboard events with enhanced debouncing and reliable navigation
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
    final now = DateTime.now();
    
    // Debounce rapid key presses to prevent jumping
    if (_lastNavigationTime != null) {
      final timeSinceLastNav = now.difference(_lastNavigationTime!);
      if (timeSinceLastNav < _navigationDebounce) {
        return; // Ignore too-rapid key presses
      }
    }
    
    // Clean up any existing timer
    _navigationTimer?.cancel();
    
    // First key press: immediate navigation
    if (_activeKey != key) {
      _activeKey = key;
      _navigateWithKey(key);
      _lastNavigationTime = now;
      
      // Start repeat timer for continuous navigation
      _navigationTimer = Timer(_navigationDelay, () {
        _startRepeatedNavigation(key);
      });
    }
  }

  void _handleKeyUp(LogicalKeyboardKey key) {
    if (_activeKey == key) {
      _navigationTimer?.cancel();
      _navigationTimer = null;
      _activeKey = null;
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

  void _startRepeatedNavigation(LogicalKeyboardKey key) {
    // Only continue if the key is still being held down
    if (_activeKey != key) return;
    
    final now = DateTime.now();
    _navigateWithKey(key);
    _lastNavigationTime = now;
    
    // Schedule next repeat navigation
    _navigationTimer = Timer(_navigationInterval, () {
      _startRepeatedNavigation(key);
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
      
      // Debounce the callback to prevent blocking the app
      _brightnessContrastDebounceTimer?.cancel();
      _brightnessContrastDebounceTimer = Timer(_brightnessContrastDebounce, () {
        if (onBrightnessContrastChanged != null) {
          onBrightnessContrastChanged!(_currentBrightness, _currentContrast);
        }
      });
      
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
    
    // For single-finger gestures, allow measurement point detection
    if (enableMeasurements && details.pointerCount == 1) {
      // Single finger gesture - could be measurement point dragging
      return;
    }
    
    // Only handle multi-touch zoom gestures
    if (details.pointerCount >= 2) {
      // Prepare for zoom
    }
  }

  /// Handle scale update (zoom/pan gestures)
  void handleScaleUpdate(ScaleUpdateDetails details) {
    // Priority 1: Measurement point dragging (single finger pan with scale = 1.0)
    if (enableMeasurements && details.scale == 1.0 && details.pointerCount == 1) {
      // Always try measurement point dragging for single-finger pan
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
    // Clear selected measurement when gesture ends (user releases)
    clearSelectedMeasurement();
  }

  /// Set the selected measurement for highlighting
  void setSelectedMeasurement(dynamic measurement, int? pointIndex) {
    _selectedMeasurement = measurement;
    _selectedPointIndex = pointIndex;
    notifyListeners();
  }

  /// Clear the selected measurement
  void clearSelectedMeasurement() {
    _selectedMeasurement = null;
    _selectedPointIndex = null;
    notifyListeners();
  }

  /// Reset interaction state
  void reset() {
    _isRightClickDragging = false;
    _lastPanPosition = null;
    _currentBrightness = 0.0;
    _currentContrast = 1.0;
    
    // Reset navigation state
    _navigationTimer?.cancel();
    _navigationTimer = null;
    _activeKey = null;
    _lastNavigationTime = null;
    
    // Reset brightness/contrast debounce
    _brightnessContrastDebounceTimer?.cancel();
    _brightnessContrastDebounceTimer = null;
    
    // Clear selected measurement
    _selectedMeasurement = null;
    _selectedPointIndex = null;
    
    notifyListeners();
  }

  /// Synchronize brightness/contrast values with external state
  void syncBrightnessContrast(double brightness, double contrast) {
    _currentBrightness = brightness;
    _currentContrast = contrast;
    // Notify listeners to update any UI that depends on these values
    notifyListeners();
  }

  /// Get current brightness value
  double get currentBrightness => _currentBrightness;
  
  /// Get current contrast value  
  double get currentContrast => _currentContrast;

  /// Set brightness/contrast values directly (for initialization)
  void setBrightnessContrast(double brightness, double contrast) {
    _currentBrightness = brightness;
    _currentContrast = contrast;
    // Cancel any pending debounce and immediately notify
    _brightnessContrastDebounceTimer?.cancel();
    onBrightnessContrastChanged?.call(_currentBrightness, _currentContrast);
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