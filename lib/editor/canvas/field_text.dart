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

  /// Places the text so its baseline lies exactly on [baselineY].
  Widget _onBaseline(double baselineY) {
    final span = TextSpan(children: [
      for (final (value, bold) in parts)
        TextSpan(text: value, style: cardTextStyle(rect.size * scale, bold: bold)),
    ]);
    final painter = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      textScaler: TextScaler.noScaling,
    )..layout();
    final distance = painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    painter.dispose();
    return Positioned(
      left: rect.x,
      top: baselineY - distance,
      width: rect.w,
      child: Align(
        alignment: rect.topAlignment,
        heightFactor: 1.0,
        child: Text.rich(
          span,
          maxLines: 1,
          softWrap: false,
          textScaler: TextScaler.noScaling,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baselineY = rect.baseline;
    if (baselineY != null) return _onBaseline(baselineY);
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
