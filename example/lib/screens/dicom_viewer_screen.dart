import 'dart:typed_data';
import 'package:dicom_rs_example/widgets/volume_viewer.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dicom_rs/dicom_rs.dart';

import '../models/load_method.dart';
import '../services/dicom_service.dart';
import '../widgets/metadata_viewer.dart';
import '../widgets/image_viewer.dart';

class DicomViewerScreen extends StatefulWidget {
  const DicomViewerScreen({super.key});

  @override
  State<DicomViewerScreen> createState() => _DicomViewerScreenState();
}

class _DicomViewerScreenState extends State<DicomViewerScreen> {
  final DicomService _dicomService = DicomService();

  // Loading state
  bool _isLoading = false;
  String? _directoryPath;
  DicomLoadMethod _selectedLoadMethod = DicomLoadMethod.LoadDicomFile;

  // Patient/Study/Series data
  List<DicomPatient> _patients = [];
  DicomPatient? _selectedPatient;
  DicomStudy? _selectedStudy;
  DicomSeries? _selectedSeries;

  // Instance data for viewing
  List<DicomDirectoryEntry> _dicomFiles = [];
  int _currentSliceIndex = 0;

  // Current image and metadata
  Uint8List? _currentImageBytes;
  DicomMetadata? _currentMetadata;
  DicomMetadataMap? _currentAllMetadata;

  // Volume data (if loaded as volume)
  DicomVolume? _loadedVolume;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DICOM Viewer'),
        leading:
            _directoryPath != null
                ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back to loading options',
                  onPressed: _resetViewer,
                )
                : null,
        actions: [
          // Directory path indicator
          if (_directoryPath != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Dir: ${_directoryPath!.split('/').last}',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          // Metadata button
          if (_currentImageBytes != null)
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'Show Full Metadata',
              onPressed: _showFullMetadata,
            ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // Load method selector
                  if (_directoryPath == null) _buildLoadMethodSelector(),

                  // Patient/study/series selectors
                  if (_patients.isNotEmpty) _buildSelectors(),

                  // Image viewer
                  Expanded(
                    flex: 3,
                    child: DicomImageViewer(
                      imageBytes: _currentImageBytes,
                      currentIndex: _currentSliceIndex,
                      totalImages: _dicomFiles.length,
                      onNext: _nextImage,
                      onPrevious: _previousImage,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child:
                        _loadedVolume != null
                            ? VolumeViewer(volume: _loadedVolume!)
                            : DicomImageViewer(
                              imageBytes: _currentImageBytes,
                              currentIndex: _currentSliceIndex,
                              totalImages: _dicomFiles.length,
                              onNext: _nextImage,
                              onPrevious: _previousImage,
                            ),
                  ),

                  // Metadata display
                  if (_currentMetadata != null) _buildMetadataDisplay(),
                ],
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickDirectory,
        tooltip: 'Load DICOM Directory',
        child: const Icon(Icons.folder_open),
      ),
    );
  }

  Widget _buildLoadMethodSelector() {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select DICOM Loading Method:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children:
                  DicomLoadMethod.values.map((method) {
                    return ChoiceChip(
                      label: Text(method.description),
                      selected: _selectedLoadMethod == method,
                      onSelected: (bool selected) {
                        if (selected) {
                          setState(() {
                            _selectedLoadMethod = method;
                          });
                        }
                      },
                      avatar: Icon(
                        IconData(
                          int.parse(
                            '0xe${method.icon.hashCode.toString().substring(0, 3)}',
                          ),
                          fontFamily: 'MaterialIcons',
                        ),
                      ),
                    );
                  }).toList(),
            ),
            const SizedBox(height: 16),
            const Text(
              'Click the folder button to select a DICOM directory.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectors() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          // Patient selector
          Expanded(
            child: DropdownButton<DicomPatient>(
              isExpanded: true,
              value: _selectedPatient,
              hint: const Text('Select Patient'),
              items:
                  _patients.map((patient) {
                    return DropdownMenuItem<DicomPatient>(
                      value: patient,
                      child: Text(
                        '${patient.patientName ?? 'Unknown'} (${patient.patientId ?? 'No ID'})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
              onChanged: (DicomPatient? patient) {
                if (patient != null) {
                  setState(() {
                    _selectedPatient = patient;
                    _selectedStudy =
                        patient.studies.isNotEmpty
                            ? patient.studies.first
                            : null;
                    _selectedSeries =
                        _selectedStudy?.series.isNotEmpty ?? false
                            ? _selectedStudy!.series.first
                            : null;
                    _updateDicomFiles();
                  });
                }
              },
            ),
          ),
          const SizedBox(width: 8),

          // Study selector
          Expanded(
            child: DropdownButton<DicomStudy>(
              isExpanded: true,
              value: _selectedStudy,
              hint: const Text('Select Study'),
              items:
                  _selectedPatient?.studies.map((study) {
                    String label = study.studyDescription ?? 'Unknown';
                    if (study.studyDate != null) {
                      label += ' (${study.studyDate})';
                    }
                    return DropdownMenuItem<DicomStudy>(
                      value: study,
                      child: Text(label, overflow: TextOverflow.ellipsis),
                    );
                  }).toList() ??
                  [],
              onChanged: (DicomStudy? study) {
                if (study != null) {
                  setState(() {
                    _selectedStudy = study;
                    _selectedSeries =
                        study.series.isNotEmpty ? study.series.first : null;
                    _updateDicomFiles();
                  });
                }
              },
            ),
          ),
          const SizedBox(width: 8),

          // Series selector
          Expanded(
            child: DropdownButton<DicomSeries>(
              isExpanded: true,
              value: _selectedSeries,
              hint: const Text('Select Series'),
              items:
                  _selectedStudy?.series.map((series) {
                    String label = series.seriesDescription ?? 'Unknown';
                    if (series.modality != null) {
                      label += ' (${series.modality})';
                    }
                    return DropdownMenuItem<DicomSeries>(
                      value: series,
                      child: Text(label, overflow: TextOverflow.ellipsis),
                    );
                  }).toList() ??
                  [],
              onChanged: (DicomSeries? series) {
                if (series != null) {
                  setState(() {
                    _selectedSeries = series;
                    _updateDicomFiles();
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataDisplay() {
    return Container(
      color: Colors.grey[200],
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Patient: ${_selectedPatient?.patientName ?? 'Unknown'} (${_selectedPatient?.patientId ?? 'No ID'})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                'Date: ${_selectedStudy?.studyDate ?? 'Unknown'}',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Study: ${_selectedStudy?.studyDescription ?? 'Unknown'}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text('Acc#: ${_selectedStudy?.accessionNumber ?? 'N/A'}'),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Series: ${_selectedSeries?.seriesDescription ?? 'Unknown'}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                'Modality: ${_selectedSeries?.modality ?? 'Unknown'}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickDirectory() async {
    setState(() => _isLoading = true);

    try {
      /// if the method is load file then pick file
      if (_selectedLoadMethod == DicomLoadMethod.LoadDicomFile) {
        final result = await FilePicker.platform.pickFiles(
          allowMultiple: false,
          type: FileType.custom,
          allowedExtensions: ['dcm'],
        );
        if (result != null && result.files.isNotEmpty) {
          final file = result.files.first;
          final path = file.path;
          if (path != null) {
            final result = await _dicomService.loadDicomData(
              path: path,
              method: _selectedLoadMethod,
            );
            await _processLoadResult(result);
          }
        }
      } else {
        String? selectedDirectory =
            await FilePicker.platform.getDirectoryPath();

        if (selectedDirectory != null) {
          _directoryPath = selectedDirectory;

          final result = await _dicomService.loadDicomData(
            path: selectedDirectory,
            method: _selectedLoadMethod,
          );

          await _processLoadResult(result);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading directory: $e')));
      print(e);
      _directoryPath = null;
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _processLoadResult(DicomLoadResult result) async {
    // Reset state
    setState(() {
      _patients = [];
      _selectedPatient = null;
      _selectedStudy = null;
      _selectedSeries = null;
      _dicomFiles = [];
      _currentSliceIndex = 0;
      _currentImageBytes = null;
      _currentMetadata = null;
      _currentAllMetadata = null;
      _loadedVolume = null;
    });

    // Handle different result types
    if (result is StudyLoadResult) {
      await _processStudyResult(result.study);
    } else if (result is DirectoryLoadResult) {
      await _processDirectoryResult(result.entries);
    } else if (result is VolumeLoadResult) {
      _processVolumeResult(result.volume);
    }
  }

  Future<void> _processStudyResult(DicomStudy study) async {
    // Create patient wrapper for the UI
    final patient = DicomPatient(
      patientId: await _dicomService.extractPatientIdFromStudy(study),
      patientName: await _dicomService.extractPatientNameFromStudy(study),
      studies: [study],
    );

    setState(() {
      // Single patient with the complete study
      _patients = [patient];
      _selectedPatient = patient;
      _selectedStudy = study;

      if (study.series.isNotEmpty) {
        _selectedSeries = study.series.first;
        _updateDicomFiles();

        // Load the first image if available
        if (_dicomFiles.isNotEmpty) {
          _currentSliceIndex = 0;
          _loadDicomImage(_dicomFiles[0].path);
        }
      }
    });
  }

  Future<void> _processDirectoryResult(
    List<DicomDirectoryEntry> entries,
  ) async {
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No DICOM files found in the selected directory'),
        ),
      );
      return;
    }

    // Just load the first image to display something
    setState(() {
      _dicomFiles = entries;
      _currentSliceIndex = 0;
    });

    await _loadDicomImage(entries[0].path);

    // Maybe implement a way to organize flat entries into patient/study/series
    // For now just show a simple view for directory loading method
  }

  void _processVolumeResult(DicomVolume volume) {
    setState(() {
      _loadedVolume = volume;
    });

    // For now just display a message that we loaded a volume
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Loaded 3D volume: ${volume.width}x${volume.height}x${volume.depth} pixels',
        ),
      ),
    );

    // Here you would normally integrate with a 3D viewer library
    // For now we'll just show a message and the first slice
  }

  void _updateDicomFiles() {
    if (_selectedSeries == null) return;

    final List<DicomDirectoryEntry> dicomEntries = [];

    for (final instance in _selectedSeries!.instances) {
      if (instance.isValid) {
        // Create a DicomDirectoryEntry for each instance with propagated metadata
        dicomEntries.add(
          DicomDirectoryEntry(
            path: instance.path,
            metadata: DicomMetadata(
              // Study-level information shared across slices
              patientName: _selectedPatient?.patientName,
              patientId: _selectedPatient?.patientId,
              studyDate: _selectedStudy?.studyDate,
              studyDescription: _selectedStudy?.studyDescription,
              accessionNumber: _selectedStudy?.accessionNumber,
              studyInstanceUid: _selectedStudy?.studyInstanceUid,

              // Series-level information
              seriesDescription: _selectedSeries?.seriesDescription,
              modality: _selectedSeries?.modality,
              seriesNumber: _selectedSeries?.seriesNumber,
              seriesInstanceUid: _selectedSeries?.seriesInstanceUid,

              // Instance-specific information
              instanceNumber: instance.instanceNumber,
              sopInstanceUid: instance.sopInstanceUid,

              // Spatial information
              imagePosition: instance.imagePosition,
              sliceLocation: instance.sliceLocation,
            ),
            isValid: instance.isValid,
          ),
        );
      }
    }

    setState(() {
      _dicomFiles = dicomEntries;
      _currentSliceIndex = 0;
    });

    if (_dicomFiles.isNotEmpty) {
      _loadDicomImage(_dicomFiles[0].path);
    }
  }

  Future<void> _loadDicomImage(String path) async {
    try {
      final imageBytes = await _dicomService.getImageBytes(path: path);
      final metadata = await _dicomService.getMetadata(path: path);
      final allMetadata = await _dicomService.getAllMetadata(path: path);

      setState(() {
        _currentImageBytes = imageBytes;
        _currentMetadata = metadata;
        _currentAllMetadata = allMetadata;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading image: $e')));
    }
  }

  void _nextImage() {
    if (_dicomFiles.isEmpty) return;

    setState(() {
      _currentSliceIndex = (_currentSliceIndex + 1) % _dicomFiles.length;
    });

    _loadDicomImage(_dicomFiles[_currentSliceIndex].path);
  }

  void _previousImage() {
    if (_dicomFiles.isEmpty) return;

    setState(() {
      _currentSliceIndex =
          (_currentSliceIndex - 1 + _dicomFiles.length) % _dicomFiles.length;
    });

    _loadDicomImage(_dicomFiles[_currentSliceIndex].path);
  }

  void _showFullMetadata() {
    if (_currentAllMetadata == null) return;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'DICOM Metadata - Slice ${_currentSliceIndex + 1}/${_dicomFiles.length}',
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.8,
              child: MetadataViewer(metadata: _currentAllMetadata!),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  // Reset the viewer state to show the loading options again
  void _resetViewer() {
    setState(() {
      _directoryPath = null;
      _patients = [];
      _selectedPatient = null;
      _selectedStudy = null;
      _selectedSeries = null;
      _dicomFiles = [];
      _currentSliceIndex = 0;
      _currentImageBytes = null;
      _currentMetadata = null;
      _currentAllMetadata = null;
      _loadedVolume = null;
    });
  }
}
