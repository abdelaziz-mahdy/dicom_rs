import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:dicom_rs/dicom_rs.dart';
import '../models/complex_types.dart';
import 'dicom_viewer_base.dart';
import 'dicom_interaction_mixin.dart';

/// A widget to display a 3D DICOM volume.
/// It shows one slice at a time with slider and next/previous controls.
class VolumeViewer extends DicomViewerBase {
  final DicomVolume volume;
  final int initialSliceIndex;

  const VolumeViewer({
    Key? key,
    required this.volume,
    this.initialSliceIndex = 0,
  }) : super(key: key);

  @override
  int getCurrentSliceIndex() => 0; // Will be handled by state

  @override
  int getTotalSlices() => volume.depth;

  @override
  VolumeViewerState createState() => VolumeViewerState();
}

class VolumeViewerState extends DicomViewerBaseState<VolumeViewer>
    with DicomInteractionMixin {
  late int _currentSliceIndex;
  Uint8List? _processedImage;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _currentSliceIndex = widget.initialSliceIndex;
    if (_currentSliceIndex >= widget.volume.depth) {
      _currentSliceIndex = 0;
    }
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
    Uint8List? currentSliceBytes;
    if (widget.volume.slices.isNotEmpty) {
      currentSliceBytes = widget.volume.slices[_currentSliceIndex].data;
      if (currentSliceBytes != null) {
        _processedImage = await applyBrightnessContrast(currentSliceBytes);
      }
    }
    // _isProcessing = false;
    // if (mounted) {
    //   setState(() {
    //     _isProcessing = false;
    //   });
    // }
  }

  @override
  int getCurrentSliceIndex() => _currentSliceIndex;

  @override
  int getTotalSlices() => widget.volume.depth;

  @override
  Widget build(BuildContext context) {
    // Retrieve the current slice image bytes.
    Uint8List? currentSliceBytes;
    if (widget.volume.slices.isNotEmpty) {
      currentSliceBytes = widget.volume.slices[_currentSliceIndex].data;
    }

    return Column(
      children: [
        // Volume info header
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            '3D Volume: ${widget.volume.width} × ${widget.volume.height} × ${widget.volume.depth}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),

        // Main image display with interaction handlers
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
                              : currentSliceBytes != null
                              ? Image.memory(
                                currentSliceBytes,
                                gaplessPlayback: true,
                              )
                              : const Center(
                                child: Text('No image data available'),
                              ),
                    ),
                  ),
                ),
              ),

              // Brightness/contrast display
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
              if (_isProcessing)
                const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),

        // Slider and navigation controls
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.navigate_before),
                tooltip: 'Previous slice',
                onPressed: previousSlice,
              ),
              Expanded(
                child: Slider(
                  value: _currentSliceIndex.toDouble(),
                  min: 0,
                  max: (widget.volume.depth - 1).toDouble(),
                  divisions: widget.volume.depth - 1,
                  label: 'Slice ${_currentSliceIndex + 1}',
                  onChanged: (value) {
                    setState(() {
                      _currentSliceIndex = value.toInt();
                    });
                    _updateProcessedImage();
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.navigate_next),
                tooltip: 'Next slice',
                onPressed: nextSlice,
              ),
            ],
          ),
        ),

        // Slice position indicator
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            'Slice: ${_currentSliceIndex + 1} / ${widget.volume.depth}',
          ),
        ),
      ],
    );
  }

  @override
  void nextSlice() {
    setState(() {
      _currentSliceIndex = (_currentSliceIndex + 1) % widget.volume.depth;
    });
    _updateProcessedImage();
  }

  @override
  void previousSlice() {
    setState(() {
      _currentSliceIndex =
          (_currentSliceIndex - 1 + widget.volume.depth) % widget.volume.depth;
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
