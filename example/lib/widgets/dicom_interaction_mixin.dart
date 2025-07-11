import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:opencv_core/opencv.dart';

/// A mixin that provides DICOM image interaction capabilities
/// including brightness/contrast adjustments via gesture detection
mixin DicomInteractionMixin<T extends StatefulWidget> on State<T> {
  // Brightness and contrast settings
  double contrast = 1.0; // Default contrast (1.0 = no change)
  double brightness = 0.0; // Default brightness (0.0 = no change)

  // Scale/zoom settings
  double scale = 1.0;

  // Track last position for relative calculations
  Offset? _lastFocalPoint;

  // For determining interaction mode
  bool _isDragging = false;

  // Debounce timer for image updates
  Timer? _debounceTimer;

  // Debounce duration - adjust as needed
  final Duration _debounceDuration = const Duration(milliseconds: 30);

  /// Process a pointer down event to start interaction
  void handlePointerDown(PointerDownEvent event) {
    _lastFocalPoint = event.localPosition;
    _isDragging = true;
  }

  /// Handle scale start event to begin interaction
  void handleScaleStart(ScaleStartDetails details) {
    _lastFocalPoint = details.focalPoint;
    _isDragging = true;
  }

  /// Process a pointer move event to update brightness/contrast
  void handlePointerMove(PointerMoveEvent event) {
    if (!_isDragging || _lastFocalPoint == null) return;

    final currentPoint = event.localPosition;
    final deltaX = currentPoint.dx - _lastFocalPoint!.dx;
    final deltaY = _lastFocalPoint!.dy - currentPoint.dy;

    // Store previous values to check if they changed
    final previousContrast = contrast;
    final previousBrightness = brightness;

    // Apply sensitivity factors
    final contrastFactor = 0.01; // Adjust for sensitivity
    final brightnessFactor = 0.5; // Adjust for sensitivity

    // Update brightness/contrast based on horizontal/vertical movement
    setState(() {
      // Horizontal movement: adjust contrast
      contrast += deltaX * contrastFactor;
      if (contrast < 0.1) contrast = 0.1; // Minimum contrast
      if (contrast > 3.0) contrast = 3.0; // Maximum contrast

      // Vertical movement: adjust brightness
      brightness += deltaY * brightnessFactor;
      if (brightness < -100.0) brightness = -100.0; // Minimum brightness
      if (brightness > 100.0) brightness = 100.0; // Maximum brightness
    });

    // Update the last focal point
    _lastFocalPoint = currentPoint;

    // If values changed, trigger debounced update
    if (previousContrast != contrast || previousBrightness != brightness) {
      _triggerDebouncedUpdate();
      updateProcessedImage();
    }
  }

  /// Trigger a debounced update to the processed image
  void _triggerDebouncedUpdate() {
    // Cancel previous timer if it exists
    _debounceTimer?.cancel();

    // Start a new timer
    _debounceTimer = Timer(_debounceDuration, () {
      if (mounted) {
        updateProcessedImage();
      }
    });
  }

  /// This method should be implemented in classes using this mixin
  /// to update the processed image with current brightness/contrast
  void updateProcessedImage();

  /// Process a pointer up event to end interaction
  void handlePointerUp(PointerUpEvent event) {
    if (_isDragging) {
      _isDragging = false;
      _lastFocalPoint = null;

      // Immediately apply the final adjustment
      _debounceTimer?.cancel();
      updateProcessedImage();
    }
  }

  /// Handle a scale gesture for zooming and brightness/contrast
  void handleScaleUpdate(ScaleUpdateDetails details) {
    // If it's a pinch gesture (scale != 1.0), handle zoom
    if (details.scale != 1.0) {
      setState(() {
        // Apply zoom/scale
        scale *= details.scale;

        // Constrain scale to reasonable values
        if (scale < 0.5) scale = 0.5;
        if (scale > 5.0) scale = 5.0;
      });
    } else if (_isDragging && _lastFocalPoint != null) {
      // Single finger drag - adjust brightness/contrast
      final currentPoint = details.focalPoint;
      final deltaX = currentPoint.dx - _lastFocalPoint!.dx;
      final deltaY = _lastFocalPoint!.dy - currentPoint.dy;

      // Store previous values to check if they changed
      final previousContrast = contrast;
      final previousBrightness = brightness;

      // Apply sensitivity factors
      final contrastFactor = 0.01; // Adjust for sensitivity
      final brightnessFactor = 0.5; // Adjust for sensitivity

      // Update brightness/contrast based on horizontal/vertical movement
      setState(() {
        // Horizontal movement: adjust contrast
        contrast += deltaX * contrastFactor;
        if (contrast < 0.1) contrast = 0.1; // Minimum contrast
        if (contrast > 3.0) contrast = 3.0; // Maximum contrast

        // Vertical movement: adjust brightness
        brightness += deltaY * brightnessFactor;
        if (brightness < -100.0) brightness = -100.0; // Minimum brightness
        if (brightness > 100.0) brightness = 100.0; // Maximum brightness
      });

      // Update the last focal point
      _lastFocalPoint = currentPoint;

      // If values changed, trigger debounced update
      if (previousContrast != contrast || previousBrightness != brightness) {
        _triggerDebouncedUpdate();
      }
    }
  }

  /// Handle end of scale gesture
  void handleScaleEnd(ScaleEndDetails details) {
    if (_isDragging) {
      _isDragging = false;
      _lastFocalPoint = null;

      // Immediately apply the final adjustment
      _debounceTimer?.cancel();
      updateProcessedImage();
    }
  }

  /// Apply brightness and contrast adjustments to an image
  /// Uses OpenCV Core for image processing
  Future<Uint8List?> applyBrightnessContrast(Uint8List? original) async {
    if (original == null) return null;

    // If no adjustment needed, return original
    if (contrast == 1.0 && brightness == 0.0) {
      return original;
    }

    try {
      // Use OpenCV to adjust brightness and contrast
      final Mat imageMat = await imdecodeAsync(original, IMREAD_UNCHANGED);

      // Apply brightness and contrast using OpenCV formula:
      // new_pixel = contrast * original_pixel + brightness
      // await convertScaleAbsAsync(
      //   imageMat,
      //   dst: imageMat,
      //   alpha: contrast,
      //   beta: brightness,
      // );
      double newBrightness = brightness + (255 * (1 - contrast) / 2);

      // """
      // Adjusts contrast and brightness of an uint8 image.
      // contrast:   (0.0,  inf) with 1.0 leaving the contrast as is
      // brightness: [-255, 255] with 0 leaving the brightness as is
      // """
      await addWeightedAsync(
        imageMat,
        contrast,
        imageMat,
        0,
        newBrightness,
        dst: imageMat,
      );
      // Convert back to bytes
      final Uint8List processedBytes =
          (await imencodeAsync('.png', imageMat)).$2;

      return processedBytes;
    } catch (e) {
      print('Error processing image: $e');
      return original; // Return original on error
    }
  }

  /// Reset brightness and contrast to default values
  void resetImageAdjustments() {
    setState(() {
      contrast = 1.0;
      brightness = 0.0;
      scale = 1.0;
    });

    // Immediately update the image after reset
    updateProcessedImage();
  }

  /// Get the current brightness and contrast settings as a formatted string
  String getAdjustmentText() {
    return 'Contrast: ${contrast.toStringAsFixed(2)} Brightness: ${brightness.toStringAsFixed(1)}';
  }

  /// Clean up resources when the state is disposed
  void disposeInteractionResources() {
    _debounceTimer?.cancel();
  }
}
