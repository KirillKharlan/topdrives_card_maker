import 'package:flutter/material.dart';

import '../../templates/tag_catalog.dart';

/// Bottom sheet with a searchable grid of the bundled series tags.
/// Returns the asset path of the chosen tag.
Future<String?> showTagPicker(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _TagPicker(),
  );
}

class _TagPicker extends StatefulWidget {
  const _TagPicker();

  @override
  State<_TagPicker> createState() => _TagPickerState();
}

class _TagPickerState extends State<_TagPicker> {
  final Future<List<String>> _tags = TagCatalog.list();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.8;
    return SizedBox(
      height: height,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
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
                  itemBuilder: (context, i) => Tooltip(
                    message: TagCatalog.nameOf(tags[i]),
                    child: InkWell(
                      onTap: () => Navigator.pop(context, tags[i]),
                      child: Image.asset(tags[i], fit: BoxFit.contain, cacheHeight: 120),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
