import 'package:flutter/material.dart';

import '../../templates/tag_catalog.dart';
import '../editor_controller.dart';
import 'section_card.dart';
import 'tag_picker_sheet.dart';

/// Series tags (above the card) and the prize-car marker (below the card).
class ExtrasSection extends StatelessWidget {
  const ExtrasSection({super.key, required this.controller});

  final EditorController controller;

  Future<void> _pickTags(BuildContext context) async {
    final c = controller;
    final result = await showTagPicker(context, selected: List<String>.of(c.project.tagAssets));
    if (result == null) return;
    c.update((p) {
      p.tagAssets = List<String>.of(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final tags = c.project.tagAssets;
    return SectionCard(
      title: 'Tags and prize marker',
      children: [
        if (tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in tags)
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8, right: 8),
                        child: Tooltip(
                          message: TagCatalog.nameOf(tag),
                          child: Image.asset(
                            tag,
                            height: 34,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => c.update((p) {
                            p.tagAssets.remove(tag);
                          }),
                          child: const CircleAvatar(
                            radius: 9,
                            child: Icon(Icons.close, size: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _pickTags(context),
              icon: const Icon(Icons.sell_outlined),
              label: Text(tags.isEmpty ? 'Add tags' : 'Edit tags'),
            ),
            if (tags.isNotEmpty)
              TextButton(
                onPressed: () => c.update((p) {
                  p.tagAssets = <String>[];
                }),
                child: const Text('Clear all'),
              ),
          ],
        ),
        const Divider(height: 24),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Prize car'),
          value: c.project.prize,
          onChanged: (v) => c.update((p) => p.prize = v),
        ),
        if (c.project.prize)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: TextFormField(
              initialValue: c.project.prizeText,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Prize marker text',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => c.update((p) => p.prizeText = v),
            ),
          ),
      ],
    );
  }
}
