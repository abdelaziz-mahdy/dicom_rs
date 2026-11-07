import 'dart:io';

import 'package:dicom_rs_example/services/example_studies.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const expectedFileCounts = {'chest_ct': 16, 'head_mr': 26, 'chest_xray': 1};

  test('every example study ships its files in slice order', () async {
    expect(
      ExampleStudy.all.map((s) => s.id).toSet(),
      expectedFileCounts.keys.toSet(),
    );
    for (final study in ExampleStudy.all) {
      final paths = await study.assetPaths();
      expect(paths, hasLength(expectedFileCounts[study.id]), reason: study.id);
      expect(paths, orderedEquals([...paths]..sort()));
      expect(paths.first, endsWith('_01.dcm'));
    }
  });

  test('every example study is credited in ATTRIBUTION.md', () {
    final attribution =
        File('assets/examples/ATTRIBUTION.md').readAsStringSync();
    expect(attribution, contains('CC BY 4.0'));
    for (final study in ExampleStudy.all) {
      expect(attribution, contains('## ${study.id}/'), reason: study.id);
      expect(attribution, contains(study.sourceUrl), reason: study.id);
    }
  });
}
