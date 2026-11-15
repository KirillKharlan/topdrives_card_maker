import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A colour wheel like the ones in drawing apps: the angle is the hue, the
/// distance from the middle is the saturation, the bar below sets the brightness.
class ColorWheelPicker extends StatelessWidget {
  const ColorWheelPicker({
    super.key,
    required this.hsv,
    required this.onChanged,
    this.diameter = 230,
  });

  final HSVColor hsv;
  final ValueChanged<HSVColor> onChanged;
  final double diameter;

  void _pickOnWheel(Offset p) {
    final r = diameter / 2;
    final d = p - Offset(r, r);
    final hue = (math.atan2(d.dy, d.dx) * 180 / math.pi + 360) % 360;
    final saturation = (d.distance / r).clamp(0.0, 1.0).toDouble();
    onChanged(hsv.withHue(hue).withSaturation(saturation));
  }

  void _pickValue(double x) {
    onChanged(hsv.withValue((x / diameter).clamp(0.0, 1.0).toDouble()));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: diameter,
          height: diameter,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanDown: (d) => _pickOnWheel(d.localPosition),
            onPanUpdate: (d) => _pickOnWheel(d.localPosition),
            child: CustomPaint(painter: _WheelPainter(hsv)),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: diameter,
          height: 30,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanDown: (d) => _pickValue(d.localPosition.dx),
            onPanUpdate: (d) => _pickValue(d.localPosition.dx),
            child: CustomPaint(painter: _ValueBarPainter(hsv)),
          ),
        ),
      ],
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter(this.hsv);

  final HSVColor hsv;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: centre, radius: radius);

    // Hue around the circle (a sweep starts at 3 o'clock and runs clockwise).
    final hues = [
      for (var h = 0; h <= 360; h += 30) HSVColor.fromAHSV(1, (h % 360).toDouble(), 1, 1).toColor(),
    ];
    canvas.drawCircle(centre, radius, Paint()..shader = SweepGradient(colors: hues).createShader(rect));
    // Saturation: white in the middle, clear at the edge.
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
        ).createShader(rect),
    );
    // Brightness darkens the whole wheel.
    canvas.drawCircle(centre, radius, Paint()..color = Color.fromRGBO(0, 0, 0, 1 - hsv.value));
    canvas.drawCircle(
      centre,
      radius - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0x66FFFFFF),
    );

    final angle = hsv.hue * math.pi / 180;
    final at = centre + Offset(math.cos(angle), math.sin(angle)) * (hsv.saturation * radius);
    canvas.drawCircle(at, 13, Paint()..color = hsv.toColor());
    canvas.drawCircle(
      at,
      13,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white,
    );
    canvas.drawCircle(
      at,
      15,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x88000000),
    );
  }

  @override
  bool shouldRepaint(_WheelPainter old) => old.hsv != hsv;
}

class _ValueBarPainter extends CustomPainter {
  _ValueBarPainter(this.hsv);

  final HSVColor hsv;

  @override
  void paint(Canvas canvas, Size size) {
    final bar = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 7, size.width, size.height - 14),
      const Radius.circular(8),
    );
    final bright = hsv.withValue(1).toColor();
    canvas.drawRRect(
      bar,
      Paint()
        ..shader = LinearGradient(colors: [Colors.black, bright]).createShader(Offset.zero & size),
    );
    final x = hsv.value * size.width;
    canvas.drawCircle(Offset(x, size.height / 2), 13, Paint()..color = hsv.toColor());
    canvas.drawCircle(
      Offset(x, size.height / 2),
      13,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_ValueBarPainter old) => old.hsv != hsv;
}

/// 42 ready colours: light, vivid and dark versions of 12 hues, and 6 greys.
final List<int> colourPalette = [
  for (final shade in const [(0.45, 1.0), (1.0, 1.0), (1.0, 0.62)])
    for (final hue in const [0, 22, 45, 60, 100, 150, 175, 200, 220, 255, 285, 330])
      HSVColor.fromAHSV(1, hue.toDouble(), shade.$1, shade.$2).toColor().value,
  for (final grey in const [1.0, 0.8, 0.62, 0.45, 0.3, 0.15])
    HSVColor.fromAHSV(1, 0, 0, grey).toColor().value,
];
