# DICOM RS

A minimal, efficient Flutter package for DICOM file handling using Rust backend.

## Features

✅ **Core DICOM Operations**
- Validate DICOM files
- Extract metadata (patient info, study details, etc.)
- Load pixel data and convert to display-ready formats
- Lightweight and fast

✅ **Simple API**
- Only essential functions exposed
- Clean, easy-to-use interface
- Comprehensive documentation

✅ **Rust-Powered Performance**
- Fast DICOM parsing using the Rust `dicom` crate
- Memory-efficient operations
- Cross-platform support (iOS, Android, Windows, macOS, Linux)

## Quick Start

### 1. Add to pubspec.yaml

```yaml
dependencies:
  dicom_rs: ^0.1.0
```

### 2. Initialize the library

```dart
import 'package:dicom_rs/dicom_rs.dart';

void main() async {
  // Initialize the Rust library
  await RustLib.init();
  
  runApp(MyApp());
}
```

### 3. Use the DICOM handler

```dart
import 'package:dicom_rs/dicom_rs.dart';

Future<void> loadDicomFile() async {
  final handler = DicomHandler();
  
  // Check if file is valid DICOM
  bool isValid = await handler.isDicomFile('/path/to/file.dcm');
  if (!isValid) return;
  
  // Load complete file with metadata and image
  DicomFile file = await handler.loadFile('/path/to/file.dcm');
  print('Patient: ${file.metadata.patientName}');
  print('Study: ${file.metadata.studyDescription}');
  
  // Get image bytes for display
  Uint8List imageBytes = await handler.getImageBytes('/path/to/file.dcm');
  
  // Display in Flutter widget
  Image.memory(imageBytes);
}
```

## API Reference

### DicomHandler

The main interface for DICOM operations:

#### Methods

- `Future<bool> isDicomFile(String path)` - Validate DICOM file
- `Future<DicomFile> loadFile(String path)` - Load complete DICOM file
- `Future<DicomMetadata> getMetadata(String path)` - Extract metadata only
- `Future<Uint8List> getImageBytes(String path)` - Get display-ready image bytes
- `Future<DicomImage> extractPixelData(String path)` - Get raw pixel data

### Data Classes

#### DicomMetadata
Contains essential DICOM metadata:
- `patientName`, `patientId`
- `studyDate`, `studyDescription`
- `modality`, `seriesDescription`
- `imagePosition`, `pixelSpacing`
- And more...

#### DicomImage
Contains pixel data and image parameters:
- `width`, `height`
- `bitsAllocated`, `bitsStored`
- `photometricInterpretation`
- `pixelData` (raw bytes)

#### DicomFile
Complete file representation:
- `path` - file path
- `metadata` - DicomMetadata
- `image` - DicomImage (optional)
- `isValid` - validation status

## Example App

The example app demonstrates advanced features:
- Volume loading and 3D visualization
- DICOMDIR parsing
- Interactive image viewers with brightness/contrast
- Directory scanning and organization
- Parallel processing

Run the example:
```bash
cd example
flutter run
```

## Performance

- **Minimal API Surface**: Only essential functions
- **Rust Backend**: Fast, memory-efficient DICOM parsing
- **Zero-Copy Operations**: Direct memory access where possible
- **Small Package Size**: No unnecessary dependencies

## Platform Support

- ✅ iOS
- ✅ Android  
- ✅ Windows
- ✅ macOS
- ✅ Linux

## Requirements

- Flutter 3.3.0+
- Dart 3.7.0+

## Contributing

Contributions are welcome! Please see the [example app](example/) for advanced usage patterns and feel free to submit issues or pull requests.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Built with [flutter_rust_bridge](https://pub.dev/packages/flutter_rust_bridge)
- Uses the excellent [dicom](https://crates.io/crates/dicom) Rust crate
- Inspired by the need for a simple, efficient DICOM package for Flutter