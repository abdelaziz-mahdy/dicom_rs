import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../controllers/dicom_viewer_controller.dart';
import '../controllers/image_interaction_controller.dart';
import '../../domain/entities/measurement_entity.dart';
import 'image_display_widget.dart';
import 'measurement_toolbar_widget.dart';
import 'viewer_controls_widget.dart';
import 'help_dialog_widget.dart';

/// Clean, optimized DICOM viewer with proper architecture
class CleanDicomViewer extends StatefulWidget {
  const CleanDicomViewer({
    super.key,
    this.controller,
    this.interactionController,
    this.showControls = true,
    this.showMeasurementToolbar = true,
    this.enableHelpButton = true,
  });

  final DicomViewerController? controller;
  final ImageInteractionController? interactionController;
  final bool showControls;
  final bool showMeasurementToolbar;
  final bool enableHelpButton;

  @override
  State<CleanDicomViewer> createState() => _CleanDicomViewerState();
}

class _CleanDicomViewerState extends State<CleanDicomViewer> {
  late final DicomViewerController _controller;
  late final ImageInteractionController _interactionController;

  // Focus management
  final FocusNode _mainFocusNode = FocusNode(
    debugLabel: 'DicomViewer',
    skipTraversal: false,
    canRequestFocus: true,
  );

  // Current image data
  Uint8List? _currentImageData;

  // Measurement state
  final List<MeasurementEntity> _measurements = [];
  final List<MeasurementPoint> _currentMeasurementPoints = [];
  MeasurementType? _selectedMeasurementTool;
  bool _measurementsVisible = true;

  // Measurement point dragging state
  MeasurementEntity? _draggingMeasurement;
  int? _draggingPointIndex;

  @override
  void initState() {
    super.initState();

    _controller = widget.controller ?? DicomViewerController();
    _interactionController =
        widget.interactionController ?? ImageInteractionController();

    // Setup interaction callbacks
    _setupInteractionCallbacks();

    // Listen to controller changes
    _controller.addListener(_onControllerChanged);

    // Request focus on first frame to ensure keyboard events work
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _mainFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _mainFocusNode.dispose();
    if (widget.controller == null) _controller.dispose();
    if (widget.interactionController == null) _interactionController.dispose();
    super.dispose();
  }

  void _setupInteractionCallbacks() {
    _interactionController
      ..onNextImage = _controller.nextImage
      ..onPreviousImage = _controller.previousImage
      ..onBrightnessContrastChanged = (brightness, contrast) {
        _controller.updateImageAdjustments(
          brightness: brightness,
          contrast: contrast,
        );
      }
      ..onScaleChanged = (scale) {
        // Only allow scaling when not measuring
        if (_selectedMeasurementTool == null) {
          _controller.updateScale(scale);
        }
      }
      ..onImageTapped = _handleImageTap
      ..onMeasurementPointDragged = _handleMeasurementPointDrag
      ..onPointDrag = _handlePointDrag;

    // Listen to interaction controller changes to clear drag state when needed
    _interactionController.addListener(() {
      if (_interactionController.selectedMeasurement == null) {
        setState(() {
          _clearDragState();
        });
      }
    });
  }

  void _onControllerChanged() {
    if (mounted) {
      // Sync interaction controller with current brightness/contrast values
      _interactionController.syncBrightnessContrast(
        _controller.state.brightness,
        _controller.state.contrast,
      );

      setState(() {});
      _loadCurrentImage();
    }
  }

  Future<void> _loadCurrentImage() async {
    final imageData = await _controller.getCurrentImageData();

    if (mounted) {
      setState(() {
        _currentImageData = imageData;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _mainFocusNode,
      onKeyEvent: (node, event) {
        // Handle keyboard navigation at the top level to prevent focus stealing
        _interactionController.handleKeyEvent(event);
        return KeyEventResult.handled;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Main content
            Column(
              children: [
                // Measurement toolbar
                if (widget.showMeasurementToolbar)
                  MeasurementToolbarWidget(
                    selectedTool: _selectedMeasurementTool,
                    onToolSelected: _handleToolSelected,
                    onClearMeasurements: _clearAllMeasurements,
                    onToggleVisibility: _toggleMeasurementsVisibility,
                    measurementsVisible: _measurementsVisible,
                    measurementCount: _measurements.length,
                  ),

                // Main image area
                Expanded(
                  child: Stack(
                    children: [
                      // Image display
                      Center(
                        child: ImageDisplayWidget(
                          imageData: _currentImageData,
                          scale: _controller.state.scale,
                          measurements: _measurements,
                          currentMeasurementPoints: _currentMeasurementPoints,
                          selectedTool: _selectedMeasurementTool,
                          measurementsVisible: _measurementsVisible,
                          interactionController: _interactionController,
                        ),
                      ),

                      // UI overlays
                      _buildUIOverlays(),
                    ],
                  ),
                ),

                // Bottom controls
                if (widget.showControls && _controller.state.hasImages)
                  ViewerControlsWidget(
                    currentIndex: _controller.state.currentIndex + 1,
                    totalImages: _controller.state.totalImages,
                    onPrevious: _controller.previousImage,
                    onNext: _controller.nextImage,
                    onGoToImage: (index) => _controller.goToImage(index - 1),
                  ),
              ],
            ),

            // Loading overlay
            if (_controller.state.isLoading)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.cyan),
                      SizedBox(height: 16),
                      Text(
                        'Loading DICOM files...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUIOverlays() {
    return Stack(
      children: [
        // Image adjustments display
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
            ),
            child: Text(
              'B: ${_controller.state.brightness.toStringAsFixed(2)} '
              'C: ${_controller.state.contrast.toStringAsFixed(2)} '
              'Z: ${(_controller.state.scale * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),

        // Reset button
        Positioned(
          top: 16,
          left: 16,
          child: IconButton(
            icon: const Icon(Icons.refresh, color: Colors.cyan),
            onPressed: _controller.resetImageAdjustments,
            tooltip: 'Reset adjustments',
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withValues(alpha: 0.7),
              side: BorderSide(color: Colors.cyan.withValues(alpha: 0.3)),
            ),
          ),
        ),

        // Help button
        if (widget.enableHelpButton)
          Positioned(
            bottom: 16,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.help_outline, color: Colors.cyan),
              onPressed: _showHelpDialog,
              tooltip: 'Show help',
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.7),
                side: BorderSide(color: Colors.cyan.withValues(alpha: 0.3)),
              ),
            ),
          ),

        // Error display
        if (_controller.state.error != null)
          Positioned(
            top: 100,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _controller.state.error!,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      // Clear error
                      _controller.reset();
                    },
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // Event handlers
  void _handleToolSelected(MeasurementType? tool) {
    setState(() {
      _selectedMeasurementTool = tool;
      _currentMeasurementPoints.clear();

      // Reset scale to 1.0 when starting measurements to avoid scaling issues
      if (tool != null) {
        _controller.updateScale(1.0);
      }
    });
  }

  void _handleImageTap(Offset position, Size imageSize) {
    // Don't handle measurement point selection in tap - let scale events handle dragging
    // This prevents the double-click issue by allowing scale events to handle everything

    // Only add new measurement points if we have a selected tool
    if (_selectedMeasurementTool == null) return;

    // Check if tap is on an existing measurement point - if so, don't add new point
    for (final measurement in _measurements) {
      for (int i = 0; i < measurement.points.length; i++) {
        final point = measurement.points[i];
        final pointCenter = Offset(point.x, point.y);
        final distance = (position - pointCenter).distance;
        if (distance <= 12) {
          // Hit an existing point, don't add new measurement point
          return;
        }
      }
    }

    setState(() {
      _currentMeasurementPoints.add(
        MeasurementPoint(x: position.dx, y: position.dy),
      );

      // Complete measurement if we have enough points
      final requiredPoints = _selectedMeasurementTool!.requiredPoints;
      if (_currentMeasurementPoints.length >= requiredPoints) {
        _completeMeasurement();
      }
    });
  }

  void _handleMeasurementPointDrag(Offset position) {
    // If no drag is in progress, check if we're starting a drag on a measurement point
    if (_draggingMeasurement == null) {
      // Check for point hit and immediately start dragging if found
      for (final measurement in _measurements) {
        for (int i = 0; i < measurement.points.length; i++) {
          final point = measurement.points[i];
          final pointCenter = Offset(point.x, point.y);
          final distance = (position - pointCenter).distance;

          // Check if the drag started on a measurement point (radius 12)
          if (distance <= 12) {
            // Immediately select and start dragging this point
            _draggingMeasurement = measurement;
            _draggingPointIndex = i;
            _interactionController.setSelectedMeasurement(measurement, i);

            // Start dragging immediately - update position on first detection
            final updatedMeasurement = _updateMeasurementPoint(
              measurement,
              i,
              position,
            );

            if (updatedMeasurement != null) {
              setState(() {
                final index = _measurements.indexWhere(
                  (m) => m.id == measurement.id,
                );
                if (index != -1) {
                  _measurements[index] = updatedMeasurement;
                }
              });
            }
            return;
          }
        }
      }
      // No point hit, nothing to drag
      return;
    }

    // Continue dragging the selected point
    if (_draggingMeasurement != null && _draggingPointIndex != null) {
      final updatedMeasurement = _updateMeasurementPoint(
        _draggingMeasurement!,
        _draggingPointIndex!,
        position,
      );

      if (updatedMeasurement != null) {
        setState(() {
          final index = _measurements.indexWhere(
            (m) => m.id == _draggingMeasurement!.id,
          );
          if (index != -1) {
            _measurements[index] = updatedMeasurement;
          }
        });
      }
    }
  }

  /// Update a specific measurement point position
  MeasurementEntity? _updateMeasurementPoint(
    MeasurementEntity measurement,
    int pointIndex,
    Offset newPosition,
  ) {
    if (pointIndex >= measurement.points.length) return null;

    final updatedPoints = List<MeasurementPoint>.from(measurement.points);
    updatedPoints[pointIndex] = MeasurementPoint(
      x: newPosition.dx,
      y: newPosition.dy,
    );

    return MeasurementEntity(
      id: measurement.id,
      type: measurement.type,
      points: updatedPoints,
      pixelSpacing: measurement.pixelSpacing,
      imageScale: measurement.imageScale,
    );
  }

  void _handlePointDrag(
    dynamic measurement,
    int pointIndex,
    Offset newPosition,
  ) {
    if (measurement is! MeasurementEntity) return;

    setState(() {
      // Find the measurement in our list and update the specific point
      final measurementIndex = _measurements.indexWhere(
        (m) => m.id == measurement.id,
      );
      if (measurementIndex != -1) {
        final currentMeasurement = _measurements[measurementIndex];
        final updatedPoints = List<MeasurementPoint>.from(
          currentMeasurement.points,
        );

        // Update the specific point if it exists
        if (pointIndex < updatedPoints.length) {
          updatedPoints[pointIndex] = MeasurementPoint(
            x: newPosition.dx,
            y: newPosition.dy,
          );

          // Create a new measurement with updated points
          final updatedMeasurement = MeasurementEntity(
            id: currentMeasurement.id,
            type: currentMeasurement.type,
            points: updatedPoints,
            pixelSpacing: currentMeasurement.pixelSpacing,
            imageScale: currentMeasurement.imageScale,
          );

          _measurements[measurementIndex] = updatedMeasurement;
        }
      }
    });
  }

  void _clearDragState() {
    _draggingMeasurement = null;
    _draggingPointIndex = null;
  }

  void _completeMeasurement() {
    if (_selectedMeasurementTool == null || _currentMeasurementPoints.isEmpty) {
      return;
    }

    // Get pixel spacing from current DICOM image metadata
    final pixelSpacing = _controller.state.currentImage?.metadata.pixelSpacing;
    final currentScale = _controller.state.scale;

    final measurement = MeasurementEntity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: _selectedMeasurementTool!,
      points: List.from(_currentMeasurementPoints),
      pixelSpacing: pixelSpacing,
      imageScale: currentScale,
    );

    setState(() {
      _measurements.add(measurement);
      _currentMeasurementPoints.clear();
      _selectedMeasurementTool = null;
    });

    // Clear any selected measurement highlighting
    _interactionController.clearSelectedMeasurement();
  }

  void _clearAllMeasurements() {
    setState(() {
      _measurements.clear();
      _currentMeasurementPoints.clear();
    });

    // Clear any selected measurement highlighting
    _interactionController.clearSelectedMeasurement();
  }

  void _toggleMeasurementsVisibility() {
    setState(() {
      _measurementsVisible = !_measurementsVisible;
    });
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => const HelpDialogWidget(),
    );
  }


  void reset() {
    _controller.reset();
    setState(() {
      _measurements.clear();
      _currentMeasurementPoints.clear();
      _selectedMeasurementTool = null;
      _measurementsVisible = true;
      _currentImageData = null;
    });
  }
}
