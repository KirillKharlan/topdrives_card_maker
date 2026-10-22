import 'package:flutter/material.dart';

import '../../data/models/card_project.dart';
import '../../templates/template_spec.dart';

/// Prize-car banner and series tag, drawn above the card (outside the frame).
class ExtrasStrip extends StatelessWidget {
  const ExtrasStrip({super.key, required this.project, required this.template});

  final CardProject project;
  final TemplateSpec template;

  bool get isEmpty => !project.prize && project.tagAsset == null;

  @override
  Widget build(BuildContext context) {
    if (isEmpty) return const SizedBox.shrink();
    final ex = template.extras;
    return SizedBox(
      width: template.width,
      height: ex.stripHeight,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: ex.padding),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (project.prize) _prizeBanner(ex),
              if (project.prize && project.tagAsset != null) SizedBox(width: ex.gap),
              if (project.tagAsset != null)
                Image.asset(
                  project.tagAsset!,
                  height: ex.tagHeight,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // prize_car.png is a wide transparent banner with the trophy at the far
  // left; only the visible part is kept so the tag can sit next to it.
  Widget _prizeBanner(ExtrasSpec ex) {
    return SizedBox(
      height: ex.prizeHeight,
      child: ClipRect(
        child: Align(
          alignment: Alignment.centerLeft,
          widthFactor: template.prizeVisibleWidth,
          child: Image.asset(
            template.prizeBanner,
            height: ex.prizeHeight,
            fit: BoxFit.fitHeight,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}
