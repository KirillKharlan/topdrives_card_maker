import 'package:flutter/material.dart';

import '../../data/models/card_tag.dart';
import '../../templates/tag_catalog.dart';
import '../canvas/custom_tag_view.dart';
import '../editor_controller.dart';
import 'section_card.dart';
import 'tag_editor_sheet.dart';
import 'tag_picker_sheet.dart';

/// Tags (above the card) and the prize-car marker (below the card).
class ExtrasSection extends StatelessWidget {
  const ExtrasSection({super.key, required this.controller});

  final EditorController controller;

  /// Ready-made tags: the picker edits only those, custom tags stay in place.
  Future<void> _pickTags(BuildContext context) async {
    final c = controller;
    final current = [
      for (final t in c.project.tags)
        if (!t.isCustom) t.asset!,
    ];
    final result = await showTagPicker(context, selected: current);
    if (result == null) return;
    c.update((p) {
      final next = <CardTag>[
        for (final t in p.tags)
          if (t.isCustom || result.contains(t.asset)) t,
      ];
      for (final path in result) {
        if (!next.any((t) => t.asset == path)) next.add(CardTag(asset: path));
      }
      p.tags = next;
    });
  }

  Future<void> _createTag(BuildContext context) async {
    final tag = await showTagEditor(context);
    if (tag == null) return;
    controller.update((p) {
      p.tags = [...p.tags, tag];
    });
  }

  Future<void> _editTag(BuildContext context, int index) async {
    final tag = await showTagEditor(context, initial: controller.project.tags[index]);
    if (tag == null) return;
    controller.update((p) {
      final next = [...p.tags];
      next[index] = tag;
      p.tags = next;
    });
  }

  Widget _chip(BuildContext context, int index, CardTag tag) {
    final preview = tag.isCustom
        ? GestureDetector(
            onTap: () => _editTag(context, index),
            child: CustomTagView(
              text: tag.text ?? '',
              colorValue: tag.colorValue ?? 0xFFF2C21B,
              height: 34,
            ),
          )
        : Tooltip(
            message: TagCatalog.nameOf(tag.asset!),
            child: Image.asset(
              tag.asset!,
              height: 34,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(padding: const EdgeInsets.only(top: 8, right: 8), child: preview),
        Positioned(
          top: 0,
          right: 0,
          child: GestureDetector(
            onTap: () => controller.update((p) {
              final next = [...p.tags];
              next.removeAt(index);
              p.tags = next;
            }),
            child: const CircleAvatar(radius: 9, child: Icon(Icons.close, size: 12)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final tags = c.project.tags;
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
                for (var i = 0; i < tags.length; i++) _chip(context, i, tags[i]),
              ],
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            OutlinedButton.icon(
              onPressed: () => _pickTags(context),
              icon: const Icon(Icons.sell_outlined),
              label: const Text('Ready-made tags'),
            ),
            OutlinedButton.icon(
              onPressed: () => _createTag(context),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Create tag'),
            ),
            if (tags.isNotEmpty)
              TextButton(
                onPressed: () => c.update((p) {
                  p.tags = <CardTag>[];
                }),
                child: const Text('Clear all'),
              ),
          ],
        ),
        if (tags.any((t) => t.isCustom))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Tap a custom tag to edit it.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
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
