import 'package:flutter_test/flutter_test.dart';
import 'package:dicom_rs/dicom_rs.dart';
import 'dart:typed_data';

void main() {
  group('DicomHandler Basic Tests', () {
    late DicomHandler handler;

    setUp(() {
      handler = DicomHandler();
    });

    test('should create DicomHandler instance', () {
      expect(handler, isA<DicomHandler>());
    });

    test('DicomFile should have correct properties', () {
      const metadata = DicomMetadata(
        patientName: 'Test Patient',
        modality: 'CT',
        studyDate: '20231201',
      );

      const file = DicomFile(
        path: '/test/path.dcm',
        metadata: metadata,
        isValid: true,
      );

      expect(file.path, '/test/path.dcm');
      expect(file.metadata.patientName, 'Test Patient');
      expect(file.metadata.modality, 'CT');
      expect(file.isValid, isTrue);
      expect(file.image, isNull);
    });

    test('DicomMetadata should have readable toString', () {
      const metadata = DicomMetadata(
        patientName: 'John Doe',
        modality: 'MR',
        studyDate: '20231201',
      );

      final str = metadata.toString();
      expect(str, contains('John Doe'));
      expect(str, contains('MR'));
      expect(str, contains('20231201'));
    });

    test('DicomImage should have correct properties', () {
      final pixelData = Uint8List.fromList([1, 2, 3, 4]);
      
      final image = DicomImage(
        width: 512,
        height: 512,
        bitsAllocated: 16,
        bitsStored: 12,
        pixelRepresentation: 0,
        photometricInterpretation: 'MONOCHROME2',
        samplesPerPixel: 1,
        pixelData: pixelData,
      );

      expect(image.width, 512);
      expect(image.height, 512);
      expect(image.bitsAllocated, 16);
      expect(image.photometricInterpretation, 'MONOCHROME2');
      expect(image.pixelData.length, 4);
    });

    test('getDicomHandler should return same instance', () {
      final handler1 = getDicomHandler();
      final handler2 = getDicomHandler();
      
      expect(handler1, same(handler2));
    });

    test('API methods should be available', () {
      expect(handler.isDicomFile, isA<Function>());
      expect(handler.loadFile, isA<Function>());
      expect(handler.getMetadata, isA<Function>());
      expect(handler.getImageBytes, isA<Function>());
      expect(handler.extractPixelData, isA<Function>());
    });
  });
}

// Note: Comprehensive tests including actual DICOM file loading
// are available in the example app at example/test/comprehensive_dicom_test.dart
// 
// This package focuses on providing the minimal API.
// The example app demonstrates advanced usage and testing patterns.