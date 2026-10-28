import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_constants.dart';
import '../../templates/template_spec.dart';
import 'card_text_style.dart';

/// Where and how large the brand and the model are drawn (card units).
///
/// The brand always has exactly its own size. The model has at most its own
/// size and is made smaller until it fits the room that is left. It shrinks on
/// one line down to [TitleStyleSpec.twoLineScale] of its size; when it would have
/// to get smaller than that it wraps to two lines instead. Both looks (fan-made
/// and game) do this, they only differ in the numbers.
class TitleLayout {
  const TitleLayout({
    required this.brandX,
    required this.right,
    required this.brandSize,
    required this.brandBaseline,
    required this.modelX,
    required this.modelSize,
    required this.modelLines,
    required this.modelBaselines,
  });

  final double brandX, right, brandSize, brandBaseline, modelX, modelSize;
  final List<String> modelLines;
  final List<double> modelBaselines;

  static double _width(String text, double size, bool bold) {
    if (text.isEmpty) return 0;
    final painter = TextPainter(
      text: TextSpan(text: text, style: cardTextStyle(size, bold: bold)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      textScaler: TextScaler.noScaling,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  /// Greedy word wrap into at most two lines; null when it does not fit.
  static List<String>? _wrapTwoLines(List<String> words, double size, double available) {
    final lines = <String>[];
    var current = '';
    for (final word in words) {
      if (_width(word, size, false) > available) return null;
      final candidate = current.isEmpty ? word : '$current $word';
      if (_width(candidate, size, false) <= available) {
        current = candidate;
      } else {
        lines.add(current);
        current = word;
      }
    }
    lines.add(current);
    return lines.length <= 2 ? lines : null;
  }

  /// Shrinks [size] a little at a time until [text] is at most [available] wide.
  static double _shrinkToWidth(String text, double size, double available, double floor) {
    var result = size;
    var guard = 0;
    while (_width(text, result, false) > available && result > floor && guard < 8) {
      result = math.max(floor, result * math.min(0.99, available / _width(text, result, false)));
      guard++;
    }
    return result;
  }

  /// Half the cap height of the card font, in font sizes (cap height 0.711).
  static const _halfCap = 0.3555;

  static TitleLayout compute({
    required String brand,
    required String model,
    required TitleStyleSpec style,
    required double textScale,
    required double brandScale,
    required double modelScale,
  }) {
    final brandText = brand.trim();
    final modelText = model.trim().replaceAll(RegExp(r'\s+'), ' ');

    final brandSize = style.brandSize * textScale * brandScale;
    final modelMax = style.modelSize * textScale * modelScale;
    final modelFloor = modelMax * 0.2;

    final brandWidth = _width(brandText, brandSize, true);
    final modelX = style.x + (brandText.isEmpty ? 0.0 : brandWidth + style.gapEm * brandSize);
    final right = style.x + style.w;
    final available = math.max(right - modelX, 40.0);

    var lines = modelText.isEmpty ? <String>[] : <String>[modelText];
    var modelSize = modelMax;

    if (modelText.isNotEmpty) {
      final fullWidth = _width(modelText, modelMax, false);
      if (fullWidth > available) {
        final oneLineSize = math.max(modelFloor, modelMax * available / fullWidth);
        var wrappedSize = modelMax * style.twoLineScale;
        List<String>? wrapped;
        // Wrap only when one line would get smaller than the two-line size.
        if (style.wrap && oneLineSize < wrappedSize) {
          final words = modelText.split(' ');
          while (wrappedSize >= modelFloor) {
            wrapped = _wrapTwoLines(words, wrappedSize, available);
            if (wrapped != null) break;
            wrappedSize *= 0.96;
          }
        }
        if (wrapped != null) {
          lines = wrapped;
          modelSize = wrappedSize;
        } else {
          modelSize = _shrinkToWidth(modelText, oneLineSize, available, modelFloor);
        }
      }
    }

    // One line: model and brand stand on the style's baseline. Two lines: the
    // block of two lines keeps the same vertical centre as one line of capitals,
    // the brand stands on the middle between the two model baselines.
    var brandBaseline = style.baseline;
    var modelBaselines = <double>[style.baseline];
    if (lines.length == 2) {
      final capCentre = style.baseline - _halfCap * style.brandSize * textScale;
      final middle = capCentre + _halfCap * modelSize;
      final pitch = style.lineHeight * modelSize;
      brandBaseline = middle;
      modelBaselines = [middle - pitch / 2, middle + pitch / 2];
    }
    return TitleLayout(
      brandX: style.x,
      right: right,
      brandSize: brandSize,
      brandBaseline: brandBaseline,
      modelX: modelX,
      modelSize: modelSize,
      modelLines: lines,
      modelBaselines: modelBaselines,
    );
  }
}

/// The brand + model line of the card. The brand is bold and keeps its size,
/// the model is regular and fits itself into the rest of the line.
class TitleText extends StatelessWidget {
  const TitleText({
    super.key,
    required this.brand,
    required this.model,
    required this.style,
    required this.textScale,
    required this.brandScale,
    required this.modelScale,
  });

  final String brand;
  final String model;
  final TitleStyleSpec style;
  final double textScale;
  final double brandScale;
  final double modelScale;

  @override
  Widget build(BuildContext context) {
    final layout = TitleLayout.compute(
      brand: brand,
      model: model,
      style: style,
      textScale: textScale,
      brandScale: brandScale,
      modelScale: modelScale,
    );
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(painter: _TitlePainter(brand: brand.trim(), layout: layout)),
      ),
    );
  }
}

class _TitlePainter extends CustomPainter {
  _TitlePainter({required this.brand, required this.layout});

  final String brand;
  final TitleLayout layout;

  /// Draws [text] so that its baseline lies on [baseline] (card units).
  static void _drawLine(
    Canvas canvas,
    String text,
    double size,
    bool bold,
    double x,
    double baseline,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: cardTextStyle(size, bold: bold)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      textScaler: TextScaler.noScaling,
    )..layout();
    final distance = painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    painter.paint(canvas, Offset(x, baseline - distance));
    painter.dispose();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (brand.isNotEmpty) {
      _drawLine(canvas, brand, layout.brandSize, true, layout.brandX, layout.brandBaseline);
    }
    for (var i = 0; i < layout.modelLines.length; i++) {
      _drawLine(
        canvas,
        layout.modelLines[i],
        layout.modelSize,
        false,
        layout.modelX,
        layout.modelBaselines[i],
      );
    }
    if (AppConstants.debugGuides) {
      final guide = Paint()
        ..color = Colors.cyanAccent
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(layout.brandX, layout.brandBaseline),
        Offset(layout.right, layout.brandBaseline),
        guide,
      );
      canvas.drawLine(Offset(layout.right, 0), Offset(layout.right, 97), guide);
    }
  }

  @override
  bool shouldRepaint(_TitlePainter oldDelegate) => true;
}
