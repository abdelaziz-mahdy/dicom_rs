import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:dicom_rs/dicom_rs.dart';
import 'package:file_picker/file_picker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DICOM Viewer',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const DicomViewerScreen(),
    );
  }
}

class DicomViewerScreen extends StatefulWidget {
  const DicomViewerScreen({super.key});

  @override
  State<DicomViewerScreen> createState() => _DicomViewerScreenState();
}

class _DicomViewerScreenState extends State<DicomViewerScreen> {
  final DicomHandler _dicomHandler = DicomHandler();
  List<DicomPatient> _patients = [];
  DicomPatient? _selectedPatient;
  DicomStudy? _selectedStudy;
  DicomSeries? _selectedSeries;
  List<DicomDirectoryEntry> _dicomFiles = [];
  int _currentSliceIndex = 0;
  bool _isLoading = false;
  Uint8List? _currentImageBytes;
  DicomMetadata? _currentMetadata;
  String? _directoryPath;

  Future<void> _pickDirectory() async {
    setState(() => _isLoading = true);

    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory != null) {
        _directoryPath = selectedDirectory;

        // Use loadCompleteStudyRecursive to get a single study with propagated metadata
        final completeStudy = await _dicomHandler.loadCompleteStudyRecursive(
          path: selectedDirectory,
        );

        // Create patient wrapper for the UI
        final patient = DicomPatient(
          patientId: await _extractPatientIdFromStudy(completeStudy),
          patientName: await _extractPatientNameFromStudy(completeStudy),
          studies: [completeStudy],
        );

        setState(() {
          // Single patient with the complete study
          _patients = [patient];
          _selectedPatient = patient;
          _selectedStudy = completeStudy;

          if (_selectedStudy!.series.isNotEmpty) {
            _selectedSeries = _selectedStudy!.series.first;

            // Flatten the instances for the selected series
            _updateDicomFiles();

            // Load the first image if available
            if (_dicomFiles.isNotEmpty) {
              _currentSliceIndex = 0;
              _loadDicomImage(_dicomFiles[0].path);
            }
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading directory: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Extract patient ID from study - check all series and instances if needed
  Future<String?> _extractPatientIdFromStudy(DicomStudy study) async {
    for (final series in study.series) {
      for (final instance in series.instances) {
        if (instance.isValid) {
          try {
            final metadata = await _dicomHandler.getMetadata(path: instance.path);
            return metadata.patientId;
          } catch (_) {}
        }
      }
    }
    return null;
  }

  // Extract patient name from study - check all series and instances if needed
  Future<String?> _extractPatientNameFromStudy(DicomStudy study) async {
    for (final series in study.series) {
      for (final instance in series.instances) {
        if (instance.isValid) {
          try {
            final metadata = await _dicomHandler.getMetadata(path: instance.path);
            return metadata.patientName;
          } catch (_) {}
        }
      }
    }
    return null;
  }

  // Update the flattened file list when series selection changes
  void _updateDicomFiles() {
    if (_selectedSeries == null) return;

    final List<DicomDirectoryEntry> dicomEntries = [];

    // Use patient, study, and series information to populate all slices
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
      final imageBytes = await _dicomHandler.getImageBytes(path: path);
      final metadata = await _dicomHandler.getMetadata(path: path);

      setState(() {
        _currentImageBytes = imageBytes;
        _currentMetadata = metadata;
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

  void _handleScroll(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      if (event.scrollDelta.dy > 0) {
        _nextImage();
      } else if (event.scrollDelta.dy < 0) {
        _previousImage();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DICOM Viewer'),
        actions: [
          if (_directoryPath != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Dir: ${_directoryPath!.split('/').last}',
                style: const TextStyle(fontSize: 14),
              ),
            ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // Selector row for patient/study/series
                  if (_patients.isNotEmpty)
                    Padding(
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
                                        _selectedStudy?.series.isNotEmpty ??
                                                false
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
                                    String label =
                                        study.studyDescription ?? 'Unknown';
                                    if (study.studyDate != null) {
                                      label += ' (${study.studyDate})';
                                    }
                                    return DropdownMenuItem<DicomStudy>(
                                      value: study,
                                      child: Text(
                                        label,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList() ??
                                  [],
                              onChanged: (DicomStudy? study) {
                                if (study != null) {
                                  setState(() {
                                    _selectedStudy = study;
                                    _selectedSeries =
                                        study.series.isNotEmpty
                                            ? study.series.first
                                            : null;
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
                                    String label =
                                        series.seriesDescription ?? 'Unknown';
                                    if (series.modality != null) {
                                      label += ' (${series.modality})';
                                    }
                                    return DropdownMenuItem<DicomSeries>(
                                      value: series,
                                      child: Text(
                                        label,
                                        overflow: TextOverflow.ellipsis,
                                      ),
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
                    ),

                  // Image display area with scroll listener
                  Expanded(
                    flex: 3,
                    child: Listener(
                      onPointerSignal: _handleScroll,
                      child: Center(
                        child:
                            _currentImageBytes != null
                                ? Image.memory(
                                  _currentImageBytes!,
                                  gaplessPlayback: true,
                                )
                                : const Text('No image loaded'),
                      ),
                    ),
                  ),

                  // Enhanced metadata display
                  if (_currentMetadata != null)
                    Container(
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
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                'Date: ${_selectedStudy?.studyDate ?? 'Unknown'}',
                                style: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                ),
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
                              Text(
                                'Acc#: ${_selectedStudy?.accessionNumber ?? 'N/A'}',
                              ),
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.navigate_before),
                                onPressed: _previousImage,
                              ),
                              Text(
                                'Slice: ${_currentSliceIndex + 1} / ${_dicomFiles.length}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.navigate_next),
                                onPressed: _nextImage,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickDirectory,
        tooltip: 'Load DICOM Directory',
        child: const Icon(Icons.folder_open),
      ),
    );
  }
}
