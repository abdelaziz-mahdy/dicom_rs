import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

/// Service to handle platform-specific file selection
class FileSelectorService {
  /// Select multiple DICOM files using the universal file picker
  /// Returns a FileSelectorResult with file data for cross-platform compatibility
  static Future<FileSelectorResult?> selectDicomFiles() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select DICOM Files',
      type: FileType.custom,
      allowedExtensions: ['dcm', 'dicom', 'ima', 'DICOM'],
      allowMultiple: true,
      withReadStream: false, // Use bytes instead of streams for better performance
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      // Convert PlatformFiles to DicomFileData with bytes
      final dicomFiles = <DicomFileData>[];
      for (final file in result.files) {
        Uint8List bytes;
        if (file.bytes != null) {
          bytes = file.bytes!;
        } else if (file.path != null) {
          // Read file bytes on native platforms
          bytes = await File(file.path!).readAsBytes();
        } else {
          continue; // Skip if no bytes or path
        }
        
        dicomFiles.add(DicomFileData(
          name: file.name,
          bytes: bytes,
        ));
      }
      return FileSelectorResult.files(dicomFiles);
    }
    return null;
  }

  /// Select a single DICOM file (works on all platforms)
  static Future<FileSelectorResult?> selectSingleDicomFile() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select Single DICOM File',
      type: FileType.custom,
      allowedExtensions: ['dcm', 'dicom', 'ima', 'DICOM'],
      allowMultiple: false,
      withReadStream: false, // Use bytes instead of streams
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      // Convert PlatformFiles to DicomFileData
      final dicomFiles = <DicomFileData>[];
      for (final file in result.files) {
        Uint8List bytes;
        if (file.bytes != null) {
          bytes = file.bytes!;
        } else if (file.path != null) {
          // Read file bytes on native platforms
          bytes = await File(file.path!).readAsBytes();
        } else {
          continue; // Skip if no bytes or path
        }
        dicomFiles.add(DicomFileData(
          name: file.name,
          bytes: bytes,
        ));
      }
      return FileSelectorResult.files(dicomFiles);
    }
    return null;
  }

  /// Get universal file selection UI configuration
  /// Now consistent across all platforms for better UX
  static FileSelectorUIConfig getUIConfig() {
    return const FileSelectorUIConfig(
      primaryIcon: Icons.file_open_rounded,
      primaryLabel: 'Select DICOM Files',
      primaryTooltip: 'Select one or more DICOM files to view',
      helpText: 'Select DICOM files to get started',
      actionDescription: 'selecting DICOM files',
    );
  }
}

/// DICOM file data with bytes
class DicomFileData {
  final String name;
  final Uint8List bytes;

  const DicomFileData({
    required this.name,
    required this.bytes,
  });
}

/// Result of file selection operation (file-only)
class FileSelectorResult {
  final List<DicomFileData> files;

  const FileSelectorResult._({
    required this.files,
  });

  /// Create result for file selection
  factory FileSelectorResult.files(List<DicomFileData> files) {
    return FileSelectorResult._(files: files);
  }

  /// Check if result has valid content
  bool get hasContent => files.isNotEmpty;

  /// For backward compatibility - always false now
  bool get isDirectory => false;
}

/// UI configuration for universal file selection
/// Provides consistent messaging across all platforms
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
