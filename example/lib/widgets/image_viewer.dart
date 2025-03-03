import 'dart:typed_data';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'dicom_viewer_base.dart';
import 'dicom_interaction_mixin.dart';

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
    with DicomInteractionMixin {
  late int _currentIndex;
  Uint8List? _processedImage;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
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
                  onScaleUpdate: handleScaleUpdate,
                  onScaleEnd: handleScaleEnd,
                  child: Center(
                    child: Transform.scale(
                      scale: scale,
                      child:
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
}
