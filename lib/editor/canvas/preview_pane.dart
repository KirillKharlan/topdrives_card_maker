import 'package:flutter/material.dart';

import '../editor_controller.dart';
import 'card_composition.dart';

/// Live preview. Drag / pinch on it to move and zoom the photo.
class PreviewPane extends StatelessWidget {
  const PreviewPane({super.key, required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return LayoutBuilder(builder: (context, box) {
      final displayScale = box.maxWidth / c.template.width;
      return GestureDetector(
        onScaleStart: (_) => c.gestureStart(),
        onScaleUpdate: (d) => c.gestureUpdate(d.scale, d.rotation, d.focalPointDelta, displayScale),
        child: FittedBox(
          fit: BoxFit.fitWidth,
          child: CardComposition(
            project: c.project,
            template: c.template,
            photoFile: c.photoFile,
            logoFile: c.logoFile,
            fillFile: c.smartFillFile,
            cardKey: c.cardKey,
            fullKey: c.fullKey,
          ),
        ),
      );
    });
  }
}
