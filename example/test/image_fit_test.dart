import 'dart:typed_data';
import 'dart:ui';

import 'package:dicom_rs_example/presentation/widgets/image_fit.dart';
import 'package:flutter_test/flutter_test.dart';

/// The first 24 bytes of a PNG: signature, IHDR length and type, then the
/// big-endian width and height.
Uint8List pngHeader(int width, int height) {
  final bytes = ByteData(24);
  const signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  for (var i = 0; i < signature.length; i++) {
    bytes.setUint8(i, signature[i]);
  }
  bytes.setUint32(8, 13); // IHDR length
  bytes.setUint32(12, 0x49484452); // "IHDR"
  bytes.setUint32(16, width);
  bytes.setUint32(20, height);
  return bytes.buffer.asUint8List();
}

void main() {
  group('pngPixelSize', () {
    test('reads width and height from the IHDR chunk', () {
      expect(pngPixelSize(pngHeader(1760, 2140)), const Size(1760, 2140));
    });

    test('returns null for bytes that are not a PNG', () {
      expect(pngPixelSize(Uint8List.fromList(List.filled(32, 0))), isNull);
      expect(pngPixelSize(Uint8List(4)), isNull);
    });
  });

  group('fitInside', () {
    test('enlarges an image smaller than the box', () {
      // A 320x320 MR slice in a 1000x700 viewer fills the height.
      expect(
        fitInside(const Size(320, 320), const Size(1000, 700)),
        const Size(700, 700),
      );
    });

    test('reduces an image larger than the box, keeping its aspect ratio', () {
      final fitted = fitInside(const Size(1760, 2140), const Size(1000, 700));
      expect(fitted.height, 700);
      expect(fitted.width, closeTo(1760 * 700 / 2140, 1e-9));
    });
  });

  group('spacingForDisplay', () {
    test('scales the spacing when the image is shown smaller', () {
      // 0.14 mm/pixel X-ray, 1760 px wide, shown 586.7 px wide: one displayed
      // pixel covers three image pixels.
      final spacing = spacingForDisplay(
        [0.14, 0.14],
        imageWidth: 1760,
        displayedWidth: 1760 / 3,
      );
      expect(spacing![0], closeTo(0.42, 1e-9));
      expect(spacing[1], closeTo(0.42, 1e-9));
    });

    test('scales the spacing when the image is shown larger', () {
      final spacing = spacingForDisplay(
        [0.8, 0.8],
        imageWidth: 320,
        displayedWidth: 640,
      );
      expect(spacing, [0.4, 0.4]);
    });

    test('leaves missing spacing or unknown sizes alone', () {
      expect(
        spacingForDisplay(null, imageWidth: 320, displayedWidth: 640),
        isNull,
      );
      expect(
        spacingForDisplay([0.8, 0.8], imageWidth: 0, displayedWidth: 640),
        [0.8, 0.8],
      );
    });
  });
}
