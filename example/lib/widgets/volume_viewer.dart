import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:dicom_rs/dicom_rs.dart'; // Assuming DicomVolume is defined here

/// A widget to display a 3D DICOM volume.
/// It shows one slice at a time with slider and next/previous controls.
class VolumeViewer extends StatefulWidget {
  final DicomVolume volume;
  const VolumeViewer({Key? key, required this.volume}) : super(key: key);

  @override
  _VolumeViewerState createState() => _VolumeViewerState();
}

class _VolumeViewerState extends State<VolumeViewer> {
  int _currentSliceIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Retrieve the current slice image bytes.
    // This example assumes that the volume provides a list of slices.
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

        // Main image display with scroll wheel handling
        Expanded(
          child: Listener(
            onPointerSignal: _handleScroll,
            child: Center(
              child:
                  currentSliceBytes != null
                      ? Image.memory(currentSliceBytes, gaplessPlayback: true)
                      : const Center(child: Text('No image data available')),
            ),
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
                onPressed: _previousSlice,
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
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.navigate_next),
                tooltip: 'Next slice',
                onPressed: _nextSlice,
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

  void _nextSlice() {
    setState(() {
      _currentSliceIndex = (_currentSliceIndex + 1) % widget.volume.depth;
    });
  }

  void _previousSlice() {
    setState(() {
      _currentSliceIndex =
          (_currentSliceIndex - 1 + widget.volume.depth) % widget.volume.depth;
    });
  }

  void _handleScroll(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      if (event.scrollDelta.dy > 0) {
        _nextSlice();
      } else if (event.scrollDelta.dy < 0) {
        _previousSlice();
      }
    }
  }
}
