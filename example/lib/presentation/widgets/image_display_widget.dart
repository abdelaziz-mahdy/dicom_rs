import 'dart:typed_data';
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
  });

  final Uint8List? imageData;
  final double scale;
  final List<MeasurementEntity> measurements;
  final List<MeasurementPoint> currentMeasurementPoints;
  final MeasurementType? selectedTool;
  final bool measurementsVisible;
  final ImageInteractionController interactionController;

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
    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: widget.interactionController.handleKeyEvent,
      child: Listener(
        onPointerSignal: widget.interactionController.handlePointerSignal,
        onPointerDown: widget.interactionController.handlePointerDown,
        onPointerMove: widget.interactionController.handlePointerMove,
        onPointerUp: widget.interactionController.handlePointerUp,
        child: GestureDetector(
          onTapUp:
              (details) => widget.interactionController.handleTap(
                details,
                _getImageSize(),
              ),
          onScaleStart: widget.interactionController.handleScaleStart,
          onScaleUpdate: widget.interactionController.handleScaleUpdate,
          onScaleEnd: widget.interactionController.handleScaleEnd,
          child: Transform.scale(
            scale: widget.scale,
            child: Stack(
              alignment: Alignment.center,
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
                      onPointDrag: widget.interactionController.onPointDrag,
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

    // Show placeholder only when no image data, not during loading
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
    // Try to get actual image size from render box
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      return renderBox.size;
    }

    // Fallback to default size
    return const Size(300, 300);
  }
}
