import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

/// Decodes a photo, shrinking it so its longest side is at most [maxSide].
Future<ui.Image> decodePhoto(File file, {int maxSide = 2600}) async {
  final bytes = await file.readAsBytes();
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final longest = math.max(descriptor.width, descriptor.height);
    final shrink = longest > maxSide ? maxSide / longest : 1.0;
    codec = await descriptor.instantiateCodec(
      targetWidth: math.max(1, (descriptor.width * shrink).round()),
      targetHeight: math.max(1, (descriptor.height * shrink).round()),
    );
    return (await codec.getNextFrame()).image;
  } finally {
    codec?.dispose();
    descriptor?.dispose();
    buffer.dispose();
  }
}
