import 'package:flutter/material.dart';
import '../models/measurement_models.dart';

/// Mixin that provides measurement functionality to DICOM viewers
mixin MeasurementMixin<T extends StatefulWidget> on State<T> {
  MeasurementManager? _measurementManager;
  MeasurementType? _selectedTool;
  bool _measurementsVisible = true;
  List<MeasurementPoint> _currentMeasurementPoints = [];
  String? _selectedMeasurementId;
  int? _selectedPointIndex;
  bool _isDraggingPoint = false;

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

  // Tool selection - clicking the same tool will deselect it
  void selectMeasurementTool(MeasurementType? tool) {
    setState(() {
      // If clicking the same tool, deselect it
      if (tool == _selectedTool) {
        _selectedTool = null;
        _currentMeasurementPoints.clear();
      } else {
        // Switching to a different tool
        _currentMeasurementPoints.clear();
        _selectedTool = tool;
      }

      // Deselect any selected measurements when using tools
      if (_selectedTool != null) {
        _deselectAllMeasurements();
      }
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
      _selectedMeasurementId = null;
      _selectedPointIndex = null;
    });
  }

  // Remove specific measurement
  void removeMeasurement(String id) {
    setState(() {
      _measurementManager?.removeMeasurement(id);
    });
  }

  // Handle tap/click for measurement creation or selection
  bool handleMeasurementTap(Offset localPosition, Size imageSize) {
    if (_measurementManager == null) {
      return false;
    }

    final imagePoint = MeasurementPoint(localPosition.dx, localPosition.dy);

    // If no tool is selected, check for point selection
    if (_selectedTool == null) {
      return _handlePointSelection(imagePoint);
    }

    // Tool is selected - create new measurement
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

  // Handle point selection for editing existing measurements
  bool _handlePointSelection(MeasurementPoint tapPoint) {
    for (final measurement in _measurementManager!.measurements) {
      final hitIndex = measurement.getHitPointIndex(
        Offset(tapPoint.x, tapPoint.y),
        hitRadius: 20.0,
      );

      if (hitIndex != null) {
        setState(() {
          // Deselect all measurements first
          _deselectAllMeasurements();

          // Select this measurement and point
          _selectedMeasurementId = measurement.id;
          _selectedPointIndex = hitIndex;

          // Update the measurement to show it's selected
          final selectedMeasurement = measurement.copyWith(
            isSelected: true,
            selectedPointIndex: hitIndex,
          );
          _measurementManager!.updateMeasurement(selectedMeasurement);
        });
        return true;
      }
    }

    // No point hit - deselect all
    setState(() {
      _deselectAllMeasurements();
    });
    return false;
  }

  // Handle dragging of selected points
  bool handlePointDrag(Offset newPosition) {
    if (_selectedMeasurementId == null || _selectedPointIndex == null) {
      return false;
    }

    final measurement = _measurementManager!.measurements.firstWhere(
      (m) => m.id == _selectedMeasurementId,
    );

    final newPoint = MeasurementPoint(newPosition.dx, newPosition.dy);
    final updatedMeasurement = measurement.updatePoint(
      _selectedPointIndex!,
      newPoint,
    );

    setState(() {
      _measurementManager!.updateMeasurement(updatedMeasurement);
    });

    return true;
  }

  // Deselect all measurements
  void _deselectAllMeasurements() {
    _selectedMeasurementId = null;
    _selectedPointIndex = null;

    final measurements = _measurementManager!.measurements;
    for (final measurement in measurements) {
      if (measurement.isSelected) {
        final deselectedMeasurement = measurement.copyWith(
          isSelected: false,
          selectedPointIndex: null,
        );
        _measurementManager!.updateMeasurement(deselectedMeasurement);
      }
    }
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

  // Check if a measurement is selected
  bool get hasMeasurementSelected => _selectedMeasurementId != null;

  // Get selected measurement info
  String? get selectedMeasurementId => _selectedMeasurementId;
  int? get selectedPointIndex => _selectedPointIndex;

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
