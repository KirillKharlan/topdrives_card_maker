import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../editor/editor_controller.dart';
import '../editor/export/card_exporter.dart';
import 'gif_encoder.dart';
import 'video_frames.dart';

/// Thrown when the person cancels an export.
class VideoExportCancelled implements Exception {
  @override
  String toString() => 'Cancelled';
}

class _StoreArgs {
  _StoreArgs(this.path, this.data);

  final String path;
  final TransferableTypedData data;
}

/// Saves one captured frame, zlib-compressed, for the GIF encoder (runs in an isolate).
void _storeFrame(_StoreArgs a) {
  final bytes = a.data.materialize().asUint8List();
  File(a.path).writeAsBytesSync(ZLibCodec(level: 1).encode(bytes));
}

/// Renders the chosen clip of a video card frame by frame and encodes it.
///
/// Every frame of the video is put into the live card (the same widgets as the
/// preview, so framing, frosted glass, frame and texts are exactly the same),
/// the card is captured as a picture and handed to the MP4 or GIF encoder.
class VideoExporter {
  VideoExporter._();

  static const _channel = MethodChannel('card_maker/video');

  /// Number of frames of the clip at [fps].
  static int frameCount(EditorController c, int fps) =>
      math.max(1, (c.project.videoLengthMs * fps / 1000).round());

  /// Rough size of a GIF in megabytes (about 0.8 MB per frame at full size).
  static double gifMegabytes(EditorController c, int fps, double scale) =>
      frameCount(c, fps) * 0.8 * scale * scale;

  /// Puts every frame of the clip into the card and captures it.
  /// [progressShare] is the part of the progress bar this step fills.
  static Future<void> _renderClip({
    required BuildContext context,
    required EditorController controller,
    required GlobalKey key,
    required int fps,
    required double scale,
    required ValueNotifier<double> progress,
    required double progressShare,
    required ValueNotifier<bool> cancel,
    required Directory dir,
    required Future<void> Function(int index, ({Uint8List rgba, int width, int height}) shot)
        onShot,
  }) async {
    final c = controller;
    final video = c.videoFile!;
    final frames = frameCount(c, fps);
    await c.withoutVideo(() async {
      for (var i = 0; i < frames; i++) {
        if (cancel.value) throw VideoExportCancelled();
        final timeMs = c.project.videoStartMs + (i * 1000 / fps).round();
        final frame = File('${dir.path}/frame$i.jpg');
        await VideoFrames.extract(video: video, timeMs: timeMs, out: frame);
        // Same cache key as the card's photo layer, so it shows the new frame at once.
        if (!context.mounted) throw VideoExportCancelled();
        await precacheImage(ResizeImage(FileImage(frame), width: 2600), context);
        c.setExportFrame(frame);
        await WidgetsBinding.instance.endOfFrame;
        final shot = await CardExporter.captureRgba(key, pixelRatio: scale);
        await onShot(i, shot);
        await frame.delete();
        progress.value = progressShare * (i + 1) / frames;
      }
    });
  }

  static Future<Directory> _tempDir() async {
    final temp = await getTemporaryDirectory();
    final dir = Directory('${temp.path}/card_export_${DateTime.now().microsecondsSinceEpoch}');
    await dir.create(recursive: true);
    return dir;
  }

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
    if (controller.videoFile == null) throw StateError('This card has no video.');
    final dir = await _tempDir();
    final out = File('${dir.path}/card.mp4');
    var encoding = false;
    try {
      await _renderClip(
        context: context,
        controller: controller,
        key: key,
        fps: fps,
        scale: 1.0,
        progress: progress,
        progressShare: 1.0,
        cancel: cancel,
        dir: dir,
        onShot: (i, shot) async {
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
        },
      );
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
      controller.setExportFrame(null);
    }
  }

  /// GIF of the clip: the frames are rendered first (70% of the progress bar),
  /// then an isolate makes one 256-colour palette, dithers the frames to it and
  /// writes the file. [fps] must divide 100 (10, 20, 25), [scale] is 1.0 for the
  /// full card size.
  static Future<File> exportGif({
    required BuildContext context,
    required EditorController controller,
    required GlobalKey key,
    required int fps,
    required double scale,
    required ValueNotifier<double> progress,
    required ValueNotifier<bool> cancel,
  }) async {
    if (controller.videoFile == null) throw StateError('This card has no video.');
    final dir = await _tempDir();
    final out = File('${dir.path}/card.gif');
    final files = <String>[];
    final pending = <Future<void>>[];
    var width = 0;
    var height = 0;
    try {
      await _renderClip(
        context: context,
        controller: controller,
        key: key,
        fps: fps,
        scale: scale,
        progress: progress,
        progressShare: 0.7,
        cancel: cancel,
        dir: dir,
        onShot: (i, shot) async {
          width = shot.width;
          height = shot.height;
          final path = '${dir.path}/shot$i.z';
          files.add(path);
          final data = TransferableTypedData.fromList([shot.rgba]);
          pending.add(compute<_StoreArgs, void>(_storeFrame, _StoreArgs(path, data)));
          // At most two frames are being compressed while the next one renders.
          if (pending.length > 2) await pending.removeAt(0);
        },
      );
      await Future.wait(pending);
      pending.clear();

      final done = Completer<void>();
      final receive = ReceivePort();
      final isolate = await Isolate.spawn(
        gifWorker,
        GifJob(
          port: receive.sendPort,
          frames: files,
          out: out.path,
          width: width,
          height: height,
          delayCs: 100 ~/ fps,
        ),
      );
      receive.listen((message) {
        if (message is! List || message.isEmpty || done.isCompleted) return;
        switch (message[0]) {
          case 'progress':
            progress.value = 0.7 + 0.3 * (message[1] as double);
          case 'done':
            done.complete();
          case 'error':
            done.completeError(StateError(message[1] as String));
        }
      });
      final watcher = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (cancel.value && !done.isCompleted) done.completeError(VideoExportCancelled());
      });
      try {
        await done.future;
      } finally {
        watcher.cancel();
        receive.close();
        isolate.kill(priority: Isolate.immediate);
      }
      // The rendered frames are not needed any more.
      for (final path in files) {
        final f = File(path);
        if (await f.exists()) await f.delete();
      }
      return out;
    } catch (_) {
      await Future.wait(pending.map((f) => f.catchError((_) {})));
      if (await dir.exists()) await dir.delete(recursive: true);
      rethrow;
    } finally {
      controller.setExportFrame(null);
    }
  }
}
