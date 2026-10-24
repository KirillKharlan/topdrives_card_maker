import 'package:flutter/material.dart';

import '../../data/models/card_project.dart';
import '../../templates/template_spec.dart';
import 'custom_tag_view.dart';

/// Tags above the card, side by side (wrapping to a new line if they do not
/// fit the card width).
class TagStrip extends StatelessWidget {
  const TagStrip({super.key, required this.project, required this.template});

  final CardProject project;
  final TemplateSpec template;

  @override
  Widget build(BuildContext context) {
    final ex = template.extras;
    return SizedBox(
      width: template.width,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          ex.tagPaddingLeft,
          ex.tagPaddingTop,
          ex.tagPaddingLeft,
          ex.tagPaddingBottom,
        ),
        child: Wrap(
          spacing: ex.tagGap,
          runSpacing: ex.tagGap,
          children: [
            for (final tag in project.tags)
              if (tag.isCustom)
                CustomTagView(
                  text: tag.text ?? '',
                  colorValue: tag.colorValue ?? 0xFFF2C21B,
                  height: ex.tagHeight,
                )
              else
                Image.asset(
                  tag.asset!,
                  height: ex.tagHeight,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
          ],
        ),
      ),
    );
  }
}
