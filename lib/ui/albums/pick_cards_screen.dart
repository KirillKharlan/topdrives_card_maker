import 'package:flutter/material.dart';

import '../../data/card_search.dart';
import '../../data/repositories/app_store.dart';
import '../common/search_field.dart';
import '../home/project_tile.dart';

/// Pick which cards belong to a user's album. Nothing is saved until Done.
class PickCardsScreen extends StatefulWidget {
  const PickCardsScreen({super.key, required this.store, required this.albumId});

  final AppStore store;
  final String albumId;

  @override
  State<PickCardsScreen> createState() => _PickCardsScreenState();
}

class _PickCardsScreenState extends State<PickCardsScreen> {
  late final Set<String> _selected;
  final _search = TextEditingController();
  String _query = '';

  AppStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    final existing = {for (final p in store.projects.items) p.id};
    final album = store.albums.byId(widget.albumId);
    _selected = <String>{
      if (album != null) ...album.cardIds.where(existing.contains),
    };
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _done() async {
    await store.albums.setCards(widget.albumId, _selected);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final all = store.projects.items;
    final items = all.where((p) => cardMatches(p, _query)).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(_selected.isEmpty ? 'Add cars' : 'Add cars (${_selected.length})'),
        actions: [
          TextButton(onPressed: _done, child: const Text('Done')),
        ],
      ),
      body: all.isEmpty
          ? const Center(child: Text('No cards yet.'))
          : Column(
              children: [
                SearchField(
                  controller: _search,
                  hint: 'Search by brand, model or name',
                  onChanged: (v) => setState(() => _query = v),
                ),
                Expanded(
                  child: items.isEmpty
                      ? const Center(child: Text('Nothing found.'))
                      : GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 1.3,
                          ),
                          itemCount: items.length,
                          itemBuilder: (_, i) {
                            final card = items[i];
                            return ProjectTile(
                              key: ValueKey(card.id),
                              store: store,
                              project: card,
                              selected: _selected.contains(card.id),
                              onTap: () => setState(() {
                                if (!_selected.remove(card.id)) _selected.add(card.id);
                              }),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
