import 'package:flutter/material.dart';

import '../../data/models/card_project.dart';
import '../../templates/template_spec.dart';
import 'card_text_style.dart';

/// Prize-car marker under the card: trophy icon + text, like in the game.
/// Where it sits depends on the card style: the game puts the trophy further in
/// and wraps the text to two lines (see [PrizeStyleSpec]).
class PrizeStrip extends StatelessWidget {
  const PrizeStrip({super.key, required this.project, required this.template});

  final CardProject project;
  final TemplateSpec template;

  /// Roboto Condensed only comes in Regular and Bold, so a "semi-bold" is made by
  /// drawing the text twice: normally and with a thin outline of the same colour.
  Widget _heavyText(PrizeStyleSpec ps) {
    final size = ps.textSize * template.textScale;
    final fill = cardTextStyle(size, letterSpacing: ps.letterSpacing).copyWith(height: ps.lineHeight);
    final outline = cardTextStyle(
      size,
      letterSpacing: ps.letterSpacing,
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ps.textStroke
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white,
    ).copyWith(height: ps.lineHeight);
    return Stack(
      children: [
        Text(project.prizeText, style: fill),
        Text(project.prizeText, style: outline),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ps = template.prizeStyle(project.cardStyle);
    return SizedBox(
      width: template.width,
      child: Padding(
        padding: EdgeInsets.only(
          left: ps.paddingLeft,
          top: ps.paddingTop,
          bottom: ps.paddingBottom,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // prize_car.png is a wide banner whose right part is empty;
            // keep only the trophy (and the little "i"), without the empty shadow below.
            Transform.translate(
              offset: Offset(0, ps.iconDy),
              child: SizedBox(
                height: ps.iconHeight * ps.iconCrop,
                child: ClipRect(
                  child: Align(
                    alignment: Alignment.topLeft,
                    widthFactor: template.prizeVisibleWidth,
                    heightFactor: ps.iconCrop,
                    child: Image.asset(
                      template.prizeBanner,
                      height: ps.iconHeight,
                      fit: BoxFit.fitHeight,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: ps.gap),
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: ps.textWidth),
                child: _heavyText(ps),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
