import 'package:flutter/material.dart';

import '../../data/models/card_project.dart';
import '../../data/repositories/app_store.dart';
import '../../editor/canvas/card_view.dart';

/// A small picture of a card (the album cover in lists).
class CardThumb extends StatelessWidget {
  const CardThumb({super.key, required this.store, required this.project, this.height = 48});

  final AppStore store;
  final CardProject project;
  final double height;

  @override
  Widget build(BuildContext context) {
    final template = store.templateFor(project);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: height * template.width / template.height,
        height: height,
        child: FittedBox(
          fit: BoxFit.contain,
          child: IgnorePointer(
            child: CardView(
              project: project,
              template: template,
              photoFile: store.photoFileFor(project),
              logoFile: store.logos.fileOf(project.logoId),
              photoMaxWidth: 300,
              lite: true,
              fillFile: store.smartFillFor(project),
            ),
          ),
        ),
      ),
    );
  }
}
