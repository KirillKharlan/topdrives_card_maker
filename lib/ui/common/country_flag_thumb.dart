import 'package:flutter/material.dart';

import '../../data/country_flags.dart';
import '../../data/iso_countries.dart';

/// A small flag for lists: what the card will show (painted flag or the
/// picture), or an empty frame for a code without a flag.
class CountryFlagThumb extends StatelessWidget {
  const CountryFlagThumb({super.key, required this.code, this.width = 30, this.height = 20});

  final String code;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final upper = code.toUpperCase();
    final Widget flag;
    if (CountryFlags.hasPainted(upper)) {
      flag = CustomPaint(painter: _PaintedFlag(upper), size: Size(width, height));
    } else if (IsoCountries.has(upper)) {
      flag = Image.asset(
        IsoCountries.assetPath(upper),
        width: width,
        height: height,
        fit: BoxFit.fill,
        cacheWidth: (width * 3).round(),
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        excludeFromSemantics: true,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    } else {
      flag = Center(
        child: Icon(Icons.flag_outlined, size: height * 0.75, color: Colors.white54),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Container(
        width: width,
        height: height,
        color: const Color(0xFF3A3A3A),
        foregroundDecoration: BoxDecoration(
          border: Border.all(color: Colors.white24, width: 0.5),
          borderRadius: BorderRadius.circular(3),
        ),
        child: flag,
      ),
    );
  }
}

class _PaintedFlag extends CustomPainter {
  _PaintedFlag(this.code);

  final String code;

  @override
  void paint(Canvas canvas, Size size) => CountryFlags.paint(canvas, Offset.zero & size, code);

  @override
  bool shouldRepaint(_PaintedFlag old) => old.code != code;
}
