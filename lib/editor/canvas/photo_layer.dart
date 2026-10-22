import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/models/photo_transform.dart';

/// Draws the original photo with the project's crop applied. Anything that
/// leaves the card is clipped; the file itself is never changed.
class PhotoLayer extends StatelessWidget {
  const PhotoLayer({super.key, required this.file, required this.transform});

  final File file;
  final PhotoTransform transform;

  @override
  Widget build(BuildContext context) {
    final t = transform.clamped();
    return LayoutBuilder(builder: (context, box) {
      return ClipRect(
        child: Transform.translate(
          offset: Offset(t.dx * box.maxWidth, t.dy * box.maxHeight),
          child: Transform.scale(
            scale: t.scale,
            child: Image.file(
              file,
              width: box.maxWidth,
              height: box.maxHeight,
              fit: BoxFit.cover,
              cacheWidth: 2600,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
      );
    });
  }
}
