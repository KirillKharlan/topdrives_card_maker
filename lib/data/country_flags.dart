import 'dart:math' as math;
import 'dart:ui';

/// Simple painted flags for the built-in country codes. They are drawn to fill
/// whatever rectangle they get (the badge behind the country code), so details
/// are simplified: no coats of arms, few stars.
class CountryFlags {
  CountryFlags._();

  static bool has(String code) => _flags.containsKey(code.toUpperCase());

  /// Paints the flag of [code] over [r]; does nothing for an unknown code.
  static void paint(Canvas canvas, Rect r, String code) {
    final painter = _flags[code.toUpperCase()];
    if (painter == null) return;
    canvas.save();
    canvas.clipRect(r);
    painter(canvas, r);
    canvas.restore();
  }

  static Paint _fill(int argb) => Paint()..color = Color(argb);

  static void _stripes(Canvas c, Rect r, List<int> colors,
      {bool vertical = false, List<double>? weights}) {
    final w = weights ?? List<double>.filled(colors.length, 1);
    final total = w.fold<double>(0, (a, b) => a + b);
    var at = 0.0;
    for (var i = 0; i < colors.length; i++) {
      final share = w[i] / total;
      final part = vertical
          ? Rect.fromLTWH(r.left + at * r.width, r.top, share * r.width + 0.5, r.height)
          : Rect.fromLTWH(r.left, r.top + at * r.height, r.width, share * r.height + 0.5);
      c.drawRect(part, _fill(colors[i]));
      at += share;
    }
  }

  static void _disc(Canvas c, Offset centre, double radius, int argb) =>
      c.drawCircle(centre, radius, _fill(argb));

  static void _star(Canvas c, Offset centre, double outer, int argb, {int points = 5}) {
    final inner = outer * (points == 5 ? 0.382 : 0.5);
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final radius = i.isEven ? outer : inner;
      final angle = -math.pi / 2 + i * math.pi / points;
      final p = centre + Offset(math.cos(angle), math.sin(angle)) * radius;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    c.drawPath(path..close(), _fill(argb));
  }

  /// Plus-shaped cross; [horizontalAt] / [verticalAt] are the cross lines as a
  /// part of the width / height.
  static void _cross(Canvas c, Rect r, int argb,
      {required double verticalAt, required double horizontalAt, required double thickness}) {
    final t = thickness * r.height;
    c.drawRect(Rect.fromLTWH(r.left, r.top + horizontalAt * r.height - t / 2, r.width, t), _fill(argb));
    c.drawRect(Rect.fromLTWH(r.left + verticalAt * r.width - t / 2, r.top, t, r.height), _fill(argb));
  }

  static void _unionJack(Canvas c, Rect r) {
    c.save();
    c.clipRect(r);
    c.drawRect(r, _fill(0xFF012169));
    final diagonal = Paint()..style = PaintingStyle.stroke;
    diagonal.color = const Color(0xFFFFFFFF);
    diagonal.strokeWidth = r.height * 0.22;
    c.drawLine(r.topLeft, r.bottomRight, diagonal);
    c.drawLine(r.topRight, r.bottomLeft, diagonal);
    diagonal.color = const Color(0xFFC8102E);
    diagonal.strokeWidth = r.height * 0.08;
    c.drawLine(r.topLeft, r.bottomRight, diagonal);
    c.drawLine(r.topRight, r.bottomLeft, diagonal);
    _cross(c, r, 0xFFFFFFFF, verticalAt: 0.5, horizontalAt: 0.5, thickness: 0.34);
    _cross(c, r, 0xFFC8102E, verticalAt: 0.5, horizontalAt: 0.5, thickness: 0.2);
    c.restore();
  }

  static final Map<String, void Function(Canvas, Rect)> _flags = {
    'DE': (c, r) => _stripes(c, r, [0xFF000000, 0xFFDD0000, 0xFFFFCE00]),
    'NL': (c, r) => _stripes(c, r, [0xFFAE1C28, 0xFFFFFFFF, 0xFF21468B]),
    'AT': (c, r) => _stripes(c, r, [0xFFED2939, 0xFFFFFFFF, 0xFFED2939]),
    'RU': (c, r) => _stripes(c, r, [0xFFFFFFFF, 0xFF0039A6, 0xFFD52B1E]),
    'UA': (c, r) => _stripes(c, r, [0xFF0057B7, 0xFFFFD700]),
    'ES': (c, r) =>
        _stripes(c, r, [0xFFAA151B, 0xFFF1BF00, 0xFFAA151B], weights: [1, 2, 1]),
    'FR': (c, r) => _stripes(c, r, [0xFF0055A4, 0xFFFFFFFF, 0xFFEF4135], vertical: true),
    'IT': (c, r) => _stripes(c, r, [0xFF009246, 0xFFFFFFFF, 0xFFCE2B37], vertical: true),
    'CA': (c, r) {
      _stripes(c, r, [0xFFFF0000, 0xFFFFFFFF, 0xFFFF0000], vertical: true, weights: [1, 2, 1]);
      _star(c, r.center, r.height * 0.3, 0xFFFF0000, points: 8);
    },
    'IN': (c, r) {
      _stripes(c, r, [0xFFFF9933, 0xFFFFFFFF, 0xFF138808]);
      c.drawCircle(
        r.center,
        r.height * 0.12,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r.height * 0.03
          ..color = const Color(0xFF000080),
      );
    },
    'JP': (c, r) {
      c.drawRect(r, _fill(0xFFFFFFFF));
      _disc(c, r.center, r.height * 0.3, 0xFFBC002D);
    },
    'KR': (c, r) {
      c.drawRect(r, _fill(0xFFFFFFFF));
      final disc = Rect.fromCircle(center: r.center, radius: r.height * 0.26);
      c.drawArc(disc, math.pi, math.pi, true, _fill(0xFFCD2E3A));
      c.drawArc(disc, 0, math.pi, true, _fill(0xFF0047A0));
    },
    'CN': (c, r) {
      c.drawRect(r, _fill(0xFFDE2910));
      _star(c, Offset(r.left + r.width * 0.2, r.top + r.height * 0.32), r.height * 0.22, 0xFFFFDE00);
      for (final p in const [Offset(0.4, 0.14), Offset(0.48, 0.28), Offset(0.48, 0.46), Offset(0.4, 0.6)]) {
        _star(c, Offset(r.left + r.width * p.dx, r.top + r.height * p.dy), r.height * 0.06, 0xFFFFDE00);
      }
    },
    'SE': (c, r) {
      c.drawRect(r, _fill(0xFF006AA7));
      _cross(c, r, 0xFFFECC00, verticalAt: 0.36, horizontalAt: 0.5, thickness: 0.2);
    },
    'CH': (c, r) {
      c.drawRect(r, _fill(0xFFD52B1E));
      final arm = r.height * 0.22;
      final long = r.height * 0.62;
      c.drawRect(Rect.fromCenter(center: r.center, width: long, height: arm), _fill(0xFFFFFFFF));
      c.drawRect(Rect.fromCenter(center: r.center, width: arm, height: long), _fill(0xFFFFFFFF));
    },
    'GB': (c, r) => _unionJack(c, r),
    'US': (c, r) {
      _stripes(c, r, [
        for (var i = 0; i < 13; i++) i.isEven ? 0xFFB22234 : 0xFFFFFFFF,
      ]);
      final canton = Rect.fromLTWH(r.left, r.top, r.width * 0.42, r.height * 7 / 13);
      c.drawRect(canton, _fill(0xFF3C3B6E));
      for (var row = 0; row < 3; row++) {
        for (var col = 0; col < 4; col++) {
          _disc(
            c,
            Offset(canton.left + canton.width * (0.14 + col * 0.24), canton.top + canton.height * (0.2 + row * 0.3)),
            r.height * 0.028,
            0xFFFFFFFF,
          );
        }
      }
    },
    'CZ': (c, r) {
      _stripes(c, r, [0xFFFFFFFF, 0xFFD7141A]);
      final triangle = Path()
        ..moveTo(r.left, r.top)
        ..lineTo(r.left + r.width * 0.5, r.center.dy)
        ..lineTo(r.left, r.bottom)
        ..close();
      c.drawPath(triangle, _fill(0xFF11457E));
    },
    'AU': (c, r) {
      c.drawRect(r, _fill(0xFF012169));
      _unionJack(c, Rect.fromLTWH(r.left, r.top, r.width * 0.5, r.height * 0.5));
      _star(c, Offset(r.left + r.width * 0.25, r.top + r.height * 0.76), r.height * 0.14, 0xFFFFFFFF, points: 7);
      for (final p in const [Offset(0.75, 0.22), Offset(0.65, 0.5), Offset(0.85, 0.45), Offset(0.75, 0.8)]) {
        _star(c, Offset(r.left + r.width * p.dx, r.top + r.height * p.dy), r.height * 0.07, 0xFFFFFFFF);
      }
    },
    'BR': (c, r) {
      c.drawRect(r, _fill(0xFF009C3B));
      final diamond = Path()
        ..moveTo(r.left + r.width * 0.5, r.top + r.height * 0.1)
        ..lineTo(r.left + r.width * 0.92, r.center.dy)
        ..lineTo(r.left + r.width * 0.5, r.top + r.height * 0.9)
        ..lineTo(r.left + r.width * 0.08, r.center.dy)
        ..close();
      c.drawPath(diamond, _fill(0xFFFFDF00));
      _disc(c, r.center, r.height * 0.24, 0xFF002776);
    },
  };
}
