import 'package:flutter/material.dart';

import '../../data/models/card_project.dart';
import '../../data/repositories/app_store.dart';
import '../../editor/editor_screen.dart';
import '../../update/update_prompt.dart';
import '../library/library_screen.dart';
import 'project_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AppStore get store => widget.store;

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
          final items = store.projects.items;
          if (items.isEmpty) {
            return const Center(child: Text('No cards yet. Tap "New card".'));
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.3,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) => ProjectTile(store: store, project: items[i]),
          );
        },
      ),
    );
  }
}
