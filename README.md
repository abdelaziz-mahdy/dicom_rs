# dicom_rs

[![CI](https://github.com/abdelaziz-mahdy/dicom_rs/actions/workflows/ci.yml/badge.svg)](https://github.com/abdelaziz-mahdy/dicom_rs/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A high-performance Flutter package for DICOM file handling using a Rust backend. Fast, memory-efficient, and cross-platform DICOM operations optimized for production medical applications.

**This repository also ships a complete DICOM viewer app** built on the package (in [`example/`](example)). You can use it without writing any code:

- **Try it in your browser:** [abdelaziz-mahdy.github.io/dicom_rs](https://abdelaziz-mahdy.github.io/dicom_rs/)
- **Download it** for Android, macOS, Windows or Linux from [Releases](https://github.com/abdelaziz-mahdy/dicom_rs/releases)

## 🖥️ The DICOM viewer app

Open a folder or a set of DICOM files and browse them as a series. The viewer has:

- slice navigation with the keyboard, mouse wheel and on-screen controls
- brightness/contrast (right-click and drag) and zoom
- distance, angle, circle and area measurements
- a metadata panel for the current image

### Your files stay on your device

The viewer has no server. Files you open are read and decoded on your own computer or phone, and in the web demo they are decoded inside your browser tab; nothing is uploaded anywhere. Closing the tab or the app discards them.

> **Not for diagnostic use.** The viewer is a demonstration of the `dicom_rs` package. It is not a certified medical device and must not be used for diagnosis or treatment decisions.

### Medical professionals: your feedback is welcome

If you are a radiologist, technologist, clinician or medical physicist, we would love to hear from you. Try the [web demo](https://abdelaziz-mahdy.github.io/dicom_rs/) with de-identified images and [open an issue](https://github.com/abdelaziz-mahdy/dicom_rs/issues/new) with what works, what feels wrong, and what would make the viewer useful in your daily work. GitHub issues are public, so if you attach a screenshot or file to show a problem, use a de-identified image.

### Sample files you can use

You need DICOM files to try the viewer. If you don't have your own, these public sources provide de-identified research images for free:

- **[NCI Imaging Data Commons](https://portal.imaging.datacommons.cancer.gov/)**: free to download without an account. More than 95% of the data is licensed CC BY, and each file is labelled with its license.
- **[The Cancer Imaging Archive (TCIA)](https://www.cancerimagingarchive.net/)**: most collections are CC BY and can be downloaded without registration. Some collections carry non-commercial or restricted licenses, so check the collection's *Data Usage Policy* tab before you share or reuse files.

Credit the source collection when you publish or share images from these archives. Do not open files with real patient information in a demo you share with others.

### Installing the downloaded apps

The builds are not signed yet, so the first launch shows a warning. On **macOS** right-click the app and choose **Open**; on **Windows** choose **More info → Run anyway**; on **Android** allow installs from that source. On **Linux** run `bundle/dicom_rs_example`.

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

`dicom_rs` is not on pub.dev yet. Add it from GitHub in your `pubspec.yaml`:

```yaml
dependencies:
  dicom_rs:
    git: https://github.com/abdelaziz-mahdy/dicom_rs.git
```

Then run:
```bash
flutter pub get
```

The Rust backend is compiled when you build your app, so you need a Rust toolchain installed ([rustup.rs](https://rustup.rs)).

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

### Using dicom_rs on the web

On the web the Rust backend runs as WebAssembly. Build it once into your app's `web/pkg` folder, from your app's root:

```bash
dart run dicom_rs:build_web
```

This works the same on Windows, macOS and Linux. It needs Rust ([rustup.rs](https://rustup.rs)) and `wasm-pack` (`cargo install wasm-pack`). Run it again after updating `dicom_rs`.

That is all: no changes to `index.html`, no service worker and no special server headers. The module is built without threads, so the app works on any static host, GitHub Pages included. The trade-off is that decoding runs on the browser's main thread (roughly 0.1 s for a 512×512 image), so very large series load more slowly than on native platforms.

## 🚨 Current Limitations

### Platform Limitations

1. **Web Performance**: Decoding runs on the browser's main thread, so it is slower than native and the page pauses briefly per image
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
- **Measurement tools** (distance, angle, circle, area)
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
# Package tests. The Rust-backed tests load rust/target/release, so build it first
# (they are skipped with a hint when the library is missing).
cargo build --release --manifest-path rust/Cargo.toml
flutter test

# Example app tests
cd example
flutter test

# Example integration tests (on a desktop or device)
flutter test integration_test/simple_test.dart -d macos
```

### Releases

Pushing a `v*` tag (for example `v0.2.0`) builds the viewer for Android, macOS, Windows, Linux and the web and attaches the builds to a GitHub release. Every push to `main` updates the web demo on GitHub Pages.

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