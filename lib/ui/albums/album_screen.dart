import 'package:flutter/material.dart';

import '../../data/brand_groups.dart';
import '../../data/models/card_project.dart';
import '../../data/repositories/app_store.dart';
import '../common/dialogs.dart';
import '../home/project_tile.dart';
import 'pick_cards_screen.dart';

/// The cards of one album. Either a built-in brand album (read-only: it
/// follows the Brand field of the cards) or one of the user's own albums
/// (cards can be added, removed; the album can be renamed or deleted).
class AlbumScreen extends StatelessWidget {
  const AlbumScreen._({
    super.key,
    required this.store,
    this.brandKey,
    this.brandTitle,
    this.albumId,
  });

  factory AlbumScreen.brand(AppStore store, String brandKey, String title, {Key? key}) =>
      AlbumScreen._(key: key, store: store, brandKey: brandKey, brandTitle: title);

  factory AlbumScreen.custom(AppStore store, String albumId, {Key? key}) =>
      AlbumScreen._(key: key, store: store, albumId: albumId);

  final AppStore store;
  final String? brandKey;
  final String? brandTitle;
  final String? albumId;

  bool get _isCustom => albumId != null;

  List<CardProject> _cards() {
    if (!_isCustom) {
      return [
        for (final g in groupByBrand(store.projects.items))
          if (g.key == brandKey) ...g.cards,
      ];
    }
    final album = store.albums.byId(albumId!);
    if (album == null) return const [];
    final byId = {for (final p in store.projects.items) p.id: p};
    return [
      for (final id in album.cardIds)
        if (byId[id] != null) byId[id]!,
    ];
  }

  Future<void> _rename(BuildContext context) async {
    final album = store.albums.byId(albumId!);
    if (album == null) return;
    final name = await promptNameDialog(
      context,
      title: 'Rename album',
      hint: 'Album name',
      initial: album.name,
      action: 'Save',
    );
    if (name != null) await store.albums.rename(album.id, name);
  }

  Future<void> _deleteAlbum(BuildContext context) async {
    final album = store.albums.byId(albumId!);
    if (album == null) return;
    final ok = await confirmDialog(
      context,
      title: 'Delete album?',
      message: '\"${album.name}\" will be removed. The cards themselves are kept.',
    );
    if (!ok) return;
    if (context.mounted) Navigator.pop(context);
    await store.albums.delete(album.id);
  }

  Future<void> _addCards(BuildContext context) {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PickCardsScreen(store: store, albumId: albumId!)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([store.projects, store.albums]),
      builder: (context, _) {
        final cards = _cards();
        final title = _isCustom ? (store.albums.byId(albumId!)?.name ?? 'Album') : (brandTitle ?? '');
        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            actions: [
              if (_isCustom)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'rename') _rename(context);
                    if (value == 'delete') _deleteAlbum(context);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('Rename')),
                    PopupMenuItem(value: 'delete', child: Text('Delete album')),
                  ],
                ),
            ],
          ),
          floatingActionButton: _isCustom
              ? FloatingActionButton.extended(
                  onPressed: () => _addCards(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add cars'),
                )
              : null,
          body: cards.isEmpty
              ? Center(
                  child: Text(_isCustom
                      ? 'This album is empty. Tap \"Add cars\".'
                      : 'No cards with this brand.'),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.3,
                  ),
                  itemCount: cards.length,
                  itemBuilder: (_, i) {
                    final card = cards[i];
                    return ProjectTile(
                      key: ValueKey(card.id),
                      store: store,
                      project: card,
                      onRemoveFromAlbum:
                          _isCustom ? () => store.albums.removeCard(albumId!, card.id) : null,
                    );
                  },
                ),
        );
      },
    );
  }
}
