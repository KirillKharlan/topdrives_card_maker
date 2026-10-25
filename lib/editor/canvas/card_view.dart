import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/layout_tweaks.dart';
import '../../data/models/card_project.dart';
import '../../templates/template_spec.dart';
import 'field_text.dart';
import 'logo_tile.dart';
import 'photo_layer.dart';

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
  });

  final CardProject project;
  final TemplateSpec template;
  final File? photoFile;
  final File? logoFile;

  /// Photo decode width; small cards (the home grid) use a lower value.
  final int photoMaxWidth;

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
            if (photoFile != null)
              Positioned.fill(
                child: PhotoLayer(
                  file: photoFile!,
                  transform: project.photoTransform,
                  fill: project.photoFill,
                  background: t.photoBackground,
                  maxWidth: photoMaxWidth,
                ),
              ),
            // Frosted glass: blur the photo behind the semi-transparent parts of the frame.
            if (photoFile != null && t.blurSigma > 0)
              for (final r in t.blurRegions)
                Positioned(
                  left: r.x,
                  top: r.y,
                  width: r.w,
                  height: r.h,
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(
                        sigmaX: t.blurSigma,
                        sigmaY: t.blurSigma,
                        tileMode: TileMode.clamp,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
            Positioned.fill(
              child: Image.asset(
                frame,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.high,
                gaplessPlayback: true,
              ),
            ),
            if (logoFile != null) _logo(),
            FieldText(scale: t.textScale, 
              rect: t.field('title'),
              parts: [('${project.brand} ', true), (project.model, false)],
            ),
            FieldText(scale: t.textScale, rect: t.field('year'), parts: [(project.year, false)]),
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
    ));
  }

  Widget _logo() {
    final l = template.logo;
    return Positioned(
      left: l.x,
      top: l.y,
      width: l.w,
      height: l.h,
      child: LogoTile(file: logoFile!, scale: project.logoScale, padding: l.padding),
    );
  }
}
