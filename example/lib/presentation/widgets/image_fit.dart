import 'dart:typed_data';
import 'dart:ui';

/// Pixel size of a PNG from its IHDR chunk, or null if [bytes] is not a PNG.
///
/// The viewer gets each slice as a PNG from the Rust backend; reading the
/// header avoids decoding the image just to learn its size.
Size? pngPixelSize(Uint8List bytes) {
  const signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  if (bytes.length < 24) return null;
  for (var i = 0; i < signature.length; i++) {
    if (bytes[i] != signature[i]) return null;
  }
  final header = ByteData.sublistView(bytes, 16, 24);
  final width = header.getUint32(0);
  final height = header.getUint32(4);
  if (width == 0 || height == 0) return null;
  return Size(width.toDouble(), height.toDouble());
}

/// The largest size with [image]'s aspect ratio that fits inside [box].
///
/// Unlike [BoxFit.contain] inside a loosely constrained parent, this also
/// enlarges images smaller than the box, so a 320×320 MR slice fills the
/// viewer instead of sitting small in the middle.
Size fitInside(Size image, Size box) {
  if (image.isEmpty || box.isEmpty || !box.isFinite) return image;
  final scale =
      (box.width / image.width) < (box.height / image.height)
          ? box.width / image.width
          : box.height / image.height;
  return Size(image.width * scale, image.height * scale);
}

/// DICOM pixel spacing (mm per image pixel) converted to mm per displayed
/// pixel, for measurements taken on an image shown at [displayedWidth]
/// logical pixels wide while it is [imageWidth] pixels wide.
List<double>? spacingForDisplay(
  List<double>? pixelSpacing, {
  required double imageWidth,
  required double displayedWidth,
}) {
  if (pixelSpacing == null || pixelSpacing.isEmpty) return pixelSpacing;
  if (imageWidth <= 0 || displayedWidth <= 0) return pixelSpacing;
  final imagePixelsPerDisplayPixel = imageWidth / displayedWidth;
  return [for (final s in pixelSpacing) s * imagePixelsPerDisplayPixel];
}
