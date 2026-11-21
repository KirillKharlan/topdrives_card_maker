import 'package:flutter/material.dart';

import '../../data/models/card_project.dart';
import '../../data/repositories/app_store.dart';
import '../../editor/editor_screen.dart';
import '../../update/update_prompt.dart';
import '../albums/albums_screen.dart';
import '../backup/backup_sheet.dart';
import '../collection/card_collection.dart';
import '../collection/collection_controller.dart';
import '../collection/selection_app_bar.dart';
import '../library/library_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AppStore get store => widget.store;

  final _controller = CollectionController();

  @override
  void dispose() {
    _controller.dispose();
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

  Future<void> _toggleBetaMatches() async {
    final on = !store.settings.betaMatchesEnabled;
    await store.settings.setBetaMatches(on);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(on
            ? 'Beta comparison is on: it is shown in the editor of cards made with the beta template.'
            : 'Beta comparison is off.'),
      ),
    );
  }

  void _open(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([store.projects, _controller]),
      builder: (context, _) {
        final all = store.projects.items;
        return Scaffold(
          appBar: _controller.selecting
              ? selectionAppBar(
                  context,
                  store: store,
                  controller: _controller,
                  exportName: 'cards',
                )
              : AppBar(
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
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'select') _controller.startSelecting();
                        if (value == 'backup') showBackupSheet(context);
                        if (value == 'info') showAppInfoDialog(context, store.settings);
                        if (value == 'beta') _toggleBetaMatches();
                      },
                      itemBuilder: (_) => [
                        if (all.isNotEmpty)
                          const PopupMenuItem(value: 'select', child: Text('Select cards')),
                        CheckedPopupMenuItem(
                          value: 'beta',
                          checked: store.settings.betaMatchesEnabled,
                          child: const Text('Compare with beta cards'),
                        ),
                        const PopupMenuItem(value: 'backup', child: Text('Backup and restore')),
                        const PopupMenuItem(value: 'info', child: Text('Version and updates')),
                      ],
                    ),
                  ],
                ),
          floatingActionButton: _controller.selecting
              ? null
              : FloatingActionButton.extended(
                  onPressed: _newCard,
                  icon: const Icon(Icons.add),
                  label: const Text('New card'),
                ),
          body: all.isEmpty
              ? const Center(child: Text('No cards yet. Tap "New card".'))
              : CardCollection(
                  store: store,
                  controller: _controller,
                  cards: all,
                  bottomPadding: 88,
                ),
        );
      },
    );
  }
}
