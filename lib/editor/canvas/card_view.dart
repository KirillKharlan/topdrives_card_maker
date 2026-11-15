import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/layout_tweaks.dart';
import '../../data/models/card_project.dart';
import '../../data/models/photo_fill.dart';
import '../../templates/template_spec.dart';
import 'field_text.dart';
import 'logo_tile.dart';
import 'photo_layer.dart';
import 'flag_badge.dart';
import 'title_text.dart';
import '../../data/country_flags.dart';

/// The card itself, drawn at the template's native size (e.g. 1338x828).
/// Layers, bottom to top: background, photo, class frame, logo, texts.
class CardView extends StatelessWidget {
  const CardView({
    super.key,
    required this.project,
    required this.template,
    this.photoFile,
    this.logoFile,
    this.photoMaxWidth = 2600,
    this.fillFile,
    this.videoLayer,
    this.liveVideo = false,
    this.lite = false,
  });

  final CardProject project;
  final TemplateSpec template;
  final File? photoFile;
  final File? logoFile;

  /// Photo decode width; small cards (the home grid) use a lower value.
  final int photoMaxWidth;

  /// The current content-aware fill picture, if any.
  final File? fillFile;

  /// The live video of a video card (preview only), drawn over the still frame.
  final Widget? videoLayer;

  /// The live video is playing on top of the still frame (the frosted glass
  /// then fades in with a few steps, which are cheaper than a copy of the video).
  final bool liveVideo;

  /// Thumbnails (the home grid): no frosted glass, at that size it cannot be seen
  /// and every blur layer costs a lot of GPU time.
  final bool lite;

  PhotoLayer _photo(TemplateSpec t) => PhotoLayer(
        file: photoFile!,
        transform: project.photoTransform,
        // A moving picture has no generated fill, mirror stands in.
        fill: project.hasVideo && project.photoFill == PhotoFill.smart
            ? PhotoFill.mirror
            : project.photoFill,
        background: t.photoBackground,
        maxWidth: photoMaxWidth,
        smartFill: fillFile,
      );

  Widget _blur(Rect rect, double sigma) => Positioned(
        left: rect.left,
        top: rect.top,
        width: rect.width,
        height: rect.height,
        child: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.clamp),
            child: const SizedBox.expand(),
          ),
        ),
      );

  /// Frosted glass behind the semi-transparent parts of the frame. A region
  /// whose blur has to fade in from the left is one full-strength blur plus ONE
  /// shared sharp copy of the photo faded out over it (a handful of layers; many
  /// narrow blur strips were very slow on the GPU).
  List<Widget> _frostedGlass(TemplateSpec t) {
    final layers = <Widget>[];
    final fadeGroups = <String, List<RegionRect>>{};
    for (final r in t.blurRegions) {
      final fade = r.fadeLeft.clamp(0.0, r.w).toDouble();
      if (fade <= 0) {
        layers.add(_blur(Rect.fromLTWH(r.x, r.y, r.w, r.h), t.blurSigma));
      } else if (liveVideo) {
        for (final piece in r.blurPieces(t.blurSigma, steps: 3)) {
          layers.add(_blur(piece.rect, piece.sigma));
        }
      } else {
        layers.add(_blur(Rect.fromLTWH(r.x, r.y, r.w, r.h), t.blurSigma));
        (fadeGroups['${r.x}|$fade'] ??= []).add(r);
      }
    }
    for (final group in fadeGroups.values) {
      final x = group.first.x;
      final fade = group.first.fadeLeft.clamp(0.0, group.first.w).toDouble();
      final top = group.map((r) => r.y).reduce(math.min);
      final bottom = group.map((r) => r.y + r.h).reduce(math.max);
      layers.add(
        Positioned(
          left: x,
          top: top,
          width: fade,
          height: bottom - top,
          child: ClipRect(
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
              ).createShader(bounds),
              child: Transform.translate(
                offset: Offset(-x, -top),
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: t.width,
                  maxWidth: t.width,
                  minHeight: t.height,
                  maxHeight: t.height,
                  child: SizedBox(
                    width: t.width,
                    height: t.height,
                    child: Stack(
                      children: [
                        Positioned.fill(child: ColoredBox(color: t.photoBackground)),
                        Positioned.fill(child: _photo(t)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return layers;
  }

  @override
  Widget build(BuildContext context) {
    final t = template;
    final frame = t.frames[project.carClass] ?? t.frames.values.first;
    final drivePrefix = project.drive.isEmpty ? '' : project.drive[0];

    // Card text must not depend on the phone's font-size setting.
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: SizedBox(
      width: t.width,
      height: t.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(t.cornerRadius),
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: t.photoBackground)),
            if (photoFile != null) Positioned.fill(child: _photo(t)),
            if (photoFile != null && videoLayer != null)
              Positioned.fill(key: const ValueKey('video-layer'), child: videoLayer!),
            // Frosted glass: blur the photo behind the semi-transparent parts of the frame.
            if (photoFile != null && t.blurSigma > 0 && !lite) ..._frostedGlass(t),
            // Frame, logo, flag and texts do not move while the photo is dragged: one cached layer,
            // so a drag only repaints the photo (and the frosted glass), not the whole card.
            Positioned.fill(
              child: RepaintBoundary(
                child: Stack(
                  children: [
                Positioned.fill(
                  child: Image.asset(
                    frame,
                    cacheWidth: lite ? 700 : null,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.high,
                    gaplessPlayback: true,
                  ),
                ),
                if (logoFile != null) _logo(),
                if (project.showFlag && CountryFlags.has(project.country))
                  FlagBadge(code: project.country, spec: t.flag),

                // Brand keeps its size; the model fits itself into the rest of the line.
                TitleText(
                  brand: project.brand,
                  model: project.model,
                  style: t.titleStyle(project.cardStyle),
                  textScale: t.textScale,
                  brandScale: project.brandScale,
                  modelScale: project.modelScale,
                ),
                FieldText(
                  scale: t.textScale * project.yearScale,
                  rect: t.field('year'),
                  parts: [(project.year, false)],
                ),
                FieldText(scale: t.textScale, rect: t.field('country'), parts: [(project.country, true)]),
                FieldText(scale: t.textScale, rect: t.field('topSpeed'), parts: [(project.topSpeed, true)]),
                FieldText(scale: t.textScale, rect: t.field('accel'), parts: [(project.accelDisplay, true)]),
                FieldText(scale: t.textScale, rect: t.field('handling'), parts: [(project.handling, true)]),
                // The frame already contains "WD"; we add only R / F / 4.
                FieldText(scale: t.textScale, rect: t.field('drivePrefix'), parts: [(drivePrefix, true)]),
                // The word "Tyres" is part of the frame; we add only the tyre name before it.
                ValueListenableBuilder<double>(
                  valueListenable: LayoutTweaks.tyreNameOffset,
                  builder: (context, offset, _) => FieldText(
                    scale: t.textScale,
                    rect: t.field('tyre').shifted(offset),
                    parts: [(project.tyre.toUpperCase(), false)],
                  ),
                ),
                FieldText(scale: t.textScale, rect: t.field('rq'), parts: [(project.rq, true)]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ));
  }

  Widget _logo() {
    final l = template.logo;
    return Positioned(
      left: l.x,
      top: l.y,
      width: l.w,
      height: l.h,
      child: LogoTile(
        file: logoFile!,
        scale: project.logoScale,
        padding: l.padding,
        dx: project.logoDx,
        dy: project.logoDy,
      ),
    );
  }
}
