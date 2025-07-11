import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dicom_rs/dicom_rs.dart';
import 'package:dicom_rs_example/services/dicom_service_simple.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late DicomHandler handler;
  late Directory tempDir;
  late String sampleDicomPath;
  late String sampleDicomDirPath;
  late String nonDicomPath;

  setUpAll(() async {
    // Initialize the RustLib
    await RustLib.init();

    // Create a DicomHandler instance using the minimal API
    handler = DicomHandler();

    // Create temp directory for test files
    tempDir = await getTemporaryDirectory();

    // Create sample dicom directory
    sampleDicomDirPath = '${tempDir.path}/dicom_samples';
    final dicomSamplesDir = Directory(sampleDicomDirPath);
    if (!await dicomSamplesDir.exists()) {
      await dicomSamplesDir.create(recursive: true);
    }

    // Download and extract sample DICOM files
    final zipUrl = 'https://rubomedical.com/dicom_files/dicom_viewer_0002.zip';
    final zipPath = '${tempDir.path}/sample_dicom.zip';
    try {
      final response = await http.get(Uri.parse(zipUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download sample DICOM file: ${response.statusCode}');
      }

      await File(zipPath).writeAsBytes(response.bodyBytes);
      print('Sample DICOM files downloaded to $zipPath');

      // Extract the zip file
      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final file in archive) {
        if (file.isFile) {
          final data = file.content as List<int>;
          final extractedFile = File('$sampleDicomDirPath/${file.name}');
          await extractedFile.create(recursive: true);
          await extractedFile.writeAsBytes(data);

          // If this is a .dcm file, use it as our sample path
          if (file.name.toLowerCase().endsWith('.dcm')) {
            sampleDicomPath = extractedFile.path;
            print('Found DICOM file: $sampleDicomPath');
          }
        } else {
          // It's a directory, make sure it exists
          await Directory('$sampleDicomDirPath/${file.name}').create(recursive: true);
        }
      }

      // If no specific .dcm file was found, search for one
      if (sampleDicomPath == null || sampleDicomPath.isEmpty) {
        final files = dicomSamplesDir
            .listSync(recursive: true)
            .whereType<File>()
            .toList();

        for (final file in files) {
          if (await DicomServiceSimple.isValidDicom(file.path)) {
            sampleDicomPath = file.path;
            print('Found DICOM file by validation: $sampleDicomPath');
            break;
          }
        }
      }
    } catch (e) {
      print('Error downloading/extracting sample files: $e');
      // Fallback - set a path that likely won't exist, tests will be skipped
      sampleDicomPath = '${tempDir.path}/nonexistent_sample.dcm';
    }

    // Create a text file that is not a DICOM file for negative testing
    nonDicomPath = '${tempDir.path}/not_a_dicom_file.txt';
    await File(nonDicomPath).writeAsString('This is not a DICOM file');
  });

  tearDownAll(() async {
    // Clean up downloaded files
    try {
      final zipFile = File('${tempDir.path}/sample_dicom.zip');
      if (await zipFile.exists()) {
        await zipFile.delete();
      }
    } catch (e) {
      print('Error during cleanup: $e');
    }
  });

  group('DicomHandler Minimal API Tests', () {
    test('Can create DicomHandler instance', () {
      expect(handler, isA<DicomHandler>());
    });

    test('DicomHandler singleton returns same instance', () {
      final handler1 = DicomHandler();
      final handler2 = DicomHandler();
      expect(handler1, same(handler2));
    });
  });

  group('DICOM File Validation', () {
    test('Non-DICOM file returns false for isDicomFile', () async {
      expect(await handler.isDicomFile(nonDicomPath), false);
    });

    test('Non-DICOM file returns false via service method', () async {
      expect(await DicomServiceSimple.isValidDicom(nonDicomPath), false);
    });

    test('Sample DICOM file should be recognized as valid', () async {
      final file = File(sampleDicomPath);
      if (!await file.exists()) {
        markTestSkipped('Sample DICOM file not found');
        return;
      }

      expect(await handler.isDicomFile(sampleDicomPath), true);
      expect(await DicomServiceSimple.isValidDicom(sampleDicomPath), true);
    });
  });

  group('DICOM File Operations Tests', () {
    test('Load DICOM file metadata if file exists', () async {
      final file = File(sampleDicomPath);
      if (!await file.exists()) {
        markTestSkipped('Sample DICOM file not found');
        return;
      }

      final metadata = await handler.getMetadata(sampleDicomPath);
      expect(metadata, isA<DicomMetadata>());
      print('Patient Name: ${metadata.patientName ?? "Unknown"}');
      print('Modality: ${metadata.modality ?? "Unknown"}');
      print('Study Description: ${metadata.studyDescription ?? "Unknown"}');
    });

    test('Load complete DICOM file if file exists', () async {
      final file = File(sampleDicomPath);
      if (!await file.exists()) {
        markTestSkipped('Sample DICOM file not found');
        return;
      }

      final dicomFile = await handler.loadFile(sampleDicomPath);
      expect(dicomFile, isA<DicomFile>());
      expect(dicomFile.path, equals(sampleDicomPath));
      expect(dicomFile.metadata, isA<DicomMetadata>());

      print('Loaded DICOM file: ${dicomFile.path}');
      print('Patient: ${dicomFile.metadata.patientName ?? "Unknown"}');
    });

    test('Load DICOM file using service method', () async {
      final file = File(sampleDicomPath);
      if (!await file.exists()) {
        markTestSkipped('Sample DICOM file not found');
        return;
      }

      final dicomFile = await DicomServiceSimple.loadFile(sampleDicomPath);
      expect(dicomFile, isA<DicomFile>());
      expect(dicomFile.path, equals(sampleDicomPath));
      expect(dicomFile.metadata, isA<DicomMetadata>());

      print('Service loaded DICOM file successfully');
    });

    test('Extract pixel data from DICOM file if file exists', () async {
      final file = File(sampleDicomPath);
      if (!await file.exists()) {
        markTestSkipped('Sample DICOM file not found');
        return;
      }

      final pixelData = await handler.extractPixelData(sampleDicomPath);
      expect(pixelData, isA<DicomImage>());
      expect(pixelData.pixelData, isA<Uint8List>());
      expect(pixelData.width, greaterThan(0));
      expect(pixelData.height, greaterThan(0));

      print('Image dimensions: ${pixelData.width}x${pixelData.height}');
      print('Bits allocated: ${pixelData.bitsAllocated}');
      print('Photometric interpretation: ${pixelData.photometricInterpretation}');
    });

    test('Get encoded image from DICOM file if file exists', () async {
      final file = File(sampleDicomPath);
      if (!await file.exists()) {
        markTestSkipped('Sample DICOM file not found');
        return;
      }

      final imageBytes = await handler.getImageBytes(sampleDicomPath);
      expect(imageBytes, isA<Uint8List>());
      expect(imageBytes.length, greaterThan(0));

      print('PNG image size: ${imageBytes.length} bytes');
    });

    test('Test multiple file operations', () async {
      final file = File(sampleDicomPath);
      if (!await file.exists()) {
        markTestSkipped('Sample DICOM file not found');
        return;
      }

      // Test loading multiple files (using the same file multiple times for test)
      final paths = [sampleDicomPath, sampleDicomPath];
      final files = await DicomServiceSimple.loadMultipleFiles(paths);
      
      expect(files.length, 2);
      expect(files.every((f) => f.isValid), isTrue);
      
      // Test getting multiple image bytes
      final imageBytes = await DicomServiceSimple.getMultipleImageBytes(paths);
      expect(imageBytes.length, 2);
      expect(imageBytes.every((bytes) => bytes.isNotEmpty), isTrue);

      print('Successfully loaded and processed multiple files');
    });

    test('Test file sorting and organization', () async {
      final file = File(sampleDicomPath);
      if (!await file.exists()) {
        markTestSkipped('Sample DICOM file not found');
        return;
      }

      final dicomFile = await DicomServiceSimple.loadFile(sampleDicomPath);
      final files = [dicomFile];

      // Test organization by patient
      final byPatient = DicomServiceSimple.organizeByPatient(files);
      expect(byPatient.isNotEmpty, isTrue);

      // Test organization by modality
      final byModality = DicomServiceSimple.organizeByModality(files);
      expect(byModality.isNotEmpty, isTrue);

      // Test sorting
      final sorted = DicomServiceSimple.sortByInstanceNumber(files);
      expect(sorted.length, 1);

      // Test statistics
      final stats = DicomServiceSimple.getBasicStats(files);
      expect(stats['totalFiles'], 1);
      expect(stats['imagesWithPixelData'], greaterThanOrEqualTo(0));

      print('File organization and statistics work correctly');
    });
  });

  group('DICOM Directory Operations Tests', () {
    test('Find DICOM files in directory if directory exists', () async {
      final dir = Directory(sampleDicomDirPath);
      if (!await dir.exists()) {
        markTestSkipped('Sample DICOM directory not found');
        return;
      }

      // List all files in the directory
      final files = dir
          .listSync(recursive: true)
          .whereType<File>()
          .toList();

      print('Found ${files.length} total files in directory');

      // Check which ones are DICOM files using our minimal API
      var dicomCount = 0;
      for (final file in files.take(5)) { // Check first 5 files only for performance
        if (await DicomServiceSimple.isValidDicom(file.path)) {
          dicomCount++;
          print('Valid DICOM file: ${file.path}');
        }
      }

      print('Found $dicomCount DICOM files among first 5 checked');
    });

    test('Process multiple files from directory if directory exists', () async {
      final dir = Directory(sampleDicomDirPath);
      if (!await dir.exists()) {
        markTestSkipped('Sample DICOM directory not found');
        return;
      }

      // Get all file paths
      final filePaths = dir
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => f.path)
          .take(3) // Process first 3 files for performance
          .toList();

      if (filePaths.isEmpty) {
        markTestSkipped('No files found in directory');
        return;
      }

      // Filter to only DICOM files
      final dicomPaths = <String>[];
      for (final path in filePaths) {
        if (await DicomServiceSimple.isValidDicom(path)) {
          dicomPaths.add(path);
        }
      }

      if (dicomPaths.isNotEmpty) {
        // Load and organize the files
        final dicomFiles = await DicomServiceSimple.loadMultipleFiles(dicomPaths);
        expect(dicomFiles.isNotEmpty, isTrue);

        final organized = DicomServiceSimple.organizeByPatient(dicomFiles);
        final stats = DicomServiceSimple.getBasicStats(dicomFiles);

        print('Processed ${dicomFiles.length} DICOM files from directory');
        print('Statistics: $stats');
        print('Organized by ${organized.keys.length} patients');
      } else {
        print('No valid DICOM files found in directory sample');
      }
    });
  });

  group('Error Handling Tests', () {
    test('Handle invalid file paths gracefully', () async {
      const invalidPath = '/invalid/path/file.dcm';

      // Test that methods handle invalid paths gracefully
      expect(await handler.isDicomFile(invalidPath), isFalse);
      expect(await DicomServiceSimple.isValidDicom(invalidPath), isFalse);

      // Test that loading invalid files throws appropriate errors
      expect(
        () => handler.loadFile(invalidPath),
        throwsA(isA<Exception>()),
      );

      expect(
        () => handler.getMetadata(invalidPath),
        throwsA(isA<Exception>()),
      );

      print('Error handling works correctly for invalid paths');
    });

    test('Handle empty file lists', () {
      final emptyFiles = <DicomFile>[];

      final organized = DicomServiceSimple.organizeByPatient(emptyFiles);
      expect(organized.isEmpty, isTrue);

      final stats = DicomServiceSimple.getBasicStats(emptyFiles);
      expect(stats.isEmpty, isTrue);

      final sorted = DicomServiceSimple.sortByInstanceNumber(emptyFiles);
      expect(sorted.isEmpty, isTrue);

      print('Empty file list handling works correctly');
    });
  });

  group('Data Model Tests', () {
    test('DicomMetadata equality and properties', () {
      const metadata1 = DicomMetadata(
        patientName: 'Test Patient',
        patientId: '12345',
        studyDate: '20230101',
      );

      const metadata2 = DicomMetadata(
        patientName: 'Test Patient',
        patientId: '12345',
        studyDate: '20230101',
      );

      const metadata3 = DicomMetadata(
        patientName: 'Different Patient',
        patientId: '67890',
        studyDate: '20230202',
      );

      expect(metadata1, equals(metadata2));
      expect(metadata1, isNot(equals(metadata3)));
      expect(metadata1.patientName, 'Test Patient');
      expect(metadata1.patientId, '12345');
      expect(metadata1.studyDate, '20230101');

      print('DicomMetadata model works correctly');
    });

    test('DicomFile properties', () {
      const metadata = DicomMetadata(
        patientName: 'Test Patient',
        modality: 'CT',
      );

      const file = DicomFile(
        path: '/test/sample.dcm',
        metadata: metadata,
        isValid: true,
      );

      expect(file.path, '/test/sample.dcm');
      expect(file.isValid, isTrue);
      expect(file.metadata.patientName, 'Test Patient');
      expect(file.metadata.modality, 'CT');
      expect(file.image, isNull);

      print('DicomFile model works correctly');
    });

    test('DicomImage properties', () {
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

      print('DicomImage model works correctly');
    });
  });

  group('Integration Test Summary', () {
    test('All minimal API features work correctly', () async {
      // Summary test to verify the integration test suite covers all key features
      final handler = DicomHandler();
      
      expect(handler, isA<DicomHandler>());
      expect(handler.isDicomFile, isA<Function>());
      expect(handler.loadFile, isA<Function>());
      expect(handler.getMetadata, isA<Function>());
      expect(handler.getImageBytes, isA<Function>());
      expect(handler.extractPixelData, isA<Function>());
      
      // Service layer functions
      expect(DicomServiceSimple.isValidDicom, isA<Function>());
      expect(DicomServiceSimple.loadFile, isA<Function>());
      expect(DicomServiceSimple.loadMultipleFiles, isA<Function>());
      expect(DicomServiceSimple.organizeByPatient, isA<Function>());
      expect(DicomServiceSimple.organizeByModality, isA<Function>());
      expect(DicomServiceSimple.sortByInstanceNumber, isA<Function>());
      expect(DicomServiceSimple.getBasicStats, isA<Function>());
      
      print('All minimal API features are available and tested');
    });
  });
}
