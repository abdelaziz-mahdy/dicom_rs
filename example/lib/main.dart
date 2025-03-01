import 'dart:io';
import 'dart:typed_data';
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
  List<DicomDirectoryEntry> _dicomFiles = [];
  int _currentIndex = 0;
  bool _isLoading = false;
  Uint8List? _currentImageBytes;
  DicomMetadata? _currentMetadata;

  // Min and max values for windowing
  double _minValue = 0;
  double _maxValue = 255;

  Future<void> _pickDirectory() async {
    setState(() => _isLoading = true);

    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory != null) {
        // Load DICOM files from the selected directory
        final dicomFiles = await _dicomHandler.loadDirectoryRecursive(
          path: selectedDirectory,
        );

        setState(() {
          _dicomFiles = dicomFiles.where((entry) => entry.isValid).toList();
          _currentIndex = 0;
        });

        if (_dicomFiles.isNotEmpty) {
          await _loadDicomImage(_dicomFiles[0].path);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading directory: $e')));
    } finally {
      setState(() => _isLoading = false);
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
      _currentIndex = (_currentIndex + 1) % _dicomFiles.length;
    });

    _loadDicomImage(_dicomFiles[_currentIndex].path);
  }

  void _previousImage() {
    if (_dicomFiles.isEmpty) return;

    setState(() {
      _currentIndex =
          (_currentIndex - 1 + _dicomFiles.length) % _dicomFiles.length;
    });

    _loadDicomImage(_dicomFiles[_currentIndex].path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DICOM Viewer')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // Image display area
                  Expanded(
                    flex: 3,
                    child: Center(
                      child:
                          _currentImageBytes != null
                              ? Image.memory(_currentImageBytes!)
                              : const Text('No image loaded'),
                    ),
                  ),

                  // Metadata display
                  if (_currentMetadata != null)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Patient: ${_currentMetadata!.patientName ?? 'Unknown'}',
                          ),
                          Text(
                            'Study: ${_currentMetadata!.studyDescription ?? 'Unknown'}',
                          ),
                          Text(
                            'Series: ${_currentMetadata!.seriesDescription ?? 'Unknown'}',
                          ),
                          Text(
                            'Modality: ${_currentMetadata!.modality ?? 'Unknown'}',
                          ),
                        ],
                      ),
                    ),

                  // Min and Max sliders
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Text('Min: '),
                            Expanded(
                              child: Slider(
                                min: 0,
                                max: 255,
                                value: _minValue,
                                onChanged: (value) {
                                  setState(() {
                                    _minValue =
                                        value < _maxValue ? value : _minValue;
                                  });
                                  // In a real implementation, you would apply windowing here
                                },
                              ),
                            ),
                            Text(_minValue.toStringAsFixed(0)),
                          ],
                        ),
                        Row(
                          children: [
                            const Text('Max: '),
                            Expanded(
                              child: Slider(
                                min: 0,
                                max: 255,
                                value: _maxValue,
                                onChanged: (value) {
                                  setState(() {
                                    _maxValue =
                                        value > _minValue ? value : _maxValue;
                                  });
                                  // In a real implementation, you would apply windowing here
                                },
                              ),
                            ),
                            Text(_maxValue.toStringAsFixed(0)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Navigation controls
                  if (_dicomFiles.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.navigate_before),
                            onPressed: _previousImage,
                          ),
                          Text('${_currentIndex + 1} / ${_dicomFiles.length}'),
                          IconButton(
                            icon: const Icon(Icons.navigate_next),
                            onPressed: _nextImage,
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
