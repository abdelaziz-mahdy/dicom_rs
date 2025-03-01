import 'dart:typed_data';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// A widget for displaying DICOM images with navigation controls
class DicomImageViewer extends StatelessWidget {
  final Uint8List? imageBytes;
  final int currentIndex;
  final int totalImages;
  final Function() onNext;
  final Function() onPrevious;
  final bool showControls;

  const DicomImageViewer({
    super.key,
    required this.imageBytes,
    required this.currentIndex,
    required this.totalImages,
    required this.onNext,
    required this.onPrevious,
    this.showControls = true,
  });

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
                  imageBytes != null
                      ? Image.memory(imageBytes!, gaplessPlayback: true)
                      : const Text('No image loaded'),
            ),
          ),
        ),

        // Navigation controls
        if (showControls && totalImages > 1)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.navigate_before),
                  onPressed: onPrevious,
                  tooltip: 'Previous slice',
                ),
                Text(
                  'Slice: ${currentIndex + 1} / $totalImages',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.navigate_next),
                  onPressed: onNext,
                  tooltip: 'Next slice',
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _handleScroll(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      if (event.scrollDelta.dy > 0) {
        onNext();
      } else if (event.scrollDelta.dy < 0) {
        onPrevious();
      }
    }
  }
}
