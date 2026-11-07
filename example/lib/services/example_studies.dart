import 'package:dicom_rs/dicom_rs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'file_selector_service.dart';

/// A de-identified study bundled with the app so people can try the viewer
/// without their own files. Sources and licenses are listed in
/// assets/examples/ATTRIBUTION.md.
class ExampleStudy {
  const ExampleStudy({
    required this.id,
    required this.title,
    required this.details,
    required this.icon,
    required this.source,
    required this.sourceUrl,
    this.startSlice = 1,
  });

  /// Folder name under assets/examples/.
  final String id;
  final String title;

  /// Modality, slice count and matrix size, e.g. "CT · 13 axial slices".
  final String details;
  final IconData icon;

  /// Short name of the collection the images come from.
  final String source;
  final String sourceUrl;

  /// Slice to show first (1-based): one where the anatomy is easy to
  /// recognise, rather than the edge of the scan.
  final int startSlice;

  static const license = 'CC BY 4.0';
  static const licenseUrl = 'https://creativecommons.org/licenses/by/4.0/';

  static const all = [
    ExampleStudy(
      id: 'chest_ct',
      title: 'Chest CT',
      details: 'CT · 16 axial slices · 512×512',
      icon: Icons.view_in_ar_rounded,
      source: 'Cancer Moonshot Biobank, CMB-BRCA',
      sourceUrl: 'https://doi.org/10.7937/dx22-8j71',
      startSlice: 9,
    ),
    ExampleStudy(
      id: 'head_mr',
      title: 'Head MRI',
      details: 'MR T2 · 26 coronal slices · 320×320',
      icon: Icons.psychology_alt_rounded,
      source: 'Cancer Moonshot Biobank, CMB-LCA',
      sourceUrl: 'https://doi.org/10.7937/3cx3-s132',
      startSlice: 14,
    ),
    ExampleStudy(
      id: 'chest_xray',
      title: 'Chest X-ray',
      details: 'CR · 1 image · 1760×2140',
      icon: Icons.airline_seat_flat_rounded,
      source: 'COVID-19-AR',
      sourceUrl: 'https://doi.org/10.7937/tcia.2020.py71-5978',
    ),
  ];

  /// Reads the study's files from the app bundle, in slice order, with their
  /// metadata, ready for the viewer. On the web the files are downloaded only
  /// now, when the study is opened.
  Future<List<DicomFileData>> load({AssetBundle? bundle}) async {
    final assets = bundle ?? rootBundle;
    final paths = await assetPaths(bundle: assets);
    if (paths.isEmpty) {
      throw StateError('No files found for the "$title" example.');
    }

    final handler = DicomHandler();
    final files = <DicomFileData>[];
    for (final path in paths) {
      final data = await assets.load(path);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      files.add(
        DicomFileData(
          name: path.split('/').last,
          bytes: bytes,
          metadata: await handler.getMetadata(bytes),
        ),
      );
    }
    return files;
  }

  /// The study's DICOM files in the app bundle, in slice order (the files
  /// are named so that sorting by name gives slice order).
  Future<List<String>> assetPaths({AssetBundle? bundle}) async {
    final manifest = await AssetManifest.loadFromAssetBundle(
      bundle ?? rootBundle,
    );
    return manifest
        .listAssets()
        .where(
          (path) =>
              path.startsWith('assets/examples/$id/') && path.endsWith('.dcm'),
        )
        .toList()
      ..sort();
  }
}
