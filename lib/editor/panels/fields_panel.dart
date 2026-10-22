import 'package:flutter/material.dart';

import '../editor_controller.dart';
import 'extras_section.dart';
import 'media_section.dart';
import 'options_section.dart';
import 'text_section.dart';

/// The scrollable form under the preview. One section per concern.
class FieldsPanel extends StatelessWidget {
  const FieldsPanel({super.key, required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          MediaSection(controller: controller),
          TextSection(controller: controller),
          OptionsSection(controller: controller),
          ExtrasSection(controller: controller),
        ],
      ),
    );
  }
}
