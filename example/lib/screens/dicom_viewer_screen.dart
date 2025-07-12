import 'dart:typed_data';
import 'package:dicom_rs_example/widgets/volume_viewer.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dicom_rs/dicom_rs.dart';

import '../models/load_method.dart';
import '../models/complex_types.dart';
import '../services/dicom_service.dart';
import '../services/lazy_image_service.dart';
import '../widgets/metadata_viewer.dart';
import '../widgets/image_viewer.dart';
import '../widgets/metadata_panel.dart';
import '../widgets/dicom_viewer_base.dart';

class DicomViewerScreen extends StatefulWidget {
  const DicomViewerScreen({super.key});

  @override
  State<DicomViewerScreen> createState() => _DicomViewerScreenState();
}

class _DicomViewerScreenState extends State<DicomViewerScreen> {
  final DicomService _dicomService = DicomService();
  late final LazyImageService _lazyImageService;

  // Loading state
  bool _isLoading = false;
  String? _directoryPath;
  DicomLoadMethod _selectedLoadMethod = DicomLoadMethod.loadDicomFile;

  // Progress tracking for volume loading
  int _loadingProgress = 0;
  int _totalFiles = 0;
  bool _showProgress = false;

  // Patient/Study/Series data
  List<DicomPatient> _patients = [];
  DicomPatient? _selectedPatient;
  DicomStudy? _selectedStudy;
  DicomSeries? _selectedSeries;

  // Instance data for viewing
  List<DicomDirectoryEntry> _dicomFiles = [];
  List<Uint8List?> _imageBytesList = [];
  int _currentSliceIndex = 0;

  // Current metadata
  DicomMetadata? _currentMetadata;
  DicomMetadataMap? _currentAllMetadata;

  // Volume data (if loaded as volume)
  DicomVolume? _loadedVolume;

  // Current viewer
  DicomViewerBase? _currentViewer;
  GlobalKey<DicomViewerBaseState> _viewerKey = GlobalKey();

  // Metadata panel state
  bool _isMetadataPanelCollapsed = false;

  @override
  void initState() {
    super.initState();
    _lazyImageService = LazyImageService(
      dicomService: _dicomService,
      preloadBuffer: 3, // Load 3 images ahead/behind
    );
  }

  @override
  void dispose() {
    _lazyImageService.dispose();
    super.dispose();
  }

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
          if (_currentViewer != null)
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'Show Full Metadata',
              onPressed: _showFullMetadata,
            ),
        ],
      ),
      body:
          _showProgress
              ? _buildProgressIndicator()
              : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _directoryPath == null
              ? _buildLoadMethodSelector()
              : _buildMainLayout(),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickDirectory,
        tooltip: 'Load DICOM Directory',
        child: const Icon(Icons.folder_open),
      ),
    );
  }

  // New method to build the main layout with side panel
  Widget _buildMainLayout() {
    return Column(
      children: [
        // Patient/study/series selectors at the top
        if (_patients.isNotEmpty) _buildSelectors(),

        // Main content area with metadata panel and viewer
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left side: Metadata Panel
              if (_currentMetadata != null || _loadedVolume != null)
                MetadataPanel(
                  metadata: _currentMetadata,
                  dicomFile: null,
                  volume: _loadedVolume,
                  currentSliceIndex:
                      _viewerKey.currentState?.getCurrentSliceIndex() ??
                      _currentSliceIndex,
                  totalSlices:
                      _viewerKey.currentState?.getTotalSlices() ??
                      (_loadedVolume?.depth ?? _imageBytesList.length),
                  patient: _selectedPatient,
                  study: _selectedStudy,
                  series: _selectedSeries,
                  isCollapsed: _isMetadataPanelCollapsed,
                  onTogglePanel: _toggleMetadataPanel,
                ),

              // Right side: Content area with unified viewer
              Expanded(
                child: Column(
                  children: [
                    // Main viewer area with unified interface
                    Expanded(
                      child:
                          _currentViewer ??
                          const Center(child: Text('No DICOM data loaded')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Toggle metadata panel expanded/collapsed state
  void _toggleMetadataPanel() {
    setState(() {
      _isMetadataPanelCollapsed = !_isMetadataPanelCollapsed;
    });
  }

  Widget _buildProgressIndicator() {
    final double percentComplete =
        _totalFiles > 0 ? (_loadingProgress / _totalFiles * 100) : 0.0;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            value: _totalFiles > 0 ? _loadingProgress / _totalFiles : null,
          ),
          const SizedBox(height: 20),
          Text(
            'Loading 3D Volume...',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Text(
            '$_loadingProgress of $_totalFiles slices (${percentComplete.toStringAsFixed(1)}%)',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMethodSelector() {
    return Center(
      child: Card(
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

  Future<void> _pickDirectory() async {
    setState(() {
      _isLoading = true;
      _showProgress = false;
    });

    try {
      /// if the method is load file then pick file
      if (_selectedLoadMethod == DicomLoadMethod.loadDicomFile) {
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

          // For volume loading, enable progress tracking
          if (_selectedLoadMethod == DicomLoadMethod.volume) {
            setState(() {
              _showProgress = true;
              _loadingProgress = 0;
              _totalFiles = 0;
              _isLoading = false;
            });
          }

          final result = await _dicomService.loadDicomData(
            path: selectedDirectory,
            method: _selectedLoadMethod,
            onProgress:
                _selectedLoadMethod == DicomLoadMethod.volume
                    ? _updateProgress
                    : null,
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
      setState(() {
        _isLoading = false;
        _showProgress = false;
      });
    }
  }

  void _updateProgress(int current, int total) {
    setState(() {
      _loadingProgress = current;
      _totalFiles = total;
    });
  }

  Future<void> _processLoadResult(DicomLoadResult result) async {
    // Reset state
    setState(() {
      _patients = [];
      _selectedPatient = null;
      _selectedStudy = null;
      _selectedSeries = null;
      _dicomFiles = [];
      _imageBytesList = [];
      _currentSliceIndex = 0;
      _currentMetadata = null;
      _currentAllMetadata = null;
      _loadedVolume = null;
      _currentViewer = null;
      _viewerKey = GlobalKey();
      _isMetadataPanelCollapsed = false;
    });

    // Handle different result types
    if (result is StudyLoadResult) {
      await _processStudyResult(result.study);
    } else if (result is DirectoryLoadResult) {
      await _processDirectoryResult(result.entries);
    } else if (result is VolumeLoadResult) {
      _processVolumeResult(result.volume);
    } else if (result is DicomFileLoadResult) {
      _processDicomFileResult(result.file);
    }
  }

  // Process DICOM file result with unified viewer
  void _processDicomFileResult(DicomFile file) async {
    final imageBytes = await _dicomService.getImageBytes(file.path);

    setState(() {
      _currentMetadata = file.metadata;
      _dicomFiles = [
        DicomDirectoryEntry(
          path: file.path,
          metadata: file.metadata,
          isValid: true,
        ),
      ];
      _imageBytesList = [imageBytes];
      _currentSliceIndex = 0;

      // Create the viewer with the file data
      _currentViewer = DicomImageViewer(
        key: _viewerKey,
        imageBytesList: _imageBytesList,
        pixelSpacing: _currentMetadata?.pixelSpacing,
        onSliceChanged: _onSliceChanged,
      );
    });
  }

  void _processVolumeResult(DicomVolume volume) {
    setState(() {
      _loadedVolume = volume;
      // // Try to extract metadata from the first slice if available
      // if (volume.slices.isNotEmpty) {
      //   _loadDicomImageMetadataOnly(volume.slices.first.path);
      // }

      // Create the volume viewer
      _currentViewer = VolumeViewer(key: _viewerKey, volume: volume);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Loaded 3D volume: ${volume.width}x${volume.height}x${volume.depth} pixels',
        ),
      ),
    );
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

    setState(() {
      _dicomFiles = entries;
      _currentSliceIndex = 0;
    });

    // Load all images for the image viewer
    _imageBytesList = List.filled(entries.length, null);

    // Load the first image immediately
    _imageBytesList[0] = await _dicomService.getImageBytes(entries[0].path);
    final metadata = await _dicomService.getMetadata(path: entries[0].path);
    final allMetadata = await _dicomService.getAllMetadata(
      path: entries[0].path,
    );

    setState(() {
      _currentMetadata = metadata;
      _currentAllMetadata = allMetadata;

      // Create the image viewer
      _currentViewer = DicomImageViewer(
        key: _viewerKey,
        imageBytesList: _imageBytesList,
        pixelSpacing: _currentMetadata?.pixelSpacing,
        onSliceChanged: _onSliceChanged,
      );
    });

    // Initialize lazy loading for this method as well
    if (entries.length > 1) {
      final dicomEntries = entries.map((entry) => DicomDirectoryEntry(
        path: entry.path,
        metadata: entry.metadata,
        isValid: true,
      )).toList();
      
      _lazyImageService.initialize(dicomEntries);
      await _lazyImageService.updateCurrentIndex(0);
    }
  }

  // Update the study result processing to use the unified viewer
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
      }
    });
  }

  // Update for the unified viewer approach
  void _updateDicomFiles() async {
    if (_selectedSeries == null) return;

    final List<DicomDirectoryEntry> dicomEntries = [];

    for (final instance in _selectedSeries!.instances) {
      if (instance.isValid) {
        dicomEntries.add(
          DicomDirectoryEntry(
            path: instance.path,
            metadata: DicomMetadata(
              // Study-level information shared across slices
              patientName: _selectedPatient?.patientName,
              patientId: _selectedPatient?.patientId,
              studyDate: _selectedStudy?.studyDate,
              studyDescription: _selectedStudy?.studyDescription,
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
      _imageBytesList = List.filled(dicomEntries.length, null);
      _currentSliceIndex = 0;
    });

    if (_dicomFiles.isNotEmpty) {
      // Initialize lazy loading service
      _lazyImageService.initialize(_dicomFiles);
      
      // Load first image and create viewer
      final firstBytes = await _lazyImageService.getImageAt(0);
      final metadata = await _dicomService.getMetadata(
        path: _dicomFiles[0].path,
      );
      final allMetadata = await _dicomService.getAllMetadata(
        path: _dicomFiles[0].path,
      );

      setState(() {
        _imageBytesList[0] = firstBytes;
        _currentMetadata = metadata;
        _currentAllMetadata = allMetadata;

        // Create image viewer with lazy loading support
        _currentViewer = DicomImageViewer(
          key: _viewerKey,
          imageBytesList: _imageBytesList,
          pixelSpacing: _currentMetadata?.pixelSpacing,
          onSliceChanged: _onSliceChanged,
        );
      });

      // Preload surrounding images
      await _lazyImageService.updateCurrentIndex(0);
    }
  }

  // Handle slice changes for lazy loading
  void _onSliceChanged(int newIndex) async {
    _currentSliceIndex = newIndex;
    
    // Update lazy loading service
    await _lazyImageService.updateCurrentIndex(newIndex);
    
    // Load the image if not already loaded
    final imageBytes = await _lazyImageService.getImageAt(newIndex);
    
    if (mounted && imageBytes != null) {
      setState(() {
        _imageBytesList[newIndex] = imageBytes;
      });
    }
  }

  // Reset the viewer state
  void _resetViewer() {
    setState(() {
      _directoryPath = null;
      _patients = [];
      _selectedPatient = null;
      _selectedStudy = null;
      _selectedSeries = null;
      _dicomFiles = [];
      _imageBytesList = [];
      _currentSliceIndex = 0;
      _currentMetadata = null;
      _currentAllMetadata = null;
      _loadedVolume = null;
      _currentViewer = null;
      _viewerKey = GlobalKey();
      _isMetadataPanelCollapsed = false;
    });
  }

  // Show full metadata dialog
  void _showFullMetadata() {
    if (_currentAllMetadata == null) return;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'DICOM Metadata - Slice ${(_viewerKey.currentState?.getCurrentSliceIndex() ?? 0) + 1}/' +
                  '${_viewerKey.currentState?.getTotalSlices() ?? (_loadedVolume?.depth ?? _imageBytesList.length)}',
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

  // Keep other methods as they are
  // ... existing code ...
}
