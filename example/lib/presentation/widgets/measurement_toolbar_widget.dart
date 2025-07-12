import 'package:flutter/material.dart';
import '../../domain/entities/measurement_entity.dart';

/// Clean measurement toolbar widget
class MeasurementToolbarWidget extends StatelessWidget {
  const MeasurementToolbarWidget({
    super.key,
    required this.selectedTool,
    required this.onToolSelected,
    required this.onClearMeasurements,
    required this.onToggleVisibility,
    required this.measurementsVisible,
    required this.measurementCount,
  });

  final MeasurementType? selectedTool;
  final Function(MeasurementType?) onToolSelected;
  final VoidCallback onClearMeasurements;
  final VoidCallback onToggleVisibility;
  final bool measurementsVisible;
  final int measurementCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(
          bottom: BorderSide(color: Colors.cyan.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          // Measurement tools
          ...MeasurementType.values.map((type) => _buildToolButton(type)),
          
          const Spacer(),
          
          // Controls
          IconButton(
            icon: Icon(
              measurementsVisible ? Icons.visibility : Icons.visibility_off,
              color: Colors.cyan,
            ),
            onPressed: onToggleVisibility,
            tooltip: measurementsVisible ? 'Hide measurements' : 'Show measurements',
          ),
          
          IconButton(
            icon: const Icon(Icons.clear_all, color: Colors.red),
            onPressed: measurementCount > 0 ? onClearMeasurements : null,
            tooltip: 'Clear all measurements',
          ),
          
          // Measurement count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.cyan.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$measurementCount',
              style: const TextStyle(color: Colors.cyan, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton(MeasurementType type) {
    final isSelected = selectedTool == type;
    
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: isSelected ? Colors.cyan.withValues(alpha: 0.3) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onToolSelected(isSelected ? null : type),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? Colors.cyan : Colors.grey.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getIconForType(type),
                  size: 16,
                  color: isSelected ? Colors.cyan : Colors.white70,
                ),
                const SizedBox(width: 6),
                Text(
                  type.displayName,
                  style: TextStyle(
                    color: isSelected ? Colors.cyan : Colors.white70,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconForType(MeasurementType type) {
    return switch (type) {
      MeasurementType.distance => Icons.straighten,
      MeasurementType.angle => Icons.architecture,
      MeasurementType.circle => Icons.circle_outlined,
      MeasurementType.area => Icons.crop_free,
    };
  }
}