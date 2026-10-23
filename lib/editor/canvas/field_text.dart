import 'package:flutter/material.dart';

import '../../core/app_constants.dart';
import '../../templates/template_spec.dart';
import 'card_text_style.dart';

/// One text field of the card, placed by a [FieldRect] from the template.
/// [parts] are (text, bold) pairs drawn on a single line.
class FieldText extends StatelessWidget {
  const FieldText({super.key, required this.rect, required this.parts, this.scale = 1.0});

  final FieldRect rect;
  final double scale;
  final List<(String, bool)> parts;

  @override
  Widget build(BuildContext context) {
    Widget text = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: rect.alignment,
      child: Text.rich(
        TextSpan(children: [
          for (final (value, bold) in parts)
            TextSpan(text: value, style: cardTextStyle(rect.size * scale, bold: bold)),
        ]),
        maxLines: 1,
        softWrap: false,
      ),
    );
    if (AppConstants.debugGuides) {
      text = DecoratedBox(
        decoration: BoxDecoration(border: Border.all(color: Colors.cyanAccent, width: 1)),
        child: text,
      );
    }
    return Positioned(left: rect.x, top: rect.y, width: rect.w, height: rect.h, child: text);
  }
}
