import 'dart:async';
import 'dart:math' as math;

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
  bool _isMiddleButtonPanning = false;
  Offset? _lastPanPosition;

  // View transform: the image is scaled by [zoom] about the centre of the
  // view and then moved by [pan] (both in logical pixels).
  double _zoom = 1.0;
  Offset _pan = Offset.zero;
  Size _viewSize = Size.zero;
  Size? _contentSize;
  static const double minZoom = 0.5;
  static const double maxZoom = 10.0;

  // Scroll distance collected towards the next slice. A mouse wheel notch
  // arrives as one large event or several small ones, and a trackpad sends
  // many tiny deltas, so slices step on distance travelled, not per event.
  double _wheelDistance = 0;
  double _trackpadDistance = 0;
  static const double _wheelDistancePerSlice = 50;
  static const double _trackpadDistancePerSlice = 30;

  // Current drag or pinch gesture.
  double _gestureStartZoom = 1.0;
  bool _trackpadPinching = false;
  _DragMode? _dragMode;

  // Selected measurement tracking for highlighting
  dynamic _selectedMeasurement;
  int? _selectedPointIndex;

  // Callbacks
  VoidCallback? onNextImage;
  VoidCallback? onPreviousImage;
  void Function(double brightness, double contrast)?
  onBrightnessContrastChanged;
  void Function(double scale)? onScaleChanged;
  void Function(Offset position, Size imageSize)? onImageTapped;

  /// Called with image-space positions while dragging; returns whether a
  /// measurement point is being dragged.
  bool Function(Offset position)? onMeasurementPointDragged;
  void Function(dynamic measurement, int pointIndex, Offset newPosition)?
  onPointDrag;

  // Brightness/contrast state with debouncing
  double _currentBrightness = 0.0;
  double _currentContrast = 1.0;
  // Removed debouncing for immediate brightness/contrast response

  // Enhanced navigation state - simplified and more reliable
  Timer? _navigationTimer;
  LogicalKeyboardKey? _activeKey;
  DateTime? _lastNavigationTime;
  static const Duration _navigationDelay = Duration(milliseconds: 150);
  static const Duration _navigationInterval = Duration(milliseconds: 120);
  static const Duration _navigationDebounce = Duration(milliseconds: 50);

  bool get isInteracting => _isRightClickDragging;
  double get zoom => _zoom;
  Offset get pan => _pan;

  /// Size of the input area and, when the image is centred inside it, the
  /// image's size, for zooming around the pointer and mapping positions.
  void setViewSize(Size size, {Size? content}) {
    _viewSize = size;
    _contentSize = content;
  }

  /// Converts a position in the view to the image's own coordinates, undoing
  /// zoom and pan, so taps and measurement points land on the same pixel at
  /// any zoom.
  Offset toImageSpace(Offset viewPosition) {
    final center = _viewSize.center(Offset.zero);
    final unzoomed = center + (viewPosition - center - _pan) / _zoom;
    final content = _contentSize;
    if (content == null) return unzoomed;
    // Relative to the image box centred in the area.
    return unzoomed - (center - content.center(Offset.zero));
  }

  /// Zooms to [newZoom], keeping the image point under [focus] (a view
  /// position) where it is.
  void zoomTo(double newZoom, {Offset? focus}) {
    if (!enableZoom) return;
    final clamped = newZoom.clamp(minZoom, maxZoom).toDouble();
    if (clamped == _zoom) return;
    final center = _viewSize.center(Offset.zero);
    final anchor = (focus ?? center) - center;
    _pan = anchor - (anchor - _pan) * (clamped / _zoom);
    _zoom = clamped;
    _clampPan();
    onScaleChanged?.call(_zoom);
    notifyListeners();
  }

  /// Moves the image by [delta] logical pixels.
  void panBy(Offset delta) {
    if (delta == Offset.zero) return;
    _pan += delta;
    _clampPan();
    notifyListeners();
  }

  /// Back to fit-to-view: zoom 100 %, centred.
  void resetView() {
    _zoom = 1.0;
    _pan = Offset.zero;
    onScaleChanged?.call(_zoom);
    notifyListeners();
  }

  @visibleForTesting
  void setZoomForTest(double zoom, {Offset pan = Offset.zero}) {
    _zoom = zoom;
    _pan = pan;
    notifyListeners();
  }

  /// Keeps at least part of the image on screen.
  void _clampPan() {
    final image = _contentSize ?? _viewSize;
    final limitX = image.width * _zoom / 2;
    final limitY = image.height * _zoom / 2;
    if (limitX <= 0 || limitY <= 0) return;
    _pan = Offset(
      _pan.dx.clamp(-limitX, limitX).toDouble(),
      _pan.dy.clamp(-limitY, limitY).toDouble(),
    );
  }

  static bool get _zoomModifierPressed =>
      HardwareKeyboard.instance.isControlPressed ||
      HardwareKeyboard.instance.isMetaPressed;
  dynamic get selectedMeasurement => _selectedMeasurement;
  int? get selectedPointIndex => _selectedPointIndex;

  @override
  void dispose() {
    _navigationTimer?.cancel();
    super.dispose();
  }

  /// Mouse wheel and other scroll signals: change slice, or zoom with
  /// Ctrl/Cmd held. Browsers send trackpad pinches as scale signals.
  void handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScaleEvent) {
      zoomTo(_zoom * event.scale, focus: event.localPosition);
      return;
    }
    if (event is! PointerScrollEvent) return;

    final delta = event.scrollDelta;
    if (_zoomModifierPressed) {
      zoomTo(_zoom * math.exp(-delta.dy / 300), focus: event.localPosition);
      return;
    }
    if (!enableScrollNavigation) return;

    final distance = delta.dy.abs() >= delta.dx.abs() ? delta.dy : delta.dx;
    if (distance == 0) return;
    // Start over when the direction changes.
    if (_wheelDistance.sign != distance.sign) _wheelDistance = 0;
    _wheelDistance += distance;
    // At most one slice per event, so one notch is one slice.
    if (_wheelDistance.abs() >= _wheelDistancePerSlice) {
      _wheelDistance > 0 ? onNextImage?.call() : onPreviousImage?.call();
      _wheelDistance = 0;
    }
  }

  /// Trackpad two-finger gestures (macOS, Windows precision touchpads):
  /// swiping changes slices, pinching zooms.
  void handlePanZoomStart(PointerPanZoomStartEvent event) {
    _gestureStartZoom = _zoom;
    _trackpadPinching = false;
    _trackpadDistance = 0;
  }

  void handlePanZoomUpdate(PointerPanZoomUpdateEvent event) {
    if (!_trackpadPinching && (event.scale - 1).abs() > 0.05 && enableZoom) {
      _trackpadPinching = true;
    }
    if (_trackpadPinching) {
      zoomTo(_gestureStartZoom * event.scale, focus: event.localPosition);
      return;
    }
    if (!enableScrollNavigation) return;

    // Fingers moving up scroll forward, like a mouse wheel turned down.
    _trackpadDistance -= event.panDelta.dy;
    while (_trackpadDistance.abs() >= _trackpadDistancePerSlice) {
      if (_trackpadDistance > 0) {
        onNextImage?.call();
        _trackpadDistance -= _trackpadDistancePerSlice;
      } else {
        onPreviousImage?.call();
        _trackpadDistance += _trackpadDistancePerSlice;
      }
    }
  }

  void handlePanZoomEnd(PointerPanZoomEndEvent event) {
    _trackpadPinching = false;
    _trackpadDistance = 0;
  }

  /// Handle keyboard events with enhanced debouncing and reliable navigation
  void handleKeyEvent(KeyEvent event) {
    if (!enableKeyboardNavigation) return;

    final key = event.logicalKey;
    final isNavigationKey =
        key == LogicalKeyboardKey.arrowLeft ||
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

  /// Right-drag or Shift+drag adjusts brightness/contrast; middle-drag pans.
  void handlePointerDown(PointerDownEvent event) {
    if (event.buttons == kMiddleMouseButton) {
      _isMiddleButtonPanning = true;
      _lastPanPosition = event.localPosition;
      return;
    }
    if (!enableBrightnessContrast) return;

    final shiftDrag =
        event.buttons == kPrimaryButton &&
        HardwareKeyboard.instance.isShiftPressed;
    if (event.buttons == kSecondaryMouseButton || shiftDrag) {
      _isRightClickDragging = true;
      _lastPanPosition = event.localPosition;
      notifyListeners();
    }
  }

  /// Handle pointer move events (during interactions)
  void handlePointerMove(PointerMoveEvent event) {
    if (_isMiddleButtonPanning && _lastPanPosition != null) {
      panBy(event.localPosition - _lastPanPosition!);
      _lastPanPosition = event.localPosition;
      return;
    }
    if (!enableBrightnessContrast || !_isRightClickDragging) return;

    if (_lastPanPosition != null) {
      final delta = event.localPosition - _lastPanPosition!;

      // Convert movement to brightness/contrast adjustments
      final brightnessChange = delta.dx * brightnessContrastSensitivity;
      final contrastChange =
          -delta.dy *
          brightnessContrastSensitivity; // Negative for intuitive up/down

      // Update internal state
      _currentBrightness += brightnessChange;
      _currentContrast += contrastChange;

      // Clamp values to reasonable ranges
      _currentBrightness = _currentBrightness.clamp(-1.0, 1.0);
      _currentContrast = _currentContrast.clamp(0.1, 3.0);

      // Call immediately for responsive adjustments
      if (onBrightnessContrastChanged != null) {
        onBrightnessContrastChanged!(_currentBrightness, _currentContrast);
      }

      _lastPanPosition = event.localPosition;
    }
  }

  /// Handle pointer up events (end of interactions)
  void handlePointerUp(PointerUpEvent event) {
    if (_isMiddleButtonPanning) {
      _isMiddleButtonPanning = false;
      _lastPanPosition = null;
    }
    if (_isRightClickDragging) {
      _isRightClickDragging = false;
      _lastPanPosition = null;
      notifyListeners();
    }
  }

  /// Handle tap events for measurements
  void handleTap(TapUpDetails details, Size imageSize) {
    if (!enableMeasurements) return;

    onImageTapped?.call(toImageSpace(details.localPosition), imageSize);
  }

  /// Mouse drags and touch gestures. One pointer moves a measurement point
  /// when the drag starts on one, otherwise pans; two fingers pinch-zoom and
  /// pan. Trackpads go through [handlePanZoomUpdate] instead.
  void handleScaleStart(ScaleStartDetails details) {
    _gestureStartZoom = _zoom;
    _dragMode = null;
  }

  void handleScaleUpdate(ScaleUpdateDetails details) {
    if (_isRightClickDragging || _isMiddleButtonPanning) return;

    if (details.pointerCount >= 2) {
      zoomTo(_gestureStartZoom * details.scale, focus: details.localFocalPoint);
      panBy(details.focalPointDelta);
      return;
    }

    // Decide on the first movement whether this drag moves a point or pans.
    if (_dragMode == null) {
      final grabbedPoint =
          enableMeasurements &&
          (onMeasurementPointDragged?.call(
                toImageSpace(details.localFocalPoint),
              ) ??
              false);
      _dragMode = grabbedPoint ? _DragMode.measurementPoint : _DragMode.pan;
      if (grabbedPoint) return;
    }
    if (_dragMode == _DragMode.measurementPoint) {
      onMeasurementPointDragged?.call(toImageSpace(details.localFocalPoint));
    } else {
      panBy(details.focalPointDelta);
    }
  }

  void handleScaleEnd(ScaleEndDetails details) {
    _dragMode = null;
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
    _isMiddleButtonPanning = false;
    _zoom = 1.0;
    _pan = Offset.zero;
    _wheelDistance = 0;
    _trackpadDistance = 0;
    _dragMode = null;
    _lastPanPosition = null;
    _currentBrightness = 0.0;
    _currentContrast = 1.0;

    // Reset navigation state
    _navigationTimer?.cancel();
    _navigationTimer = null;
    _activeKey = null;
    _lastNavigationTime = null;

    // Brightness/contrast state reset (no debouncing)

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
    // Immediately notify without debouncing
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
      enableScrollNavigation:
          enableScrollNavigation ?? this.enableScrollNavigation,
      enableKeyboardNavigation:
          enableKeyboardNavigation ?? this.enableKeyboardNavigation,
      enableBrightnessContrast:
          enableBrightnessContrast ?? this.enableBrightnessContrast,
      enableZoom: enableZoom ?? this.enableZoom,
      enableMeasurements: enableMeasurements ?? this.enableMeasurements,
      scrollThreshold: scrollThreshold ?? this.scrollThreshold,
      brightnessContrastSensitivity:
          brightnessContrastSensitivity ?? this.brightnessContrastSensitivity,
      zoomSensitivity: zoomSensitivity ?? this.zoomSensitivity,
    );
  }
}

enum _DragMode { measurementPoint, pan }
