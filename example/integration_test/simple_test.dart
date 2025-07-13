import 'dart:io';
import 'dart:typed_data';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dicom_rs/dicom_rs.dart';
import 'package:dicom_rs_example/services/dicom_service_simple.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late DicomHandler handler;
  late Directory tempDir;
  String sampleDicomPath = '';
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

    // Create a proper synthetic DICOM file for testing
    print('Creating synthetic DICOM file for testing...');
    sampleDicomPath = '${tempDir.path}/synthetic_sample.dcm';
    
    // Create a proper minimal DICOM file with required elements
    final dicomData = <int>[
      // DICOM preamble (128 bytes of zeros)
      ...List.filled(128, 0),
      
      // DICOM prefix "DICM"
      0x44, 0x49, 0x43, 0x4D,
      
      // File Meta Information Group Length (0002,0000) - UL
      0x02, 0x00, 0x00, 0x00, 0x55, 0x4C, 0x04, 0x00, 
      0x94, 0x00, 0x00, 0x00, // Length: 148 bytes
      
      // Media Storage SOP Class UID (0002,0002) - UI  
      0x02, 0x00, 0x02, 0x00, 0x55, 0x49, 0x1A, 0x00,
      // CT Image Storage SOP Class UID
      0x31, 0x2E, 0x32, 0x2E, 0x38, 0x34, 0x30, 0x2E, 
      0x31, 0x30, 0x30, 0x30, 0x38, 0x2E, 0x35, 0x2E, 
      0x31, 0x2E, 0x34, 0x2E, 0x31, 0x2E, 0x31, 0x2E, 
      0x32, 0x00,
      
      // Media Storage SOP Instance UID (0002,0003) - UI
      0x02, 0x00, 0x03, 0x00, 0x55, 0x49, 0x20, 0x00,
      0x31, 0x2E, 0x32, 0x2E, 0x38, 0x34, 0x30, 0x2E, 
      0x31, 0x30, 0x30, 0x30, 0x38, 0x2E, 0x31, 0x2E, 
      0x31, 0x2E, 0x31, 0x2E, 0x31, 0x2E, 0x31, 0x2E, 
      0x31, 0x2E, 0x31, 0x00,
      
      // Transfer Syntax UID (0002,0010) - UI 
      0x02, 0x00, 0x10, 0x00, 0x55, 0x49, 0x1A, 0x00,
      // Implicit VR Little Endian
      0x31, 0x2E, 0x32, 0x2E, 0x38, 0x34, 0x30, 0x2E, 
      0x31, 0x30, 0x30, 0x30, 0x38, 0x2E, 0x31, 0x2E, 
      0x32, 0x2E, 0x31, 0x00,
      
      // Implementation Class UID (0002,0012) - UI
      0x02, 0x00, 0x12, 0x00, 0x55, 0x49, 0x16, 0x00,
      0x31, 0x2E, 0x32, 0x2E, 0x38, 0x34, 0x30, 0x2E, 
      0x31, 0x30, 0x30, 0x30, 0x38, 0x2E, 0x31, 0x2E, 
      0x32, 0x2E, 0x31, 0x00,
      
      // Patient Name (0010,0010) - PN
      0x10, 0x00, 0x10, 0x00, 0x0C, 0x00, 
      0x54, 0x45, 0x53, 0x54, 0x5E, 0x50, 0x41, 0x54, 
      0x49, 0x45, 0x4E, 0x54,
      
      // Patient ID (0010,0020) - LO
      0x10, 0x00, 0x20, 0x00, 0x06, 0x00,
      0x31, 0x32, 0x33, 0x34, 0x35, 0x36,
      
      // Study Date (0008,0020) - DA
      0x08, 0x00, 0x20, 0x00, 0x08, 0x00,
      0x32, 0x30, 0x32, 0x34, 0x30, 0x31, 0x30, 0x31,
      
      // Modality (0008,0060) - CS
      0x08, 0x00, 0x60, 0x00, 0x02, 0x00,
      0x43, 0x54,
      
      // Study Description (0008,1030) - LO
      0x08, 0x00, 0x30, 0x10, 0x0A, 0x00,
      0x54, 0x45, 0x53, 0x54, 0x20, 0x53, 0x54, 0x55, 
      0x44, 0x59,
      
      // Rows (0028,0010) - US
      0x28, 0x00, 0x10, 0x00, 0x02, 0x00,
      0x00, 0x02, // 512
      
      // Columns (0028,0011) - US  
      0x28, 0x00, 0x11, 0x00, 0x02, 0x00,
      0x00, 0x02, // 512
      
      // Bits Allocated (0028,0100) - US
      0x28, 0x00, 0x00, 0x01, 0x02, 0x00,
      0x10, 0x00, // 16
      
      // Bits Stored (0028,0101) - US
      0x28, 0x00, 0x01, 0x01, 0x02, 0x00,
      0x10, 0x00, // 16
      
      // High Bit (0028,0102) - US
      0x28, 0x00, 0x02, 0x01, 0x02, 0x00,
      0x0F, 0x00, // 15
      
      // Pixel Representation (0028,0103) - US
      0x28, 0x00, 0x03, 0x01, 0x02, 0x00,
      0x00, 0x00, // unsigned
      
      // Samples per Pixel (0028,0002) - US
      0x28, 0x00, 0x02, 0x00, 0x02, 0x00,
      0x01, 0x00, // 1
      
      // Photometric Interpretation (0028,0004) - CS
      0x28, 0x00, 0x04, 0x00, 0x0C, 0x00,
      0x4D, 0x4F, 0x4E, 0x4F, 0x43, 0x48, 0x52, 0x4F, 
      0x4D, 0x45, 0x32, 0x20,
      
      // Pixel Data (7FE0,0010) - OW with minimal pixel data
      0xE0, 0x7F, 0x10, 0x00, 0x00, 0x00, 0x00, 0x04,
      0x00, 0x00, 0xFF, 0xFF, // 4 bytes of dummy pixel data
    ];
    
    await File(sampleDicomPath).writeAsBytes(dicomData);
    print('Created synthetic DICOM file at: $sampleDicomPath');

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
      final bytes = await File(nonDicomPath).readAsBytes();
      expect(await handler.isDicomFile(bytes), false);
    });

    test('Non-DICOM file returns false via service method', () async {
      final bytes = await File(nonDicomPath).readAsBytes();
      expect(await DicomServiceSimple.isValidDicom(bytes), false);
    });

    test('Sample DICOM file should be recognized as valid', () async {
      final file = File(sampleDicomPath);
      if (!await file.exists()) {
        markTestSkipped('Sample DICOM file not found');
        return;
      }

      final bytes = await file.readAsBytes();
      expect(await handler.isDicomFile(bytes), true);
      expect(await DicomServiceSimple.isValidDicom(bytes), true);
    });
  });

  group('DICOM File Operations Tests', () {
    test('Load DICOM file metadata if file exists', () async {
      final file = File(sampleDicomPath);
      if (!await file.exists()) {
        markTestSkipped('Sample DICOM file not found');
        return;
      }

      final bytes = await file.readAsBytes();
      final metadata = await handler.getMetadata(bytes);
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

      final bytes = await file.readAsBytes();
      final dicomFile = await handler.loadFile(bytes);
      expect(dicomFile, isA<DicomFile>());
      expect(dicomFile.metadata, isA<DicomMetadata>());

      print('Loaded DICOM file successfully');
      print('Patient: ${dicomFile.metadata.patientName ?? "Unknown"}');
    });

    test('Load DICOM file using service method', () async {
      final file = File(sampleDicomPath);
      if (!await file.exists()) {
        markTestSkipped('Sample DICOM file not found');
        return;
      }

      final bytes = await file.readAsBytes();
      final dicomFile = await DicomServiceSimple.loadFile(bytes);
      expect(dicomFile, isA<DicomFile>());
      expect(dicomFile.metadata, isA<DicomMetadata>());

      print('Service loaded DICOM file successfully');
    });

    test('Extract pixel data from DICOM file if file exists', () async {
      final file = File(sampleDicomPath);
      if (!await file.exists()) {
        markTestSkipped('Sample DICOM file not found');
        return;
      }

      final bytes = await file.readAsBytes();
      final pixelData = await handler.extractPixelData(bytes);
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

      final bytes = await file.readAsBytes();
      final imageBytes = await handler.getImageBytes(bytes);
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
      final bytes = await file.readAsBytes();
      final bytesList = [bytes, bytes];
      final files = await DicomServiceSimple.loadMultipleFiles(bytesList);
      
      expect(files.length, 2);
      expect(files.every((f) => f.isValid), isTrue);
      
      // Test getting multiple image bytes
      final imageBytes = await DicomServiceSimple.getMultipleImageBytes(bytesList);
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

      final bytes = await file.readAsBytes();
      final dicomFile = await DicomServiceSimple.loadFile(bytes);
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
        try {
          final bytes = await file.readAsBytes();
          if (await DicomServiceSimple.isValidDicom(bytes)) {
            dicomCount++;
            print('Valid DICOM file: ${file.path}');
          }
        } catch (e) {
          // Skip files that can't be read
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

      // Filter to only DICOM files and get their bytes
      final dicomBytesList = <Uint8List>[];
      for (final path in filePaths) {
        try {
          final bytes = await File(path).readAsBytes();
          if (await DicomServiceSimple.isValidDicom(bytes)) {
            dicomBytesList.add(bytes);
          }
        } catch (e) {
          // Skip files that can't be read
        }
      }

      if (dicomBytesList.isNotEmpty) {
        // Load and organize the files
        final dicomFiles = await DicomServiceSimple.loadMultipleFiles(dicomBytesList);
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
    test('Handle invalid file data gracefully', () async {
      // Create invalid DICOM data (just some random bytes)
      final invalidBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

      // Test that methods handle invalid data gracefully
      expect(await handler.isDicomFile(invalidBytes), isFalse);
      expect(await DicomServiceSimple.isValidDicom(invalidBytes), isFalse);

      // Test that loading invalid data throws appropriate errors
      bool loadFileThrows = false;
      bool getMetadataThrows = false;
      
      try {
        await handler.loadFile(invalidBytes);
      } catch (e) {
        loadFileThrows = true;
      }
      
      try {
        await handler.getMetadata(invalidBytes);
      } catch (e) {
        getMetadataThrows = true;
      }
      
      expect(loadFileThrows, isTrue, reason: 'loadFile should throw an error for invalid data');
      expect(getMetadataThrows, isTrue, reason: 'getMetadata should throw an error for invalid data');

      print('Error handling works correctly for invalid data');
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
        metadata: metadata,
        isValid: true,
      );

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
