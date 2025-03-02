import 'dart:typed_data';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'dicom_viewer_base.dart';

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

class DicomImageViewerState extends DicomViewerBaseState<DicomImageViewer> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  int getCurrentSliceIndex() => _currentIndex;

  @override
  int getTotalSlices() => widget.imageBytesList.length;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Image display area with scroll listener
        Expanded(
          child: Listener(
            onPointerSignal: _handleScroll,
            child: Center(
              child:
                  widget.imageBytesList.isNotEmpty &&
                          _currentIndex < widget.imageBytesList.length &&
                          widget.imageBytesList[_currentIndex] != null
                      ? Image.memory(
                        widget.imageBytesList[_currentIndex]!,
                        gaplessPlayback: true,
                      )
                      : const Text('No image loaded'),
            ),
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
  }

  @override
  void previousSlice() {
    if (widget.imageBytesList.isEmpty) return;

    setState(() {
      _currentIndex =
          (_currentIndex - 1 + widget.imageBytesList.length) %
          widget.imageBytesList.length;
    });
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
