import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A tag built in code, drawn like the ready-made ones: a coloured border, a
/// fill that is the same colour about 4.55 times darker, white text in Roboto Medium
/// (the font of the game's tags, measured on the bundled ones: capital height and
/// width of the words fit at 0.505 of the tag height, with no extra letter spacing).
/// The width follows the text length; all proportions are relative to [height].
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

  /// Font family bundled in pubspec.yaml (Roboto Medium).
  static const fontFamily = 'TagRoboto';

  static TextStyle labelStyle(double height) => TextStyle(
        fontFamily: fontFamily,
        fontSize: height * 0.505,
        fontWeight: FontWeight.w500,
        color: Colors.white,
        height: 1.0,
        decoration: TextDecoration.none,
      );

  Widget _label() => Text(
        text,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        textScaler: TextScaler.noScaling,
        style: labelStyle(height),
      );

  /// The tag as a PNG picture, drawn straight onto a canvas (no widget on screen needed),
  /// with the same proportions as the widget. [scale] 6 on a height of 100 gives 600 px,
  /// about the size of the ready-made tag pictures.
  static Future<Uint8List> renderPng(
    String text,
    int colorValue, {
    double height = 100,
    double scale = 6,
  }) async {
    final border = height * 0.08;
    final padding = border + height * 0.25;
    final painter = TextPainter(
      text: TextSpan(text: text, style: labelStyle(height)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      textScaler: TextScaler.noScaling,
    )..layout();
    final width = painter.width + padding * 2;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(scale);
    final box = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, width, height),
      Radius.circular(height * 0.38),
    );
    canvas.drawRRect(box, Paint()..color = fillFor(colorValue));
    canvas.drawRRect(
      box.deflate(border / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = border
        ..color = Color(colorValue | 0xFF000000),
    );
    painter.paint(canvas, Offset(padding, (height - painter.height) / 2));
    painter.dispose();

    final picture = recorder.endRecording();
    final image = await picture.toImage((width * scale).ceil(), (height * scale).ceil());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    return data!.buffer.asUint8List();
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
              Flexible(child: _label()),
            ],
          ),
        ),
      ),
    );
  }
}
