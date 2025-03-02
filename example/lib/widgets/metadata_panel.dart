import 'package:flutter/material.dart';
import 'package:dicom_rs/dicom_rs.dart';

/// A widget that displays DICOM metadata in a side panel
class MetadataPanel extends StatelessWidget {
  final DicomMetadata? metadata;
  final DicomFile? dicomFile;
  final DicomVolume? volume;
  final int currentSliceIndex;
  final int totalSlices;
  final DicomPatient? patient;
  final DicomStudy? study;
  final DicomSeries? series;
  final bool isCollapsed;
  final VoidCallback onTogglePanel;

  const MetadataPanel({
    super.key,
    this.metadata,
    this.dicomFile,
    this.volume,
    this.currentSliceIndex = 0,
    this.totalSlices = 0,
    this.patient,
    this.study,
    this.series,
    this.isCollapsed = false,
    required this.onTogglePanel,
  });

  @override
  Widget build(BuildContext context) {
    // If panel is collapsed, show only a narrow bar with toggle button
    if (isCollapsed) {
      return Container(
        width: 24,
        color: Theme.of(context).colorScheme.surfaceVariant,
        child: Column(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: onTogglePanel,
              tooltip: 'Show metadata panel',
            ),
            const Expanded(
              child: RotatedBox(
                quarterTurns: 1,
                child: Center(
                  child: Text(
                    'DICOM Metadata',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: 280,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with collapse button
          Container(
            color: Theme.of(context).colorScheme.primaryContainer,
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              children: [
                const Text(
                  'DICOM Metadata',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: onTogglePanel,
                  tooltip: 'Hide metadata panel',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Metadata content
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: _buildMetadataContent(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataContent() {
    if (dicomFile != null) {
      return _buildDicomFileMetadata();
    } else if (volume != null) {
      return _buildVolumeMetadata();
    } else if (metadata != null) {
      return _buildBasicMetadata();
    } else {
      return const Center(child: Text('No metadata available'));
    }
  }

  Widget _buildDicomFileMetadata() {
    final file = dicomFile!;
    final meta = file.metadata;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // File Information
        _buildSectionHeader('File Information'),
        _buildDetailItem('Path', file.path.split('/').last),
        _buildDetailItem('Multi-frame', file.isMultiframe ? 'Yes' : 'No'),
        if (file.isMultiframe)
          _buildDetailItem('Number of frames', file.numFrames.toString()),

        // Showing the current slice index if there are multiple slices
        if (totalSlices > 1)
          _buildDetailItem(
            'Current slice',
            '${currentSliceIndex + 1} of $totalSlices',
          ),

        const Divider(),

        // Patient Information
        _buildSectionHeader('Patient'),
        _buildDetailItem('Name', meta.patientName ?? 'Unknown'),
        _buildDetailItem('ID', meta.patientId ?? 'Unknown'),

        const Divider(),

        // Study Information
        _buildSectionHeader('Study'),
        _buildDetailItem('Date', meta.studyDate ?? 'Unknown'),
        _buildDetailItem('Description', meta.studyDescription ?? 'Unknown'),
        _buildDetailItem('Accession', meta.accessionNumber ?? 'Unknown'),
        _buildDetailItem('UID', _truncateUID(meta.studyInstanceUid)),

        const Divider(),

        // Series Information
        _buildSectionHeader('Series'),
        _buildDetailItem('Description', meta.seriesDescription ?? 'Unknown'),
        _buildDetailItem('Number', meta.seriesNumber?.toString() ?? 'Unknown'),
        _buildDetailItem('Modality', meta.modality ?? 'Unknown'),
        _buildDetailItem('UID', _truncateUID(meta.seriesInstanceUid)),

        const Divider(),

        // Instance Information
        _buildSectionHeader('Instance'),
        _buildDetailItem(
          'Number',
          meta.instanceNumber?.toString() ?? 'Unknown',
        ),
        _buildDetailItem('UID', _truncateUID(meta.sopInstanceUid)),

        const Divider(),

        // Spatial Information
        _buildSectionHeader('Spatial Information'),
        if (meta.imagePosition != null)
          _buildDetailItem('Position', _formatVector(meta.imagePosition!)),
        if (meta.sliceLocation != null)
          _buildDetailItem('Slice Location', meta.sliceLocation!.toString()),
        if (meta.sliceThickness != null)
          _buildDetailItem('Slice Thickness', meta.sliceThickness!.toString()),
        if (meta.pixelSpacing != null)
          _buildDetailItem('Pixel Spacing', _formatVector(meta.pixelSpacing!)),
      ],
    );
  }

  Widget _buildVolumeMetadata() {
    final vol = volume!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Volume Information
        _buildSectionHeader('Volume Information'),
        _buildDetailItem(
          'Dimensions',
          '${vol.width} × ${vol.height} × ${vol.depth}',
        ),
        _buildDetailItem(
          'Current slice',
          '${currentSliceIndex + 1} of ${vol.depth}',
        ),
        _buildDetailItem('Data Type', vol.dataType),
        _buildDetailItem('Components', vol.numComponents.toString()),

        const Divider(),

        // Spacing information
        _buildSectionHeader('Spacing'),
        _buildDetailItem(
          'X Spacing',
          vol.spacing.$1.toStringAsFixed(3) + ' mm',
        ),
        _buildDetailItem(
          'Y Spacing',
          vol.spacing.$2.toStringAsFixed(3) + ' mm',
        ),
        _buildDetailItem(
          'Z Spacing',
          vol.spacing.$3.toStringAsFixed(3) + ' mm',
        ),

        const Divider(),

        // Patient/Study/Series info if available
        _buildSectionHeader('Patient'),
        _buildDetailItem('Name', vol.metadata.patientName ?? 'Unknown'),
        _buildDetailItem('ID', vol.metadata!.patientId ?? 'Unknown'),
        const Divider(),

        _buildSectionHeader('Study'),
        _buildDetailItem('ID', vol.metadata!.studyId ?? 'Unknown'),
        _buildDetailItem(
          'Description',
          vol.metadata!.studyDescription ?? 'Unknown',
        ),
        _buildDetailItem(
          'truncated UID',
          _truncateUID(vol.metadata!.studyInstanceUid),
        ),
        _buildDetailItem("UID", vol.metadata!.studyInstanceUid),
        const Divider(),

        if (series != null) ...[
          _buildSectionHeader('Series'),
          _buildDetailItem(
            'Description',
            series!.seriesDescription ?? 'Unknown',
          ),
          _buildDetailItem('Modality', series!.modality ?? 'Unknown'),
          const Divider(),
        ],

        // First slice path
        if (vol.slices.isNotEmpty) ...[
          _buildSectionHeader('First Slice'),
          _buildDetailItem('Path', vol.slices.first.path.split('/').last),
        ],
      ],
    );
  }

  Widget _buildBasicMetadata() {
    final meta = metadata!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Patient Information
        _buildSectionHeader('Patient'),
        _buildDetailItem('Name', meta.patientName ?? 'Unknown'),
        _buildDetailItem('ID', meta.patientId ?? 'Unknown'),

        const Divider(),

        // Study Information
        _buildSectionHeader('Study'),
        _buildDetailItem('Date', meta.studyDate ?? 'Unknown'),
        _buildDetailItem('Description', meta.studyDescription ?? 'Unknown'),
        _buildDetailItem('Accession', meta.accessionNumber ?? 'Unknown'),
        _buildDetailItem('UID', _truncateUID(meta.studyInstanceUid)),

        const Divider(),

        // Series Information
        _buildSectionHeader('Series'),
        _buildDetailItem('Description', meta.seriesDescription ?? 'Unknown'),
        _buildDetailItem('Number', meta.seriesNumber?.toString() ?? 'Unknown'),
        _buildDetailItem('Modality', meta.modality ?? 'Unknown'),
        _buildDetailItem('UID', _truncateUID(meta.seriesInstanceUid)),

        const Divider(),

        // Instance Information
        _buildSectionHeader('Instance'),
        _buildDetailItem(
          'Number',
          meta.instanceNumber?.toString() ?? 'Unknown',
        ),
        _buildDetailItem('UID', _truncateUID(meta.sopInstanceUid)),

        // Current slice if multiple slices
        if (totalSlices > 1)
          _buildDetailItem(
            'Current slice',
            '${currentSliceIndex + 1} of $totalSlices',
          ),

        const Divider(),

        // Spatial Information
        _buildSectionHeader('Spatial Information'),
        if (meta.imagePosition != null)
          _buildDetailItem('Position', _formatVector(meta.imagePosition!)),
        if (meta.sliceLocation != null)
          _buildDetailItem('Slice Location', meta.sliceLocation!.toString()),
        if (meta.sliceThickness != null)
          _buildDetailItem('Slice Thickness', meta.sliceThickness!.toString()),
        if (meta.pixelSpacing != null)
          _buildDetailItem('Pixel Spacing', _formatVector(meta.pixelSpacing!)),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }

  Widget _buildDetailItem(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label + ':',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value ?? 'Unknown', softWrap: true)),
        ],
      ),
    );
  }

  String? _truncateUID(String? uid) {
    if (uid == null) return null;
    if (uid.length <= 20) return uid;
    return uid.substring(0, 10) + '...' + uid.substring(uid.length - 10);
  }

  String _formatVector(List<double> vector) {
    return vector.map((v) => v.toStringAsFixed(2)).join(', ');
  }
}
