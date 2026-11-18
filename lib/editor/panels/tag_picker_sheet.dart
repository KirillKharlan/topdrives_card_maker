import 'package:flutter/material.dart';

import '../../data/models/card_tag.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/tag_images.dart';
import '../../templates/tag_catalog.dart';
import '../../ui/common/dialogs.dart';
import '../canvas/custom_tag_view.dart';
import 'tag_editor_sheet.dart';
import 'tag_tools.dart';

/// Tag picker. "All" lists the ready-made tags and the user's own tags in one
/// alphabetical list; "My tags" holds only the user's own tags (made of text, or
/// from a photo), where they can be created, edited and deleted. Long-pressing any tag
/// saves it to the phone's gallery. Tap to select / unselect; "Done" returns
/// the chosen tags in the order they were picked. Swiping the sheet away
/// returns null (no change).
Future<List<CardTag>?> showTagPicker(
  BuildContext context, {
  required SettingsRepository settings,
  required List<CardTag> selected,
}) {
  return showModalBottomSheet<List<CardTag>>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _TagPicker(settings: settings, initial: selected),
  );
}

class _TagPicker extends StatefulWidget {
  const _TagPicker({required this.settings, required this.initial});

  final SettingsRepository settings;
  final List<CardTag> initial;

  @override
  State<_TagPicker> createState() => _TagPickerState();
}

class _TagPickerState extends State<_TagPicker> {
  final Future<List<String>> _assets = TagCatalog.list();
  late final List<CardTag> _selected = List<CardTag>.of(widget.initial);
  String _query = '';

  static String _nameOf(CardTag tag) =>
      tag.asset != null ? TagCatalog.nameOf(tag.asset!) : (tag.text ?? '');

  bool _matches(CardTag tag) => _nameOf(tag).toLowerCase().contains(_query);

  void _toggle(CardTag tag) {
    setState(() {
      if (!_selected.remove(tag)) _selected.add(tag);
    });
  }

  Future<void> _create() async {
    final tag = await showTagEditor(context);
    if (tag == null) return;
    await widget.settings.addCustomTag(tag);
    if (!mounted) return;
    if (!_selected.contains(tag)) setState(() => _selected.add(tag));
  }

  /// Result of the last "save to phone", shown under the tabs.
  String? _status;

  Future<void> _save(CardTag tag) async {
    setState(() => _status = 'Saving...');
    final message = await saveTagToPhone(tag);
    if (!mounted) return;
    setState(() => _status = message);
  }

  Future<void> _createFromPhoto() async {
    final tag = await createTagFromPhoto(context);
    if (tag == null) return;
    await widget.settings.addCustomTag(tag);
    if (!mounted) return;
    if (!_selected.contains(tag)) setState(() => _selected.add(tag));
  }

  Future<void> _rename(CardTag tag) async {
    final input = TextEditingController(text: tag.text ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename tag'),
        content: TextField(controller: input, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, input.text), child: const Text('Save')),
        ],
      ),
    );
    input.dispose();
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return;
    final next = tag.renamed(trimmed);
    await widget.settings.updateCustomTag(tag, next);
    if (!mounted) return;
    final index = _selected.indexOf(tag);
    if (index >= 0) setState(() => _selected[index] = next);
  }

  Future<void> _edit(CardTag tag) async {
    final next = await showTagEditor(context, initial: tag);
    if (next == null) return;
    await widget.settings.updateCustomTag(tag, next);
  }

  Future<void> _delete(CardTag tag) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete tag?',
      message: '"${tag.text}" will be removed from your tags. Cards that already use it keep it.',
    );
    if (ok) await widget.settings.removeCustomTag(tag);
  }

  Widget _preview(CardTag tag) {
    if (tag.isImage) {
      return Image.file(
        TagImages.fileOf(tag.image!)!,
        fit: BoxFit.contain,
        cacheHeight: 120,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }
    if (tag.asset != null) {
      return Image.asset(tag.asset!, fit: BoxFit.contain, cacheHeight: 120);
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: CustomTagView(
          text: tag.text ?? '',
          colorValue: tag.colorValue ?? 0xFFF2C21B,
          height: 50,
        ),
      ),
    );
  }

  Widget _tile(CardTag tag, {required bool menu}) {
    final primary = Theme.of(context).colorScheme.primary;
    final picked = _selected.contains(tag);
    return Tooltip(
      message: _nameOf(tag),
      child: InkWell(
        onTap: () => _toggle(tag),
        onLongPress: () => _save(tag),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: picked ? Border.all(color: primary, width: 2) : null,
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(padding: const EdgeInsets.all(4), child: _preview(tag)),
              ),
              if (picked)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Icon(Icons.check_circle, color: primary, size: 20),
                ),
              if (menu)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        if (value == 'edit') {
                          tag.isImage ? _rename(tag) : _edit(tag);
                        } else if (value == 'save') {
                          _save(tag);
                        } else {
                          _delete(tag);
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'edit', child: Text(tag.isImage ? 'Rename' : 'Edit')),
                        const PopupMenuItem(value: 'save', child: Text('Save to phone')),
                        const PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grid(List<CardTag> tags, {required bool menu, String empty = 'Nothing found'}) {
    if (tags.isEmpty) return Center(child: Text(empty));
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 3.2,
      ),
      itemCount: tags.length,
      itemBuilder: (context, i) => _tile(tags[i], menu: menu),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.85;
    return SizedBox(
      height: height,
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search tags',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, _selected),
                    child: Text('Done (${_selected.length})'),
                  ),
                ],
              ),
            ),
            const TabBar(tabs: [Tab(text: 'All'), Tab(text: 'My tags')]),
            if (_status != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(_status!, style: Theme.of(context).textTheme.bodyMedium),
                ),
              ),
            Expanded(
              child: ListenableBuilder(
                listenable: widget.settings,
                builder: (context, _) => FutureBuilder<List<String>>(
                  future: _assets,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final custom = widget.settings.customTags;
                    final all = <CardTag>[
                      for (final path in snapshot.data!) CardTag(asset: path),
                      ...custom,
                    ]..sort((a, b) => _nameOf(a).toLowerCase().compareTo(_nameOf(b).toLowerCase()));
                    return TabBarView(
                      children: [
                        _grid(all.where(_matches).toList(), menu: false),
                        Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: _create,
                                      icon: const Icon(Icons.add),
                                      label: const Text('Create tag'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: _createFromPhoto,
                                      icon: const Icon(Icons.add_photo_alternate_outlined),
                                      label: const Text('Tag from photo'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Long-press any tag to save it to your phone.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ),
                            Expanded(
                              child: _grid(
                                (custom.toList()
                                      ..sort((a, b) => _nameOf(a)
                                          .toLowerCase()
                                          .compareTo(_nameOf(b).toLowerCase())))
                                    .where(_matches)
                                    .toList(),
                                menu: true,
                                empty: 'No tags of your own yet',
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
