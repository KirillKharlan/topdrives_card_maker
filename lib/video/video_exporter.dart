import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../editor/editor_controller.dart';
import '../editor/export/card_exporter.dart';
import 'video_frames.dart';

/// Thrown when the person cancels an export.
class VideoExportCancelled implements Exception {
  @override
  String toString() => 'Cancelled';
}

/// Renders the chosen clip of a video card frame by frame and encodes it.
///
/// Every frame of the video is put into the live card (the same widgets as the
/// preview, so framing, frosted glass, frame and texts are exactly the same),
/// the card is captured as a picture and handed to the encoder.
class VideoExporter {
  VideoExporter._();

  static const _channel = MethodChannel('card_maker/video');

  /// Number of frames of the clip at [fps].
  static int frameCount(EditorController c, int fps) =>
      math.max(1, (c.project.videoLengthMs * fps / 1000).round());

  /// MP4 (H.264, no sound) of the clip. [key] is the card (or the card with tags
  /// and prize marker) to capture. [progress] goes from 0 to 1, setting
  /// [cancel] to true stops the export.
  static Future<File> exportMp4({
    required BuildContext context,
    required EditorController controller,
    required GlobalKey key,
    required int fps,
    required ValueNotifier<double> progress,
    required ValueNotifier<bool> cancel,
  }) async {
    final c = controller;
    final video = c.videoFile;
    if (video == null) throw StateError('This card has no video.');
    final frames = frameCount(c, fps);
    final temp = await getTemporaryDirectory();
    final dir = Directory('${temp.path}/card_export_${DateTime.now().microsecondsSinceEpoch}');
    await dir.create(recursive: true);
    final out = File('${dir.path}/card.mp4');
    var encoding = false;
    try {
      await c.withoutVideo(() async {
        for (var i = 0; i < frames; i++) {
          if (cancel.value) throw VideoExportCancelled();
          final timeMs = c.project.videoStartMs + (i * 1000 / fps).round();
          final frame = File('${dir.path}/frame$i.jpg');
          await VideoFrames.extract(video: video, timeMs: timeMs, out: frame);
          // Same cache key as the card's photo layer, so it shows the new frame at once.
          await precacheImage(ResizeImage(FileImage(frame), width: 2600), context);
          c.setExportFrame(frame);
          await WidgetsBinding.instance.endOfFrame;
          final shot = await CardExporter.captureRgba(key);
          if (!encoding) {
            await _channel.invokeMethod<bool>('encoderStart', {
              'out': out.path,
              'width': shot.width,
              'height': shot.height,
              'fps': fps,
              // About 0.35 bits per pixel: practically as sharp as the photo.
              'bitrate': (shot.width * shot.height * fps * 0.35).round(),
            });
            encoding = true;
          }
          await _channel.invokeMethod<bool>('encoderAdd', {'rgba': shot.rgba});
          await frame.delete();
          progress.value = (i + 1) / frames;
        }
      });
      await _channel.invokeMethod<bool>('encoderFinish');
      encoding = false;
      return out;
    } catch (_) {
      if (encoding) {
        try {
          await _channel.invokeMethod<bool>('encoderCancel');
        } catch (_) {}
      }
      if (await dir.exists()) await dir.delete(recursive: true);
      rethrow;
    } finally {
      c.setExportFrame(null);
    }
  }
}
