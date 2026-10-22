import 'package:flutter/material.dart';

import '../../templates/tag_catalog.dart';
import '../editor_controller.dart';
import 'section_card.dart';
import 'tag_picker_sheet.dart';

/// Prize-car banner and series tag (drawn above the card).
class ExtrasSection extends StatelessWidget {
  const ExtrasSection({super.key, required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final tag = c.project.tagAsset;
    return SectionCard(
      title: 'Above the card',
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Prize car'),
          value: c.project.prize,
          onChanged: (v) => c.update((p) => p.prize = v),
        ),
        Row(
          children: [
            Expanded(
              child: tag == null
                  ? const Text('No tag')
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: Tooltip(
                        message: TagCatalog.nameOf(tag),
                        child: Image.asset(tag, height: 36, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                      ),
                    ),
            ),
            OutlinedButton(
              onPressed: () async {
                final path = await showTagPicker(context);
                if (path != null) c.update((p) => p.tagAsset = path);
              },
              child: Text(tag == null ? 'Choose tag' : 'Change'),
            ),
            if (tag != null)
              IconButton(
                tooltip: 'Remove tag',
                icon: const Icon(Icons.close),
                onPressed: () => c.update((p) => p.tagAsset = null),
              ),
          ],
        ),
      ],
    );
  }
}
