import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dicom_rs/dicom_rs.dart';
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

    // Create a DicomHandler instance
    handler = await DicomHandler.newInstance();

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
          if (await isDicomFile(path: file.path)) {
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

  group('DicomHandler Factory Methods', () {
    test('Can create new DicomHandler instance', () {
      expect(handler, isA<DicomHandler>());
    });

    test('Can create default DicomHandler instance', () async {
      final defaultHandler = await DicomHandler.default_();
      expect(defaultHandler, isA<DicomHandler>());
    });
  });

  group('DICOM File Validation', () {
    test('Non-DICOM file returns false for isValidDicom', () async {
      expect(await handler.isValidDicom(path: nonDicomPath), false);
    });

    test('Non-DICOM file returns false for isDicomdir', () async {
      expect(await handler.isDicomdir(path: nonDicomPath), false);
    });

    test('isDicomFile function returns false for non-DICOM file', () async {
      expect(await isDicomFile(path: nonDicomPath), false);
    });

    test('isDicomdirFile function returns false for non-DICOM file', () async {
      expect(await isDicomdirFile(path: nonDicomPath), false);
    });

    test('Sample DICOM file should be recognized as valid', () async {
      final file = File(sampleDicomPath);
      if (!await file.exists()) {
        markTestSkipped('Sample DICOM file not found');
        return;
      }

      expect(await isDicomFile(path: sampleDicomPath), true);
      expect(await handler.isValidDicom(path: sampleDicomPath), true);
    });
  });

  group('DICOM File Operations Tests', () {
    test('Load DICOM file metadata if file exists', () async {
      final file = File(sampleDicomPath);
      if (!await file.exists()) {
        markTestSkipped('Sample DICOM file not found');
        return;
      }

      final metadata = await handler.getMetadata(path: sampleDicomPath);
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

      final dicomFile = await handler.loadFile(path: sampleDicomPath);
      expect(dicomFile, isA<DicomFile>());
      expect(dicomFile.path, equals(sampleDicomPath));
      expect(dicomFile.metadata, isA<DicomMetadata>());
      expect(dicomFile.allTags, isA<List<DicomTag>>());

      print('Loaded ${dicomFile.allTags.length} tags from DICOM file');
    });

    test('Get all tags from DICOM file if file exists', () async {
      final file = File(sampleDicomPath);
      if (!await file.exists()) {
        markTestSkipped('Sample DICOM file not found');
        return;
      }

      final tags = await handler.getAllTags(path: sampleDicomPath);
      expect(tags, isA<List<DicomTag>>());
      expect(tags.length, greaterThan(0));

      // Print a few important tags for visibility
      final patientNameTag = tags.firstWhere(
        (tag) => tag.name == 'PatientName', 
        orElse: () => DicomTag(tag: '00100010', vr: 'PN', name: 'PatientName', value: const DicomValueType.unknown())
      );

      final modalityTag = tags.firstWhere(
        (tag) => tag.name == 'Modality', 
        orElse: () => DicomTag(tag: '00080060', vr: 'CS', name: 'Modality', value: const DicomValueType.unknown())
      );

      print('PatientName tag: ${patientNameTag.value}');
      print('Modality tag: ${modalityTag.value}');
    });

    test('List tag names from DICOM file if file exists', () async {
      final file = File(sampleDicomPath);
      if (!await file.exists()) {
        markTestSkipped('Sample DICOM file not found');
        return;
      }

      final tagNames = await handler.listTags(path: sampleDicomPath);
      expect(tagNames, isA<List<String>>());
      expect(tagNames.length, greaterThan(0));

      print('First 5 tag names: ${tagNames.take(5).join(', ')}');
    });

    test('Extract pixel data from DICOM file if file exists', () async {
      final file = File(sampleDicomPath);
      if (!await file.exists()) {
        markTestSkipped('Sample DICOM file not found');
        return;
      }

      final pixelData = await handler.getPixelData(path: sampleDicomPath);
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

      final imageBytes = await handler.getImageBytes(path: sampleDicomPath);
      expect(imageBytes, isA<Uint8List>());
      expect(imageBytes.length, greaterThan(0));

      // Optionally save PNG for visual inspection
      // await File('${tempDir.path}/test_image.png').writeAsBytes(imageBytes);
      // print('PNG image saved to ${tempDir.path}/test_image.png');
    });

    test('Extract all metadata as map from DICOM file if file exists', () async {
      final file = File(sampleDicomPath);
      if (!await file.exists()) {
        markTestSkipped('Sample DICOM file not found');
        return;
      }

      final metadataMap = await handler.getAllMetadata(path: sampleDicomPath);
      expect(metadataMap, isA<DicomMetadataMap>());
      expect(metadataMap.tags, isA<Map<String, DicomTag>>());
      expect(metadataMap.groupElements, isA<Map<String, Map<String, DicomTag>>>());

      print('Metadata map contains ${metadataMap.tags.length} tags');
    });

    test('Get specific tag value from DICOM file if file exists', () async {
      final file = File(sampleDicomPath);
      if (!await file.exists()) {
        markTestSkipped('Sample DICOM file not found');
        return;
      }

      // First get all tag names to find a valid one
      final tagNames = await handler.listTags(path: sampleDicomPath);
      final tagName = tagNames.firstWhere(
        (name) => name == 'Modality' || name == 'PatientName' || name == 'StudyDate',
        orElse: () => tagNames.first,
      );

      final tagValue = await handler.getTagValue(
        path: sampleDicomPath, 
        tagName: tagName
      );

      expect(tagValue, isA<DicomValueType>());
      print('$tagName value: $tagValue');
    });
  });

  group('DICOM Directory Operations Tests', () {
    test('Load DICOM directory if directory exists', () async {
      final dir = Directory(sampleDicomDirPath);
      if (!await dir.exists()) {
        markTestSkipped('Sample DICOM directory not found');
        return;
      }

      final entries = await handler.loadDirectory(path: sampleDicomDirPath);
      expect(entries, isA<List<DicomDirectoryEntry>>());

      if (entries.isNotEmpty) {
        print('Found ${entries.length} DICOM files in directory');

        final validEntries = entries.where((e) => e.isValid).toList();
        print('${validEntries.length} entries are valid DICOM files');

        if (validEntries.isNotEmpty) {
          final firstEntry = validEntries.first;
          print('First valid entry: ${firstEntry.path}');
          print('Metadata: ${firstEntry.metadata.patientName ?? "Unknown"}, ${firstEntry.metadata.modality ?? "Unknown"}');
        }
      }
    });

    test('Load DICOM directory recursively if directory exists', () async {
      final dir = Directory(sampleDicomDirPath);
      if (!await dir.exists()) {
        markTestSkipped('Sample DICOM directory not found');
        return;
      }

      final entries = await handler.loadDirectoryRecursive(
        path: sampleDicomDirPath,
      );
      expect(entries, isA<List<DicomDirectoryEntry>>());

      print('Found ${entries.length} DICOM files recursively');
    });

    test('Load organized DICOM directory if directory exists', () async {
      final dir = Directory(sampleDicomDirPath);
      if (!await dir.exists()) {
        markTestSkipped('Sample DICOM directory not found');
        return;
      }

      final patients = await handler.loadDirectoryOrganized(
        path: sampleDicomDirPath,
      );
      expect(patients, isA<List<DicomPatient>>());

      if (patients.isNotEmpty) {
        print('Found ${patients.length} patient(s) in directory');
        for (final patient in patients) {
          print('Patient ID: ${patient.patientId ?? "Unknown"}, Name: ${patient.patientName ?? "Unknown"}');
          print('Studies: ${patient.studies.length}');
        }
      }
    });

    test('Load unified DICOM directory if directory exists', () async {
      final dir = Directory(sampleDicomDirPath);
      if (!await dir.exists()) {
        markTestSkipped('Sample DICOM directory not found');
        return;
      }

      final entries = await handler.loadDirectoryUnified(
        path: sampleDicomDirPath, 
        recursive: true,
      );
      expect(entries, isA<List<DicomDirectoryEntry>>());

      print('Unified loading found ${entries.length} DICOM files');
    });

    test('Compute slice spacing if entries exist', () async {
      final dir = Directory(sampleDicomDirPath);
      if (!await dir.exists()) {
        markTestSkipped('Sample DICOM directory not found');
        return;
      }

      final entries = await handler.loadDirectory(path: sampleDicomDirPath);
      if (entries.isEmpty) {
        markTestSkipped('No DICOM entries found in directory');
        return;
      }

      final spacing = await computeSliceSpacing(entries: entries);
      if (spacing != null) {
        expect(spacing, isA<double>());
        print('Computed slice spacing: $spacing mm');
      } else {
        print('Could not compute slice spacing - likely not a multi-slice series');
      }
    });
  });

  group('Image Processing Tests', () {
    test('Flip image vertically', () async {
      // Create a simple test image
      final width = 4;
      final height = 4;
      final rowLength = BigInt.from(width);

      // Test image: 4x4 pixels with increasing values
      final pixelData = Uint8List.fromList(
        List.generate(width * height, (i) => i),
      );

      final flipped = await flipVertically(
        pixelData: pixelData,
        height: height,
        rowLength: rowLength,
      );

      expect(flipped, isA<Uint8List>());
      expect(flipped.length, equals(pixelData.length));

      // Verify that rows are in reverse order
      // First row becomes last row
      expect(flipped[width * (height - 1)], equals(pixelData[0]));
      // Last row becomes first row
      expect(flipped[0], equals(pixelData[width * (height - 1)]));
    });

    test('Flip real DICOM image data vertically if file exists', () async {
      final file = File(sampleDicomPath);
      if (!await file.exists()) {
        markTestSkipped('Sample DICOM file not found');
        return;
      }

      final pixelData = await handler.getPixelData(path: sampleDicomPath);
      final rowLength = BigInt.from(pixelData.width);

      final flipped = await flipVertically(
        pixelData: pixelData.pixelData,
        height: pixelData.height,
        rowLength: rowLength,
      );

      expect(flipped, isA<Uint8List>());
      expect(flipped.length, equals(pixelData.pixelData.length));
    });
  });

  group('Direct DICOM Functions Tests', () {
    test('Extract raw pixel data directly', () async {
      final file = File(sampleDicomPath);
      if (!await file.exists()) {
        markTestSkipped('Sample DICOM file not found');
        return;
      }

      final image = await extractPixelData(path: sampleDicomPath);
      expect(image, isA<DicomImage>());
    });

    test('Load DICOM file directly', () async {
      final file = File(sampleDicomPath);
      if (!await file.exists()) {
        markTestSkipped('Sample DICOM file not found');
        return;
      }

      final dicomFile = await loadDicomFile(path: sampleDicomPath);
      expect(dicomFile, isA<DicomFile>());
    });

    test('Extract all metadata directly', () async {
      final file = File(sampleDicomPath);
      if (!await file.exists()) {
        markTestSkipped('Sample DICOM file not found');
        return;
      }

      final metadata = await extractAllMetadata(path: sampleDicomPath);
      expect(metadata, isA<DicomMetadataMap>());
    });

    test('Load DICOM directory directly', () async {
      final dir = Directory(sampleDicomDirPath);
      if (!await dir.exists()) {
        markTestSkipped('Sample DICOM directory not found');
        return;
      }

      final entries = await loadDicomDirectory(dirPath: sampleDicomDirPath);
      expect(entries, isA<List<DicomDirectoryEntry>>());
    });

    test('Load DICOM directory recursively directly', () async {
      final dir = Directory(sampleDicomDirPath);
      if (!await dir.exists()) {
        markTestSkipped('Sample DICOM directory not found');
        return;
      }

      final entries = await loadDicomDirectoryRecursive(
        dirPath: sampleDicomDirPath,
      );
      expect(entries, isA<List<DicomDirectoryEntry>>());
    });

    test('Load DICOM directory organized directly', () async {
      final dir = Directory(sampleDicomDirPath);
      if (!await dir.exists()) {
        markTestSkipped('Sample DICOM directory not found');
        return;
      }

      final patients = await loadDicomDirectoryOrganized(
        dirPath: sampleDicomDirPath, 
        recursive: true,
      );
      expect(patients, isA<List<DicomPatient>>());
    });
  });

  group('Data Model Tests', () {
    test('DicomMetadata equality', () {
      final metadata1 = DicomMetadata(
        patientName: 'Test Patient',
        patientId: '12345',
        studyDate: '20230101',
      );

      final metadata2 = DicomMetadata(
        patientName: 'Test Patient',
        patientId: '12345',
        studyDate: '20230101',
      );

      final metadata3 = DicomMetadata(
        patientName: 'Different Patient',
        patientId: '67890',
        studyDate: '20230202',
      );

      expect(metadata1, equals(metadata2));
      expect(metadata1, isNot(equals(metadata3)));
    });

    test('DicomTag equality', () {
      final tag1 = DicomTag(
        tag: '00100010',
        vr: 'PN',
        name: 'PatientName',
        value: const DicomValueType.str('Test Patient'),
      );

      final tag2 = DicomTag(
        tag: '00100010',
        vr: 'PN',
        name: 'PatientName',
        value: const DicomValueType.str('Test Patient'),
      );

      final tag3 = DicomTag(
        tag: '00100020',
        vr: 'LO',
        name: 'PatientID',
        value: const DicomValueType.str('12345'),
      );

      expect(tag1, equals(tag2));
      expect(tag1, isNot(equals(tag3)));
    });

    test('DicomValueType variants', () {
      const strValue = DicomValueType.str('test');
      const intValue = DicomValueType.int(42);
      const floatValue = DicomValueType.float(3.14);

      expect(strValue, isA<DicomValueType_Str>());
      expect(intValue, isA<DicomValueType_Int>());
      expect(floatValue, isA<DicomValueType_Float>());
    });
  });

  // Legacy test
  test('Can call rust function', () async {
    // This is the original test, we're keeping it for reference
    // It's not actually a valid test for this library
    expect((name: "Tom"), "Hello, Tom!");
  });
}
