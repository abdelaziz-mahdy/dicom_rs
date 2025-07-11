import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:dicom_rs/dicom_rs.dart';
import '../models/complex_types.dart';

/// Widget to display the full DICOM metadata in a structured way
class MetadataViewer extends StatelessWidget {
  final DicomMetadataMap metadata;

  const MetadataViewer({super.key, required this.metadata});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [Tab(text: 'By Group'), Tab(text: 'All Tags')],
            labelColor: Colors.blue,
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Group view
                _buildGroupsView(),
                // Flat view
                _buildAllTagsView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupsView() {
    // Sort groups by number
    final groups = metadata.groupElements.keys.toList()..sort();

    return ListView.builder(
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final groupKey = groups[index];
        final groupElements = metadata.groupElements[groupKey]!;

        return ExpansionTile(
          title: Text('Group: $groupKey'),
          children:
              groupElements.entries.map((entry) {
                final tag = entry.value;
                return _buildTagRow(tag);
              }).toList(),
        );
      },
    );
  }

  Widget _buildAllTagsView() {
    // Sort tags by tag ID
    final allTags =
        metadata.tags.values.toList()..sort((a, b) => a.tag.compareTo(b.tag));

    return ListView.builder(
      itemCount: allTags.length,
      itemBuilder: (context, index) {
        return _buildTagRow(allTags[index]);
      },
    );
  }

  Widget _buildTagRow(DicomTag tag) {
    String valueText = '';

    switch (tag.value) {
      case DicomValueType_Str(:final field0):
        valueText = field0;
      case DicomValueType_Int(:final field0):
        valueText = field0.toString();
      case DicomValueType_Float(:final field0):
        valueText = field0.toString();
      case DicomValueType_StrList(:final field0):
        valueText = field0.join(', ');
      case DicomValueType_IntList(:final field0):
        valueText = field0.join(', ');
      case DicomValueType_FloatList(:final field0):
        valueText = field0.join(', ');
      case DicomValueType_Unknown():
        valueText = '<unknown>';
    }

    return ListTile(
      dense: true,
      title: Text(
        tag.name,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tag: ${tag.tag} | VR: ${tag.vr}',
            style: const TextStyle(fontSize: 12),
          ),
          Text(valueText),
        ],
      ),
      isThreeLine: true,
    );
  }
}
