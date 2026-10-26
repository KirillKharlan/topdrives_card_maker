import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../data/models/photo_fill.dart';
import '../../data/models/photo_transform.dart';

/// Draws the framed photo on a card-sized canvas ([size] is in card units).
/// The same function paints the on-screen card and the exported cropped photo,
/// so both always agree.
///
/// Where the photo does not reach the card edges the empty area is filled
/// according to [fill]. This is an edge extension (mirror + blur), not an AI
/// "generative fill".
void paintPhoto(
  Canvas canvas,
  Size size,
  ui.Image image,
  PhotoTransform transform,
  PhotoFill fill,
  Color background, {
  ui.Image? smartFill,
}) {
  final t = transform.clamped();
  final cardRect = Offset.zero & size;
  final iw = image.width.toDouble();
  final ih = image.height.toDouble();
  final cover = math.max(size.width / iw, size.height / ih);
  final w = iw * cover * t.scale;
  final h = ih * cover * t.scale;
  final centre = Offset(size.width / 2 + t.dx * size.width, size.height / 2 + t.dy * size.height);
  final src = Rect.fromLTWH(0, 0, iw, ih);
  final dst = Rect.fromCenter(center: Offset.zero, width: w, height: h);
  final quality = Paint()..filterQuality = FilterQuality.high;
  final sigma = math.max(size.width, size.height) * 0.012;

  canvas.save();
  canvas.clipRect(cardRect);
  canvas.drawRect(cardRect, Paint()..color = background);

  // The card's corners in the photo's own (turned) coordinates tell whether
  // the photo covers the whole card and which mirrored tiles are needed.
  final cosA = math.cos(-t.rotation);
  final sinA = math.sin(-t.rotation);
  Offset toLocal(Offset p) {
    final d = p - centre;
    return Offset(d.dx * cosA - d.dy * sinA, d.dx * sinA + d.dy * cosA);
  }

  final corners = [
    toLocal(cardRect.topLeft),
    toLocal(cardRect.topRight),
    toLocal(cardRect.bottomLeft),
    toLocal(cardRect.bottomRight),
  ];
  final minX = corners.map((c) => c.dx).reduce(math.min);
  final maxX = corners.map((c) => c.dx).reduce(math.max);
  final minY = corners.map((c) => c.dy).reduce(math.min);
  final maxY = corners.map((c) => c.dy).reduce(math.max);
  final covered = minX >= -w / 2 && maxX <= w / 2 && minY >= -h / 2 && maxY <= h / 2;

  // Content-aware fill needs the generated picture; without it (or after the
  // framing changed) the mirror mode stands in.
  final effectiveFill = (fill == PhotoFill.smart && smartFill == null) ? PhotoFill.mirror : fill;

  if (!covered && effectiveFill == PhotoFill.smart) {
    canvas.drawImageRect(
      smartFill!,
      Rect.fromLTWH(0, 0, smartFill.width.toDouble(), smartFill.height.toDouble()),
      cardRect,
      quality,
    );
  } else if (!covered && effectiveFill == PhotoFill.blur) {
    canvas.saveLayer(
      cardRect,
      Paint()
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: sigma * 3,
          sigmaY: sigma * 3,
          tileMode: TileMode.clamp,
        ),
    );
    canvas.drawImageRect(
      image,
      src,
      Rect.fromCenter(
        center: cardRect.center,
        width: iw * cover * 1.35,
        height: ih * cover * 1.35,
      ),
      quality,
    );
    canvas.restore();
  } else if (!covered && effectiveFill == PhotoFill.mirror) {
    final iMin = (minX / w + 0.5).floor().clamp(-4, 4).toInt();
    final iMax = (maxX / w + 0.5).floor().clamp(-4, 4).toInt();
    final jMin = (minY / h + 0.5).floor().clamp(-4, 4).toInt();
    final jMax = (maxY / h + 0.5).floor().clamp(-4, 4).toInt();
    canvas.saveLayer(
      cardRect,
      Paint()
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: sigma,
          sigmaY: sigma,
          tileMode: TileMode.clamp,
        ),
    );
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate(t.rotation);
    for (var j = jMin; j <= jMax; j++) {
      for (var i = iMin; i <= iMax; i++) {
        if (i == 0 && j == 0) continue;
        canvas.save();
        canvas.translate(i * w, j * h);
        canvas.scale(i.isOdd ? -1.0 : 1.0, j.isOdd ? -1.0 : 1.0);
        canvas.drawImageRect(image, src, dst, quality);
        canvas.restore();
      }
    }
    canvas.restore();
  }

  canvas.save();
  canvas.translate(centre.dx, centre.dy);
  canvas.rotate(t.rotation);
  canvas.drawImageRect(image, src, dst, quality);
  canvas.restore();

  canvas.restore();
}

class PhotoPainter extends CustomPainter {
  const PhotoPainter({
    required this.image,
    required this.transform,
    required this.fill,
    required this.background,
    this.smartFill,
  });

  final ui.Image image;
  final PhotoTransform transform;
  final PhotoFill fill;
  final Color background;
  final ui.Image? smartFill;

  @override
  void paint(Canvas canvas, Size size) =>
      paintPhoto(canvas, size, image, transform, fill, background, smartFill: smartFill);

  @override
  bool shouldRepaint(PhotoPainter old) =>
      old.image != image ||
      old.transform != transform ||
      old.fill != fill ||
      old.smartFill != smartFill ||
      old.background != background;
}
