import 'package:flutter/material.dart';

/// Help dialog widget explaining DICOM viewer interactions
class HelpDialogWidget extends StatelessWidget {
  const HelpDialogWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.grey[900],
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.help_outline, color: Colors.cyan, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'DICOM Viewer Help',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            const Divider(color: Colors.cyan),
            const SizedBox(height: 20),

            // Navigation section
            _buildSection(
              'Navigation',
              Icons.navigation,
              [
                _buildHelpItem('← → Arrow Keys', 'Navigate between slices'),
                _buildHelpItem('Mouse Wheel', 'Scroll through slices'),
                _buildHelpItem('Click Image Counter', 'Jump to specific slice'),
                _buildHelpItem('Fast Forward/Rewind', 'Jump ±10 slices'),
              ],
            ),

            const SizedBox(height: 16),

            // Image adjustments section
            _buildSection(
              'Image Adjustments',
              Icons.tune,
              [
                _buildHelpItem('Right-click + Drag', 'Adjust brightness/contrast'),
                _buildHelpItem('Reset Button', 'Reset all adjustments'),
                _buildHelpItem('Live Preview', 'See values in top-right corner'),
              ],
            ),

            const SizedBox(height: 16),

            // Measurements section
            _buildSection(
              'Measurements',
              Icons.straighten,
              [
                _buildHelpItem('Distance Tool', 'Click two points to measure'),
                _buildHelpItem('Angle Tool', 'Click three points (vertex in middle)'),
                _buildHelpItem('Circle Tool', 'Click center, then edge point'),
                _buildHelpItem('Area Tool', 'Click multiple points, auto-close'),
                _buildHelpItem('Visibility Toggle', 'Show/hide all measurements'),
                _buildHelpItem('Clear All', 'Remove all measurements'),
              ],
            ),

            const SizedBox(height: 16),

            // Tips section
            _buildSection(
              'Tips',
              Icons.lightbulb_outline,
              [
                _buildHelpItem('Keyboard Focus', 'Click image area for arrow keys'),
                _buildHelpItem('Multi-touch Zoom', 'Pinch to zoom on touch devices'),
                _buildHelpItem('Error Messages', 'Check top-left for any issues'),
                _buildHelpItem('File Selection', 'Select multiple DICOM files at once'),
              ],
            ),

            const SizedBox(height: 20),
            
            // Close button
            Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text(
                  'Got it!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.cyan, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.cyan,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...items,
      ],
    );
  }

  Widget _buildHelpItem(String action, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              action,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              description,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
