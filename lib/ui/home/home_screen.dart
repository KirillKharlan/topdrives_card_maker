import 'package:flutter/material.dart';

import '../../data/card_search.dart';
import '../../data/models/card_project.dart';
import '../../data/repositories/app_store.dart';
import '../../editor/editor_screen.dart';
import '../../update/update_prompt.dart';
import '../albums/albums_screen.dart';
import '../library/library_screen.dart';
import '../common/search_field.dart';
import 'project_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AppStore get store => widget.store;

  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Silent check once per launch; does nothing when offline.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) checkForUpdates(context, manual: false);
    });
  }

  Future<void> _newCard() async {
    final project = CardProject.create();
    await store.projects.save(project);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditorScreen(store: store, project: project)),
    );
  }

  void _open(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Card Maker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.collections_bookmark_outlined),
            tooltip: 'Albums',
            onPressed: () => _open(AlbumsScreen(store: store)),
          ),
          IconButton(
            icon: const Icon(Icons.photo_library_outlined),
            tooltip: 'Car photos',
            onPressed: () => _open(LibraryScreen.photos(store)),
          ),
          IconButton(
            icon: const Icon(Icons.shield_outlined),
            tooltip: 'Logos',
            onPressed: () => _open(LibraryScreen.logos(store)),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Version and updates',
            onPressed: () => showAppInfoDialog(context, store.settings),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newCard,
        icon: const Icon(Icons.add),
        label: const Text('New card'),
      ),
      body: ListenableBuilder(
        listenable: store.projects,
        builder: (context, _) {
          final all = store.projects.items;
          if (all.isEmpty) {
            return const Center(child: Text('No cards yet. Tap "New card".'));
          }
          final items = all.where((p) => cardMatches(p, _query)).toList();
          return Column(
            children: [
              SearchField(
                controller: _searchController,
                hint: 'Search by brand, model or name',
                onChanged: (v) => setState(() => _query = v),
              ),
              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('Nothing found.'))
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.3,
                        ),
                        itemCount: items.length,
                        itemBuilder: (_, i) => ProjectTile(store: store, project: items[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
