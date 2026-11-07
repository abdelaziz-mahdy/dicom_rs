import 'dart:typed_data';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/measurement_entity.dart';
import '../controllers/image_interaction_controller.dart';
import 'measurement_overlay_widget.dart';

/// Clean image display widget with unified interaction handling
class ImageDisplayWidget extends StatefulWidget {
  const ImageDisplayWidget({
    super.key,
    required this.imageData,
    required this.scale,
    required this.measurements,
    required this.currentMeasurementPoints,
    this.selectedTool,
    this.measurementsVisible = true,
    required this.interactionController,
    this.isLoading = false,
    this.imageSize,
  });

  final Uint8List? imageData;
  final double scale;
  final List<MeasurementEntity> measurements;
  final List<MeasurementPoint> currentMeasurementPoints;
  final MeasurementType? selectedTool;
  final bool measurementsVisible;
  final ImageInteractionController interactionController;
  final bool isLoading;

  /// Size the image is shown at (its fitted size). When set, this widget
  /// fills its parent and centres the image, so input works over the whole
  /// area; positions reported to measurements are relative to the image.
  final Size? imageSize;

  @override
  State<ImageDisplayWidget> createState() => _ImageDisplayWidgetState();
}

class _ImageDisplayWidgetState extends State<ImageDisplayWidget> {
  final FocusNode _focusNode = FocusNode(
    skipTraversal: true, // Skip this widget in focus traversal
    canRequestFocus: true,
    descendantsAreFocusable: false, // Prevent children from stealing focus
  );

  @override
  void initState() {
    super.initState();
    // Request focus on first frame to ensure keyboard events work
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final interaction = widget.interactionController;
    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: interaction.handleKeyEvent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          interaction.setViewSize(
            constraints.biggest,
            content: widget.imageSize,
          );
          return Listener(
            // Clicking the image gives it keyboard focus for arrow-key navigation.
            onPointerDown: (event) {
              _focusNode.requestFocus();
              interaction.handlePointerDown(event);
            },
            onPointerSignal: interaction.handlePointerSignal,
            onPointerMove: interaction.handlePointerMove,
            onPointerUp: interaction.handlePointerUp,
            // Trackpad two-finger swipes and pinches.
            onPointerPanZoomStart: interaction.handlePanZoomStart,
            onPointerPanZoomUpdate: interaction.handlePanZoomUpdate,
            onPointerPanZoomEnd: interaction.handlePanZoomEnd,
            child: GestureDetector(
              // Trackpad gestures are handled above (swipe = slices), so the
              // pan/zoom recogniser here only sees mouse, touch and stylus.
              supportedDevices: const {
                PointerDeviceKind.mouse,
                PointerDeviceKind.touch,
                PointerDeviceKind.stylus,
                PointerDeviceKind.invertedStylus,
                PointerDeviceKind.unknown,
              },
              onTapUp:
                  (details) => interaction.handleTap(details, _getImageSize()),
              onScaleStart: interaction.handleScaleStart,
              onScaleUpdate: interaction.handleScaleUpdate,
              onScaleEnd: interaction.handleScaleEnd,
              // Zoom about the centre, then pan.
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.translationValues(
                  interaction.pan.dx,
                  interaction.pan.dy,
                  0,
                )..multiply(
                  Matrix4.diagonal3Values(
                    interaction.zoom,
                    interaction.zoom,
                    1,
                  ),
                ),
                child: _centred(
                  Stack(
                    alignment: Alignment.center,
                    // With an image, fill the box the viewer sized to the image's
                    // fitted size, so small images are enlarged too.
                    fit:
                        widget.imageData != null
                            ? StackFit.expand
                            : StackFit.loose,
                    children: [
                      // Main image
                      _buildImage(),

                      // Measurement overlays
                      if (widget.measurementsVisible)
                        Positioned.fill(
                          child: MeasurementOverlayWidget(
                            measurements: widget.measurements,
                            currentPoints: widget.currentMeasurementPoints,
                            selectedTool: widget.selectedTool,
                            scale: widget.scale,
                            onPointDrag:
                                widget.interactionController.onPointDrag,
                            selectedMeasurement:
                                widget
                                    .interactionController
                                    .selectedMeasurement,
                            selectedPointIndex:
                                widget.interactionController.selectedPointIndex,
                          ),
                        ),

                      // Interaction feedback
                      if (widget.interactionController.isInteracting)
                        const Positioned(
                          top: 10,
                          left: 10,
                          child: Icon(Icons.tune, color: Colors.cyan, size: 24),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// With [ImageDisplayWidget.imageSize], centres the image box in the area.
  Widget _centred(Widget image) {
    final size = widget.imageSize;
    if (size == null) return image;
    return Center(child: SizedBox.fromSize(size: size, child: image));
  }

  Widget _buildImage() {
    if (widget.imageData != null) {
      return Image.memory(
        widget.imageData!,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        fit: BoxFit.contain,
        isAntiAlias: true,
        errorBuilder: (context, error, stackTrace) => _buildErrorIndicator(),
      );
    }

    // OPTIMIZED: Show loading state during image processing, placeholder only when no images
    if (widget.isLoading) {
      return _buildLoadingIndicator();
    }

    return _buildPlaceholder();
  }

  Widget _buildErrorIndicator() {
    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 48),
          SizedBox(height: 16),
          Text(
            'Failed to load image',
            style: TextStyle(color: Colors.red, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.cyan),
            strokeWidth: 3,
          ),
          SizedBox(height: 16),
          Text(
            'Loading image...',
            style: TextStyle(color: Colors.cyan, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, color: Colors.cyan, size: 48),
          SizedBox(height: 16),
          Text(
            'No image loaded',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Size _getImageSize() {
    if (widget.imageSize != null) return widget.imageSize!;
    // Try to get actual image size from render box
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      return renderBox.size;
    }

    // Fallback to default size
    return const Size(300, 300);
  }
}
