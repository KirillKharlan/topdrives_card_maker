import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/models/photo_fill.dart';
import '../../data/models/photo_transform.dart';
import 'photo_painter.dart';

/// One image that follows its provider through Flutter's image cache.
class _ImageSlot {
  _ImageSlot(this._onChanged);

  final VoidCallback _onChanged;
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ImageInfo? info;

  void resolve(ImageProvider? provider, BuildContext context) {
    if (provider == null) {
      _detach();
      info?.dispose();
      info = null;
      return;
    }
    final stream = provider.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _detach();
    _listener = ImageStreamListener(_handle, onError: (_, __) {});
    _stream = stream..addListener(_listener!);
  }

  void _handle(ImageInfo next, bool synchronous) {
    info?.dispose();
    info = next;
    _onChanged();
  }

  void _detach() {
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    _stream = null;
    _listener = null;
  }

  void dispose() {
    _detach();
    info?.dispose();
    info = null;
  }
}

/// The car photo with the project's framing (move, zoom, turn) and the fill for
/// empty areas. Images come through Flutter's image cache, the photo shrunk to
/// [maxWidth] pixels, so many cards do not exhaust memory.
class PhotoLayer extends StatefulWidget {
  const PhotoLayer({
    super.key,
    required this.file,
    required this.transform,
    required this.fill,
    required this.background,
    this.smartFill,
    this.maxWidth = 2600,
  });

  final File file;
  final PhotoTransform transform;
  final PhotoFill fill;
  final Color background;

  /// The generated content-aware fill, if there is a current one.
  final File? smartFill;
  final int maxWidth;

  @override
  State<PhotoLayer> createState() => _PhotoLayerState();
}

class _PhotoLayerState extends State<PhotoLayer> {
  late final _ImageSlot _photo = _ImageSlot(_refresh);
  late final _ImageSlot _fill = _ImageSlot(_refresh);

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _resolve() {
    _photo.resolve(ResizeImage(FileImage(widget.file), width: widget.maxWidth), context);
    _fill.resolve(widget.smartFill == null ? null : FileImage(widget.smartFill!), context);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(PhotoLayer old) {
    super.didUpdateWidget(old);
    _resolve();
  }

  @override
  void dispose() {
    _photo.dispose();
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photo = _photo.info;
    if (photo == null) return const SizedBox.expand();
    return SizedBox.expand(
      child: CustomPaint(
        painter: PhotoPainter(
          image: photo.image,
          transform: widget.transform,
          fill: widget.fill,
          background: widget.background,
          smartFill: _fill.info?.image,
        ),
      ),
    );
  }
}
