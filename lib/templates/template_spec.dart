import 'package:flutter/painting.dart';

import '../data/models/card_style.dart';

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
    this.baseline,
  });

  final double x, y, w, h, size;
  final String align;

  /// If set, the text sits exactly on this baseline (card units) instead of being
  /// centred vertically in the rectangle. Used to line the tyre name up with the
  /// letter T of the "Tyres" word that is part of the frame.
  final double? baseline;

  Alignment get alignment => switch (align) {
        'left' => Alignment.centerLeft,
        'right' => Alignment.centerRight,
        _ => Alignment.center,
      };

  /// The same field moved down by [dy] (used for the fine-tune setting).
  FieldRect shifted(double dy) => FieldRect(
        x: x,
        y: baseline == null ? y + dy : y,
        w: w,
        h: h,
        size: size,
        align: align,
        baseline: baseline == null ? null : baseline! + dy,
      );

  Alignment get topAlignment => switch (align) {
        'left' => Alignment.topLeft,
        'right' => Alignment.topRight,
        _ => Alignment.topCenter,
      };

  factory FieldRect.fromJson(Map<String, dynamic> j) => FieldRect(
        x: _d(j['x']),
        y: _d(j['y']),
        w: _d(j['w']),
        h: _d(j['h']),
        size: _d(j['size']),
        align: (j['align'] as String?) ?? 'left',
        baseline: (j['baseline'] as num?)?.toDouble(),
      );
}

/// How the brand + model line is set in one look (fan-made or game). Sizes are
/// before [TemplateSpec.textScale], like every other size in the template.
class TitleStyleSpec {
  const TitleStyleSpec({
    required this.x,
    required this.w,
    required this.brandSize,
    required this.modelSize,
    required this.baseline,
    required this.gapEm,
    required this.wrap,
    required this.twoLineScale,
    required this.lineHeight,
  });

  /// Left edge of the brand and the width the whole line may use.
  final double x, w;

  /// Brand size (never changes with the text) and the largest model size.
  final double brandSize, modelSize;

  /// Baseline of the line (card units). With two model lines they sit half a
  /// line step above and below it, the brand stays on it.
  final double baseline;

  /// Space between brand and model, in brand sizes.
  final double gapEm;

  /// A model that does not fit wraps to two lines (both looks do this).
  final bool wrap;

  /// The model shrinks on one line only down to this part of its size; beyond that
  /// it wraps to two lines, and this is also its size on those two lines.
  final double twoLineScale;

  /// Distance between the two model baselines, in model sizes.
  final double lineHeight;

  /// Measured on the fan card (BMW M4 GTS): size, x and baseline.
  static const fanDefault = TitleStyleSpec(
    x: 158,
    w: 890,
    brandSize: 71.8,
    modelSize: 71.8,
    baseline: 68,
    gapEm: 0.35,
    wrap: true,
    twoLineScale: 0.7,
    lineHeight: 0.93,
  );

  /// Measured on the game cards (Nissan Primera, McMurtry Speirling).
  static const gameDefault = TitleStyleSpec(
    x: 154,
    w: 894,
    brandSize: 48.9,
    modelSize: 51.1,
    baseline: 62,
    gapEm: 0.35,
    wrap: true,
    twoLineScale: 0.99,
    lineHeight: 0.93,
  );

  /// Missing keys fall back to [fallback], so an older standard.json still works.
  factory TitleStyleSpec.fromJson(Map<String, dynamic> j, TitleStyleSpec fallback) =>
      TitleStyleSpec(
        x: _d(j['x'] ?? fallback.x),
        w: _d(j['w'] ?? fallback.w),
        brandSize: _d(j['brandSize'] ?? fallback.brandSize),
        modelSize: _d(j['modelSize'] ?? fallback.modelSize),
        baseline: _d(j['baseline'] ?? fallback.baseline),
        gapEm: _d(j['gapEm'] ?? fallback.gapEm),
        wrap: (j['wrap'] as bool?) ?? fallback.wrap,
        twoLineScale: _d(j['twoLineScale'] ?? fallback.twoLineScale),
        lineHeight: _d(j['lineHeight'] ?? fallback.lineHeight),
      );
}

/// Prize-car marker under the card in one look. The fan-made look is the
/// `extras.prize*` values of the template; the game look sets the trophy further
/// in and bigger, and the text wraps to two lines (measured on game cards).
class PrizeStyleSpec {
  const PrizeStyleSpec({
    required this.paddingLeft,
    required this.paddingTop,
    required this.paddingBottom,
    required this.iconHeight,
    required this.iconCrop,
    required this.iconDy,
    required this.gap,
    required this.textSize,
    required this.textWidth,
    required this.letterSpacing,
    required this.textStroke,
    required this.lineHeight,
  });

  final double paddingLeft, paddingTop, paddingBottom;

  /// Trophy picture height, the part of it that is kept, and how far it is
  /// moved down (card units) to line it up with the text.
  final double iconHeight, iconCrop, iconDy;

  /// Space between the trophy and the text, and the width at which the text wraps.
  final double gap, textWidth;

  /// Text size (before textScale), extra letter spacing, outline width and line
  /// height (in text sizes).
  final double textSize, letterSpacing, textStroke, lineHeight;

  factory PrizeStyleSpec.fromExtras(ExtrasSpec e) => PrizeStyleSpec(
        paddingLeft: e.prizePaddingLeft,
        paddingTop: e.prizePaddingTop,
        paddingBottom: e.prizePaddingBottom,
        iconHeight: e.prizeIconHeight,
        iconCrop: e.prizeIconCrop,
        iconDy: 0,
        gap: e.prizeGap,
        textSize: e.prizeTextSize,
        textWidth: e.prizeTextWidth,
        letterSpacing: e.prizeLetterSpacing,
        textStroke: e.prizeTextStroke,
        lineHeight: 1.1,
      );

  static const gameDefault = PrizeStyleSpec(
    paddingLeft: 62.7,
    paddingTop: 21.1,
    paddingBottom: 2,
    iconHeight: 119.3,
    iconCrop: 0.82,
    iconDy: 8,
    gap: 20,
    textSize: 41,
    textWidth: 560,
    letterSpacing: 2.9,
    textStroke: 1.8,
    lineHeight: 1.15,
  );

  /// Missing keys fall back to [fallback], so an older standard.json still works.
  factory PrizeStyleSpec.fromJson(Map<String, dynamic> j, PrizeStyleSpec fallback) =>
      PrizeStyleSpec(
        paddingLeft: _d(j['paddingLeft'] ?? fallback.paddingLeft),
        paddingTop: _d(j['paddingTop'] ?? fallback.paddingTop),
        paddingBottom: _d(j['paddingBottom'] ?? fallback.paddingBottom),
        iconHeight: _d(j['iconHeight'] ?? fallback.iconHeight),
        iconCrop: _d(j['iconCrop'] ?? fallback.iconCrop),
        iconDy: _d(j['iconDy'] ?? fallback.iconDy),
        gap: _d(j['gap'] ?? fallback.gap),
        textSize: _d(j['textSize'] ?? fallback.textSize),
        textWidth: _d(j['textWidth'] ?? fallback.textWidth),
        letterSpacing: _d(j['letterSpacing'] ?? fallback.letterSpacing),
        textStroke: _d(j['textStroke'] ?? fallback.textStroke),
        lineHeight: _d(j['lineHeight'] ?? fallback.lineHeight),
      );
}

/// A rectangle in card units.
class RegionRect {
  const RegionRect({required this.x, required this.y, required this.w, required this.h});

  final double x, y, w, h;

  factory RegionRect.fromJson(Map<String, dynamic> j) =>
      RegionRect(x: _d(j['x']), y: _d(j['y']), w: _d(j['w']), h: _d(j['h']));
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
    required this.prizePaddingTop,
    required this.prizePaddingBottom,
    required this.prizeIconCrop,
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
  final double prizePaddingTop, prizePaddingBottom, prizeIconHeight, prizePaddingLeft, prizeGap;

  /// Fraction of the icon picture's height that is kept (the rest is empty shadow).
  final double prizeIconCrop;
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
        prizePaddingTop: _d(j['prizePaddingTop'] ?? 22),
        prizePaddingBottom: _d(j['prizePaddingBottom'] ?? 2),
        prizeIconCrop: _d(j['prizeIconCrop'] ?? 0.82),
        prizeIconHeight: _d(j['prizeIconHeight'] ?? 92),
        prizePaddingLeft: _d(j['prizePaddingLeft'] ?? 0),
        prizeGap: _d(j['prizeGap'] ?? 12),
        prizeTextSize: _d(j['prizeTextSize'] ?? 41),
        prizeTextWidth: _d(j['prizeTextWidth'] ?? 1000),
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
    required this.blurSigma,
    required this.blurRegions,
    required this.photoBackground,
    required this.frames,
    required this.prizeBanner,
    required this.prizeVisibleWidth,
    required this.logo,
    required this.extras,
    required this.fields,
    required this.titleStyles,
    required this.prizeStyles,
  });

  final String id, name;
  final double width, height, cornerRadius;

  /// Multiplies every text size of the template (one knob for fine-tuning).
  final double textScale;

  /// Frosted-glass effect: the photo is blurred behind these semi-transparent
  /// parts of the frame (the title bar and the stat panels).
  final double blurSigma;
  final List<RegionRect> blurRegions;
  final Color photoBackground;
  final Map<String, String> frames;
  final String prizeBanner;
  final double prizeVisibleWidth;
  final LogoSpec logo;
  final ExtrasSpec extras;
  final Map<String, FieldRect> fields;
  final Map<CardStyle, TitleStyleSpec> titleStyles;
  final Map<CardStyle, PrizeStyleSpec> prizeStyles;

  FieldRect field(String key) => fields[key]!;

  TitleStyleSpec titleStyle(CardStyle style) => titleStyles[style] ?? TitleStyleSpec.fanDefault;

  PrizeStyleSpec prizeStyle(CardStyle style) =>
      prizeStyles[style] ?? PrizeStyleSpec.fromExtras(extras);

  factory TemplateSpec.fromJson(Map<String, dynamic> j) {
    final rawStyles = (j['titleStyles'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final rawPrize = (j['prizeStyles'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final extras = ExtrasSpec.fromJson(j['extras'] as Map<String, dynamic>);
    return TemplateSpec(
      id: j['id'] as String,
      name: j['name'] as String,
      width: _d(j['width']),
      height: _d(j['height']),
      cornerRadius: _d(j['cornerRadius'] ?? 0),
      textScale: _d(j['textScale'] ?? 1.0),
      blurSigma: _d(j['blurSigma'] ?? 0),
      blurRegions: [
        for (final e in (j['blurRegions'] as List? ?? const []))
          RegionRect.fromJson(e as Map<String, dynamic>),
      ],
      photoBackground: _hexColor(j['photoBackground'] as String? ?? '#2B2B2B'),
      frames: (j['frames'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String)),
      prizeBanner: j['prizeBanner'] as String,
      prizeVisibleWidth: _d(j['prizeVisibleWidth'] ?? 1),
      logo: LogoSpec.fromJson(j['logo'] as Map<String, dynamic>),
      extras: extras,
      fields: (j['fields'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, FieldRect.fromJson(v as Map<String, dynamic>))),
      titleStyles: {
        for (final style in CardStyle.values)
          style: TitleStyleSpec.fromJson(
            (rawStyles[style.name] as Map<String, dynamic>?) ?? const <String, dynamic>{},
            style == CardStyle.game ? TitleStyleSpec.gameDefault : TitleStyleSpec.fanDefault,
          ),
      },
      prizeStyles: {
        for (final style in CardStyle.values)
          style: PrizeStyleSpec.fromJson(
            (rawPrize[style.name] as Map<String, dynamic>?) ?? const <String, dynamic>{},
            style == CardStyle.game ? PrizeStyleSpec.gameDefault : PrizeStyleSpec.fromExtras(extras),
          ),
      },
    );
  }
}
