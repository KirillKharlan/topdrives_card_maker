import 'package:flutter/painting.dart';

Color _hexColor(String hex) =>
    Color(int.parse(hex.replaceFirst('#', ''), radix: 16) | 0xFF000000);

double _d(Object? v) => (v as num).toDouble();

/// Rectangle (in card pixels) where one piece of text is drawn. The text is
/// vertically centred and shrinks automatically when it does not fit.
class FieldRect {
  const FieldRect({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.size,
    required this.align,
  });

  final double x, y, w, h, size;
  final String align;

  Alignment get alignment => switch (align) {
        'left' => Alignment.centerLeft,
        'right' => Alignment.centerRight,
        _ => Alignment.center,
      };

  factory FieldRect.fromJson(Map<String, dynamic> j) => FieldRect(
        x: _d(j['x']),
        y: _d(j['y']),
        w: _d(j['w']),
        h: _d(j['h']),
        size: _d(j['size']),
        align: (j['align'] as String?) ?? 'left',
      );
}

/// The logo slot of the frame (the dark tile in the top-left corner).
class LogoSpec {
  const LogoSpec({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.padding,
  });

  final double x, y, w, h, padding;

  factory LogoSpec.fromJson(Map<String, dynamic> j) => LogoSpec(
        x: _d(j['x'] ?? 0),
        y: _d(j['y'] ?? 0),
        w: _d(j['w'] ?? 139),
        h: _d(j['h'] ?? 96),
        padding: _d(j['padding'] ?? 8),
      );
}

/// Tag (above the card) and prize-car marker (below the card).
class ExtrasSpec {
  const ExtrasSpec({
    required this.backdrop,
    required this.tagHeight,
    required this.tagPaddingLeft,
    required this.tagPaddingTop,
    required this.tagPaddingBottom,
    required this.tagGap,
    required this.prizeStripHeight,
    required this.prizeIconHeight,
    required this.prizePaddingLeft,
    required this.prizeGap,
    required this.prizeTextSize,
    required this.prizeTextWidth,
    required this.prizeLetterSpacing,
    required this.prizeTextStroke,
  });

  final Color backdrop;
  final double tagHeight, tagPaddingLeft, tagPaddingTop, tagPaddingBottom, tagGap;
  final double prizeStripHeight, prizeIconHeight, prizePaddingLeft, prizeGap;
  final double prizeTextSize, prizeTextWidth;

  /// Extra spacing and outline width (card units) that make the prize text look heavier.
  final double prizeLetterSpacing, prizeTextStroke;

  factory ExtrasSpec.fromJson(Map<String, dynamic> j) => ExtrasSpec(
        backdrop: _hexColor(j['backdrop'] as String? ?? '#1E1E1E'),
        // Defaults keep the app starting even if an older standard.json is bundled.
        tagHeight: _d(j['tagHeight'] ?? 50),
        tagPaddingLeft: _d(j['tagPaddingLeft'] ?? 4),
        tagPaddingTop: _d(j['tagPaddingTop'] ?? 8),
        tagPaddingBottom: _d(j['tagPaddingBottom'] ?? 12),
        tagGap: _d(j['tagGap'] ?? 10),
        prizeStripHeight: _d(j['prizeStripHeight'] ?? 148),
        prizeIconHeight: _d(j['prizeIconHeight'] ?? 92),
        prizePaddingLeft: _d(j['prizePaddingLeft'] ?? 68),
        prizeGap: _d(j['prizeGap'] ?? 22),
        prizeTextSize: _d(j['prizeTextSize'] ?? 41),
        prizeTextWidth: _d(j['prizeTextWidth'] ?? 560),
        prizeLetterSpacing: _d(j['prizeLetterSpacing'] ?? 2.4),
        prizeTextStroke: _d(j['prizeTextStroke'] ?? 1.4),
      );
}

/// Everything the renderer needs to draw a card: frames, text positions and
/// the extras. Loaded from assets/templates/<id>.json, so a new template is
/// a new JSON + images, not new code.
class TemplateSpec {
  const TemplateSpec({
    required this.id,
    required this.name,
    required this.width,
    required this.height,
    required this.cornerRadius,
    required this.textScale,
    required this.photoBackground,
    required this.frames,
    required this.prizeBanner,
    required this.prizeVisibleWidth,
    required this.logo,
    required this.extras,
    required this.fields,
  });

  final String id, name;
  final double width, height, cornerRadius;

  /// Multiplies every text size of the template (one knob for fine-tuning).
  final double textScale;
  final Color photoBackground;
  final Map<String, String> frames;
  final String prizeBanner;
  final double prizeVisibleWidth;
  final LogoSpec logo;
  final ExtrasSpec extras;
  final Map<String, FieldRect> fields;

  FieldRect field(String key) => fields[key]!;

  factory TemplateSpec.fromJson(Map<String, dynamic> j) {
    return TemplateSpec(
      id: j['id'] as String,
      name: j['name'] as String,
      width: _d(j['width']),
      height: _d(j['height']),
      cornerRadius: _d(j['cornerRadius'] ?? 0),
      textScale: _d(j['textScale'] ?? 1.0),
      photoBackground: _hexColor(j['photoBackground'] as String? ?? '#2B2B2B'),
      frames: (j['frames'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String)),
      prizeBanner: j['prizeBanner'] as String,
      prizeVisibleWidth: _d(j['prizeVisibleWidth'] ?? 1),
      logo: LogoSpec.fromJson(j['logo'] as Map<String, dynamic>),
      extras: ExtrasSpec.fromJson(j['extras'] as Map<String, dynamic>),
      fields: (j['fields'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, FieldRect.fromJson(v as Map<String, dynamic>))),
    );
  }
}
