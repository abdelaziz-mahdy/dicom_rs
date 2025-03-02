import 'package:flutter/material.dart';

/// Represents different methods to load DICOM data
enum DicomLoadMethod {
  loadDicomFile(
    description: 'Load DICOM File',
    icon: Icons.insert_drive_file,
    isRecursive: false,
  ),

  /// Load from a directory without recursion
  directory(description: 'Directory', icon: Icons.folder, isRecursive: false),

  /// Load from a directory with recursion
  directoryRecursive(
    description: 'Directory (Recursive)',
    icon: Icons.folder_copy,
    isRecursive: true,
  ),

  // /// Load as a complete study
  // completeStudy(
  //   description: 'Complete Study',
  //   icon: 'medical_services',
  //   isRecursive: false,
  // ),

  // /// Load as a complete study recursively
  // completeStudyRecursive(
  //   description: 'Complete Study (Recursive)',
  //   icon: 'medical_information',
  //   isRecursive: true,
  // ),

  /// Load as a 3D volume
  volume(description: '3D Volume', icon: Icons.view_in_ar, isRecursive: false);

  final String description;
  final IconData icon;
  final bool isRecursive;

  const DicomLoadMethod({
    required this.description,
    required this.icon,
    required this.isRecursive,
  });
}
