import 'package:flutter/material.dart';
import 'dart:async';

/// Enhanced loading screen that shows detailed progress for DICOM file loading
class DicomLoadingScreen extends StatefulWidget {
  const DicomLoadingScreen({
    super.key,
    required this.onLoadingComplete,
    required this.onLoadingError,
    this.initialMessage = 'Preparing to load DICOM files...',
  });

  final VoidCallback onLoadingComplete;
  final void Function(String error) onLoadingError;
  final String initialMessage;

  @override
  State<DicomLoadingScreen> createState() => _DicomLoadingScreenState();
}

class _DicomLoadingScreenState extends State<DicomLoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _pulseController;
  late Animation<double> _progressAnimation;
  late Animation<double> _pulseAnimation;

  int _filesProcessed = 0;
  int _totalFiles = 0;
  String _currentMessage = '';
  String _currentFileName = '';
  bool _isScanning = true;
  
  StreamSubscription? _progressSubscription;

  @override
  void initState() {
    super.initState();
    
    _currentMessage = widget.initialMessage;
    
    // Setup animations
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start pulse animation
    _pulseController.repeat(reverse: true);
    
    // Listen to global loading progress events
    _listenToLoadingProgress();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pulseController.dispose();
    _progressSubscription?.cancel();
    super.dispose();
  }

  void _listenToLoadingProgress() {
    // Listen to loading progress events from the global stream
    _progressSubscription = DicomLoadingProgressNotifier.stream.listen((event) {
      if (!mounted) return;
      
      setState(() {
        _currentMessage = event.message;
        _currentFileName = event.currentFile ?? '';
        _filesProcessed = event.filesProcessed;
        _totalFiles = event.totalFiles;
        _isScanning = event.isScanning;
      });

      // Update progress animation
      if (_totalFiles > 0) {
        final progress = _filesProcessed / _totalFiles;
        _progressController.animateTo(progress);
      }

      // Handle completion
      if (event.isComplete) {
        _handleLoadingComplete();
      } else if (event.error != null) {
        widget.onLoadingError(event.error!);
      }
    });
  }

  void _handleLoadingComplete() async {
    // Complete the progress animation
    await _progressController.forward();
    
    // Show completion briefly
    setState(() {
      _currentMessage = 'Loading complete!';
    });
    
    // Wait a moment then notify completion
    await Future.delayed(const Duration(milliseconds: 800));
    widget.onLoadingComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey[900]!, const Color(0xFF0A0A0A)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Loading icon with pulse animation
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
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
                    );
                  },
                ),

                const SizedBox(height: 48),

                // Main title
                const Text(
                  'Loading DICOM Files',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                // Current message
                Text(
                  _currentMessage,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                // Progress section
                if (_totalFiles > 0) ...[
                  // Progress bar
                  Container(
                    width: double.infinity,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: AnimatedBuilder(
                      animation: _progressAnimation,
                      builder: (context, child) {
                        return FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: _progressAnimation.value,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.cyan,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Progress text
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$_filesProcessed of $_totalFiles files',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${(_totalFiles > 0 ? (_filesProcessed / _totalFiles * 100) : 0).round()}%',
                        style: const TextStyle(
                          color: Colors.cyan,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ] else if (_isScanning) ...[
                  // Scanning indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.cyan),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Scanning for DICOM files...',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 24),

                // Current file name (if available)
                if (_currentFileName.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[800]?.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.cyan.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Processing:',
                          style: TextStyle(
                            color: Colors.cyan,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentFileName,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 48),

                // Tips section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[900]?.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey[700]!,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline_rounded,
                            color: Colors.yellow[600],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Loading Tips',
                            style: TextStyle(
                              color: Colors.yellow[600],
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '• Large directories may take longer to scan\n'
                        '• DICOM validation ensures file compatibility\n'
                        '• Files are processed in parallel for speed\n'
                        '• Progress is saved during loading',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Global progress notification system for DICOM loading
class DicomLoadingProgressNotifier {
  static final StreamController<DicomLoadingProgressEvent> _controller =
      StreamController<DicomLoadingProgressEvent>.broadcast();

  static Stream<DicomLoadingProgressEvent> get stream => _controller.stream;

  static void notify(DicomLoadingProgressEvent event) {
    _controller.add(event);
  }

  static void dispose() {
    _controller.close();
  }
}

/// Event class for loading progress updates
class DicomLoadingProgressEvent {
  const DicomLoadingProgressEvent({
    required this.message,
    this.currentFile,
    this.filesProcessed = 0,
    this.totalFiles = 0,
    this.isScanning = false,
    this.isComplete = false,
    this.error,
  });

  final String message;
  final String? currentFile;
  final int filesProcessed;
  final int totalFiles;
  final bool isScanning;
  final bool isComplete;
  final String? error;

  /// Create scanning event
  factory DicomLoadingProgressEvent.scanning({String? directory}) {
    return DicomLoadingProgressEvent(
      message: directory != null 
          ? 'Scanning directory: ${directory.split('/').last}'
          : 'Scanning for DICOM files...',
      isScanning: true,
    );
  }

  /// Create file processing event
  factory DicomLoadingProgressEvent.processing({
    required String fileName,
    required int processed,
    required int total,
  }) {
    return DicomLoadingProgressEvent(
      message: 'Processing DICOM files...',
      currentFile: fileName,
      filesProcessed: processed,
      totalFiles: total,
    );
  }

  /// Create validation event
  factory DicomLoadingProgressEvent.validating({
    required String fileName,
    required int processed,
    required int total,
  }) {
    return DicomLoadingProgressEvent(
      message: 'Validating DICOM content...',
      currentFile: fileName,
      filesProcessed: processed,
      totalFiles: total,
    );
  }

  /// Create completion event
  factory DicomLoadingProgressEvent.completed({required int totalLoaded}) {
    return DicomLoadingProgressEvent(
      message: 'Successfully loaded $totalLoaded DICOM files!',
      isComplete: true,
    );
  }

  /// Create error event
  factory DicomLoadingProgressEvent.error(String error) {
    return DicomLoadingProgressEvent(
      message: 'Loading failed',
      error: error,
    );
  }
}