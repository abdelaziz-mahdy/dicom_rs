import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dicom_rs/dicom_rs.dart';
import 'package:flutter_test/flutter_test.dart';

/// Native library produced by `cargo build --release` in `rust/`.
/// `RustLib.init()` loads it from `rust/target/release/` when the tests run
/// from the package root.
String get _nativeLibraryPath {
  if (Platform.isMacOS) return 'rust/target/release/libdicom_rs.dylib';
  if (Platform.isWindows) return 'rust/target/release/dicom_rs.dll';
  return 'rust/target/release/libdicom_rs.so';
}

void main() {
  final nativeLibraryBuilt = File(_nativeLibraryPath).existsSync();
  final skipReason =
      nativeLibraryBuilt
          ? false
          : 'Native library not built: run `cargo build --release` in rust/';

  group('DicomHandler with the Rust backend', () {
    final handler = DicomHandler();
    late Uint8List dicom;

    setUpAll(() async {
      if (!nativeLibraryBuilt) return;
      await RustLib.init();
      dicom = buildSyntheticDicom();
    });

    test('recognises a DICOM file', () async {
      expect(await handler.isDicomFile(dicom), isTrue);
    });

    test('rejects bytes that are not DICOM', () async {
      expect(
        await handler.isDicomFile(utf8.encode('not a dicom file')),
        isFalse,
      );
      expect(await handler.isDicomFile(const []), isFalse);
    });

    test('reads metadata', () async {
      final metadata = await handler.getMetadata(dicom);

      expect(metadata.patientName, 'Test^Patient');
      expect(metadata.patientId, 'ID123');
      expect(metadata.studyDate, '20240101');
      expect(metadata.modality, 'CT');
      expect(metadata.instanceNumber, 7);
      expect(metadata.pixelSpacing, [0.5, 0.5]);
    });

    test('extracts pixel data', () async {
      final image = await handler.extractPixelData(dicom);

      expect(image.width, 2);
      expect(image.height, 2);
      expect(image.bitsAllocated, 8);
      expect(image.bitsStored, 8);
      expect(image.photometricInterpretation, 'MONOCHROME2');
      expect(image.samplesPerPixel, 1);
      expect(image.pixelData, hasLength(4));
    });

    test('encodes the image as PNG', () async {
      final png = await handler.getImageBytes(dicom);

      expect(png.sublist(0, 8), [
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
      ]);
    });

    test('loads metadata and image together', () async {
      final file = await handler.loadFile(dicom);

      expect(file.isValid, isTrue);
      expect(file.metadata.modality, 'CT');
      expect(file.image, isNotNull);
      expect(file.image!.width, 2);
    });

    test('reports an error for bytes that are not DICOM', () async {
      final notDicom = utf8.encode('not a dicom file');

      await expectLater(handler.loadFile(notDicom), throwsA(anything));
      await expectLater(handler.getMetadata(notDicom), throwsA(anything));
      await expectLater(handler.getImageBytes(notDicom), throwsA(anything));
      await expectLater(handler.extractPixelData(notDicom), throwsA(anything));
    });
  }, skip: skipReason);
}

/// Builds a minimal 2x2, 8-bit MONOCHROME2 CT image in Explicit VR Little
/// Endian, with the 128-byte preamble a file on disk has.
Uint8List buildSyntheticDicom() {
  const explicitVrLittleEndian = '1.2.840.10008.1.2.1';
  const ctImageStorage = '1.2.840.10008.5.1.4.1.1.2';
  const sopInstanceUid = '1.2.3.4.5.6.7.8.9';

  final meta =
      BytesBuilder()
        ..add(_element(0x0002, 0x0001, 'OB', [0x00, 0x01]))
        ..add(_element(0x0002, 0x0002, 'UI', _uid(ctImageStorage)))
        ..add(_element(0x0002, 0x0003, 'UI', _uid(sopInstanceUid)))
        ..add(_element(0x0002, 0x0010, 'UI', _uid(explicitVrLittleEndian)))
        ..add(_element(0x0002, 0x0012, 'UI', _uid('1.2.3.4')));
  final metaBytes = meta.toBytes();

  final dataset =
      BytesBuilder()
        ..add(_element(0x0008, 0x0016, 'UI', _uid(ctImageStorage)))
        ..add(_element(0x0008, 0x0018, 'UI', _uid(sopInstanceUid)))
        ..add(_element(0x0008, 0x0020, 'DA', _text('20240101')))
        ..add(_element(0x0008, 0x0060, 'CS', _text('CT')))
        ..add(_element(0x0010, 0x0010, 'PN', _text('Test^Patient')))
        ..add(_element(0x0010, 0x0020, 'LO', _text('ID123')))
        ..add(_element(0x0020, 0x0013, 'IS', _text('7')))
        ..add(_element(0x0028, 0x0002, 'US', _u16(1)))
        ..add(_element(0x0028, 0x0004, 'CS', _text('MONOCHROME2')))
        ..add(_element(0x0028, 0x0010, 'US', _u16(2)))
        ..add(_element(0x0028, 0x0011, 'US', _u16(2)))
        ..add(_element(0x0028, 0x0030, 'DS', _text(r'0.5\0.5')))
        ..add(_element(0x0028, 0x0100, 'US', _u16(8)))
        ..add(_element(0x0028, 0x0101, 'US', _u16(8)))
        ..add(_element(0x0028, 0x0102, 'US', _u16(7)))
        ..add(_element(0x0028, 0x0103, 'US', _u16(0)))
        ..add(_element(0x7FE0, 0x0010, 'OB', [0, 64, 128, 255]));

  return (BytesBuilder()
        ..add(Uint8List(128))
        ..add(ascii.encode('DICM'))
        ..add(_element(0x0002, 0x0000, 'UL', _u32(metaBytes.length)))
        ..add(metaBytes)
        ..add(dataset.toBytes()))
      .toBytes();
}

const _longLengthVrs = {'OB', 'OW', 'OF', 'SQ', 'UT', 'UN'};

List<int> _element(int group, int element, String vr, List<int> value) {
  final header =
      ByteData(_longLengthVrs.contains(vr) ? 12 : 8)
        ..setUint16(0, group, Endian.little)
        ..setUint16(2, element, Endian.little)
        ..setUint8(4, vr.codeUnitAt(0))
        ..setUint8(5, vr.codeUnitAt(1));
  if (_longLengthVrs.contains(vr)) {
    header.setUint32(8, value.length, Endian.little);
  } else {
    header.setUint16(6, value.length, Endian.little);
  }
  return [...header.buffer.asUint8List(), ...value];
}

/// UIDs are padded to even length with a NUL byte.
List<int> _uid(String uid) => [...ascii.encode(uid), if (uid.length.isOdd) 0];

/// Text values are padded to even length with a space.
List<int> _text(String text) =>
    ascii.encode(text.length.isOdd ? '$text ' : text);

List<int> _u16(int value) =>
    (ByteData(2)..setUint16(0, value, Endian.little)).buffer.asUint8List();

List<int> _u32(int value) =>
    (ByteData(4)..setUint32(0, value, Endian.little)).buffer.asUint8List();
