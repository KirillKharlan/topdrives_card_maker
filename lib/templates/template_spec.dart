import 'package:flutter/painting.dart';

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
        x: (j['x'] as num).toDouble(),
        y: (j['y'] as num).toDouble(),
        w: (j['w'] as num).toDouble(),
        h: (j['h'] as num).toDouble(),
        size: (j['size'] as num).toDouble(),
        align: (j['align'] as String?) ?? 'left',
      );
}

class LogoSpec {
  const LogoSpec({required this.cx, required this.cy, required this.diameter});

  final double cx, cy, diameter;

  factory LogoSpec.fromJson(Map<String, dynamic> j) => LogoSpec(
        cx: (j['cx'] as num).toDouble(),
        cy: (j['cy'] as num).toDouble(),
        diameter: (j['diameter'] as num).toDouble(),
      );
}

/// Strip above the card that holds the prize banner and the series tag.
class ExtrasSpec {
  const ExtrasSpec({
    required this.stripHeight,
    required this.padding,
    required this.gap,
    required this.prizeHeight,
    required this.tagHeight,
  });

  final double stripHeight, padding, gap, prizeHeight, tagHeight;

  factory ExtrasSpec.fromJson(Map<String, dynamic> j) => ExtrasSpec(
        stripHeight: (j['stripHeight'] as num).toDouble(),
        padding: (j['padding'] as num).toDouble(),
        gap: (j['gap'] as num).toDouble(),
        prizeHeight: (j['prizeHeight'] as num).toDouble(),
        tagHeight: (j['tagHeight'] as num).toDouble(),
      );
}

/// Everything the renderer needs to draw a card: frames, text positions and
/// the extras strip. Loaded from assets/templates/<id>.json, so a new
/// template is a new JSON + images, not new code.
class TemplateSpec {
  const TemplateSpec({
    required this.id,
    required this.name,
    required this.width,
    required this.height,
    required this.cornerRadius,
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
  final Color photoBackground;
  final Map<String, String> frames;
  final String prizeBanner;
  final double prizeVisibleWidth;
  final LogoSpec logo;
  final ExtrasSpec extras;
  final Map<String, FieldRect> fields;

  FieldRect field(String key) => fields[key]!;

  factory TemplateSpec.fromJson(Map<String, dynamic> j) {
    final hex = (j['photoBackground'] as String? ?? '#2B2B2B').replaceFirst('#', '');
    return TemplateSpec(
      id: j['id'] as String,
      name: j['name'] as String,
      width: (j['width'] as num).toDouble(),
      height: (j['height'] as num).toDouble(),
      cornerRadius: (j['cornerRadius'] as num?)?.toDouble() ?? 0,
      photoBackground: Color(int.parse(hex, radix: 16) | 0xFF000000),
      frames: (j['frames'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String)),
      prizeBanner: j['prizeBanner'] as String,
      prizeVisibleWidth: (j['prizeVisibleWidth'] as num?)?.toDouble() ?? 1,
      logo: LogoSpec.fromJson(j['logo'] as Map<String, dynamic>),
      extras: ExtrasSpec.fromJson(j['extras'] as Map<String, dynamic>),
      fields: (j['fields'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, FieldRect.fromJson(v as Map<String, dynamic>))),
    );
  }
}
