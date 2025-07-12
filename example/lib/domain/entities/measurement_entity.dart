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
    this.pixelSpacing,
    this.imageScale = 1.0,
  });

  final String id;
  final MeasurementType type;
  final List<MeasurementPoint> points;
  final double? value;
  final String unit;
  final Color color;
  final bool isSelected;
  final List<double>? pixelSpacing; // DICOM pixel spacing [row, column] in mm/pixel
  final double imageScale; // Current image scale factor

  MeasurementEntity copyWith({
    String? id,
    MeasurementType? type,
    List<MeasurementPoint>? points,
    double? value,
    String? unit,
    Color? color,
    bool? isSelected,
    List<double>? pixelSpacing,
    double? imageScale,
  }) {
    return MeasurementEntity(
      id: id ?? this.id,
      type: type ?? this.type,
      points: points ?? this.points,
      value: value ?? this.value,
      unit: unit ?? this.unit,
      color: color ?? this.color,
      isSelected: isSelected ?? this.isSelected,
      pixelSpacing: pixelSpacing ?? this.pixelSpacing,
      imageScale: imageScale ?? this.imageScale,
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
    final actualUnit = _getActualUnit();
    return '${calculatedValue.toStringAsFixed(1)} $actualUnit';
  }

  /// Get the actual unit based on pixel spacing availability
  String _getActualUnit() {
    if (pixelSpacing != null && pixelSpacing!.isNotEmpty) {
      switch (type) {
        case MeasurementType.distance:
        case MeasurementType.circle:
          return 'mm';
        case MeasurementType.area:
          return 'mm²';
        case MeasurementType.angle:
          return '°';
      }
    }
    return unit; // Fallback to original unit (px)
  }

  double _calculateValue() {
    if (points.isEmpty) return 0.0;

    switch (type) {
      case MeasurementType.distance:
        if (points.length >= 2) {
          final p1 = points[0].toOffset();
          final p2 = points[1].toOffset();
          final pixelDistance = (p2 - p1).distance;
          return _convertToRealWorldUnits(pixelDistance);
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
          
          return angleDiff * 180 / 3.14159; // Convert to degrees (no scaling needed)
        }
        return 0.0;

      case MeasurementType.circle:
        if (points.length >= 2) {
          final center = points[0].toOffset();
          final edge = points[1].toOffset();
          final pixelRadius = (edge - center).distance;
          return _convertToRealWorldUnits(pixelRadius); // Radius
        }
        return 0.0;

      case MeasurementType.area:
        if (points.length >= 3) {
          // Simple polygon area calculation using shoelace formula
          double pixelArea = 0.0;
          for (int i = 0; i < points.length; i++) {
            final j = (i + 1) % points.length;
            pixelArea += points[i].x * points[j].y;
            pixelArea -= points[j].x * points[i].y;
          }
          pixelArea = pixelArea.abs() / 2.0;
          return _convertAreaToRealWorldUnits(pixelArea);
        }
        return 0.0;
    }
  }

  /// Convert pixel distance to real-world units (mm) using DICOM pixel spacing
  double _convertToRealWorldUnits(double pixelDistance) {
    if (pixelSpacing == null || pixelSpacing!.isEmpty) {
      return pixelDistance; // Return pixel value if no spacing info
    }
    
    // Use average of row and column spacing for distance calculations
    final avgSpacing = (pixelSpacing![0] + (pixelSpacing!.length > 1 ? pixelSpacing![1] : pixelSpacing![0])) / 2.0;
    
    // Account for image scaling: measurements are in original image space,
    // but we want real-world measurements regardless of zoom level
    return pixelDistance * avgSpacing;
  }

  /// Convert pixel area to real-world units (mm²) using DICOM pixel spacing
  double _convertAreaToRealWorldUnits(double pixelArea) {
    if (pixelSpacing == null || pixelSpacing!.isEmpty) {
      return pixelArea; // Return pixel value if no spacing info
    }
    
    // For area, we need both row and column spacing
    final rowSpacing = pixelSpacing![0];
    final colSpacing = pixelSpacing!.length > 1 ? pixelSpacing![1] : pixelSpacing![0];
    
    // Area scaling is spacing_row * spacing_col
    return pixelArea * rowSpacing * colSpacing;
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