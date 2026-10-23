import 'dart:io';

import 'package:flutter/material.dart';

/// The logo inside its slot: fitted to the slot, scaled by [scale] around the
/// centre, and clipped to the slot. Used on the card and in the editor panel,
/// so both always look the same.
class LogoTile extends StatelessWidget {
  const LogoTile({super.key, required this.file, required this.scale, this.padding = 0});

  final File file;
  final double scale;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Padding(
        padding: EdgeInsets.all(padding),
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
    );
  }
}
