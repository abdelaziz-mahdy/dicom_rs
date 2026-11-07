import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dicom_rs/dicom_rs.dart';
import 'package:path/path.dart' as path;
import '../screens/dicom_loading_screen.dart';
import 'dicom_isolate_validator.dart';

/// Service to handle platform-specific file selection
class FileSelectorService {
  /// Get platform-specific file picker configuration
  static _FilePickerConfig _getFilePickerConfig() {
    if (kIsWeb) {
      // Web: Allow all files (no extension filtering)
      return _FilePickerConfig(
        fileType: FileType.any,
        allowedExtensions: null,
        dialogTitle: 'Select Files (DICOM validation after selection)',
      );
    } else {
      // Native: Use extension filtering for better UX
      return _FilePickerConfig(
        fileType: FileType.custom,
        allowedExtensions: ['dcm', 'dicom', 'ima', 'DICOM'],
        dialogTitle: 'Select DICOM Files',
      );
    }
  }

  /// ULTRA-OPTIMIZED: Try to extract metadata directly - if successful, it's valid DICOM
  static Future<DicomFileData?> _tryExtractDicomMetadata(PlatformFile file, int fileIndex, int totalFiles) async {
    try {
      debugPrint('🚀 Processing file $fileIndex/$totalFiles: ${file.name}');
      
      // Reads from the path on native and from the browser's file on web.
      final bytes = await file.readAsBytes();
      
      // SINGLE PASS: Try to extract metadata directly - if this succeeds, it's valid DICOM!
      final handler = DicomHandler();
      final metadata = await handler.getMetadata(bytes); // This will throw if not valid DICOM
      
      debugPrint('✅ Valid DICOM file: ${file.name}');
      return DicomFileData(
        name: file.name,
        bytes: bytes,
        metadata: metadata, // Store the metadata we just extracted!
      );
    } catch (e) {
      debugPrint('❌ Invalid/unreadable file ${file.name}: $e');
      return null;
    }
  }

  /// ULTRA-OPTIMIZED: Single-pass metadata extraction for all files in parallel
  static Future<List<DicomFileData>> _validateAndFilterDicomFiles(
    List<PlatformFile> platformFiles
  ) async {
    debugPrint('🚀 ULTRA-OPTIMIZED: Single-pass metadata extraction for ${platformFiles.length} files in parallel...');
    
    // NO BATCHING - Process ALL files in parallel for maximum speed!
    final futures = platformFiles.asMap().entries.map(
      (entry) => _tryExtractDicomMetadata(entry.value, entry.key + 1, platformFiles.length)
    ).toList();
    
    // Wait for all files to process in parallel
    final results = await Future.wait(futures, eagerError: false);
    
    // Collect valid results
    final validDicomFiles = results.where((result) => result != null).cast<DicomFileData>().toList();
    
    debugPrint('✅ ULTRA-OPTIMIZED: Single-pass processing complete: ${validDicomFiles.length}/${platformFiles.length} valid DICOM files');
    return validDicomFiles;
  }
  /// Select multiple DICOM files using the universal file picker
  /// Returns a FileSelectorResult with file data for cross-platform compatibility
  /// On web: Allows all files, validates DICOM content after selection
  /// On native: Uses extension filtering for better UX
  static Future<FileSelectorResult?> selectDicomFiles() async {
    final config = _getFilePickerConfig();
    
    final files = await FilePicker.pickFiles(
      dialogTitle: config.dialogTitle,
      type: config.fileType,
      allowedExtensions: config.allowedExtensions,
    );

    if (files.isNotEmpty) {
      // Validate and filter DICOM files based on content
      final validDicomFiles = await _validateAndFilterDicomFiles(files);
      
      if (validDicomFiles.isNotEmpty) {
        return FileSelectorResult.files(validDicomFiles);
      }
    }
    return null;
  }

  /// Select a single DICOM file (works on all platforms)
  /// On web: Allows all files, validates DICOM content after selection
  /// On native: Uses extension filtering for better UX
  static Future<FileSelectorResult?> selectSingleDicomFile() async {
    final config = _getFilePickerConfig();
    
    final file = await FilePicker.pickFile(
      dialogTitle: config.dialogTitle.replaceAll('Files', 'File'),
      type: config.fileType,
      allowedExtensions: config.allowedExtensions,
    );

    if (file != null) {
      // Validate and filter DICOM files based on content
      final validDicomFiles = await _validateAndFilterDicomFiles([file]);
      
      if (validDicomFiles.isNotEmpty) {
        return FileSelectorResult.files(validDicomFiles);
      }
    }
    return null;
  }

  /// Select DICOM content - directories on native platforms, files on web
  /// Returns a FileSelectorResult with file data for cross-platform compatibility
  static Future<FileSelectorResult?> selectDicomContent() async {
    if (kIsWeb) {
      // Web: Use existing file selection with validation
      return selectDicomFiles();
    } else {
      // Native: Use directory selection
      return selectDicomDirectory();
    }
  }

  /// Select a directory containing DICOM files (native platforms only)
  /// Recursively scans directory and validates DICOM content
  static Future<FileSelectorResult?> selectDicomDirectory() async {
    if (kIsWeb) {
      throw UnsupportedError('Directory selection is not supported on web platforms');
    }

    debugPrint('📂 Starting directory selection...');

    try {
      final directoryPath = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select Directory Containing DICOM Files',
      );

      if (directoryPath != null) {
        debugPrint('📂 Selected directory: $directoryPath');
        final dicomFiles = await _scanDirectoryForDicomFiles(directoryPath);
        if (dicomFiles.isNotEmpty) {
          debugPrint('✅ Directory scan complete: ${dicomFiles.length} DICOM files found');
          return FileSelectorResult.directory(
            directoryPath: directoryPath,
            files: dicomFiles,
          );
        } else {
          debugPrint('❌ No valid DICOM files found in directory: $directoryPath');
        }
      } else {
        debugPrint('🚫 Directory selection cancelled by user');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error selecting directory: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      rethrow;
    }
    
    return null;
  }

  /// ISOLATE-OPTIMIZED: Directory scanning with CPU-core based validation
  static Future<List<DicomFileData>> _scanDirectoryForDicomFiles(String directoryPath) async {
    final directory = Directory(directoryPath);

    try {
      // Notify start of scanning
      DicomLoadingProgressNotifier.notify(
        DicomLoadingProgressEvent.scanning(directory: directoryPath),
      );

      // Collect ALL files for processing
      final allFiles = <File>[];
      await for (final entity in directory.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          allFiles.add(entity);
        }
      }
      
      debugPrint('🚀 ISOLATE-OPTIMIZED: Found ${allFiles.length} files, using ${Platform.numberOfProcessors} CPU cores for validation...');
      
      // Use isolate-based validation with RustLib initialization
      final dicomFiles = await DicomIsolateValidator.validateFilesWithIsolates(allFiles);
      
      debugPrint('✅ ISOLATE-OPTIMIZED: Directory scan complete: ${dicomFiles.length}/${allFiles.length} valid DICOM files');
      return dicomFiles;
      
    } catch (e) {
      debugPrint('Error scanning directory $directoryPath: $e');
      DicomLoadingProgressNotifier.notify(
        DicomLoadingProgressEvent.error('Error scanning directory: $e'),
      );
      return [];
    }
  }
  
  /// Get platform-appropriate UI configuration
  /// Web: File selection with validation, Native: Directory selection with file fallback
  static FileSelectorUIConfig getUIConfig() {
    if (kIsWeb) {
      return const FileSelectorUIConfig(
        primaryIcon: Icons.file_open_rounded,
        primaryLabel: 'Select Files',
        primaryTooltip: 'Select files (DICOM validation after selection)',
        helpText: 'Select files - DICOM content will be validated automatically',
        actionDescription: 'selecting files for DICOM validation',
        supportsDirectory: false,
      );
    } else {
      return const FileSelectorUIConfig(
        primaryIcon: Icons.folder_open_rounded,
        primaryLabel: 'Select DICOM Directory',
        primaryTooltip: 'Select a directory containing DICOM files',
        helpText: 'Select a directory containing DICOM files to get started',
        actionDescription: 'selecting DICOM directory',
        supportsDirectory: true,
        secondaryIcon: Icons.file_open_rounded,
        secondaryLabel: 'Select Individual Files',
        secondaryTooltip: 'Select individual DICOM files instead',
      );
    }
  }
}

/// DICOM file data with bytes, optional path, and pre-extracted metadata
class DicomFileData {
  final String name;
  final Uint8List bytes;
  final String? fullPath;
  final dynamic metadata; // Pre-extracted metadata to avoid duplicate processing

  const DicomFileData({
    required this.name,
    required this.bytes,
    this.fullPath,
    this.metadata,
  });
}

/// Result of file or directory selection operation
class FileSelectorResult {
  final List<DicomFileData> files;
  final String? directoryPath;
  final bool _isDirectory;

  const FileSelectorResult._({
    required this.files,
    this.directoryPath,
    bool isDirectory = false,
  }) : _isDirectory = isDirectory;

  /// Create result for file selection
  factory FileSelectorResult.files(List<DicomFileData> files) {
    return FileSelectorResult._(files: files);
  }

  /// Create result for directory selection
  factory FileSelectorResult.directory({
    required String directoryPath,
    required List<DicomFileData> files,
  }) {
    return FileSelectorResult._(
      files: files,
      directoryPath: directoryPath,
      isDirectory: true,
    );
  }

  /// Check if result has valid content
  bool get hasContent => files.isNotEmpty;

  /// Check if this result is from directory selection
  bool get isDirectory => _isDirectory;

  /// Get display name for the source
  String get sourceName {
    if (isDirectory && directoryPath != null) {
      return path.basename(directoryPath!);
    }
    return '${files.length} file${files.length != 1 ? 's' : ''}';
  }
}

/// Internal configuration for file picker
class _FilePickerConfig {
  final FileType fileType;
  final List<String>? allowedExtensions;
  final String dialogTitle;

  const _FilePickerConfig({
    required this.fileType,
    required this.allowedExtensions,
    required this.dialogTitle,
  });
}

/// UI configuration for platform-appropriate selection
/// Provides different options for web (files) vs native (directories + files)
class FileSelectorUIConfig {
  final IconData primaryIcon;
  final String primaryLabel;
  final String primaryTooltip;
  final String helpText;
  final String actionDescription;
  final bool supportsDirectory;
  final IconData? secondaryIcon;
  final String? secondaryLabel;
  final String? secondaryTooltip;

  const FileSelectorUIConfig({
    required this.primaryIcon,
    required this.primaryLabel,
    required this.primaryTooltip,
    required this.helpText,
    required this.actionDescription,
    this.supportsDirectory = false,
    this.secondaryIcon,
    this.secondaryLabel,
    this.secondaryTooltip,
  });

  /// Check if this config has secondary options
  bool get hasSecondaryOption => secondaryIcon != null && secondaryLabel != null;
}