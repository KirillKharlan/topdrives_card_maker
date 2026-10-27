import 'dart:io';

import 'package:flutter/material.dart';

/// The logo inside its slot: fitted to the slot, scaled by [scale] around the
/// centre, shifted by [dx]/[dy] (fractions of the slot size) and clipped to the
/// slot. Used on the card and in the editor panel, so both always look the same.
class LogoTile extends StatelessWidget {
  const LogoTile({
    super.key,
    required this.file,
    required this.scale,
    this.padding = 0,
    this.dx = 0,
    this.dy = 0,
  });

  final File file;
  final double scale;
  final double padding;
  final double dx;
  final double dy;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      return ClipRect(
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Transform.translate(
            offset: Offset(dx * box.maxWidth, dy * box.maxHeight),
            child: Transform.scale(
              scale: scale,
              child: Image.file(
                file,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                cacheWidth: 512,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
    });
  }
}
