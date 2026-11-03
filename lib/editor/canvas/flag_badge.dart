import 'package:flutter/material.dart';

import '../../data/country_flags.dart';
import '../../templates/template_spec.dart';

/// The flag of the card's country behind the country code. It fills the
/// country block of the frame (a slanted shape, see [FlagSpec]) and is a bit
/// see-through, so the block's own shading shows through like on the game's cards.
class FlagBadge extends StatelessWidget {
  const FlagBadge({super.key, required this.code, required this.spec});

  final String code;
  final FlagSpec spec;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(child: CustomPaint(painter: _FlagPainter(code, spec))),
    );
  }
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
