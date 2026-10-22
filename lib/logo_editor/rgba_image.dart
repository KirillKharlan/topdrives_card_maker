import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Plain RGBA pixels (straight alpha) that can be edited in pure Dart.
class RgbaImage {
  RgbaImage(this.width, this.height, this.data);

  final int width;
  final int height;
  final Uint8List data;

  /// Decodes an encoded image (PNG/JPG/...), shrinking it so the longest side
  /// is at most [maxSide]. Logos are drawn tiny on the card, so this is plenty.
  static Future<RgbaImage> decode(Uint8List bytes, {int maxSide = 640}) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      try {
        final longest = max(descriptor.width, descriptor.height);
        final scale = longest > maxSide ? maxSide / longest : 1.0;
        final codec = await descriptor.instantiateCodec(
          targetWidth: max(1, (descriptor.width * scale).round()),
          targetHeight: max(1, (descriptor.height * scale).round()),
        );
        final frame = await codec.getNextFrame();
        final image = frame.image;
        final raw = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
        final result = RgbaImage(
          image.width,
          image.height,
          Uint8List.fromList(raw!.buffer.asUint8List()),
        );
        image.dispose();
        codec.dispose();
        return result;
      } finally {
        descriptor.dispose();
      }
    } finally {
      buffer.dispose();
    }
  }

  Future<ui.Image> toUiImage() {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(data, width, height, ui.PixelFormat.rgba8888, completer.complete);
    return completer.future;
  }

  Future<Uint8List> toPng() async {
    final image = await toUiImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return bytes!.buffer.asUint8List();
  }
}
