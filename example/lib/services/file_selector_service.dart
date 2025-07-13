import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

/// Service to handle platform-specific file selection
class FileSelectorService {
  /// Select DICOM files or directory based on platform capabilities
  /// Returns a FileSelectorResult with either directory path or file list
  static Future<FileSelectorResult?> selectDicomFiles() async {
    if (kIsWeb) {
      // Web: Select multiple files
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select DICOM Files',
        type: FileType.custom,
        allowedExtensions: ['dcm', 'dicom', 'ima', 'DICOM'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        return FileSelectorResult.files(result.files);
      }
    } else {
      // Native: Select directory
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select DICOM Directory',
      );

      if (result != null) {
        return FileSelectorResult.directory(result);
      }
    }
    return null;
  }

  /// Select a single DICOM file (works on all platforms)
  static Future<FileSelectorResult?> selectSingleDicomFile() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select DICOM File',
      type: FileType.custom,
      allowedExtensions: ['dcm', 'dicom', 'ima', 'DICOM'],
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      return FileSelectorResult.files(result.files);
    }
    return null;
  }

  /// Get platform-specific UI configuration
  static FileSelectorUIConfig getUIConfig() {
    if (kIsWeb) {
      return const FileSelectorUIConfig(
        primaryIcon: Icons.file_open_rounded,
        primaryLabel: 'Select DICOM Files',
        primaryTooltip: 'Select DICOM files',
        helpText: 'Select DICOM files',
        actionDescription: 'selecting multiple files',
      );
    } else {
      return const FileSelectorUIConfig(
        primaryIcon: Icons.folder_open_rounded,
        primaryLabel: 'Open DICOM Directory',
        primaryTooltip: 'Open DICOM directory',
        helpText: 'Open DICOM directory',
        actionDescription: 'opening a directory',
      );
    }
  }
}

/// Result of file selection operation
class FileSelectorResult {
  final String? directoryPath;
  final List<PlatformFile>? files;
  final bool isDirectory;

  const FileSelectorResult._({
    this.directoryPath,
    this.files,
    required this.isDirectory,
  });

  /// Create result for directory selection
  factory FileSelectorResult.directory(String path) {
    return FileSelectorResult._(directoryPath: path, isDirectory: true);
  }

  /// Create result for file selection
  factory FileSelectorResult.files(List<PlatformFile> files) {
    return FileSelectorResult._(files: files, isDirectory: false);
  }

  /// Check if result has valid content
  bool get hasContent =>
      (isDirectory && directoryPath != null) ||
      (!isDirectory && files != null && files!.isNotEmpty);
}

/// UI configuration for platform-specific file selection
class FileSelectorUIConfig {
  final IconData primaryIcon;
  final String primaryLabel;
  final String primaryTooltip;
  final String helpText;
  final String actionDescription;

  const FileSelectorUIConfig({
    required this.primaryIcon,
    required this.primaryLabel,
    required this.primaryTooltip,
    required this.helpText,
    required this.actionDescription,
  });
}
