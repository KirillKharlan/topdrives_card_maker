import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/models/card_project.dart';
import '../../templates/template_spec.dart';
import 'card_view.dart';
import 'prize_strip.dart';
import 'tag_strip.dart';

/// Tag (top) + card + prize marker (bottom) on a dark backdrop, like a game
/// screenshot. [fullKey] captures everything, [cardKey] only the card
/// (transparent rounded corners).
class CardComposition extends StatelessWidget {
  const CardComposition({
    super.key,
    required this.project,
    required this.template,
    this.photoFile,
    this.logoFile,
    this.cardKey,
    this.fullKey,
  });

  final CardProject project;
  final TemplateSpec template;
  final File? photoFile;
  final File? logoFile;
  final GlobalKey? cardKey;
  final GlobalKey? fullKey;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: RepaintBoundary(
      key: fullKey,
      child: SizedBox(
        width: template.width,
        child: ColoredBox(
          color: template.extras.backdrop,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (project.tagAssets.isNotEmpty) TagStrip(project: project, template: template),
              RepaintBoundary(
                key: cardKey,
                child: CardView(
                  project: project,
                  template: template,
                  photoFile: photoFile,
                  logoFile: logoFile,
                ),
              ),
              if (project.prize) PrizeStrip(project: project, template: template),
            ],
          ),
        ),
      ),
    ));
  }
}
