# dicom_rs

[![pub package](https://img.shields.io/pub/v/dicom_rs.svg)](https://pub.dev/packages/dicom_rs)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A high-performance Flutter package for DICOM file handling using a Rust backend. Fast, memory-efficient, and cross-platform DICOM operations optimized for production medical applications.

## 🚀 Features

### ✅ **Core DICOM Operations**
- **Fast validation** - Check if bytes represent valid DICOM files
- **Metadata extraction** - Extract patient info, study details, and technical parameters
- **Image processing** - Convert DICOM pixel data to display-ready formats (PNG)
- **Raw pixel access** - Direct access to pixel data for custom processing
- **Bytes-first design** - Works with `Uint8List` for maximum flexibility including web support

### ✅ **High Performance**
- **Rust-powered backend** - Fast DICOM parsing using the proven `dicom` Rust crate
- **Memory efficient** - Zero-copy operations where possible
- **Minimal overhead** - Lightweight API with only essential functions
- **Cross-platform** - Supports iOS, Android, Windows, macOS, Linux, and Web

### ✅ **Developer Friendly**
- **Simple API** - Clean, intuitive interface designed for flexibility
- **Type-safe** - Full Dart type safety with null-aware design
- **Error handling** - Robust error handling with meaningful error messages
- **Minimal and flexible** - Simple interface allows users to build their own workflows

## 📦 Installation

Add `dicom_rs` to your `pubspec.yaml`:

```yaml
dependencies:
  dicom_rs: ^0.1.0
```

Then run:
```bash
flutter pub get
```

## 🛠️ Quick Start

### 1. Initialize the library

```dart
import 'package:dicom_rs/dicom_rs.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize the Rust library (required for flutter_rust_bridge)
  await RustLib.init();
  
  runApp(MyApp());
}
```

### 2. Basic DICOM operations

```dart
import 'dart:io';
import 'package:dicom_rs/dicom_rs.dart';

Future<void> basicDicomExample() async {
  final handler = DicomHandler();
  
  // Read DICOM file as bytes
  final file = File('/path/to/file.dcm');
  final bytes = await file.readAsBytes();
  
  // Check if file is valid DICOM
  bool isValid = await handler.isDicomFile(bytes);
  if (!isValid) {
    print('Not a valid DICOM file');
    return;
  }
  
  // Extract metadata only (fast)
  DicomMetadata metadata = await handler.getMetadata(bytes);
  print('Patient: ${metadata.patientName}');
  print('Study: ${metadata.studyDescription}');
  print('Modality: ${metadata.modality}');
  
  // Get display-ready image bytes
  Uint8List imageBytes = await handler.getImageBytes(bytes);
  
  // Display in Flutter widget
  Widget dicomImage = Image.memory(imageBytes);
}
```

### 3. Advanced usage with full file loading

```dart
Future<void> advancedDicomExample() async {
  final handler = DicomHandler();
  final bytes = await File('/path/to/file.dcm').readAsBytes();
  
  try {
    // Load complete file with metadata and image data
    DicomFile file = await handler.loadFile(bytes);
    
    print('File valid: ${file.isValid}');
    print('Patient: ${file.metadata.patientName}');
    print('Study Date: ${file.metadata.studyDate}');
    print('Series: ${file.metadata.seriesDescription}');
    
    if (file.image != null) {
      DicomImage image = file.image!;
      print('Image size: ${image.width}x${image.height}');
      print('Bits allocated: ${image.bitsAllocated}');
      print('Photometric interpretation: ${image.photometricInterpretation}');
      
      // Access raw pixel data
      Uint8List rawPixelData = image.pixelData;
      print('Pixel data size: ${rawPixelData.length} bytes');
    }
  } catch (e) {
    print('Error loading DICOM file: $e');
  }
}
```

## 📚 API Reference

### DicomHandler

The main interface for all DICOM operations:

#### Core Methods

| Method | Description | Use Case |
|--------|-------------|----------|
| `isDicomFile(List<int> bytes)` | Validate DICOM format | Quick validation before processing |
| `getMetadata(List<int> bytes)` | Extract metadata only | Fast scanning, file organization |
| `getImageBytes(List<int> bytes)` | Get PNG-encoded image | Direct display in Flutter widgets |
| `extractPixelData(List<int> bytes)` | Get raw pixel data | Custom image processing |
| `loadFile(List<int> bytes)` | Load complete file | Full DICOM analysis with metadata and image |

### Data Classes

#### DicomMetadata
Essential DICOM metadata fields:

```dart
class DicomMetadata {
  final String? patientName;        // Patient's name
  final String? patientId;          // Patient ID
  final String? studyDate;          // Study date (YYYYMMDD format)
  final String? modality;           // Imaging modality (CT, MR, US, etc.)
  final String? studyDescription;   // Study description
  final String? seriesDescription;  // Series description
  final int? instanceNumber;        // Instance number in series
  final int? seriesNumber;          // Series number in study
  final String? studyInstanceUid;   // Unique study identifier
  final String? seriesInstanceUid;  // Unique series identifier
  final String? sopInstanceUid;     // Unique instance identifier
  final List<double>? imagePosition; // Image position [x, y, z]
  final List<double>? pixelSpacing;  // Pixel spacing [row, column]
  final double? sliceLocation;       // Slice location
  final double? sliceThickness;      // Slice thickness
}
```

#### DicomImage
Pixel data and image parameters:

```dart
class DicomImage {
  final int width;                           // Image width in pixels
  final int height;                          // Image height in pixels
  final int bitsAllocated;                   // Bits allocated per pixel
  final int bitsStored;                      // Bits stored per pixel
  final int pixelRepresentation;             // Signed (1) or unsigned (0)
  final String photometricInterpretation;    // Color space interpretation
  final int samplesPerPixel;                 // Samples per pixel (1 for grayscale)
  final Uint8List pixelData;                 // Raw pixel data bytes
}
```

#### DicomFile
Complete file representation:

```dart
class DicomFile {
  final DicomMetadata metadata;  // DICOM metadata
  final DicomImage? image;       // Image data (null if no image)
  final bool isValid;            // Validation status
}
```

## 🌐 Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| **iOS** | ✅ Supported | Full native performance |
| **Android** | ✅ Supported | Full native performance |
| **Windows** | ✅ Supported | Full native performance |
| **macOS** | ✅ Supported | Full native performance |
| **Linux** | ✅ Supported | Full native performance |
| **Web** | ✅ Supported | WebAssembly build with performance considerations |

### Web Platform Notes

The package supports web platforms with some considerations:

- **WebAssembly backend**: Uses Rust compiled to WebAssembly
- **Performance**: Slower than native due to WebAssembly overhead and lack of isolate support
- **Build steps**: Requires `flutter_rust_bridge_codegen build-web` and moving the web pkg to your app's web directory
- **Memory constraints**: Works within browser memory limitations

#### Web Build Steps
```bash
# Generate web build
flutter_rust_bridge_codegen build-web

# Move the generated web package to your app's web directory
# (Copy the generated pkg files to your Flutter app's web/ folder)
```

Web support is functional but performance is not as optimal as native platforms due to WebAssembly limitations and the absence of isolate support.

## 🚨 Current Limitations

### Platform Limitations

1. **Web Performance**: Slower than native due to WebAssembly and lack of isolates
2. **Native Dependencies**: Requires native compilation on each platform

### DICOM Support

The package focuses on core DICOM functionality with a minimal interface to allow users to build their own workflows:

1. **Compressed Transfer Syntaxes**: Limited support for JPEG compression
2. **Multi-frame Images**: Basic support (advanced handling can be built using the API)
3. **DICOMDIR**: Partially implemented in the example app
4. **Network Operations**: No built-in DICOM networking (DIMSE, WADO)

### Design Philosophy

The interface is intentionally minimal and simple to give users maximum flexibility in building their own workflows and applications. Advanced features like multi-series viewers, interactive controls, and file management should be built on top of this foundation.

## 🏥 Example Application

The package includes a comprehensive example app showcasing how to build advanced DICOM features using the minimal API:

```bash
cd example
flutter run
```

### Example App Features

- **Multi-series DICOM viewer** with smooth navigation
- **Interactive image controls** (brightness, contrast, zoom)
- **Measurement tools** (distance, area)
- **Performance optimization** examples
- **File organization** and series management

The example demonstrates how to build production-ready DICOM applications using this package as the foundation.

## 🛠️ Development

### Building from Source

```bash
# Clone the repository
git clone https://github.com/abdelaziz-mahdy/dicom_rs.git
cd dicom_rs

# Generate Rust bridge code
flutter_rust_bridge_codegen generate

# Build for your platform
flutter build <platform>

# For building the example app, cd to example first
cd example
flutter build <platform>
```

### Testing

```bash
# Package tests (work in progress)
flutter test

# Example app tests (work in progress)
cd example
flutter test

# Integration tests
flutter test integration_test/
# or run with specific driver
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/simple_test.dart

# Example app integration tests
cd example
flutter test integration_test/
```

## 🤝 Contributing

Contributions are welcome! Please read our contributing guidelines and:

1. **Check the example app** first - many advanced features are already implemented there
2. **Focus on core functionality** - the package API should remain minimal
3. **Add tests** for new features
4. **Update documentation** for API changes

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **[dicom](https://crates.io/crates/dicom)**: Excellent Rust DICOM library
- **[flutter_rust_bridge](https://pub.dev/packages/flutter_rust_bridge)**: Seamless Rust-Flutter integration
- **Flutter team**: For the amazing cross-platform framework

## 📞 Support

- **Documentation**: Check the example app for advanced usage patterns
- **Issues**: [GitHub Issues](https://github.com/abdelaziz-mahdy/dicom_rs/issues)
- **Discussions**: [GitHub Discussions](https://github.com/abdelaziz-mahdy/dicom_rs/discussions)

---

*Built with ❤️ for the medical imaging community*