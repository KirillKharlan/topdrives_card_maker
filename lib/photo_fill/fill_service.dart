import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../data/models/photo_fill.dart';
import '../data/models/photo_transform.dart';
import '../editor/canvas/photo_painter.dart';
import 'patch_match_fill.dart';
import 'photo_decoder.dart';

class FillOutcome {
  const FillOutcome({this.png, this.message});

  /// The generated fill (card sized), or null if nothing was generated.
  final Uint8List? png;

  /// Why nothing was generated.
  final String? message;
}

/// Builds the content-aware fill for the empty areas around a framed photo.
class FillService {
  FillService._();

  /// The search runs on a card-shaped canvas this many pixels along its long
  /// side; the texture is then brought back at the card's own resolution.
  static const workLongSide = 400;

  static Future<FillOutcome> generate({
    required File photo,
    required PhotoTransform transform,
    required double cardWidth,
    required double cardHeight,
  }) async {
    final image = await decodePhoto(photo);
    try {
      final fullW = cardWidth.round(), fullH = cardHeight.round();
      final scale = workLongSide / math.max(cardWidth, cardHeight);
      final workW = (cardWidth * scale).round(), workH = (cardHeight * scale).round();

      final workRgba = await _renderPlaced(image, transform, cardWidth, cardHeight, workW, workH);
      if (!_hasHole(workRgba)) {
        return const FillOutcome(
          message: 'The photo already covers the whole card, there is nothing to fill.',
        );
      }
      final fullRgba = await _renderPlaced(image, transform, cardWidth, cardHeight, fullW, fullH);

      final job = FillJob(
        workWidth: workW,
        workHeight: workH,
        workRgba: workRgba,
        fullWidth: fullW,
        fullHeight: fullH,
        fullRgba: fullRgba,
      );
      final rgba = await Isolate.run(() => runFillJob(job));
      if (rgba == null) {
        return const FillOutcome(
          message: 'The photo is too small to take texture from. Make it a bit bigger and try again.',
        );
      }
      return FillOutcome(png: await _encodePng(rgba, fullW, fullH));
    } finally {
      image.dispose();
    }
  }

  static bool _hasHole(Uint8List rgba) {
    for (var i = 3; i < rgba.length; i += 4) {
      if (rgba[i] < 250) return true;
    }
    return false;
  }

  /// The photo exactly as it stands on the card, on a transparent canvas.
  static Future<Uint8List> _renderPlaced(
    ui.Image image,
    PhotoTransform transform,
    double cardWidth,
    double cardHeight,
    int outWidth,
    int outHeight,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.scale(outWidth / cardWidth, outHeight / cardHeight);
    paintPhoto(
      canvas,
      ui.Size(cardWidth, cardHeight),
      image,
      transform,
      PhotoFill.none,
      const ui.Color(0x00000000),
    );
    final picture = recorder.endRecording();
    final rendered = await picture.toImage(outWidth, outHeight);
    final data = await rendered.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    rendered.dispose();
    picture.dispose();
    return Uint8List.fromList(data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  }

  static Future<Uint8List> _encodePng(Uint8List rgba, int width, int height) async {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(rgba, width, height, ui.PixelFormat.rgba8888, completer.complete);
    final image = await completer.future;
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }
}
