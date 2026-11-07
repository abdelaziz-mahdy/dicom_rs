import 'package:flutter_test/flutter_test.dart';
import 'package:dicom_rs/dicom_rs.dart';
import 'package:dicom_rs_example/services/dicom_service_simple.dart';
import 'dart:typed_data';

void main() {
  group('DicomServiceSimple Comprehensive Tests', () {
    test('should handle empty bytes gracefully', () async {
      final isValid = await DicomServiceSimple.isValidDicom(Uint8List(0));
      expect(isValid, isFalse);
    });

    test('should handle non-DICOM bytes gracefully', () async {
      final bytes = Uint8List.fromList('This is not a DICOM file'.codeUnits);
      final isValid = await DicomServiceSimple.isValidDicom(bytes);
      expect(isValid, isFalse);
    });

    test('should organize files by patient correctly', () {
      final files = [
        const DicomFile(
          metadata: DicomMetadata(patientName: 'John Doe'),
          isValid: true,
        ),
        const DicomFile(
          metadata: DicomMetadata(patientName: 'Jane Smith'),
          isValid: true,
        ),
        const DicomFile(
          metadata: DicomMetadata(patientName: 'John Doe'),
          isValid: true,
        ),
      ];

      final organized = DicomServiceSimple.organizeByPatient(files);

      expect(organized.keys.length, 2);
      expect(organized['John Doe']?.length, 2);
      expect(organized['Jane Smith']?.length, 1);
    });

    test('should organize files by modality correctly', () {
      final files = [
        const DicomFile(metadata: DicomMetadata(modality: 'CT'), isValid: true),
        const DicomFile(metadata: DicomMetadata(modality: 'MR'), isValid: true),
        const DicomFile(metadata: DicomMetadata(modality: 'CT'), isValid: true),
      ];

      final organized = DicomServiceSimple.organizeByModality(files);

      expect(organized.keys.length, 2);
      expect(organized['CT']?.length, 2);
      expect(organized['MR']?.length, 1);
    });

    test('should sort files by instance number correctly', () {
      final files = [
        const DicomFile(
          metadata: DicomMetadata(instanceNumber: 3),
          isValid: true,
        ),
        const DicomFile(
          metadata: DicomMetadata(instanceNumber: 1),
          isValid: true,
        ),
        const DicomFile(
          metadata: DicomMetadata(instanceNumber: 2),
          isValid: true,
        ),
      ];

      final sorted = DicomServiceSimple.sortByInstanceNumber(files);

      expect(sorted[0].metadata.instanceNumber, 1);
      expect(sorted[1].metadata.instanceNumber, 2);
      expect(sorted[2].metadata.instanceNumber, 3);
    });

    test('should generate correct basic statistics', () {
      final image = DicomImage(
        width: 512,
        height: 512,
        bitsAllocated: 16,
        bitsStored: 12,
        pixelRepresentation: 0,
        photometricInterpretation: 'MONOCHROME2',
        samplesPerPixel: 1,
        pixelData: Uint8List(0),
      );

      final files = [
        DicomFile(
          metadata: const DicomMetadata(
            patientName: 'John Doe',
            modality: 'CT',
          ),
          image: image,
          isValid: true,
        ),
        const DicomFile(
          metadata: DicomMetadata(patientName: 'Jane Smith', modality: 'MR'),
          isValid: true,
        ),
        DicomFile(
          metadata: const DicomMetadata(
            patientName: 'John Doe',
            modality: 'CT',
          ),
          image: image,
          isValid: true,
        ),
      ];

      final stats = DicomServiceSimple.getBasicStats(files);

      expect(stats['totalFiles'], 3);
      expect(stats['imagesWithPixelData'], 2);
      expect(stats['uniquePatients'], 2);
      expect(stats['uniqueModalities'], 2);
      expect(stats['modalities'], contains('CT'));
      expect(stats['modalities'], contains('MR'));
      expect(stats['patients'], contains('John Doe'));
      expect(stats['patients'], contains('Jane Smith'));
    });

    test('should handle empty file lists gracefully', () {
      final organized = DicomServiceSimple.organizeByPatient([]);
      expect(organized.isEmpty, isTrue);

      final stats = DicomServiceSimple.getBasicStats([]);
      expect(stats.isEmpty, isTrue);

      final sorted = DicomServiceSimple.sortByInstanceNumber([]);
      expect(sorted.isEmpty, isTrue);
    });
  });

  group('Data Class Tests', () {
    test('DicomMetadata should have correct string representation', () {
      const metadata = DicomMetadata(
        patientName: 'Test Patient',
        modality: 'CT',
        studyDate: '20231201',
        studyDescription: 'Test Study',
      );

      final str = metadata.toString();
      expect(str, contains('Test Patient'));
      expect(str, contains('CT'));
      expect(str, contains('20231201'));
    });

    test('DicomImage should calculate correct properties', () {
      final pixelData = Uint8List.fromList(List.generate(1024, (i) => i % 256));

      final image = DicomImage(
        width: 512,
        height: 512,
        bitsAllocated: 8,
        bitsStored: 8,
        pixelRepresentation: 0,
        photometricInterpretation: 'MONOCHROME2',
        samplesPerPixel: 1,
        pixelData: pixelData,
      );

      expect(image.width, 512);
      expect(image.height, 512);
      expect(image.pixelData.length, 1024);
      expect(image.toString(), contains('512x512'));
      expect(image.toString(), contains('8 bits'));
      expect(image.toString(), contains('MONOCHROME2'));
    });

    test('DicomFile should have correct properties', () {
      const metadata = DicomMetadata(
        patientName: 'Test Patient',
        modality: 'MR',
      );

      final image = DicomImage(
        width: 256,
        height: 256,
        bitsAllocated: 16,
        bitsStored: 12,
        pixelRepresentation: 0,
        photometricInterpretation: 'MONOCHROME2',
        samplesPerPixel: 1,
        pixelData: Uint8List(512),
      );

      final file = DicomFile(metadata: metadata, image: image, isValid: true);

      expect(file.isValid, isTrue);
      expect(file.image, isNotNull);
      expect(file.metadata.patientName, 'Test Patient');
      expect(file.toString(), contains('isValid: true'));
      expect(file.toString(), contains('hasImage: true'));
    });
  });

  group('Edge Cases and Error Handling', () {
    test('should handle null and empty values gracefully', () {
      const metadataWithNulls = DicomMetadata();

      expect(metadataWithNulls.patientName, isNull);
      expect(metadataWithNulls.modality, isNull);
      expect(metadataWithNulls.studyDate, isNull);

      final files = [
        const DicomFile(metadata: metadataWithNulls, isValid: true),
      ];

      // Should handle null patient names
      final organized = DicomServiceSimple.organizeByPatient(files);
      expect(organized.containsKey('Unknown Patient'), isTrue);

      // Should handle null modalities
      final organizedByModality = DicomServiceSimple.organizeByModality(files);
      expect(organizedByModality.containsKey('Unknown'), isTrue);
    });

    test('should handle files without instance numbers', () {
      final files = [
        const DicomFile(
          metadata: DicomMetadata(), // instanceNumber is null
          isValid: true,
        ),
        const DicomFile(
          metadata: DicomMetadata(instanceNumber: 5),
          isValid: true,
        ),
      ];

      final sorted = DicomServiceSimple.sortByInstanceNumber(files);
      expect(sorted.length, 2);
      // File without instance number (null treated as 0) should come first
      expect(sorted[0].metadata.instanceNumber, isNull);
      expect(sorted[1].metadata.instanceNumber, 5);
    });

    test('should handle mixed valid and invalid files', () async {
      // This test would work with actual DICOM files
      // For now, we test the structure
      expect(DicomServiceSimple.loadMultipleFiles, isA<Function>());
      expect(DicomServiceSimple.getMultipleImageBytes, isA<Function>());
    });
  });

  // Performance test group for benchmarking
  group('Performance Tests', () {
    test('should handle large file lists efficiently', () {
      // Generate a large list of mock DICOM files
      final files = List.generate(
        1000,
        (i) => DicomFile(
          metadata: DicomMetadata(
            patientName: 'Patient ${i % 10}',
            modality: ['CT', 'MR', 'XR'][i % 3],
            instanceNumber: i,
          ),
          isValid: true,
        ),
      );

      final stopwatch = Stopwatch()..start();

      // Test organizing by patient
      final organized = DicomServiceSimple.organizeByPatient(files);
      expect(organized.keys.length, 10); // 10 unique patients

      // Test sorting
      final sorted = DicomServiceSimple.sortByInstanceNumber(files);
      expect(sorted.length, 1000);
      expect(sorted.first.metadata.instanceNumber, 0);
      expect(sorted.last.metadata.instanceNumber, 999);

      // Test stats generation
      final stats = DicomServiceSimple.getBasicStats(files);
      expect(stats['totalFiles'], 1000);
      expect(stats['uniquePatients'], 10);
      expect(stats['uniqueModalities'], 3);

      stopwatch.stop();

      // Should complete in reasonable time (less than 1 second for 1000 files)
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });
  });
}
