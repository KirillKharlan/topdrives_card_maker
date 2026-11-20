import 'package:flutter/material.dart';

import '../../data/country_flags.dart';
import '../../data/iso_countries.dart';
import '../../templates/template_spec.dart';

/// The flag of the card's country behind the country code. It fills the
/// country block of the frame (a slanted shape, see [FlagSpec]) and is a bit
/// see-through, so the block's own shading shows through like on the game's cards.
///
/// The first built-in flags are painted by code (simplified), every other ISO
/// country uses its picture from assets/flags.
class FlagBadge extends StatelessWidget {
  const FlagBadge({super.key, required this.code, required this.spec});

  final String code;
  final FlagSpec spec;

  @override
  Widget build(BuildContext context) {
    if (!CountryFlags.hasPainted(code) && IsoCountries.has(code)) {
      final bounds = (Path()..addPolygon(spec.points, true)).getBounds();
      return Positioned.fill(
        child: IgnorePointer(
          child: Stack(
            children: [
              Positioned.fromRect(
                rect: bounds,
                child: ClipPath(
                  clipper: _PolygonClipper(spec.points, bounds.topLeft),
                  child: Opacity(
                    opacity: spec.opacity,
                    child: Image.asset(
                      IsoCountries.assetPath(code),
                      fit: BoxFit.fill,
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.medium,
                      excludeFromSemantics: true,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Positioned.fill(
      child: IgnorePointer(child: CustomPaint(painter: _FlagPainter(code, spec))),
    );
  }
}

/// Cuts the picture to the slanted country block (points are card units;
/// [origin] is the top-left of the picture's box).
class _PolygonClipper extends CustomClipper<Path> {
  _PolygonClipper(this.points, this.origin);

  final List<Offset> points;
  final Offset origin;

  @override
  Path getClip(Size size) =>
      Path()..addPolygon([for (final p in points) p - origin], true);

  @override
  bool shouldReclip(_PolygonClipper old) => old.points != points || old.origin != origin;
}

class _FlagPainter extends CustomPainter {
  _FlagPainter(this.code, this.spec);

  final String code;
  final FlagSpec spec;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = Path()..addPolygon(spec.points, true);
    final bounds = shape.getBounds();
    canvas.save();
    canvas.clipPath(shape);
    canvas.saveLayer(bounds, Paint()..color = Color.fromRGBO(255, 255, 255, spec.opacity));
    CountryFlags.paint(canvas, bounds, code);
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FlagPainter old) => old.code != code || old.spec != spec;
}
