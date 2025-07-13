import 'dart:math';
import 'dart:ui';

/// Types of measurements that can be performed
enum MeasurementType { distance, angle, area, circle }

/// A point in 2D space with pixel coordinates
class MeasurementPoint {
  final double x;
  final double y;

  const MeasurementPoint(this.x, this.y);

  @override
  String toString() => 'Point($x, $y)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeasurementPoint &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => x.hashCode ^ y.hashCode;

  /// Calculate distance to another point in pixels
  double distanceTo(MeasurementPoint other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return sqrt(dx * dx + dy * dy);
  }

  /// Scale point by a factor
  MeasurementPoint scale(double factor) {
    return MeasurementPoint(x * factor, y * factor);
  }

  /// Translate point by offset
  MeasurementPoint translate(double dx, double dy) {
    return MeasurementPoint(x + dx, y + dy);
  }
}

/// A measurement annotation on a DICOM image
class DicomMeasurement {
  final String id;
  final MeasurementType type;
  final List<MeasurementPoint> points;
  final String label;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;
  final bool isSelected;
  final int? selectedPointIndex;

  const DicomMeasurement({
    required this.id,
    required this.type,
    required this.points,
    required this.label,
    required this.createdAt,
    this.metadata = const {},
    this.isSelected = false,
    this.selectedPointIndex,
  });

  /// Create a distance measurement between two points
  factory DicomMeasurement.distance({
    required String id,
    required MeasurementPoint start,
    required MeasurementPoint end,
    String? label,
  }) {
    return DicomMeasurement(
      id: id,
      type: MeasurementType.distance,
      points: [start, end],
      label: label ?? 'Distance',
      createdAt: DateTime.now(),
    );
  }

  /// Create an angle measurement with three points
  factory DicomMeasurement.angle({
    required String id,
    required MeasurementPoint vertex,
    required MeasurementPoint point1,
    required MeasurementPoint point2,
    String? label,
  }) {
    return DicomMeasurement(
      id: id,
      type: MeasurementType.angle,
      points: [vertex, point1, point2],
      label: label ?? 'Angle',
      createdAt: DateTime.now(),
    );
  }

  /// Create a circle measurement
  factory DicomMeasurement.circle({
    required String id,
    required MeasurementPoint center,
    required MeasurementPoint edge,
    String? label,
  }) {
    return DicomMeasurement(
      id: id,
      type: MeasurementType.circle,
      points: [center, edge],
      label: label ?? 'Circle',
      createdAt: DateTime.now(),
    );
  }

  /// Create a copy of this measurement with updated properties
  DicomMeasurement copyWith({
    String? id,
    MeasurementType? type,
    List<MeasurementPoint>? points,
    String? label,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
    bool? isSelected,
    int? selectedPointIndex,
  }) {
    return DicomMeasurement(
      id: id ?? this.id,
      type: type ?? this.type,
      points: points ?? this.points,
      label: label ?? this.label,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
      isSelected: isSelected ?? this.isSelected,
      selectedPointIndex: selectedPointIndex ?? this.selectedPointIndex,
    );
  }

  /// Update a specific point in this measurement
  DicomMeasurement updatePoint(int index, MeasurementPoint newPoint) {
    if (index < 0 || index >= points.length) {
      return this;
    }
    final newPoints = List<MeasurementPoint>.from(points);
    newPoints[index] = newPoint;
    return copyWith(points: newPoints);
  }

  /// Check if a tap is near any point (within hitRadius pixels)
  int? getHitPointIndex(Offset tapPosition, {double hitRadius = 20.0}) {
    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final distance = sqrt(
        pow(tapPosition.dx - point.x, 2) + pow(tapPosition.dy - point.y, 2),
      );
      if (distance <= hitRadius) {
        return i;
      }
    }
    return null;
  }

  /// Calculate the measurement value based on type and pixel spacing
  MeasurementResult calculateValue({
    List<double>? pixelSpacing,
    String units = 'mm',
  }) {
    switch (type) {
      case MeasurementType.distance:
        return _calculateDistance(pixelSpacing, units);
      case MeasurementType.angle:
        return _calculateAngle();
      case MeasurementType.area:
        return _calculateArea(pixelSpacing, units);
      case MeasurementType.circle:
        return _calculateCircle(pixelSpacing, units);
    }
  }

  MeasurementResult _calculateDistance(
    List<double>? pixelSpacing,
    String units,
  ) {
    if (points.length != 2) {
      return MeasurementResult.invalid('Distance requires exactly 2 points');
    }

    final pixelDistance = points[0].distanceTo(points[1]);

    if (pixelSpacing != null && pixelSpacing.isNotEmpty) {
      // Use pixel spacing to convert to real-world units
      final mmDistance =
          pixelDistance * pixelSpacing[0]; // Assume square pixels
      return MeasurementResult.distance(
        pixels: pixelDistance,
        realWorld: mmDistance,
        units: units,
      );
    } else {
      // No pixel spacing available - show only pixel measurements
      return MeasurementResult.distance(
        pixels: pixelDistance,
        realWorld: null,
        units: 'pixels',
      );
    }
  }

  MeasurementResult _calculateAngle() {
    if (points.length != 3) {
      return MeasurementResult.invalid('Angle requires exactly 3 points');
    }

    final vertex = points[0];
    final point1 = points[1];
    final point2 = points[2];

    // Calculate vectors from vertex to each point
    final dx1 = point1.x - vertex.x;
    final dy1 = point1.y - vertex.y;
    final dx2 = point2.x - vertex.x;
    final dy2 = point2.y - vertex.y;

    // Calculate angle using dot product
    final dot = dx1 * dx2 + dy1 * dy2;
    final mag1 = sqrt(dx1 * dx1 + dy1 * dy1);
    final mag2 = sqrt(dx2 * dx2 + dy2 * dy2);

    if (mag1 == 0 || mag2 == 0) {
      return MeasurementResult.invalid('Invalid angle points');
    }

    final angleRad = acos(dot / (mag1 * mag2));
    final angleDeg = angleRad * 180 / pi;

    return MeasurementResult.angle(degrees: angleDeg);
  }

  MeasurementResult _calculateArea(List<double>? pixelSpacing, String units) {
    // For polygon area calculation - would need more complex implementation
    return MeasurementResult.invalid('Area calculation not implemented');
  }

  MeasurementResult _calculateCircle(List<double>? pixelSpacing, String units) {
    if (points.length != 2) {
      return MeasurementResult.invalid('Circle requires exactly 2 points');
    }

    final center = points[0];
    final edge = points[1];
    final radiusPixels = center.distanceTo(edge);
    final areaPixels = pi * radiusPixels * radiusPixels;

    if (pixelSpacing != null && pixelSpacing.isNotEmpty) {
      final radiusMm = radiusPixels * pixelSpacing[0];
      final areaMm = pi * radiusMm * radiusMm;
      return MeasurementResult.circle(
        radiusPixels: radiusPixels,
        radiusRealWorld: radiusMm,
        areaPixels: areaPixels,
        areaRealWorld: areaMm,
        units: units,
      );
    } else {
      return MeasurementResult.circle(
        radiusPixels: radiusPixels,
        radiusRealWorld: null,
        areaPixels: areaPixels,
        areaRealWorld: null,
        units: 'pixels',
      );
    }
  }

  @override
  String toString() => '$label: $type (${points.length} points)';
}

/// Result of a measurement calculation
class MeasurementResult {
  final MeasurementType type;
  final double? pixelValue;
  final double? realWorldValue;
  final String units;
  final String displayText;
  final bool isValid;
  final String? error;
  final Map<String, dynamic> additionalData;

  const MeasurementResult({
    required this.type,
    this.pixelValue,
    this.realWorldValue,
    required this.units,
    required this.displayText,
    this.isValid = true,
    this.error,
    this.additionalData = const {},
  });

  factory MeasurementResult.distance({
    required double pixels,
    double? realWorld,
    required String units,
  }) {
    final displayValue = realWorld ?? pixels;
    final displayUnits = realWorld != null ? units : 'px';
    return MeasurementResult(
      type: MeasurementType.distance,
      pixelValue: pixels,
      realWorldValue: realWorld,
      units: units,
      displayText: '${displayValue.toStringAsFixed(2)} $displayUnits',
    );
  }

  factory MeasurementResult.angle({required double degrees}) {
    return MeasurementResult(
      type: MeasurementType.angle,
      pixelValue: degrees,
      realWorldValue: degrees,
      units: '°',
      displayText: '${degrees.toStringAsFixed(1)}°',
    );
  }

  factory MeasurementResult.circle({
    required double radiusPixels,
    double? radiusRealWorld,
    required double areaPixels,
    double? areaRealWorld,
    required String units,
  }) {
    final displayRadius = radiusRealWorld ?? radiusPixels;
    final displayArea = areaRealWorld ?? areaPixels;
    final displayUnits = radiusRealWorld != null ? units : 'px';

    return MeasurementResult(
      type: MeasurementType.circle,
      pixelValue: radiusPixels,
      realWorldValue: radiusRealWorld,
      units: units,
      displayText:
          'R: ${displayRadius.toStringAsFixed(2)} $displayUnits\n'
          'A: ${displayArea.toStringAsFixed(2)} $displayUnits²',
      additionalData: {
        'radius': displayRadius,
        'area': displayArea,
        'radiusPixels': radiusPixels,
        'areaPixels': areaPixels,
      },
    );
  }

  factory MeasurementResult.invalid(String error) {
    return MeasurementResult(
      type: MeasurementType.distance, // default
      units: '',
      displayText: 'Invalid',
      isValid: false,
      error: error,
    );
  }

  @override
  String toString() => displayText;
}

/// Manages measurements for a DICOM image
class MeasurementManager {
  final List<DicomMeasurement> _measurements = [];
  final List<double>? pixelSpacing;
  final String units;

  MeasurementManager({this.pixelSpacing, this.units = 'mm'});

  List<DicomMeasurement> get measurements => List.unmodifiable(_measurements);

  /// Add a new measurement
  void addMeasurement(DicomMeasurement measurement) {
    _measurements.add(measurement);
  }

  /// Remove a measurement by ID
  bool removeMeasurement(String id) {
    final index = _measurements.indexWhere((m) => m.id == id);
    if (index >= 0) {
      _measurements.removeAt(index);
      return true;
    }
    return false;
  }

  /// Update an existing measurement
  bool updateMeasurement(DicomMeasurement updatedMeasurement) {
    final index = _measurements.indexWhere(
      (m) => m.id == updatedMeasurement.id,
    );
    if (index >= 0) {
      _measurements[index] = updatedMeasurement;
      return true;
    }
    return false;
  }

  /// Get measurement by ID
  DicomMeasurement? getMeasurement(String id) {
    try {
      return _measurements.firstWhere((m) => m.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Clear all measurements
  void clearMeasurements() {
    _measurements.clear();
  }

  /// Get measurements of a specific type
  List<DicomMeasurement> getMeasurementsByType(MeasurementType type) {
    return _measurements.where((m) => m.type == type).toList();
  }

  /// Calculate results for all measurements
  List<MeasurementResult> calculateAllResults() {
    return _measurements
        .map((m) => m.calculateValue(pixelSpacing: pixelSpacing, units: units))
        .toList();
  }

  /// Export measurements to a map for saving
  Map<String, dynamic> toJson() {
    return {
      'measurements':
          _measurements
              .map(
                (m) => {
                  'id': m.id,
                  'type': m.type.name,
                  'points': m.points.map((p) => {'x': p.x, 'y': p.y}).toList(),
                  'label': m.label,
                  'createdAt': m.createdAt.toIso8601String(),
                  'metadata': m.metadata,
                },
              )
              .toList(),
      'pixelSpacing': pixelSpacing,
      'units': units,
    };
  }

  /// Import measurements from a map
  factory MeasurementManager.fromJson(Map<String, dynamic> json) {
    final manager = MeasurementManager(
      pixelSpacing: json['pixelSpacing']?.cast<double>(),
      units: json['units'] ?? 'mm',
    );

    final measurementsList = json['measurements'] as List<dynamic>? ?? [];
    for (final measurementData in measurementsList) {
      final typeStr = measurementData['type'] as String;
      final type = MeasurementType.values.firstWhere(
        (t) => t.name == typeStr,
        orElse: () => MeasurementType.distance,
      );

      final pointsList = measurementData['points'] as List<dynamic>;
      final points =
          pointsList
              .map((p) => MeasurementPoint(p['x'] as double, p['y'] as double))
              .toList();

      final measurement = DicomMeasurement(
        id: measurementData['id'] as String,
        type: type,
        points: points,
        label: measurementData['label'] as String,
        createdAt: DateTime.parse(measurementData['createdAt'] as String),
        metadata: measurementData['metadata'] as Map<String, dynamic>? ?? {},
      );

      manager.addMeasurement(measurement);
    }

    return manager;
  }
}
