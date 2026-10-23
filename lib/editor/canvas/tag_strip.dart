import 'package:flutter/material.dart';

import '../../data/models/card_project.dart';
import '../../templates/template_spec.dart';

/// Series tag above the card (the card's own "Team Favourite"-style pill).
class TagStrip extends StatelessWidget {
  const TagStrip({super.key, required this.project, required this.template});

  final CardProject project;
  final TemplateSpec template;

  @override
  Widget build(BuildContext context) {
    final ex = template.extras;
    return SizedBox(
      width: template.width,
      height: ex.tagStripHeight,
      child: Padding(
        padding: EdgeInsets.only(left: ex.tagPaddingLeft, top: ex.tagPaddingTop),
        child: Align(
          alignment: Alignment.topLeft,
          child: Image.asset(
            project.tagAsset!,
            height: ex.tagHeight,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
