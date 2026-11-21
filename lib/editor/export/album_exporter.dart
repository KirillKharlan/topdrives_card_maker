import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../data/models/card_project.dart';
import '../../data/repositories/app_store.dart';
import '../canvas/card_composition.dart';
import 'card_exporter.dart';

/// Pictures of many cards without opening the editor: each card is built in an
/// overlay far outside the screen and captured like the editor does.
class AlbumExporter {
  AlbumExporter._();

  /// One card as a PNG. [extras] adds the tags above and the prize marker below
  /// (only for cards that have them). [pixelRatio] defaults to the 2400 px width
  /// the editor uses for its saved pictures.
  static Future<Uint8List> renderCard(
    BuildContext context,
    AppStore store,
    CardProject project, {
    bool extras = true,
    double? pixelRatio,
  }) async {
    final template = store.templateFor(project);
    final scale = pixelRatio ?? 2400 / template.width;
    final withExtras = extras && (project.prize || project.tags.isNotEmpty);
    final key = GlobalKey();
    final photo = store.photoFileFor(project);
    if (photo != null) {
      try {
        // Same decode as the card layer uses, so the photo is there in the first frame.
        await precacheImage(ResizeImage(FileImage(photo), width: 2600), context);
      } catch (_) {}
    }
    if (!context.mounted) throw StateError('the screen was closed');
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -(template.width + 400),
        top: 0,
        width: template.width,
        height: 4000,
        child: IgnorePointer(
          child: Align(
            alignment: Alignment.topLeft,
            child: CardComposition(
              project: project,
              template: template,
              photoFile: photo,
              logoFile: store.logos.fileOf(project.logoId),
              fillFile: store.smartFillFor(project),
              fullKey: withExtras ? key : null,
              cardKey: withExtras ? null : key,
            ),
          ),
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(entry);
    try {
      await WidgetsBinding.instance.endOfFrame;
      // Logo, fill and tag pictures load after the first frame.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await WidgetsBinding.instance.endOfFrame;
      return await CardExporter.captureVerified(key, pixelRatio: scale);
    } finally {
      entry.remove();
    }
  }

  /// Puts the pictures into one picture, [columns] per row on a dark background.
  /// Cards of different height share a row (the row is as tall as the tallest).
  static Future<Uint8List> collage(
    List<Uint8List> pngs, {
    int columns = 3,
    int cellWidth = 800,
    int gap = 24,
    int maxSide = 8192,
  }) async {
    if (pngs.isEmpty) throw StateError('nothing to put into the collage');
    final heights = <int>[];
    for (final png in pngs) {
      final buffer = await ui.ImmutableBuffer.fromUint8List(png);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      heights.add((descriptor.height * cellWidth / descriptor.width).round());
      descriptor.dispose();
      buffer.dispose();
    }
    final cols = math.min(columns, pngs.length);
    final rows = (pngs.length + cols - 1) ~/ cols;
    final rowHeights = <int>[
      for (var r = 0; r < rows; r++)
        heights.sublist(r * cols, math.min((r + 1) * cols, heights.length)).reduce(math.max),
    ];
    final width = cols * cellWidth + (cols + 1) * gap;
    final height = rowHeights.fold<int>(0, (a, b) => a + b) + (rows + 1) * gap;
    final scale = math.min(1.0, maxSide / math.max(width, height));

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(scale);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = const Color(0xFF121212),
    );
    var y = gap.toDouble();
    for (var r = 0; r < rows; r++) {
      for (var col = 0; col < cols; col++) {
        final i = r * cols + col;
        if (i >= pngs.length) break;
        final codec = await ui.instantiateImageCodec(pngs[i], targetWidth: cellWidth);
        final frame = await codec.getNextFrame();
        canvas.drawImage(
          frame.image,
          Offset(gap + col * (cellWidth + gap).toDouble(), y),
          Paint()..filterQuality = FilterQuality.medium,
        );
        frame.image.dispose();
        codec.dispose();
      }
      y += rowHeights[r] + gap;
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage((width * scale).round(), (height * scale).round());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    return data!.buffer.asUint8List();
  }
}
