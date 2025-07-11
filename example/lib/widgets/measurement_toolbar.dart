import 'package:flutter/material.dart';
import '../models/measurement_models.dart';

/// Toolbar for measurement tools and controls
class MeasurementToolbar extends StatelessWidget {
  final MeasurementType? selectedTool;
  final Function(MeasurementType?) onToolSelected;
  final VoidCallback? onClearMeasurements;
  final VoidCallback? onToggleMeasurements;
  final bool measurementsVisible;
  final int measurementCount;

  const MeasurementToolbar({
    super.key,
    this.selectedTool,
    required this.onToolSelected,
    this.onClearMeasurements,
    this.onToggleMeasurements,
    this.measurementsVisible = true,
    this.measurementCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Distance measurement tool
          _buildToolButton(
            icon: Icons.straighten,
            label: 'Distance',
            tool: MeasurementType.distance,
            tooltip: 'Measure distance between two points',
          ),
          
          const SizedBox(width: 4),
          
          // Angle measurement tool
          _buildToolButton(
            icon: Icons.architecture,
            label: 'Angle',
            tool: MeasurementType.angle,
            tooltip: 'Measure angle between three points',
          ),
          
          const SizedBox(width: 4),
          
          // Circle measurement tool
          _buildToolButton(
            icon: Icons.circle_outlined,
            label: 'Circle',
            tool: MeasurementType.circle,
            tooltip: 'Measure circle radius and area',
          ),
          
          const SizedBox(width: 8),
          
          // Separator
          Container(
            width: 1,
            height: 30,
            color: Colors.grey.withOpacity(0.3),
          ),
          
          const SizedBox(width: 8),
          
          // Toggle measurements visibility
          if (onToggleMeasurements != null)
            IconButton(
              icon: Icon(
                measurementsVisible ? Icons.visibility : Icons.visibility_off,
                size: 20,
              ),
              onPressed: onToggleMeasurements,
              tooltip: measurementsVisible 
                  ? 'Hide measurements' 
                  : 'Show measurements',
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(4),
                minimumSize: const Size(32, 32),
              ),
            ),
          
          // Clear all measurements
          if (onClearMeasurements != null && measurementCount > 0)
            IconButton(
              icon: const Icon(Icons.clear_all, size: 20),
              onPressed: onClearMeasurements,
              tooltip: 'Clear all measurements',
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(4),
                minimumSize: const Size(32, 32),
              ),
            ),
          
          // Measurement count indicator
          if (measurementCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$measurementCount',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required MeasurementType tool,
    required String tooltip,
  }) {
    final isSelected = selectedTool == tool;
    
    return GestureDetector(
      onTap: () => onToolSelected(isSelected ? null : tool),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected 
              ? Colors.blue.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isSelected 
              ? Border.all(color: Colors.blue, width: 1)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.blue : Colors.grey[600],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.blue : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}