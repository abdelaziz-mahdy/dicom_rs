import 'package:flutter/material.dart';
import '../models/measurement_models.dart';

/// Mixin that provides measurement functionality to DICOM viewers
mixin MeasurementMixin<T extends StatefulWidget> on State<T> {
  MeasurementManager? _measurementManager;
  MeasurementType? _selectedTool;
  bool _measurementsVisible = true;
  List<MeasurementPoint> _currentMeasurementPoints = [];

  // Getters
  MeasurementManager get measurementManager => _measurementManager!;
  MeasurementType? get selectedTool => _selectedTool;
  bool get measurementsVisible => _measurementsVisible;
  List<DicomMeasurement> get measurements =>
      _measurementManager?.measurements ?? [];

  // Initialize measurement system
  void initializeMeasurements({
    List<double>? pixelSpacing,
    String units = 'mm',
  }) {
    _measurementManager = MeasurementManager(
      pixelSpacing: pixelSpacing,
      units: units,
    );
  }

  // Update pixel spacing when image changes
  void updatePixelSpacing(List<double>? pixelSpacing) {
    if (_measurementManager != null) {
      _measurementManager = MeasurementManager(
        pixelSpacing: pixelSpacing,
        units: _measurementManager!.units,
      );
      // Re-add existing measurements
      final existingMeasurements = List<DicomMeasurement>.from(
        _measurementManager!.measurements,
      );
      _measurementManager!.clearMeasurements();
      for (final measurement in existingMeasurements) {
        _measurementManager!.addMeasurement(measurement);
      }
    }
  }

  // Tool selection
  void selectMeasurementTool(MeasurementType? tool) {
    setState(() {
      // Only clear points if we're switching to a different tool
      if (tool != _selectedTool) {
        _currentMeasurementPoints.clear();
      }
      
      _selectedTool = tool;
    });
  }

  // Toggle measurements visibility
  void toggleMeasurementsVisibility() {
    setState(() {
      _measurementsVisible = !_measurementsVisible;
    });
  }

  // Clear all measurements
  void clearAllMeasurements() {
    setState(() {
      _measurementManager?.clearMeasurements();
      _currentMeasurementPoints.clear();
    });
  }

  // Remove specific measurement
  void removeMeasurement(String id) {
    setState(() {
      _measurementManager?.removeMeasurement(id);
    });
  }

  // Handle tap/click for measurement creation
  bool handleMeasurementTap(Offset localPosition, Size imageSize) {
    if (_selectedTool == null || _measurementManager == null) {
      return false;
    }

    // Convert screen coordinates to image coordinates
    final imagePoint = MeasurementPoint(localPosition.dx, localPosition.dy);
    
    setState(() {
      _currentMeasurementPoints.add(imagePoint);

      // Check if we have enough points to complete the measurement
      final requiredPoints = _getRequiredPointsForTool(_selectedTool!);
      
      if (_currentMeasurementPoints.length >= requiredPoints) {
        _completeMeasurement();
      }
    });

    return true; // Indicates the tap was handled
  }

  // Complete the current measurement
  void _completeMeasurement() {
    if (_selectedTool == null || _currentMeasurementPoints.isEmpty) return;

    final id = DateTime.now().millisecondsSinceEpoch.toString();

    DicomMeasurement? measurement;

    switch (_selectedTool!) {
      case MeasurementType.distance:
        if (_currentMeasurementPoints.length >= 2) {
          measurement = DicomMeasurement.distance(
            id: id,
            start: _currentMeasurementPoints[0],
            end: _currentMeasurementPoints[1],
          );
        }
        break;

      case MeasurementType.angle:
        if (_currentMeasurementPoints.length >= 3) {
          measurement = DicomMeasurement.angle(
            id: id,
            vertex: _currentMeasurementPoints[0],
            point1: _currentMeasurementPoints[1],
            point2: _currentMeasurementPoints[2],
          );
        }
        break;

      case MeasurementType.circle:
        if (_currentMeasurementPoints.length >= 2) {
          measurement = DicomMeasurement.circle(
            id: id,
            center: _currentMeasurementPoints[0],
            edge: _currentMeasurementPoints[1],
          );
        }
        break;

      case MeasurementType.area:
        // Area measurements need at least 3 points
        if (_currentMeasurementPoints.length >= 3) {
          measurement = DicomMeasurement(
            id: id,
            type: MeasurementType.area,
            points: List.from(_currentMeasurementPoints),
            label: 'Area',
            createdAt: DateTime.now(),
          );
        }
        break;
    }

    if (measurement != null) {
      _measurementManager!.addMeasurement(measurement);
    }

    // Reset for next measurement
    _currentMeasurementPoints.clear();
  }

  // Cancel current measurement
  void cancelCurrentMeasurement() {
    setState(() {
      _currentMeasurementPoints.clear();
    });
  }

  // Get required number of points for each tool
  int _getRequiredPointsForTool(MeasurementType tool) {
    switch (tool) {
      case MeasurementType.distance:
      case MeasurementType.circle:
        return 2;
      case MeasurementType.angle:
        return 3;
      case MeasurementType.area:
        return 3; // Minimum, can be extended
    }
  }

  // Get current measurement points for drawing preview
  List<MeasurementPoint> get currentMeasurementPoints =>
      List.unmodifiable(_currentMeasurementPoints);

  // Check if currently creating a measurement
  bool get isCreatingMeasurement =>
      _selectedTool != null && _currentMeasurementPoints.isNotEmpty;

  // Get measurement results for display
  List<MeasurementResult> getMeasurementResults() {
    return _measurementManager?.calculateAllResults() ?? [];
  }

  // Export measurements
  Map<String, dynamic> exportMeasurements() {
    return _measurementManager?.toJson() ?? {};
  }

  // Import measurements
  void importMeasurements(Map<String, dynamic> data) {
    setState(() {
      _measurementManager = MeasurementManager.fromJson(data);
    });
  }
}
