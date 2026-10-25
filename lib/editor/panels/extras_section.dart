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

  /// Keeps the tags that are still selected in their current order and
  /// appends the newly selected ones.
  Future<void> _pickTags(BuildContext context) async {
    final c = controller;
    final result = await showTagPicker(
      context,
      settings: c.store.settings,
      selected: List<CardTag>.of(c.project.tags),
    );
    if (result == null) return;
    c.update((p) {
      final next = <CardTag>[
        for (final t in p.tags)
          if (result.contains(t)) t,
      ];
      for (final t in result) {
        if (!next.contains(t)) next.add(t);
      }
      p.tags = next;
    });
  }

  /// A new tag is saved to "My tags" (so it can be reused) and added to this card.
  Future<void> _createTag(BuildContext context) async {
    final tag = await showTagEditor(context);
    if (tag == null) return;
    await controller.store.settings.addCustomTag(tag);
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

  void _reorder(int oldIndex, int newIndex) {
    controller.update((p) {
      final next = [...p.tags];
      final target = newIndex > oldIndex ? newIndex - 1 : newIndex;
      next.insert(target, next.removeAt(oldIndex));
      p.tags = next;
    });
  }

  Widget _row(BuildContext context, int index, CardTag tag) {
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
    return Padding(
      key: ObjectKey(tag),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.drag_handle),
            ),
          ),
          Expanded(child: Align(alignment: Alignment.centerLeft, child: preview)),
          IconButton(
            tooltip: 'Remove from this card',
            icon: const Icon(Icons.close),
            onPressed: () => controller.update((p) {
              final next = [...p.tags];
              next.removeAt(index);
              p.tags = next;
            }),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final tags = c.project.tags;
    return SectionCard(
      title: 'Tags and prize marker',
      children: [
        if (tags.isNotEmpty) ...[
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorder: _reorder,
            children: [
              for (var i = 0; i < tags.length; i++) _row(context, i, tags[i]),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Hold the handle and drag to change the order. '
              'Tap a custom tag to edit it.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
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
