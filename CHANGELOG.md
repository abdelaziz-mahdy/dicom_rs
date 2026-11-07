## 0.2.0

### Added
* Web support without setup: build the WebAssembly module with `dart run dicom_rs:build_web`, the same on Windows, macOS and Linux. No `index.html` changes, service worker or cross-origin headers are needed, so apps work on any static host, GitHub Pages included.
* The example viewer is now available as a web demo (https://abdelaziz-mahdy.github.io/dicom_rs/) and as downloadable apps for Android, macOS, Windows and Linux on each GitHub release.
* The example viewer ships de-identified example studies (chest CT, head MRI, chest X-ray, CC BY 4.0) that open in one tap, and an in-app log (About > View logs).

### Fixed
* Android builds now include the Rust library; apps built with recent Flutter versions crashed at start because it was missing.
* macOS release builds with Xcode 27 no longer fail with "can't find crate".
* The Android plugin compiles against API 36, as required by current AndroidX libraries.
* Example viewer measurement tools: the angle tool reports the angle between the arms (it could show 350° for a 10° angle), the area tool takes any number of points and closes when you click the first point again (it only allowed triangles), and the circle tool labels its value as a radius.
* Example viewer works with a mouse and a trackpad: the wheel and two-finger swipes change slices, pinch or Ctrl/Cmd + scroll zooms at the pointer, drag moves the image, and right-drag or Shift + drag adjusts brightness and contrast.
* Example viewer: measurements are correct at any zoom-to-fit size, small images fill the viewer, loading a folder no longer leaves a blank window, the loading screen no longer waits forever when a load finishes quickly, and layouts no longer overflow on small windows and phones.

### Changed
* Update the Rust `dicom` crates to 0.10.1 (1-bit segmentation images now decode) and flutter_rust_bridge to 2.13.0.
* License the project under MIT.

## 0.1.0

* Initial release of dicom_rs package
* Core DICOM operations with Rust backend: validation, metadata extraction, image processing
* Cross-platform support including iOS, Android, Windows, macOS, Linux, and Web
* Minimal and flexible API designed for building custom workflows
* Example application demonstrating advanced DICOM viewer features
