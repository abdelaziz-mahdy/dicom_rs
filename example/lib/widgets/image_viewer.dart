import 'dart:typed_data';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'dicom_viewer_base.dart';
import 'dicom_interaction_mixin.dart';
import '../mixins/measurement_mixin.dart';
import '../models/measurement_models.dart';
import 'measurement_toolbar.dart';
import 'measurement_overlay.dart';

/// A widget for displaying DICOM images with navigation controls
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
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    initializeMeasurements(); // Initialize measurement system
    _updateProcessedImage();
  }

  @override
  void dispose() {
    disposeInteractionResources(); // Clean up timers
    super.dispose();
  }

  // Implement the required method from DicomInteractionMixin
  @override
  void updateProcessedImage() {
    _updateProcessedImage();
  }

  Future<void> _updateProcessedImage() async {
    // if (_isProcessing) return;

    // _isProcessing = true;
    if (widget.imageBytesList.isNotEmpty &&
        _currentIndex < widget.imageBytesList.length &&
        widget.imageBytesList[_currentIndex] != null) {
      _processedImage = await applyBrightnessContrast(
        widget.imageBytesList[_currentIndex],
      );
    }
    // _isProcessing = false;
    // if (mounted) {
    //   setState(() {
    //     _isProcessing = false;
    //   });
    // }
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
        
        // Image display area with interaction detectors
        Expanded(
          child: Stack(
            children: [
              // Main image with gesture detectors
              Listener(
                onPointerSignal: _handleScroll,
                onPointerDown: handlePointerDown,
                onPointerMove: handlePointerMove,
                onPointerUp: handlePointerUp,
                child: GestureDetector(
                  onTapUp: _handleImageTap,
                  onScaleUpdate: handleScaleUpdate,
                  onScaleEnd: handleScaleEnd,
                  child: Center(
                    child: Transform.scale(
                      scale: scale,
                      child: Stack(
                        children: [
                          // The actual image
                          _processedImage != null
                              ? Image.memory(
                                _processedImage!,
                                gaplessPlayback: true,
                              )
                              : widget.imageBytesList.isNotEmpty &&
                                  _currentIndex <
                                      widget.imageBytesList.length &&
                                  widget.imageBytesList[_currentIndex] != null
                              ? Image.memory(
                                widget.imageBytesList[_currentIndex]!,
                                gaplessPlayback: true,
                              )
                              : const Text('No image loaded'),
                          
                          // Measurement overlay
                          if (measurementsVisible)
                            MeasurementOverlay(
                              measurements: measurements,
                              pixelSpacing: null, // TODO: Get from DICOM metadata
                              units: 'mm',
                              visible: measurementsVisible,
                              onMeasurementDelete: removeMeasurement,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Brightness/contrast display overlay
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 4.0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: Text(
                    getAdjustmentText(),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),

              // Reset button for brightness/contrast
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
              if (_isProcessing)
                const Center(child: CircularProgressIndicator()),
                
              // Current measurement points preview
              if (isCreatingMeasurement)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _MeasurementPreviewPainter(
                      points: currentMeasurementPoints,
                      tool: selectedTool!,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Navigation controls
        if (widget.showControls && widget.imageBytesList.length > 1)
          Container(
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
          ),
      ],
    );
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

  void _handleScroll(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      if (event.scrollDelta.dy > 0) {
        nextSlice();
      } else if (event.scrollDelta.dy < 0) {
        previousSlice();
      }
    }
  }
  
  void _handleImageTap(TapUpDetails details) {
    // Handle measurement creation on tap
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    
    // Only handle if we have a selected measurement tool
    if (selectedTool != null) {
      handleMeasurementTap(localPosition, renderBox.size);
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
      ..color = Colors.cyan.withOpacity(0.7)
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
          // Draw polygon preview
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
