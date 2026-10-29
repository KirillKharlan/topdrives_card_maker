import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/models/photo_fill.dart';
import '../../data/models/photo_transform.dart';
import '../canvas/photo_painter.dart';

/// Turns the on-screen composition into a PNG at the template's native size,
/// and produces the cropped car photo on its own.
class CardExporter {
  CardExporter._();

  static Future<Uint8List> capture(GlobalKey key, {double pixelRatio = 1.0}) async {
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  /// The card as raw pixels (RGBA), for the video encoder.
  static Future<({Uint8List rgba, int width, int height})> captureRgba(GlobalKey key) async {
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.0);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return (
        rgba: data!.buffer.asUint8List(),
        width: image.width,
        height: image.height,
      );
    } finally {
      image.dispose();
    }
  }

  /// The framed car photo on its own: exactly what the photo layer shows on the
  /// card (zoom, shift, turn and the fill of empty areas), without frame, texts
  /// or tags. It is drawn from the original at its own resolution (at least the
  /// card size, at most [maxWidth] pixels wide), so it is sharper than the photo
  /// on the 1338-pixel card.
  static Future<Uint8List> croppedPhoto({
    required File file,
    required PhotoTransform transform,
    required PhotoFill fill,
    required Color background,
    File? smartFillFile,
    required double cardWidth,
    required double cardHeight,
    int maxWidth = 4096,
    int maxDecodeSide = 6000,
  }) async {
    final bytes = await file.readAsBytes();
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      // Very large photos are decoded smaller so the phone does not run out of memory.
      final longest = math.max(descriptor.width, descriptor.height);
      final shrink = longest > maxDecodeSide ? maxDecodeSide / longest : 1.0;
      codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (descriptor.width * shrink).round()),
        targetHeight: math.max(1, (descriptor.height * shrink).round()),
      );
      image = (await codec.getNextFrame()).image;

      // One source pixel should stay about one output pixel.
      final t = transform.clamped();
      final cover = math.max(cardWidth / image.width, cardHeight / image.height);
      final pixelsPerUnit = 1 / (cover * t.scale);
      final outWidth = (cardWidth * pixelsPerUnit)
          .round()
          .clamp(cardWidth.round(), maxWidth)
          .toInt();
      final outHeight = (outWidth * cardHeight / cardWidth).round();

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.scale(outWidth / cardWidth);
      ui.Image? smartFill;
      if (smartFillFile != null && fill == PhotoFill.smart) {
        final codec = await ui.instantiateImageCodec(await smartFillFile.readAsBytes());
        smartFill = (await codec.getNextFrame()).image;
        codec.dispose();
      }
      paintPhoto(
        canvas,
        Size(cardWidth, cardHeight),
        image,
        transform,
        fill,
        background,
        smartFill: smartFill,
      );
      smartFill?.dispose();
      final picture = recorder.endRecording();
      final out = await picture.toImage(outWidth, outHeight);
      final data = await out.toByteData(format: ui.ImageByteFormat.png);
      out.dispose();
      picture.dispose();
      return data!.buffer.asUint8List();
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }

  static Future<void> saveToGallery(Uint8List png) async {
    if (!await Gal.hasAccess()) await Gal.requestAccess();
    await Gal.putImageBytes(png);
  }

  static Future<void> saveVideoToGallery(File video) async {
    if (!await Gal.hasAccess()) await Gal.requestAccess();
    await Gal.putVideo(video.path);
  }

  static Future<void> shareFile(File file, String fileName) async {
    final dir = await getTemporaryDirectory();
    final ext = file.path.substring(file.path.lastIndexOf('.'));
    final copy = await file.copy('${dir.path}/$fileName$ext');
    await Share.shareXFiles([XFile(copy.path)]);
  }

  static Future<void> share(Uint8List png, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName.png');
    await file.writeAsBytes(png, flush: true);
    await Share.shareXFiles([XFile(file.path)]);
  }
}
