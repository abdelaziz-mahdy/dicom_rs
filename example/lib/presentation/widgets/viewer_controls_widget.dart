import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Clean navigation controls widget for DICOM viewer
class ViewerControlsWidget extends StatefulWidget {
  const ViewerControlsWidget({
    super.key,
    required this.currentIndex,
    required this.totalImages,
    required this.onPrevious,
    required this.onNext,
    required this.onGoToImage,
  });

  final int currentIndex;
  final int totalImages;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final Function(int index) onGoToImage;

  @override
  State<ViewerControlsWidget> createState() => _ViewerControlsWidgetState();
}

class _ViewerControlsWidgetState extends State<ViewerControlsWidget> {
  final TextEditingController _indexController = TextEditingController();
  bool _showIndexInput = false;

  @override
  void initState() {
    super.initState();
    _updateIndexController();
  }

  @override
  void didUpdateWidget(ViewerControlsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _updateIndexController();
    }
  }

  @override
  void dispose() {
    _indexController.dispose();
    super.dispose();
  }

  void _updateIndexController() {
    if (!_showIndexInput) {
      _indexController.text = widget.currentIndex.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(
          top: BorderSide(color: Colors.cyan.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          // Previous button
          IconButton(
            icon: const Icon(Icons.skip_previous, color: Colors.cyan),
            onPressed: widget.currentIndex > 1 ? widget.onPrevious : null,
            tooltip: 'Previous image (←)',
          ),

          // Fast rewind
          IconButton(
            icon: const Icon(Icons.fast_rewind, color: Colors.cyan),
            onPressed: widget.currentIndex > 10 
                ? () => widget.onGoToImage(widget.currentIndex - 10)
                : null,
            tooltip: 'Go back 10 images',
          ),

          const Spacer(),

          // Image counter / input
          GestureDetector(
            onTap: () {
              setState(() {
                _showIndexInput = true;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.cyan.withValues(alpha: 0.1),
                border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _showIndexInput ? _buildIndexInput() : _buildIndexDisplay(),
            ),
          ),

          const Spacer(),

          // Fast forward
          IconButton(
            icon: const Icon(Icons.fast_forward, color: Colors.cyan),
            onPressed: widget.currentIndex + 10 <= widget.totalImages 
                ? () => widget.onGoToImage(widget.currentIndex + 10)
                : null,
            tooltip: 'Go forward 10 images',
          ),

          // Next button
          IconButton(
            icon: const Icon(Icons.skip_next, color: Colors.cyan),
            onPressed: widget.currentIndex < widget.totalImages ? widget.onNext : null,
            tooltip: 'Next image (→)',
          ),
        ],
      ),
    );
  }

  Widget _buildIndexDisplay() {
    return Text(
      '${widget.currentIndex} / ${widget.totalImages}',
      style: const TextStyle(
        color: Colors.cyan,
        fontSize: 16,
        fontWeight: FontWeight.bold,
        fontFamily: 'monospace',
      ),
    );
  }

  Widget _buildIndexInput() {
    return SizedBox(
      width: 80,
      child: TextField(
        controller: _indexController,
        style: const TextStyle(
          color: Colors.cyan,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
        textAlign: TextAlign.center,
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
        ],
        onSubmitted: (value) {
          final index = int.tryParse(value);
          if (index != null && index >= 1 && index <= widget.totalImages) {
            try {
              widget.onGoToImage(index);
            } catch (e) {
              debugPrint('❌ Error navigating to image $index: $e');
              // Reset to current index on error
              _indexController.text = widget.currentIndex.toString();
            }
          } else {
            // Invalid input - reset to current index
            _indexController.text = widget.currentIndex.toString();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Please enter a number between 1 and ${widget.totalImages}'),
                  backgroundColor: Colors.orange[700],
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          }
          setState(() {
            _showIndexInput = false;
          });
        },
        onTapOutside: (_) {
          setState(() {
            _showIndexInput = false;
          });
        },
        autofocus: true,
      ),
    );
  }
}
