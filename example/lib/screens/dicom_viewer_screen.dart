import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../presentation/widgets/clean_dicom_viewer.dart';
import '../presentation/controllers/dicom_viewer_controller.dart';
import '../presentation/controllers/image_interaction_controller.dart';
import '../domain/usecases/load_dicom_directory_usecase.dart';
import '../domain/entities/dicom_image_entity.dart';
import '../data/repositories/dicom_repository_impl.dart';
import '../core/app_log.dart';
import '../services/example_studies.dart';
import '../services/file_selector_service.dart';
import 'dicom_loading_screen.dart';

/// Modern DICOM viewer screen with clean architecture and enhanced UI/UX
class DicomViewerScreen extends StatefulWidget {
  const DicomViewerScreen({super.key});

  @override
  State<DicomViewerScreen> createState() => _DicomViewerScreenState();
}

class _DicomViewerScreenState extends State<DicomViewerScreen>
    with SingleTickerProviderStateMixin {
  late final DicomViewerController _controller;
  late final ImageInteractionController _interactionController;
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;

  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();

    // Setup animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Setup clean architecture dependencies
    final repository = DicomRepositoryImpl();
    final loadDirectoryUseCase = LoadDicomDirectoryUseCase(repository);

    _controller = DicomViewerController(
      loadDirectoryUseCase: loadDirectoryUseCase,
      repository: repository,
    );

    _interactionController = ImageInteractionController(
      enableScrollNavigation: true,
      enableKeyboardNavigation: true,
      enableBrightnessContrast: true,
      enableZoom: true,
      enableMeasurements: true,
    );

    // Listen to controller changes for animations
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _interactionController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (_controller.state.hasImages) {
      if (_isFirstLoad) {
        _animationController.forward();
        _isFirstLoad = false;
      }
      // Trigger a rebuild to show the viewer instead of welcome screen
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.grey[900],
      foregroundColor: Colors.white,
      elevation: 0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.cyan.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'DICOM',
              style: TextStyle(
                color: Colors.cyan,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Flexible(
            child: Text(
              'Medical Image Viewer',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
      actions: [
        // Show loading options only when no images are loaded
        if (!_controller.state.hasImages) ...[
          () {
            final config = FileSelectorService.getUIConfig();
            return IconButton(
              icon: Icon(config.primaryIcon),
              onPressed: _selectFiles,
              tooltip: config.primaryTooltip,
              style: IconButton.styleFrom(
                backgroundColor: Colors.cyan.withValues(alpha: 0.1),
                foregroundColor: Colors.cyan,
              ),
            );
          }(),
          IconButton(
            icon: const Icon(Icons.description_rounded),
            onPressed: _selectSingleFile,
            tooltip:
                kIsWeb
                    ? 'Select single file (DICOM validation after selection)'
                    : 'Select single DICOM file',
          ),
        ],
        // Show back and new directory buttons when images are loaded
        if (_controller.state.hasImages) ...[
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _goBackToWelcome,
            tooltip: 'Back to welcome',
            style: IconButton.styleFrom(
              backgroundColor: Colors.grey.withValues(alpha: 0.1),
              foregroundColor: Colors.grey[300],
            ),
          ),
          () {
            final config = FileSelectorService.getUIConfig();
            return IconButton(
              icon: Icon(config.primaryIcon),
              onPressed: _selectFiles,
              tooltip: config.primaryTooltip,
              style: IconButton.styleFrom(
                backgroundColor: Colors.cyan.withValues(alpha: 0.1),
                foregroundColor: Colors.cyan,
              ),
            );
          }(),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: _closeViewer,
            tooltip: 'Close viewer',
            style: IconButton.styleFrom(
              backgroundColor: Colors.red.withValues(alpha: 0.1),
              foregroundColor: Colors.red,
            ),
          ),
        ],
        IconButton(
          icon: const Icon(Icons.settings_rounded),
          onPressed: _showSettings,
          tooltip: 'Settings',
        ),
        if (_controller.state.hasImages)
          IconButton(
            icon: const Icon(Icons.info_rounded),
            onPressed: _showMetadata,
            tooltip: 'Show metadata',
            style: IconButton.styleFrom(
              backgroundColor: Colors.blue.withValues(alpha: 0.1),
              foregroundColor: Colors.blue,
            ),
          ),
        IconButton(
          icon: const Icon(Icons.info_outline_rounded),
          onPressed: _showAbout,
          tooltip: 'About',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBody() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.grey[900]!, const Color(0xFF0A0A0A)],
        ),
      ),
      child:
          _controller.state.hasImages
              ? FadeTransition(
                opacity: _fadeAnimation,
                child: CleanDicomViewer(
                  controller: _controller,
                  interactionController: _interactionController,
                  showControls: true,
                  showMeasurementToolbar: true,
                  enableHelpButton: true,
                ),
              )
              : _buildWelcomeScreen(),
    );
  }

  Widget _buildWelcomeScreen() {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Welcome icon
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.cyan.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.cyan.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.medical_information_rounded,
                  size: 64,
                  color: Colors.cyan,
                ),
              ),

              const SizedBox(height: 32),

              // Welcome text
              const Text(
                'Welcome to DICOM Viewer',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              Text(
                'Browse DICOM series, adjust brightness and contrast, and take '
                'measurements. Your files are opened on this device and never '
                'uploaded. Select a folder or files to get started.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 16,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // Quick start buttons
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: () {
                      final config = FileSelectorService.getUIConfig();
                      return ElevatedButton.icon(
                        onPressed: _selectFiles,
                        icon: Icon(config.primaryIcon),
                        label: Text(config.primaryLabel),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyan,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    }(),
                  ),

                  // Secondary button for native platforms
                  () {
                    final config = FileSelectorService.getUIConfig();
                    if (config.hasSecondaryOption) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _selectFilesAlternative,
                            icon: Icon(config.secondaryIcon),
                            label: Text(config.secondaryLabel!),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.cyan,
                              side: const BorderSide(color: Colors.cyan),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }(),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _showHelp,
                          icon: const Icon(Icons.help_outline_rounded),
                          label: const Text('Help'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.cyan,
                            side: const BorderSide(color: Colors.cyan),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _showExamples,
                          icon: const Icon(Icons.play_circle_outline_rounded),
                          label: const Text('Examples'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.cyan,
                            side: const BorderSide(color: Colors.cyan),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  _ExampleStudyPicker(onOpen: _openExample),
                ],
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  void _closeViewer() {
    _controller.reset();
    setState(() {
      _isFirstLoad = true;
    });
  }

  Future<void> _selectFiles() async {
    try {
      await _navigateToLoadingAndProcess(() async {
        debugPrint('📂 Starting directory/file selection...');

        final result = await FileSelectorService.selectDicomContent();
        debugPrint('📂 Selection result: ${result?.files.length ?? 0} files');

        if (result != null && result.hasContent) {
          debugPrint('📂 Loading ${result.files.length} files...');
          await _loadMultipleFiles(result.files);
          debugPrint('📂 Files loaded successfully');
        } else {
          final error = 'No files selected or no valid DICOM content found';
          debugPrint('❌ Selection failed: $error');
          throw Exception(error);
        }
      });
    } catch (e, stackTrace) {
      debugPrint('❌ _selectFiles error: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      if (mounted) {
        _showErrorSnackBar('Failed to select files: $e');
      }
    }
  }

  Future<void> _selectFilesAlternative() async {
    try {
      await _navigateToLoadingAndProcess(() async {
        debugPrint('📄 Starting individual files selection...');

        final result = await FileSelectorService.selectDicomFiles();
        debugPrint('📄 Selection result: ${result?.files.length ?? 0} files');

        if (result != null && result.hasContent) {
          debugPrint('📄 Loading ${result.files.length} files...');
          await _loadMultipleFiles(result.files);
          debugPrint('📄 Files loaded successfully');
        } else {
          final error = 'No files selected or no valid DICOM files found';
          debugPrint('❌ Selection failed: $error');
          throw Exception(error);
        }
      });
    } catch (e, stackTrace) {
      debugPrint('❌ _selectFilesAlternative error: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      if (mounted) {
        _showErrorSnackBar('Failed to select files: $e');
      }
    }
  }

  Future<void> _selectSingleFile() async {
    try {
      await _navigateToLoadingAndProcess(() async {
        debugPrint('📄 Starting single file selection...');

        final result = await FileSelectorService.selectSingleDicomFile();
        debugPrint('📄 Selection result: ${result?.files.length ?? 0} files');

        if (result != null && result.hasContent) {
          final fileData = result.files.first;
          debugPrint('📄 Loading single file: ${fileData.name}');
          await _loadSingleFileFromData(fileData);
          debugPrint('📄 Single file loaded successfully');
        } else {
          final error = 'No file selected or invalid DICOM file';
          debugPrint('❌ Selection failed: $error');
          throw Exception(error);
        }
      });
    } catch (e, stackTrace) {
      debugPrint('❌ _selectSingleFile error: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      if (mounted) {
        _showErrorSnackBar('Failed to select file: $e');
      }
    }
  }

  /// Navigate to loading screen and process the loading task
  Future<void> _navigateToLoadingAndProcess(
    Future<void> Function() loadingTask,
  ) async {
    if (!mounted) return;

    debugPrint('🚀 Starting navigation to loading screen...');

    // Start loading now; the loading screen waits on this future, so it sees
    // the outcome even if loading finishes before the screen is built.
    debugPrint('🔄 Starting loading task...');
    final task = Future<void>.microtask(loadingTask);
    unawaited(
      task.then(
        (_) => debugPrint('✅ Loading task completed successfully'),
        onError: (Object error, StackTrace stackTrace) {
          appLog.handle(error, stackTrace, 'Loading DICOM files failed');
        },
      ),
    );

    // Navigate to loading screen - this will block until loading is complete
    debugPrint('🔄 Pushing loading screen...');
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder:
            (context) => DicomLoadingScreen(
              task: task,
              onLoadingComplete: () {
                debugPrint('✅ Loading completed - popping screen with success');
                // Pop the loading screen when complete
                Navigator.of(context).pop(true);
              },
              onLoadingError: (error) {
                debugPrint('❌ Loading error received: $error');
                // Pop the loading screen with error
                Navigator.of(context).pop(false);
              },
              initialMessage: 'Preparing to load DICOM files...',
            ),
      ),
    );

    debugPrint('🔄 Loading screen returned with result: $result');

    // If loading was successful, trigger the UI update
    if (result == true && mounted) {
      debugPrint('✅ Loading successful - updating UI');
      setState(() {
        _isFirstLoad = false;
      });
      _animationController.forward();
    } else if (result == false && mounted) {
      debugPrint('❌ Loading failed - showing error');
      // Show error message if loading failed
      _showErrorSnackBar('Failed to load the DICOM files.');
    } else if (result == null && mounted) {
      debugPrint('🚫 Loading cancelled by user');
      // User cancelled the loading
    }
  }

  Future<void> _loadSingleFileFromData(DicomFileData fileData) async {
    try {
      debugPrint('📄 Loading single file: ${fileData.name}');
      debugPrint('📄 File size: ${fileData.bytes.length} bytes');

      await _controller.loadSingleFileFromData(fileData);

      if (mounted && _controller.state.hasImages) {
        debugPrint('✅ Single DICOM file loaded successfully');
        _showSuccessSnackBar('DICOM file loaded successfully');
      } else {
        final error = 'No images found in the selected file';
        debugPrint('❌ $error');
        _showErrorSnackBar(error);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to load single DICOM file: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      if (mounted) {
        _showErrorSnackBar('Failed to load DICOM file: $e');
      }
      rethrow; // Re-throw to be caught by the navigation handler
    }
  }

  Future<void> _loadMultipleFiles(List<DicomFileData> files) async {
    try {
      debugPrint('📄 Loading ${files.length} files...');
      for (int i = 0; i < files.length && i < 5; i++) {
        debugPrint(
          '📄 File $i: ${files[i].name} (${files[i].bytes.length} bytes)',
        );
      }
      if (files.length > 5) {
        debugPrint('📄 ... and ${files.length - 5} more files');
      }

      // Load files from DicomFileData list (bytes-based)
      await _controller.loadFromFileDataList(files);

      if (mounted && _controller.state.hasImages) {
        debugPrint(
          '✅ ${_controller.state.images.length} DICOM files loaded successfully from ${files.length} files',
        );
        _showSuccessSnackBar(
          _controller.state.images.length == 1
              ? '1 DICOM file loaded'
              : '${_controller.state.images.length} DICOM files loaded',
        );
      } else {
        final error = 'No valid DICOM images found in ${files.length} files';
        debugPrint('❌ $error');
        throw Exception(error);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to load multiple DICOM files: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      if (mounted) {
        _showErrorSnackBar('Failed to load DICOM files: $e');
      }
      rethrow; // Re-throw to be caught by the navigation handler
    }
  }

  /// Legacy directory loading - deprecated
  /// Use FileSelectorService.selectDicomFiles() instead

  void _showSettings() {
    showDialog(
      context: context,
      builder:
          (context) =>
              _SettingsDialog(interactionController: _interactionController),
    );
  }

  void _showHelp() {
    showDialog(context: context, builder: (context) => _HelpDialog());
  }

  void _showExamples() {
    showDialog(
      context: context,
      builder: (context) => _ExamplesDialog(onOpen: _openExample),
    );
  }

  /// Opens one of the bundled example studies in the viewer.
  Future<void> _openExample(ExampleStudy study) async {
    try {
      await _navigateToLoadingAndProcess(() async {
        final files = await study.load();
        await _loadMultipleFiles(files);
        // Before the loading screen closes, so the viewer opens on this slice.
        if (_controller.state.hasImages) {
          _controller.goToImage(study.startSlice - 1);
        }
      });
    } catch (e, stackTrace) {
      appLog.handle(e, stackTrace, 'Opening the ${study.title} example failed');
      if (mounted) {
        _showErrorSnackBar('Could not open the ${study.title} example.');
      }
    }
  }

  void _showMetadata() {
    if (!_controller.state.hasImages) return;

    showDialog(
      context: context,
      builder:
          (context) => _MetadataDialog(
            metadata: _controller.state.currentImage?.metadata,
            imageName: _controller.state.currentImage?.name ?? '',
            imageIndex: _controller.state.currentIndex + 1,
            totalImages: _controller.state.totalImages,
          ),
    );
  }

  void _goBackToWelcome() {
    _controller.reset();
    setState(() {
      _isFirstLoad = true;
    });
    _animationController.reset();
  }

  void _showAbout() {
    showDialog(context: context, builder: (context) => _AboutDialog());
  }

  /// Keeps messages above the viewer's slice controls instead of covering
  /// the slice counter and navigation buttons.
  EdgeInsets get _snackBarMargin =>
      EdgeInsets.fromLTRB(16, 0, 16, _controller.state.hasImages ? 88 : 16);

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        margin: _snackBarMargin,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        margin: _snackBarMargin,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        // The details are in the in-app log, not only in a developer console.
        action: SnackBarAction(
          label: 'View logs',
          textColor: Colors.white,
          onPressed: () => showAppLogs(context),
        ),
      ),
    );
  }
}

/// Enhanced settings dialog with better UX
class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog({required this.interactionController});

  final ImageInteractionController interactionController;

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  late bool _enableScrollNavigation;
  late bool _enableKeyboardNavigation;
  late bool _enableBrightnessContrast;
  late bool _enableZoom;
  late bool _enableMeasurements;

  @override
  void initState() {
    super.initState();
    _enableScrollNavigation =
        widget.interactionController.enableScrollNavigation;
    _enableKeyboardNavigation =
        widget.interactionController.enableKeyboardNavigation;
    _enableBrightnessContrast =
        widget.interactionController.enableBrightnessContrast;
    _enableZoom = widget.interactionController.enableZoom;
    _enableMeasurements = widget.interactionController.enableMeasurements;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.cyan.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.settings_rounded,
                    color: Colors.cyan,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Interaction Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            const Divider(color: Colors.cyan),
            const SizedBox(height: 24),

            // Settings
            _buildSettingCard(
              Icons.mouse_rounded,
              'Mouse Navigation',
              'Navigate slices with mouse wheel',
              _enableScrollNavigation,
              (value) => setState(() => _enableScrollNavigation = value),
            ),

            _buildSettingCard(
              Icons.keyboard_rounded,
              'Keyboard Navigation',
              'Navigate slices with arrow keys',
              _enableKeyboardNavigation,
              (value) => setState(() => _enableKeyboardNavigation = value),
            ),

            _buildSettingCard(
              Icons.tune_rounded,
              'Image Adjustments',
              'Adjust brightness/contrast with right-click drag',
              _enableBrightnessContrast,
              (value) => setState(() => _enableBrightnessContrast = value),
            ),

            _buildSettingCard(
              Icons.zoom_in_rounded,
              'Zoom Controls',
              'Enable pinch-to-zoom gestures',
              _enableZoom,
              (value) => setState(() => _enableZoom = value),
            ),

            _buildSettingCard(
              Icons.straighten_rounded,
              'Measurement Tools',
              'Enable distance, angle, and area measurements',
              _enableMeasurements,
              (value) => setState(() => _enableMeasurements = value),
            ),

            const SizedBox(height: 24),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[400],
                  ),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    // Apply settings would be implemented here
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyan,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingCard(
    IconData icon,
    String title,
    String description,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[800]?.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? Colors.cyan.withValues(alpha: 0.3) : Colors.grey[700]!,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: value ? Colors.cyan : Colors.grey[400], size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.cyan,
          ),
        ],
      ),
    );
  }
}

/// Help dialog with comprehensive usage instructions
class _HelpDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        height: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.cyan.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.help_outline_rounded,
                    color: Colors.cyan,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'DICOM Viewer Help',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            const Divider(color: Colors.cyan),
            const SizedBox(height: 16),

            // Help content (scrollable)
            const Expanded(
              child: SingleChildScrollView(
                child: Text(
                  'Navigation:\n'
                  '• Use the arrow keys, the mouse wheel or a two-finger swipe to change slice\n'
                  '• Click the image counter to jump to a specific slice\n'
                  '• Use fast forward/rewind buttons for quick navigation\n\n'
                  'Image Adjustments:\n'
                  '• Right-drag or Shift + drag to adjust brightness and contrast\n'
                  '• Use the reset button to restore brightness, contrast and zoom\n\n'
                  'Measurements:\n'
                  '• Select a measurement tool from the toolbar\n'
                  '• Click points on the image to create measurements\n'
                  '• Toggle visibility or clear all measurements as needed\n\n'
                  'Zoom & Pan:\n'
                  '• Drag the image to move it\n'
                  '• Pinch, or hold Ctrl/⌘ and scroll, to zoom at the pointer\n\n'
                  'Keyboard:\n'
                  '• ← → or ↑ ↓ Change slice',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Close button
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Got it!'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The app's version, passed by the release workflow with
/// `--dart-define=APP_VERSION=<version>`.
const _appVersionDefine = String.fromEnvironment('APP_VERSION');
String get _appVersion =>
    _appVersionDefine.isEmpty
        ? 'Development build'
        : 'Version $_appVersionDefine';

/// Buttons that open the bundled example studies, shown on the welcome screen
/// so people without their own DICOM files can try the viewer.
class _ExampleStudyPicker extends StatelessWidget {
  const _ExampleStudyPicker({required this.onOpen});

  final ValueChanged<ExampleStudy> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'No DICOM files at hand? Open an example',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final study in ExampleStudy.all)
              ActionChip(
                avatar: Icon(study.icon, size: 18, color: Colors.cyan),
                label: Text(study.title),
                tooltip: '${study.details}\nSource: ${study.source}',
                onPressed: () => onOpen(study),
                backgroundColor: Colors.cyan.withValues(alpha: 0.08),
                side: BorderSide(color: Colors.cyan.withValues(alpha: 0.4)),
                labelStyle: const TextStyle(color: Colors.white),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'De-identified research images, ${ExampleStudy.license}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Examples dialog: example studies to open, then common workflows.
class _ExamplesDialog extends StatelessWidget {
  const _ExamplesDialog({required this.onOpen});

  final ValueChanged<ExampleStudy> onOpen;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.cyan.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.play_circle_outline_rounded,
                      color: Colors.cyan,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Examples',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(color: Colors.cyan),
              const SizedBox(height: 16),

              const Text(
                'Open an example study',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'De-identified research images from the NCI Imaging Data '
                'Commons, licensed ${ExampleStudy.license}.',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
              const SizedBox(height: 12),

              for (final study in ExampleStudy.all)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ExampleStudyTile(
                    study: study,
                    onOpen: () {
                      Navigator.of(context).pop();
                      onOpen(study);
                    },
                  ),
                ),

              const SizedBox(height: 16),
              const Text(
                'Common workflows',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '1. Basic viewing\n'
                '   • Select one or more DICOM files\n'
                '   • Navigate through slices with arrow keys or mouse\n'
                '   • Adjust brightness/contrast with right-click drag\n\n'
                '2. Taking measurements\n'
                '   • Select a measurement tool from the toolbar\n'
                '   • Click points on the image to measure\n'
                '   • View calculated distances and angles\n\n'
                '3. Multi-file analysis\n'
                '   • Select multiple DICOM files at once\n'
                '   • Use fast navigation between images\n'
                '   • Keep consistent window/level settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One example study in the Examples dialog.
class _ExampleStudyTile extends StatelessWidget {
  const _ExampleStudyTile({required this.study, required this.onOpen});

  final ExampleStudy study;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.grey[850],
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.cyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(study.icon, color: Colors.cyan),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      study.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      study.details,
                      style: TextStyle(color: Colors.grey[300], fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${study.source} · ${study.sourceUrl.replaceFirst('https://', '')}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: 'Open ${study.title}',
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.cyan,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// About dialog with app information
class _AboutDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // App icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.cyan.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.medical_information_rounded,
                color: Colors.cyan,
                size: 48,
              ),
            ),

            const SizedBox(height: 24),

            // App info
            const Text(
              'DICOM Viewer',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              _appVersion,
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),

            const SizedBox(height: 24),

            Text(
              'DICOM viewer built with Flutter and Rust on the dicom_rs '
              'package. Files are opened on this device and never uploaded.\n\n'
              'Not for diagnostic use.',
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                // The in-app log, for bug reports and when something fails.
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    showAppLogs(context);
                  },
                  icon: const Icon(Icons.receipt_long_rounded),
                  label: const Text('View logs'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.cyan,
                    side: const BorderSide(color: Colors.cyan),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyan,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Metadata dialog displaying DICOM information
class _MetadataDialog extends StatelessWidget {
  const _MetadataDialog({
    required this.metadata,
    required this.imageName,
    required this.imageIndex,
    required this.totalImages,
  });

  final DicomMetadataEntity? metadata;
  final String imageName;
  final int imageIndex;
  final int totalImages;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.info_rounded,
                    color: Colors.blue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DICOM Metadata',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Image $imageIndex of $totalImages',
                        style: TextStyle(color: Colors.grey[400], fontSize: 14),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(color: Colors.blue),
            const SizedBox(height: 16),

            // File path
            _buildInfoRow('File Name', imageName),

            const SizedBox(height: 16),

            // Metadata content
            Expanded(
              child:
                  metadata != null
                      ? SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSection('Patient Information', [
                              _buildMetadataRow(
                                'Patient Name',
                                metadata!.patientName,
                              ),
                              _buildMetadataRow(
                                'Patient ID',
                                metadata!.patientId,
                              ),
                            ]),

                            const SizedBox(height: 24),

                            _buildSection('Study Information', [
                              _buildMetadataRow(
                                'Study Date',
                                metadata!.studyDate,
                              ),
                              _buildMetadataRow(
                                'Study Description',
                                metadata!.studyDescription,
                              ),
                              _buildMetadataRow(
                                'Study Instance UID',
                                metadata!.studyInstanceUid,
                              ),
                            ]),

                            const SizedBox(height: 24),

                            _buildSection('Series Information', [
                              _buildMetadataRow(
                                'Series Number',
                                metadata!.seriesNumber?.toString(),
                              ),
                              _buildMetadataRow(
                                'Series Description',
                                metadata!.seriesDescription,
                              ),
                              _buildMetadataRow(
                                'Series Instance UID',
                                metadata!.seriesInstanceUid,
                              ),
                              _buildMetadataRow('Modality', metadata!.modality),
                            ]),

                            const SizedBox(height: 24),

                            _buildSection('Image Information', [
                              _buildMetadataRow(
                                'Instance Number',
                                metadata!.instanceNumber?.toString(),
                              ),
                              _buildMetadataRow(
                                'SOP Instance UID',
                                metadata!.sopInstanceUid,
                              ),
                              _buildMetadataRow(
                                'Image Position',
                                _formatList(metadata!.imagePosition),
                              ),
                              _buildMetadataRow(
                                'Pixel Spacing',
                                _formatList(metadata!.pixelSpacing),
                              ),
                              _buildMetadataRow(
                                'Slice Location',
                                metadata!.sliceLocation?.toString(),
                              ),
                              _buildMetadataRow(
                                'Slice Thickness',
                                metadata!.sliceThickness?.toString(),
                              ),
                            ]),
                          ],
                        ),
                      )
                      : const Center(
                        child: Text(
                          'No metadata available',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      ),
            ),

            const SizedBox(height: 16),

            // Close button
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isPath = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[800]?.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.blue,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFamily: isPath ? 'monospace' : null,
              ),
              maxLines: isPath ? 3 : 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.blue,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildMetadataRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'N/A',
              style: TextStyle(
                color: value != null ? Colors.white : Colors.grey[600],
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _formatList(List<double>? list) {
    if (list == null || list.isEmpty) return null;
    return list.map((e) => e.toStringAsFixed(3)).join(', ');
  }
}
