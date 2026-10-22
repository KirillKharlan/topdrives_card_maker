import 'package:flutter/material.dart';

/// Grey chessboard behind transparent areas, so you can see what was removed.
class CheckerboardPainter extends CustomPainter {
  const CheckerboardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const cell = 16.0;
    final dark = Paint()..color = const Color(0xFF2A2A2A);
    final light = Paint()..color = const Color(0xFF3A3A3A);
    canvas.drawRect(Offset.zero & size, dark);
    for (var y = 0; y * cell < size.height; y++) {
      for (var x = 0; x * cell < size.width; x++) {
        if ((x + y).isOdd) {
          canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell, cell), light);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
