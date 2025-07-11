import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../models/measurement_models.dart';

/// Mixin that provides unified gesture handling for DICOM viewers
/// Handles both measurement creation and image interaction (pan/zoom/scroll)
mixin GestureHandlingMixin<T extends StatefulWidget> on State<T> {
  // Abstract methods that implementing widgets must provide
  MeasurementType? get selectedMeasurementTool;
  double get currentScale;
  bool handleMeasurementTap(Offset position, Size size);
  void handleScaleUpdate(ScaleUpdateDetails details);
  void handleScaleEnd(ScaleEndDetails details);
  void handlePointerDown(PointerDownEvent event);
  void handlePointerMove(PointerMoveEvent event);
  void handlePointerUp(PointerUpEvent event);
  void nextSlice();
  void previousSlice();

  /// Main tap handler - decides between measurement creation and normal interaction
  void handleUnifiedTap(TapUpDetails details) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);

    if (selectedMeasurementTool != null) {
      // Measurement mode - create measurement points
      _handleMeasurementTap(localPosition, renderBox.size);
    } else {
      // Normal mode - could handle other tap interactions here if needed
      _handleNormalTap(localPosition, renderBox.size);
    }
  }

  /// Handle scale gestures (pinch to zoom)
  void handleUnifiedScaleUpdate(ScaleUpdateDetails details) {
    if (selectedMeasurementTool == null) {
      // Only allow zoom/pan when not creating measurements
      handleScaleUpdate(details);
    }
  }

  void handleUnifiedScaleEnd(ScaleEndDetails details) {
    if (selectedMeasurementTool == null) {
      handleScaleEnd(details);
    }
  }

  /// Handle pointer events for drag gestures
  void handleUnifiedPointerDown(PointerDownEvent event) {
    if (selectedMeasurementTool == null) {
      handlePointerDown(event);
    }
  }

  void handleUnifiedPointerMove(PointerMoveEvent event) {
    if (selectedMeasurementTool == null) {
      handlePointerMove(event);
    }
  }

  void handleUnifiedPointerUp(PointerUpEvent event) {
    if (selectedMeasurementTool == null) {
      handlePointerUp(event);
    }
  }

  /// Handle scroll events for slice navigation
  void handleUnifiedScroll(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final scrollDelta = event.scrollDelta;
      final threshold = 10.0; // Minimum scroll distance to trigger slice change

      // Check if this is a significant scroll gesture
      if (scrollDelta.dy.abs() > threshold ||
          scrollDelta.dx.abs() > threshold) {
        final deltaY = scrollDelta.dy;
        final deltaX = scrollDelta.dx;

        if (deltaY.abs() > deltaX.abs()) {
          // Vertical scroll
          if (deltaY > 0) {
            nextSlice();
          } else {
            previousSlice();
          }
        } else {
          // Horizontal scroll (for trackpad gestures)
          if (deltaX > 0) {
            nextSlice();
          } else {
            previousSlice();
          }
        }
      }
    }
  }

  /// Private method to handle measurement creation
  void _handleMeasurementTap(Offset localPosition, Size containerSize) {
    // Delegate to the measurement handling system
    handleMeasurementTap(localPosition, containerSize);
  }

  /// Private method to handle normal taps (when no measurement tool selected)
  void _handleNormalTap(Offset localPosition, Size containerSize) {
    // Currently no special handling for normal taps
    // Could be extended for other features like region selection, etc.
  }

  /// Create the unified gesture detector widget
  Widget buildUnifiedGestureDetector({required Widget child}) {
    return Listener(
      onPointerSignal: handleUnifiedScroll,
      onPointerDown: handleUnifiedPointerDown,
      onPointerMove: handleUnifiedPointerMove,
      onPointerUp: handleUnifiedPointerUp,
      child: GestureDetector(
        onTapUp: handleUnifiedTap,
        onScaleUpdate: handleUnifiedScaleUpdate,
        onScaleEnd: handleUnifiedScaleEnd,
        child: child,
      ),
    );
  }
}
