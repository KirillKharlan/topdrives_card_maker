import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/models/card_project.dart';
import '../../templates/template_spec.dart';
import 'card_view.dart';
import 'extras_strip.dart';

/// Extras strip + card. [fullKey] captures both (transparent background),
/// [cardKey] captures only the card.
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
    return RepaintBoundary(
      key: fullKey,
      child: SizedBox(
        width: template.width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExtrasStrip(project: project, template: template),
            RepaintBoundary(
              key: cardKey,
              child: CardView(
                project: project,
                template: template,
                photoFile: photoFile,
                logoFile: logoFile,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
