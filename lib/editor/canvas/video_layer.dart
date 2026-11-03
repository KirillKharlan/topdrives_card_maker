import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../data/models/photo_transform.dart';

/// The playing video of a video card, framed exactly like the photo: it is
/// fitted to the card (cover), then scaled, turned and shifted by [transform].
/// It plays the chosen clip in a loop, without sound, on top of the still frame
/// that [PhotoLayer] draws (that frame also fills the empty areas around it).
///
/// Only the live preview shows it; exported pictures use the still frame.
class VideoLayer extends StatefulWidget {
  const VideoLayer({
    super.key,
    required this.file,
    required this.transform,
    required this.cardSize,
    required this.startMs,
    required this.lengthMs,
    this.hidden = false,
  });

  final File file;
  final PhotoTransform transform;

  /// The card's size in card units.
  final Size cardSize;
  final int startMs;
  final int lengthMs;

  /// Hides the video (while the card is captured as a picture).
  final bool hidden;

  @override
  State<VideoLayer> createState() => _VideoLayerState();
}

class _VideoLayerState extends State<VideoLayer> {
  VideoPlayerController? _controller;
  int _generation = 0;
  DateTime _lastWrap = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final generation = ++_generation;
    final controller = VideoPlayerController.file(
      widget.file,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await controller.initialize();
    } catch (_) {
      await controller.dispose();
      return;
    }
    if (!mounted || generation != _generation) {
      await controller.dispose();
      return;
    }
    await controller.setVolume(0);
    await controller.seekTo(Duration(milliseconds: widget.startMs));
    await controller.play();
    controller.addListener(_loop);
    if (!mounted || generation != _generation) {
      controller.removeListener(_loop);
      await controller.dispose();
      return;
    }
    setState(() => _controller = controller);
  }

  /// Plays only the chosen clip: at its end, jump back to its start.
  void _loop() {
    final c = _controller;
    if (c == null) return;
    final value = c.value;
    if (!value.isInitialized) return;
    final end = widget.startMs + widget.lengthMs;
    final atEnd = value.position.inMilliseconds >= end - 30 ||
        (value.duration > Duration.zero && value.position >= value.duration);
    if (!atEnd) return;
    final now = DateTime.now();
    if (now.difference(_lastWrap).inMilliseconds < 300) return;
    _lastWrap = now;
    c.seekTo(Duration(milliseconds: widget.startMs));
    if (!value.isPlaying) c.play();
  }

  @override
  void didUpdateWidget(VideoLayer old) {
    super.didUpdateWidget(old);
    if (old.file.path != widget.file.path) {
      final previous = _controller;
      _controller = null;
      previous?.removeListener(_loop);
      // The widget rebuilds right after this, without the old texture.
      previous?.dispose();
      _open();
    } else if (old.startMs != widget.startMs || old.lengthMs != widget.lengthMs) {
      _controller?.seekTo(Duration(milliseconds: widget.startMs));
    }
  }

  @override
  void dispose() {
    _generation++;
    final c = _controller;
    _controller = null;
    c?.removeListener(_loop);
    c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null || widget.hidden || !c.value.isInitialized) {
      return const SizedBox.shrink();
    }
    final video = c.value.size;
    if (video.isEmpty) return const SizedBox.shrink();
    final t = widget.transform.clamped();
    final card = widget.cardSize;
    final cover = math.max(card.width / video.width, card.height / video.height);
    final w = video.width * cover * t.scale;
    final h = video.height * cover * t.scale;
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: card.width / 2 + t.dx * card.width - w / 2,
            top: card.height / 2 + t.dy * card.height - h / 2,
            width: w,
            height: h,
            child: Transform.rotate(angle: t.rotation, child: VideoPlayer(c)),
          ),
        ],
      ),
    );
  }
}
