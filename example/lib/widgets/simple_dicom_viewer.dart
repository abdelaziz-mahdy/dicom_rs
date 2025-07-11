import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:dicom_rs/dicom_rs.dart';
import '../services/dicom_service_simple.dart';

/// A simple DICOM viewer widget using the minimal package API
class SimpleDicomViewer extends StatefulWidget {
  final List<String> dicomPaths;
  final bool showControls;

  const SimpleDicomViewer({
    super.key,
    required this.dicomPaths,
    this.showControls = true,
  });

  @override
  State<SimpleDicomViewer> createState() => _SimpleDicomViewerState();
}

class _SimpleDicomViewerState extends State<SimpleDicomViewer> {
  int _currentIndex = 0;
  List<Uint8List> _imageBytes = [];
  List<DicomFile> _dicomFiles = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDicomFiles();
  }

  Future<void> _loadDicomFiles() async {
    if (widget.dicomPaths.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load DICOM files using the minimal API
      _dicomFiles = await DicomServiceSimple.loadMultipleFiles(widget.dicomPaths);
      
      if (_dicomFiles.isNotEmpty) {
        // Get image bytes for display
        final imagePaths = _dicomFiles.map((f) => f.path).toList();
        _imageBytes = await DicomServiceSimple.getMultipleImageBytes(imagePaths);
        
        // Sort files by instance number for proper ordering
        _dicomFiles = DicomServiceSimple.sortByInstanceNumber(_dicomFiles);
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load DICOM files: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _nextImage() {
    if (_imageBytes.isNotEmpty && _currentIndex < _imageBytes.length - 1) {
      setState(() {
        _currentIndex++;
      });
    }
  }

  void _previousImage() {
    if (_imageBytes.isNotEmpty && _currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading DICOM files...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadDicomFiles,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_imageBytes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('No valid DICOM images found'),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Image display area
        Expanded(
          child: Container(
            width: double.infinity,
            color: Colors.black,
            child: Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5.0,
                child: Image.memory(
                  _imageBytes[_currentIndex],
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('Failed to display image', style: TextStyle(color: Colors.grey)),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),

        // DICOM metadata panel
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[100],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DICOM Information',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildMetadataRow('Patient', _dicomFiles[_currentIndex].metadata.patientName ?? 'Unknown'),
              _buildMetadataRow('Modality', _dicomFiles[_currentIndex].metadata.modality ?? 'Unknown'),
              _buildMetadataRow('Study Date', _dicomFiles[_currentIndex].metadata.studyDate ?? 'Unknown'),
              _buildMetadataRow('Series', _dicomFiles[_currentIndex].metadata.seriesDescription ?? 'Unknown'),
              if (_dicomFiles[_currentIndex].metadata.instanceNumber != null)
                _buildMetadataRow('Instance', _dicomFiles[_currentIndex].metadata.instanceNumber.toString()),
            ],
          ),
        ),

        // Navigation controls
        if (widget.showControls && _imageBytes.length > 1)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.navigate_before),
                  onPressed: _currentIndex > 0 ? _previousImage : null,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${_imageBytes.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.navigate_next),
                  onPressed: _currentIndex < _imageBytes.length - 1 ? _nextImage : null,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMetadataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

/// A statistics widget showing DICOM file information
class DicomStatsWidget extends StatelessWidget {
  final List<DicomFile> files;

  const DicomStatsWidget({super.key, required this.files});

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No DICOM files loaded'),
        ),
      );
    }

    final stats = DicomServiceSimple.getBasicStats(files);
    final organizedByPatient = DicomServiceSimple.organizeByPatient(files);
    final organizedByModality = DicomServiceSimple.organizeByModality(files);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DICOM Statistics',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildStatRow('Total Files', stats['totalFiles'].toString()),
            _buildStatRow('Images with Pixel Data', stats['imagesWithPixelData'].toString()),
            _buildStatRow('Unique Patients', stats['uniquePatients'].toString()),
            _buildStatRow('Unique Modalities', stats['uniqueModalities'].toString()),
            const SizedBox(height: 12),
            Text(
              'Patients:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            ...organizedByPatient.entries.map((entry) => 
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 2),
                child: Text('• ${entry.key} (${entry.value.length} files)'),
              )
            ),
            const SizedBox(height: 8),
            Text(
              'Modalities:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            ...organizedByModality.entries.map((entry) => 
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 2),
                child: Text('• ${entry.key} (${entry.value.length} files)'),
              )
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.black87),
          ),
        ],
      ),
    );
  }
}