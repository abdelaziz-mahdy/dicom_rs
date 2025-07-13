import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dicom_rs/dicom_rs.dart';
import 'package:path/path.dart' as path;

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

  /// Validate if file bytes represent a valid DICOM file
  static Future<bool> _isValidDicomContent(Uint8List bytes) async {
    try {
      final handler = DicomHandler();
      return await handler.isDicomFile(bytes);
    } catch (e) {
      return false;
    }
  }

  /// Filter and validate DICOM files after selection
  static Future<List<DicomFileData>> _validateAndFilterDicomFiles(
    List<PlatformFile> platformFiles
  ) async {
    final validDicomFiles = <DicomFileData>[];
    
    for (final file in platformFiles) {
      Uint8List bytes;
      if (file.bytes != null) {
        bytes = file.bytes!;
      } else if (file.path != null) {
        // Read file bytes on native platforms
        bytes = await File(file.path!).readAsBytes();
      } else {
        continue; // Skip if no bytes or path
      }
      
      // Validate DICOM content
      if (await _isValidDicomContent(bytes)) {
        validDicomFiles.add(DicomFileData(
          name: file.name,
          bytes: bytes,
        ));
      }
    }
    
    return validDicomFiles;
  }
  /// Select multiple DICOM files using the universal file picker
  /// Returns a FileSelectorResult with file data for cross-platform compatibility
  /// On web: Allows all files, validates DICOM content after selection
  /// On native: Uses extension filtering for better UX
  static Future<FileSelectorResult?> selectDicomFiles() async {
    final config = _getFilePickerConfig();
    
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: config.dialogTitle,
      type: config.fileType,
      allowedExtensions: config.allowedExtensions,
      allowMultiple: true,
      withReadStream: false, // Use bytes instead of streams for better performance
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      // Validate and filter DICOM files based on content
      final validDicomFiles = await _validateAndFilterDicomFiles(result.files);
      
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
    
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: config.dialogTitle.replaceAll('Files', 'File'),
      type: config.fileType,
      allowedExtensions: config.allowedExtensions,
      allowMultiple: false,
      withReadStream: false, // Use bytes instead of streams
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      // Validate and filter DICOM files based on content
      final validDicomFiles = await _validateAndFilterDicomFiles(result.files);
      
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

    final directoryPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Directory Containing DICOM Files',
    );

    if (directoryPath != null) {
      final dicomFiles = await _scanDirectoryForDicomFiles(directoryPath);
      if (dicomFiles.isNotEmpty) {
        return FileSelectorResult.directory(
          directoryPath: directoryPath,
          files: dicomFiles,
        );
      }
    }
    return null;
  }

  /// Recursively scan directory for DICOM files with validation
  static Future<List<DicomFileData>> _scanDirectoryForDicomFiles(String directoryPath) async {
    final dicomFiles = <DicomFileData>[];
    final directory = Directory(directoryPath);
    
    // DICOM file extensions to check
    const dicomExtensions = ['dcm', 'dicom', 'ima', 'DICOM'];

    try {
      await for (final entity in directory.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final extension = path.extension(entity.path).toLowerCase().replaceAll('.', '');
          
          // First check extension for performance
          if (dicomExtensions.map((e) => e.toLowerCase()).contains(extension)) {
            try {
              final bytes = await entity.readAsBytes();
              
              // Validate DICOM content
              if (await _isValidDicomContent(bytes)) {
                final fileName = path.basename(entity.path);
                dicomFiles.add(DicomFileData(
                  name: fileName,
                  bytes: bytes,
                  fullPath: entity.path,
                ));
              }
            } catch (e) {
              // Skip files that can't be read or validated
              debugPrint('Skipping file ${entity.path}: $e');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error scanning directory $directoryPath: $e');
    }

    return dicomFiles;
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

/// DICOM file data with bytes and optional path
class DicomFileData {
  final String name;
  final Uint8List bytes;
  final String? fullPath;

  const DicomFileData({
    required this.name,
    required this.bytes,
    this.fullPath,
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
