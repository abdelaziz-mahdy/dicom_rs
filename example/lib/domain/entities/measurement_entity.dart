import 'dart:ui';

/// Clean domain entity for measurements
class MeasurementEntity {
  const MeasurementEntity({
    required this.id,
    required this.type,
    required this.points,
    this.value,
    this.unit = 'px',
    this.color = const Color(0xFF00FFFF), // Cyan
    this.isSelected = false,
  });

  final String id;
  final MeasurementType type;
  final List<MeasurementPoint> points;
  final double? value;
  final String unit;
  final Color color;
  final bool isSelected;

  MeasurementEntity copyWith({
    String? id,
    MeasurementType? type,
    List<MeasurementPoint>? points,
    double? value,
    String? unit,
    Color? color,
    bool? isSelected,
  }) {
    return MeasurementEntity(
      id: id ?? this.id,
      type: type ?? this.type,
      points: points ?? this.points,
      value: value ?? this.value,
      unit: unit ?? this.unit,
      color: color ?? this.color,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeasurementEntity && other.id == id;

  /// Get calculated value with unit for display
  String get displayValue {
    if (value != null) {
      return '${value!.toStringAsFixed(1)} $unit';
    }
    
    // Calculate value based on measurement type
    final calculatedValue = _calculateValue();
    return '${calculatedValue.toStringAsFixed(1)} $unit';
  }

  double _calculateValue() {
    if (points.isEmpty) return 0.0;

    switch (type) {
      case MeasurementType.distance:
        if (points.length >= 2) {
          final p1 = points[0].toOffset();
          final p2 = points[1].toOffset();
          return (p2 - p1).distance;
        }
        return 0.0;

      case MeasurementType.angle:
        if (points.length >= 3) {
          final center = points[1].toOffset();
          final p1 = points[0].toOffset();
          final p2 = points[2].toOffset();
          
          final angle1 = (p1 - center).direction;
          final angle2 = (p2 - center).direction;
          final angleDiff = (angle2 - angle1).abs();
          
          return angleDiff * 180 / 3.14159; // Convert to degrees
        }
        return 0.0;

      case MeasurementType.circle:
        if (points.length >= 2) {
          final center = points[0].toOffset();
          final edge = points[1].toOffset();
          return (edge - center).distance; // Radius
        }
        return 0.0;

      case MeasurementType.area:
        if (points.length >= 3) {
          // Simple polygon area calculation using shoelace formula
          double area = 0.0;
          for (int i = 0; i < points.length; i++) {
            final j = (i + 1) % points.length;
            area += points[i].x * points[j].y;
            area -= points[j].x * points[i].y;
          }
          return area.abs() / 2.0;
        }
        return 0.0;
    }
  }

  @override
  int get hashCode => id.hashCode;
}

/// Measurement point with enhanced properties
class MeasurementPoint {
  const MeasurementPoint({
    required this.x,
    required this.y,
    this.isDraggable = true,
  });

  final double x;
  final double y;
  final bool isDraggable;

  MeasurementPoint copyWith({
    double? x,
    double? y,
    bool? isDraggable,
  }) {
    return MeasurementPoint(
      x: x ?? this.x,
      y: y ?? this.y,
      isDraggable: isDraggable ?? this.isDraggable,
    );
  }

  Offset toOffset() => Offset(x, y);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeasurementPoint && 
      other.x == x && 
      other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

/// Measurement types
enum MeasurementType {
  distance('Distance', 2),
  angle('Angle', 3),
  circle('Circle', 2),
  area('Area', 3);

  const MeasurementType(this.displayName, this.requiredPoints);
  
  final String displayName;
  final int requiredPoints;
}