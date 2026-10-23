import 'package:flutter/material.dart';

import '../../data/models/card_project.dart';
import '../../templates/template_spec.dart';
import 'card_text_style.dart';

/// Prize-car marker under the card: trophy icon + text, like in the game.
class PrizeStrip extends StatelessWidget {
  const PrizeStrip({super.key, required this.project, required this.template});

  final CardProject project;
  final TemplateSpec template;

  @override
  Widget build(BuildContext context) {
    final ex = template.extras;
    return SizedBox(
      width: template.width,
      height: ex.prizeStripHeight,
      child: Padding(
        padding: EdgeInsets.only(left: ex.prizePaddingLeft),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // prize_car.png is a wide banner whose right part is empty;
            // keep only the trophy (and the little "i").
            SizedBox(
              height: ex.prizeIconHeight,
              child: ClipRect(
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: template.prizeVisibleWidth,
                  child: Image.asset(
                    template.prizeBanner,
                    height: ex.prizeIconHeight,
                    fit: BoxFit.fitHeight,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ),
            SizedBox(width: ex.prizeGap),
            SizedBox(
              width: ex.prizeTextWidth,
              child: Text(
                project.prizeText,
                style: cardTextStyle(ex.prizeTextSize * template.textScale).copyWith(height: 1.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
