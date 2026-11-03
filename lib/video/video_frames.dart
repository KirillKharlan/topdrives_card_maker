import 'dart:io';

import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

/// Frames and length of a video file. Frames come from a small native module
/// (Android's MediaMetadataRetriever, see tool/patch_android.py), so no extra
/// plugin or ffmpeg is needed.
class VideoFrames {
  VideoFrames._();

  static const _channel = MethodChannel('card_maker/video');

  /// Saves the frame at [timeMs] as a JPEG file at [out].
  static Future<File> extract({
    required File video,
    required int timeMs,
    required File out,
  }) async {
    final path = await _channel.invokeMethod<String>('frame', {
      'path': video.path,
      'timeMs': timeMs,
      'out': out.path,
    });
    return File(path ?? out.path);
  }

  /// Length of the video in milliseconds.
  static Future<int> durationMs(File video) async {
    final controller = VideoPlayerController.file(video);
    try {
      await controller.initialize();
      return controller.value.duration.inMilliseconds;
    } finally {
      await controller.dispose();
    }
  }
}
