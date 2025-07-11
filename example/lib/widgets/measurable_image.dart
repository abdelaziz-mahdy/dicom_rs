import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../models/measurement_models.dart';
import 'measurement_overlay.dart';

/// A widget that combines image display with measurement capabilities
/// Handles all click events and rendering in one place
class MeasurableImage extends StatefulWidget {
  final Uint8List? imageData;
  final double scale;
  final MeasurementType? selectedTool;
  final List<DicomMeasurement> measurements;
  final List<MeasurementPoint> currentPoints;
  final bool measurementsVisible;
  final List<double>? pixelSpacing;
  final String units;
  final Function(Offset, Size) onImageTap;
  final Function(String) onMeasurementDelete;
  final Function(PointerSignalEvent)? onPointerSignal;
  final Function(ScaleStartDetails)? onScaleStart;
  final Function(ScaleUpdateDetails)? onScaleUpdate;
  final Function(ScaleEndDetails)? onScaleEnd;

  const MeasurableImage({
    super.key,
    required this.imageData,
    required this.scale,
    this.selectedTool,
    required this.measurements,
    required this.currentPoints,
    required this.measurementsVisible,
    this.pixelSpacing,
    this.units = 'mm',
    required this.onImageTap,
    required this.onMeasurementDelete,
    this.onPointerSignal,
    this.onScaleStart,
    this.onScaleUpdate,
    this.onScaleEnd,
  });

  @override
  State<MeasurableImage> createState() => _MeasurableImageState();
}

class _MeasurableImageState extends State<MeasurableImage> {
  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: widget.onPointerSignal,
      child: GestureDetector(
        onTapUp: _handleTapUp,
        onScaleStart: widget.onScaleStart,
        onScaleUpdate: widget.onScaleUpdate,
        onScaleEnd: widget.onScaleEnd,
        child: Transform.scale(
          scale: widget.scale,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // The image itself
              _buildImage(),

              // Measurement overlay
              if (widget.measurementsVisible)
                Positioned.fill(
                  child: MeasurementOverlay(
                    measurements: widget.measurements,
                    pixelSpacing: widget.pixelSpacing,
                    units: widget.units,
                    visible: widget.measurementsVisible,
                    onMeasurementDelete: widget.onMeasurementDelete,
                  ),
                ),

              // Current measurement preview
              if (widget.selectedTool != null && widget.currentPoints.isNotEmpty)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _MeasurementPreviewPainter(
                      points: widget.currentPoints,
                      tool: widget.selectedTool!,
                    ),
                  ),
                ),
            ],
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
      );
    } else {
      return const Text('No image loaded');
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.selectedTool != null) {
      // Get the render box of the image widget to calculate correct coordinates
      final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final localPosition = renderBox.globalToLocal(details.globalPosition);
        widget.onImageTap(localPosition, renderBox.size);
      }
    }
  }
}

/// Custom painter for measurement preview while creating
class _MeasurementPreviewPainter extends CustomPainter {
  final List<MeasurementPoint> points;
  final MeasurementType tool;

  _MeasurementPreviewPainter({required this.points, required this.tool});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.7)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Draw existing points
    for (final point in points) {
      canvas.drawCircle(
        Offset(point.x, point.y),
        4,
        paint..style = PaintingStyle.fill,
      );
    }

    paint.style = PaintingStyle.stroke;

    // Draw preview lines based on tool type
    if (points.length >= 2) {
      switch (tool) {
        case MeasurementType.distance:
          canvas.drawLine(
            Offset(points[0].x, points[0].y),
            Offset(points[1].x, points[1].y),
            paint,
          );
          break;
        case MeasurementType.angle:
          if (points.length >= 2) {
            canvas.drawLine(
              Offset(points[0].x, points[0].y),
              Offset(points[1].x, points[1].y),
              paint,
            );
          }
          if (points.length >= 3) {
            canvas.drawLine(
              Offset(points[0].x, points[0].y),
              Offset(points[2].x, points[2].y),
              paint,
            );
          }
          break;
        case MeasurementType.circle:
          final center = Offset(points[0].x, points[0].y);
          final edge = Offset(points[1].x, points[1].y);
          final radius = (edge - center).distance;
          canvas.drawCircle(center, radius, paint);
          break;
        case MeasurementType.area:
          final path = Path();
          path.moveTo(points[0].x, points[0].y);
          for (int i = 1; i < points.length; i++) {
            path.lineTo(points[i].x, points[i].y);
          }
          canvas.drawPath(path, paint);
          break;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MeasurementPreviewPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.tool != tool;
  }
}