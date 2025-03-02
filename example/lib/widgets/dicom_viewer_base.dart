import 'package:flutter/material.dart';

/// Abstract base class for DICOM viewers (both regular images and volumes)
abstract class DicomViewerBase extends StatefulWidget {
  const DicomViewerBase({Key? key}) : super(key: key);

  /// Get the current slice index
  int getCurrentSliceIndex();

  /// Get the total number of slices
  int getTotalSlices();
}

/// Base state class for DICOM viewers
abstract class DicomViewerBaseState<T extends DicomViewerBase>
    extends State<T> {
  /// Navigate to the next slice
  void nextSlice();

  /// Navigate to the previous slice
  void previousSlice();

  /// Get the current slice index
  int getCurrentSliceIndex();

  /// Get the total number of slices
  int getTotalSlices();
}
