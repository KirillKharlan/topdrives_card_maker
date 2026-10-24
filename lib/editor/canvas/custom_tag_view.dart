import 'package:flutter/material.dart';

import 'card_text_style.dart';

/// A tag built in code, drawn like the ready-made ones: a coloured border, a
/// fill that is the same colour about 4.55 times darker, white text. The width
/// follows the text length; all proportions are relative to [height].
class CustomTagView extends StatelessWidget {
  const CustomTagView({
    super.key,
    required this.text,
    required this.colorValue,
    required this.height,
  });

  final String text;
  final int colorValue;
  final double height;

  /// Measured on the bundled tags: border colour / fill colour = 4.55 (median).
  static const darkening = 4.55;

  static Color fillFor(int argb) {
    int channel(int shift) =>
        (((argb >> shift) & 0xFF) / darkening).round().clamp(0, 255).toInt();
    return Color.fromARGB(255, channel(16), channel(8), channel(0));
  }

  @override
  Widget build(BuildContext context) {
    final border = height * 0.08;
    final padding = border + height * 0.25;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fillFor(colorValue),
        borderRadius: BorderRadius.circular(height * 0.38),
        border: Border.all(color: Color(colorValue | 0xFF000000), width: border),
      ),
      child: SizedBox(
        height: height,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  textScaler: TextScaler.noScaling,
                  style: cardTextStyle(height * 0.53, bold: true, letterSpacing: height * 0.012),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
