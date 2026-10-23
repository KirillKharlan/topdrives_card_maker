import 'package:flutter/material.dart';

import '../../templates/tag_catalog.dart';

/// Bottom sheet with a searchable grid of the bundled series tags. Tap to
/// select / unselect several tags; "Done" returns the chosen asset paths in
/// the order they were picked. Swiping the sheet away returns null (no change).
Future<List<String>?> showTagPicker(
  BuildContext context, {
  required List<String> selected,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _TagPicker(initial: selected),
  );
}

class _TagPicker extends StatefulWidget {
  const _TagPicker({required this.initial});

  final List<String> initial;

  @override
  State<_TagPicker> createState() => _TagPickerState();
}

class _TagPickerState extends State<_TagPicker> {
  final Future<List<String>> _tags = TagCatalog.list();
  late final List<String> _selected = List<String>.of(widget.initial);
  String _query = '';

  void _toggle(String path) {
    setState(() {
      if (!_selected.remove(path)) _selected.add(path);
    });
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.8;
    final primary = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: height,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
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
          Expanded(
            child: FutureBuilder<List<String>>(
              future: _tags,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final tags = snapshot.data!
                    .where((p) => TagCatalog.nameOf(p).toLowerCase().contains(_query))
                    .toList();
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 3.2,
                  ),
                  itemCount: tags.length,
                  itemBuilder: (context, i) {
                    final path = tags[i];
                    final picked = _selected.contains(path);
                    return Tooltip(
                      message: TagCatalog.nameOf(path),
                      child: InkWell(
                        onTap: () => _toggle(path),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: picked ? Border.all(color: primary, width: 2) : null,
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Image.asset(path, fit: BoxFit.contain, cacheHeight: 120),
                                ),
                              ),
                              if (picked)
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: Icon(Icons.check_circle, color: primary, size: 20),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
