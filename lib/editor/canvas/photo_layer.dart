import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/models/photo_fill.dart';
import '../../data/models/photo_transform.dart';
import 'photo_painter.dart';

/// The car photo with the project's framing (move, zoom, turn) and the fill for
/// empty areas. The image is loaded through Flutter's image cache, shrunk to
/// [maxWidth] pixels, so many cards do not exhaust memory.
class PhotoLayer extends StatefulWidget {
  const PhotoLayer({
    super.key,
    required this.file,
    required this.transform,
    required this.fill,
    required this.background,
    this.maxWidth = 2600,
  });

  final File file;
  final PhotoTransform transform;
  final PhotoFill fill;
  final Color background;
  final int maxWidth;

  @override
  State<PhotoLayer> createState() => _PhotoLayerState();
}

class _PhotoLayerState extends State<PhotoLayer> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ImageInfo? _info;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(PhotoLayer old) {
    super.didUpdateWidget(old);
    if (old.file.path != widget.file.path || old.maxWidth != widget.maxWidth) _resolve();
  }

  void _resolve() {
    final provider = ResizeImage(FileImage(widget.file), width: widget.maxWidth);
    final stream = provider.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _detach();
    _listener = ImageStreamListener(_onImage, onError: (_, __) {});
    _stream = stream..addListener(_listener!);
  }

  void _onImage(ImageInfo info, bool synchronous) {
    if (!mounted) {
      info.dispose();
      return;
    }
    setState(() {
      _info?.dispose();
      _info = info;
    });
  }

  void _detach() {
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _detach();
    _info?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    if (info == null) return const SizedBox.expand();
    return SizedBox.expand(
      child: CustomPaint(
        painter: PhotoPainter(
          image: info.image,
          transform: widget.transform,
          fill: widget.fill,
          background: widget.background,
        ),
      ),
    );
  }
}
