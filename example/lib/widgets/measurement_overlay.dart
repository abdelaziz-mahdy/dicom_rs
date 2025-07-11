import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/measurement_models.dart';

/// Widget that displays measurement annotations over the DICOM image
class MeasurementOverlay extends StatelessWidget {
  final List<DicomMeasurement> measurements;
  final List<double>? pixelSpacing;
  final String units;
  final bool visible;
  final Function(String)? onMeasurementTap;
  final Function(String)? onMeasurementDelete;

  const MeasurementOverlay({
    super.key,
    required this.measurements,
    this.pixelSpacing,
    this.units = 'mm',
    this.visible = true,
    this.onMeasurementTap,
    this.onMeasurementDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible || measurements.isEmpty) {
      return const SizedBox.shrink();
    }

    return CustomPaint(
      painter: MeasurementPainter(
        measurements: measurements,
        pixelSpacing: pixelSpacing,
        units: units,
      ),
      child: Stack(
        children: measurements.map((measurement) {
          return _buildMeasurementInteraction(context, measurement);
        }).toList(),
      ),
    );
  }

  Widget _buildMeasurementInteraction(BuildContext context, DicomMeasurement measurement) {
    if (measurement.points.isEmpty) return const SizedBox.shrink();

    // Calculate the center point for interaction
    final centerX = measurement.points.map((p) => p.x).reduce((a, b) => a + b) / measurement.points.length;
    final centerY = measurement.points.map((p) => p.y).reduce((a, b) => a + b) / measurement.points.length;

    return Positioned(
      left: centerX - 20,
      top: centerY - 20,
      child: GestureDetector(
        onTap: () => onMeasurementTap?.call(measurement.id),
        onLongPress: () => _showMeasurementOptions(context, measurement),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.yellow.withOpacity(0.3), width: 1),
          ),
          child: const Icon(
            Icons.touch_app,
            color: Colors.yellow,
            size: 16,
          ),
        ),
      ),
    );
  }

  void _showMeasurementOptions(BuildContext context, DicomMeasurement measurement) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(measurement.label),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${measurement.type.name}'),
            Text('Points: ${measurement.points.length}'),
            Text('Created: ${measurement.createdAt.toString().split('.')[0]}'),
            const SizedBox(height: 8),
            Text(
              'Value: ${measurement.calculateValue(pixelSpacing: pixelSpacing, units: units).displayText}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (onMeasurementDelete != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onMeasurementDelete!(measurement.id);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
        ],
      ),
    );
  }
}

/// Custom painter for drawing measurement annotations
class MeasurementPainter extends CustomPainter {
  final List<DicomMeasurement> measurements;
  final List<double>? pixelSpacing;
  final String units;

  MeasurementPainter({
    required this.measurements,
    this.pixelSpacing,
    this.units = 'mm',
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final measurement in measurements) {
      _drawMeasurement(canvas, measurement);
    }
  }

  void _drawMeasurement(Canvas canvas, DicomMeasurement measurement) {
    final paint = Paint()
      ..color = Colors.yellow
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final textPaint = Paint()
      ..color = Colors.yellow
      ..style = PaintingStyle.fill;

    switch (measurement.type) {
      case MeasurementType.distance:
        _drawDistanceMeasurement(canvas, measurement, paint, textPaint);
        break;
      case MeasurementType.angle:
        _drawAngleMeasurement(canvas, measurement, paint, textPaint);
        break;
      case MeasurementType.circle:
        _drawCircleMeasurement(canvas, measurement, paint, textPaint);
        break;
      case MeasurementType.area:
        _drawAreaMeasurement(canvas, measurement, paint, textPaint);
        break;
    }
  }

  void _drawDistanceMeasurement(Canvas canvas, DicomMeasurement measurement, Paint paint, Paint textPaint) {
    if (measurement.points.length != 2) return;

    final start = Offset(measurement.points[0].x, measurement.points[0].y);
    final end = Offset(measurement.points[1].x, measurement.points[1].y);

    // Draw line
    canvas.drawLine(start, end, paint);

    // Draw endpoints
    canvas.drawCircle(start, 4, paint..style = PaintingStyle.fill);
    canvas.drawCircle(end, 4, paint..style = PaintingStyle.fill);
    paint.style = PaintingStyle.stroke;

    // Draw measurement text
    final result = measurement.calculateValue(pixelSpacing: pixelSpacing, units: units);
    _drawMeasurementText(canvas, result.displayText, _getMidpoint(start, end));
  }

  void _drawAngleMeasurement(Canvas canvas, DicomMeasurement measurement, Paint paint, Paint textPaint) {
    if (measurement.points.length != 3) return;

    final vertex = Offset(measurement.points[0].x, measurement.points[0].y);
    final point1 = Offset(measurement.points[1].x, measurement.points[1].y);
    final point2 = Offset(measurement.points[2].x, measurement.points[2].y);

    // Draw lines from vertex to both points
    canvas.drawLine(vertex, point1, paint);
    canvas.drawLine(vertex, point2, paint);

    // Draw points
    canvas.drawCircle(vertex, 4, paint..style = PaintingStyle.fill);
    canvas.drawCircle(point1, 3, paint);
    canvas.drawCircle(point2, 3, paint);
    paint.style = PaintingStyle.stroke;

    // Draw arc to show angle
    final radius = 30.0;
    final angle1 = math.atan2(point1.dy - vertex.dy, point1.dx - vertex.dx);
    final angle2 = math.atan2(point2.dy - vertex.dy, point2.dx - vertex.dx);
    
    canvas.drawArc(
      Rect.fromCircle(center: vertex, radius: radius),
      angle1,
      angle2 - angle1,
      false,
      paint,
    );

    // Draw measurement text
    final result = measurement.calculateValue(pixelSpacing: pixelSpacing, units: units);
    _drawMeasurementText(canvas, result.displayText, vertex + Offset(radius + 10, -10));
  }

  void _drawCircleMeasurement(Canvas canvas, DicomMeasurement measurement, Paint paint, Paint textPaint) {
    if (measurement.points.length != 2) return;

    final center = Offset(measurement.points[0].x, measurement.points[0].y);
    final edge = Offset(measurement.points[1].x, measurement.points[1].y);
    final radius = (edge - center).distance;

    // Draw circle
    canvas.drawCircle(center, radius, paint);

    // Draw center point
    canvas.drawCircle(center, 4, paint..style = PaintingStyle.fill);
    
    // Draw radius line
    canvas.drawLine(center, edge, paint);
    canvas.drawCircle(edge, 3, paint);
    paint.style = PaintingStyle.stroke;

    // Draw measurement text
    final result = measurement.calculateValue(pixelSpacing: pixelSpacing, units: units);
    _drawMeasurementText(canvas, result.displayText, center + Offset(radius + 10, -10));
  }

  void _drawAreaMeasurement(Canvas canvas, DicomMeasurement measurement, Paint paint, Paint textPaint) {
    // Area measurement would be more complex - for now just draw the points
    if (measurement.points.length < 3) return;

    final path = Path();
    path.moveTo(measurement.points[0].x, measurement.points[0].y);
    
    for (int i = 1; i < measurement.points.length; i++) {
      path.lineTo(measurement.points[i].x, measurement.points[i].y);
    }
    path.close();

    canvas.drawPath(path, paint);

    // Draw vertices
    for (final point in measurement.points) {
      canvas.drawCircle(Offset(point.x, point.y), 3, paint..style = PaintingStyle.fill);
    }
    paint.style = PaintingStyle.stroke;
  }

  void _drawMeasurementText(Canvas canvas, String text, Offset position) {
    final textSpan = TextSpan(
      text: text,
      style: const TextStyle(
        color: Colors.yellow,
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
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    // Draw background
    final backgroundRect = Rect.fromLTWH(
      position.dx - 2,
      position.dy - 2,
      textPainter.width + 4,
      textPainter.height + 4,
    );

    canvas.drawRect(
      backgroundRect,
      Paint()
        ..color = Colors.black.withOpacity(0.7)
        ..style = PaintingStyle.fill,
    );

    textPainter.paint(canvas, position);
  }

  Offset _getMidpoint(Offset start, Offset end) {
    return Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
  }

  @override
  bool shouldRepaint(covariant MeasurementPainter oldDelegate) {
    return oldDelegate.measurements != measurements ||
           oldDelegate.pixelSpacing != pixelSpacing ||
           oldDelegate.units != units;
  }
}