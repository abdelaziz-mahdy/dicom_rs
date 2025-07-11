import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dicom_viewer_base.dart';
import 'dicom_interaction_mixin.dart';
import '../mixins/measurement_mixin.dart';
import '../models/measurement_models.dart';
import 'measurement_toolbar.dart';
import 'measurable_image.dart';

/// A widget for displaying DICOM images with navigation controls and measurement tools
class DicomImageViewer extends DicomViewerBase {
  final List<Uint8List?> imageBytesList;
  final int initialIndex;
  final bool showControls;

  const DicomImageViewer({
    super.key,
    required this.imageBytesList,
    this.initialIndex = 0,
    this.showControls = true,
  });

  @override
  int getCurrentSliceIndex() => 0; // Will be handled by state

  @override
  int getTotalSlices() => imageBytesList.length;

  @override
  DicomImageViewerState createState() => DicomImageViewerState();
}

class DicomImageViewerState extends DicomViewerBaseState<DicomImageViewer>
    with DicomInteractionMixin, MeasurementMixin {
  late int _currentIndex;
  Uint8List? _processedImage;
  final bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    initializeMeasurements();
    _updateProcessedImage();
  }

  @override
  void dispose() {
    disposeInteractionResources();
    super.dispose();
  }

  @override
  void updateProcessedImage() {
    _updateProcessedImage();
  }

  Future<void> _updateProcessedImage() async {
    if (widget.imageBytesList.isNotEmpty &&
        _currentIndex < widget.imageBytesList.length &&
        widget.imageBytesList[_currentIndex] != null) {
      _processedImage = await applyBrightnessContrast(
        widget.imageBytesList[_currentIndex],
      );
    }
  }

  @override
  void didUpdateWidget(DicomImageViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageBytesList != widget.imageBytesList ||
        oldWidget.initialIndex != widget.initialIndex) {
      _updateProcessedImage();
    }
  }

  @override
  int getCurrentSliceIndex() => _currentIndex;

  @override
  int getTotalSlices() => widget.imageBytesList.length;

  Uint8List? get _currentImageData {
    if (_processedImage != null) {
      return _processedImage;
    } else if (widget.imageBytesList.isNotEmpty &&
        _currentIndex < widget.imageBytesList.length) {
      return widget.imageBytesList[_currentIndex];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Measurement toolbar
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: MeasurementToolbar(
            selectedTool: selectedTool,
            onToolSelected: selectMeasurementTool,
            onClearMeasurements: clearAllMeasurements,
            onToggleMeasurements: toggleMeasurementsVisibility,
            measurementsVisible: measurementsVisible,
            measurementCount: measurements.length,
          ),
        ),

        // Main image display with unified interaction handling
        Expanded(
          child: Stack(
            children: [
              // The measurable image widget - handles everything in one place
              Center(
                child: MeasurableImage(
                  imageData: _currentImageData,
                  scale: scale,
                  selectedTool: selectedTool,
                  measurements: measurements,
                  currentPoints: currentMeasurementPoints,
                  measurementsVisible: measurementsVisible,
                  pixelSpacing: null, // TODO: Get from DICOM metadata
                  units: 'mm',
                  onImageTap: _handleImageTap,
                  onMeasurementDelete: removeMeasurement,
                  onPointerSignal: _handlePointerSignal,
                  onScaleStart: _handleScaleStart,
                  onScaleUpdate: _handleScaleUpdate,
                  onScaleEnd: _handleScaleEnd,
                  onPointDrag: _handlePointDrag,
                  hasMeasurementSelected: hasMeasurementSelected,
                ),
              ),

              // UI overlays
              _buildUIOverlays(),
            ],
          ),
        ),

        // Navigation controls
        if (widget.showControls && widget.imageBytesList.length > 1)
          _buildNavigationControls(),
      ],
    );
  }

  Widget _buildUIOverlays() {
    return Stack(
      children: [
        // Brightness/contrast display
        Positioned(
          top: 10,
          right: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: Text(
              getAdjustmentText(),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),

        // Reset button
        Positioned(
          top: 10,
          left: 10,
          child: IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () {
              resetImageAdjustments();
              _updateProcessedImage();
            },
            tooltip: 'Reset adjustments',
            style: IconButton.styleFrom(backgroundColor: Colors.black38),
          ),
        ),

        // Processing indicator
        if (_isProcessing) const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  Widget _buildNavigationControls() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.navigate_before),
            onPressed: previousSlice,
            tooltip: 'Previous slice',
          ),
          Text(
            'Slice: ${_currentIndex + 1} / ${widget.imageBytesList.length}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.navigate_next),
            onPressed: nextSlice,
            tooltip: 'Next slice',
          ),
        ],
      ),
    );
  }

  // Gesture handlers - now much simpler since most logic is in MeasurableImage
  void _handleImageTap(Offset localPosition, Size imageSize) {
    // This is called directly from the image widget with correct coordinates
    handleMeasurementTap(localPosition, imageSize);
  }

  void _handlePointDrag(Offset newPosition) {
    handlePointDrag(newPosition);
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final scrollDelta = event.scrollDelta;
      const threshold = 10.0;

      if (scrollDelta.dy.abs() > threshold ||
          scrollDelta.dx.abs() > threshold) {
        final deltaY = scrollDelta.dy;
        final deltaX = scrollDelta.dx;

        if (deltaY.abs() > deltaX.abs()) {
          if (deltaY > 0) {
            nextSlice();
          } else {
            previousSlice();
          }
        } else {
          if (deltaX > 0) {
            nextSlice();
          } else {
            previousSlice();
          }
        }
      }
    }
  }

  void _handleScaleStart(ScaleStartDetails details) {
    if (selectedTool == null) {
      handleScaleStart(details);
    }
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (selectedTool == null) {
      handleScaleUpdate(details);
      _updateProcessedImage(); // Update the processed image after brightness/contrast changes
    }
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    if (selectedTool == null) {
      handleScaleEnd(details);
    }
  }

  @override
  void nextSlice() {
    if (widget.imageBytesList.isEmpty) return;

    setState(() {
      _currentIndex = (_currentIndex + 1) % widget.imageBytesList.length;
    });
    _updateProcessedImage();
  }

  @override
  void previousSlice() {
    if (widget.imageBytesList.isEmpty) return;

    setState(() {
      _currentIndex =
          (_currentIndex - 1 + widget.imageBytesList.length) %
          widget.imageBytesList.length;
    });
    _updateProcessedImage();
  }
}
