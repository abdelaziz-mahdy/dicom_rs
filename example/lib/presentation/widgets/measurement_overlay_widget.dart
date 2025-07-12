import 'package:flutter/material.dart';
import '../../domain/entities/measurement_entity.dart';

/// Widget that renders measurement overlays on top of the image
class MeasurementOverlayWidget extends StatelessWidget {
  const MeasurementOverlayWidget({
    super.key,
    required this.measurements,
    required this.currentPoints,
    this.selectedTool,
    this.scale = 1.0,
    this.onPointDrag,
  });

  final List<MeasurementEntity> measurements;
  final List<MeasurementPoint> currentPoints;
  final MeasurementType? selectedTool;
  final double scale;
  final Function(MeasurementEntity measurement, int pointIndex, Offset newPosition)? onPointDrag;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Draw lines, shapes, and labels
        CustomPaint(
          painter: MeasurementPainter(
            measurements: measurements,
            currentPoints: currentPoints,
            selectedTool: selectedTool,
          ),
          child: Container(),
        ),
        
        // Interactive points overlay
        ...measurements.map((measurement) => 
          _buildMeasurementPoints(measurement)),
        
        // Current measurement points
        ..._buildCurrentPoints(),
      ],
    );
  }

  Widget _buildMeasurementPoints(MeasurementEntity measurement) {
    return Stack(
      children: measurement.points.asMap().entries.map((entry) {
        final index = entry.key;
        final point = entry.value;
        
        return Positioned(
          left: point.x - (12 / scale), // Compensate for scale
          top: point.y - (12 / scale),
          child: GestureDetector(
            onPanUpdate: (details) {
              if (onPointDrag != null) {
                final newPosition = Offset(
                  point.x + (details.delta.dx / scale), // Scale compensation
                  point.y + (details.delta.dy / scale),
                );
                onPointDrag!(measurement, index, newPosition);
              }
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.move,
              child: Container(
                width: 24 / scale, // Scale-adjusted size
                height: 24 / scale,
                decoration: BoxDecoration(
                  color: Colors.cyan.withValues(alpha: 0.8),
                  border: Border.all(color: Colors.white, width: 2 / scale),
                  borderRadius: BorderRadius.circular(12 / scale),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4 / scale,
                      offset: Offset(0, 2 / scale),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.drag_indicator,
                  size: 12 / scale,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  List<Widget> _buildCurrentPoints() {
    return currentPoints.asMap().entries.map((entry) {
      final point = entry.value;
      
      return Positioned(
        left: point.x - (10 / scale),
        top: point.y - (10 / scale),
        child: Container(
          width: 20 / scale,
          height: 20 / scale,
          decoration: BoxDecoration(
            color: Colors.yellow.withValues(alpha: 0.8),
            border: Border.all(color: Colors.white, width: 2 / scale),
            borderRadius: BorderRadius.circular(10 / scale),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 4 / scale,
                offset: Offset(0, 2 / scale),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}

/// Custom painter for rendering measurements
class MeasurementPainter extends CustomPainter {
  const MeasurementPainter({
    required this.measurements,
    required this.currentPoints,
    this.selectedTool,
  });

  final List<MeasurementEntity> measurements;
  final List<MeasurementPoint> currentPoints;
  final MeasurementType? selectedTool;

  @override
  void paint(Canvas canvas, Size size) {
    // Paint completed measurements
    for (final measurement in measurements) {
      _paintMeasurement(canvas, measurement, false);
    }

    // Paint current measurement in progress
    if (currentPoints.isNotEmpty && selectedTool != null) {
      _paintCurrentMeasurement(canvas, currentPoints, selectedTool!);
    }
  }

  void _paintMeasurement(Canvas canvas, MeasurementEntity measurement, bool isActive) {
    final paint = Paint()
      ..color = isActive ? Colors.cyan : Colors.cyan.withValues(alpha: 0.8)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final points = measurement.points;
    if (points.isEmpty) return;

    switch (measurement.type) {
      case MeasurementType.distance:
        _paintDistance(canvas, points, paint);
        break;
      case MeasurementType.angle:
        _paintAngle(canvas, points, paint);
        break;
      case MeasurementType.circle:
        _paintCircle(canvas, points, paint);
        break;
      case MeasurementType.area:
        _paintArea(canvas, points, paint);
        break;
    }

    // Paint measurement points
    _paintPoints(canvas, points, paint);

    // Paint measurement label
    _paintLabel(canvas, measurement);
  }

  void _paintCurrentMeasurement(Canvas canvas, List<MeasurementPoint> points, MeasurementType type) {
    final paint = Paint()
      ..color = Colors.yellow
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    if (points.isEmpty) return;

    switch (type) {
      case MeasurementType.distance:
        if (points.length >= 1) {
          _paintDistance(canvas, points, paint);
        }
        break;
      case MeasurementType.angle:
        if (points.length >= 2) {
          _paintAngle(canvas, points, paint);
        }
        break;
      case MeasurementType.circle:
        if (points.length >= 2) {
          _paintCircle(canvas, points, paint);
        }
        break;
      case MeasurementType.area:
        if (points.length >= 2) {
          _paintArea(canvas, points, paint);
        }
        break;
    }

    // Paint current points
    _paintPoints(canvas, points, paint);
  }

  void _paintDistance(Canvas canvas, List<MeasurementPoint> points, Paint paint) {
    if (points.length < 2) return;

    final start = Offset(points[0].x, points[0].y);
    final end = Offset(points[1].x, points[1].y);

    canvas.drawLine(start, end, paint);
  }

  void _paintAngle(Canvas canvas, List<MeasurementPoint> points, Paint paint) {
    if (points.length < 3) return;

    final center = Offset(points[1].x, points[1].y);
    final start = Offset(points[0].x, points[0].y);
    final end = Offset(points[2].x, points[2].y);

    // Draw lines
    canvas.drawLine(center, start, paint);
    canvas.drawLine(center, end, paint);

    // Draw angle arc
    final radius = 30.0;
    final startAngle = (start - center).direction;
    final endAngle = (end - center).direction;
    final sweepAngle = endAngle - startAngle;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  void _paintCircle(Canvas canvas, List<MeasurementPoint> points, Paint paint) {
    if (points.length < 2) return;

    final center = Offset(points[0].x, points[0].y);
    final edge = Offset(points[1].x, points[1].y);
    final radius = (edge - center).distance;

    canvas.drawCircle(center, radius, paint);
  }

  void _paintArea(Canvas canvas, List<MeasurementPoint> points, Paint paint) {
    if (points.length < 3) return;

    final path = Path();
    path.moveTo(points[0].x, points[0].y);

    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].x, points[i].y);
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  void _paintPoints(Canvas canvas, List<MeasurementPoint> points, Paint paint) {
    final pointPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;

    for (final point in points) {
      canvas.drawCircle(
        Offset(point.x, point.y),
        4.0,
        pointPaint,
      );
    }
  }

  void _paintLabel(Canvas canvas, MeasurementEntity measurement) {
    if (measurement.points.isEmpty) return;

    final center = measurement.points.fold<Offset>(
      Offset.zero,
      (sum, point) => sum + Offset(point.x, point.y),
    ) / measurement.points.length.toDouble();

    final textPainter = TextPainter(
      text: TextSpan(
        text: measurement.displayValue,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              offset: Offset(1, 1),
              blurRadius: 2,
              color: Colors.black,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    
    final labelOffset = center - Offset(
      textPainter.width / 2,
      textPainter.height / 2,
    );
    
    textPainter.paint(canvas, labelOffset);
  }

  @override
  bool shouldRepaint(covariant MeasurementPainter oldDelegate) {
    return measurements != oldDelegate.measurements ||
           currentPoints != oldDelegate.currentPoints ||
           selectedTool != oldDelegate.selectedTool;
  }
}
