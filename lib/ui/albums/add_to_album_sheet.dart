import 'package:flutter/material.dart';

import '../../data/models/card_project.dart';
import '../../data/repositories/app_store.dart';
import '../common/dialogs.dart';

/// Bottom sheet: tick the albums the card should be in, or make a new album.
Future<void> showAddToAlbumSheet(BuildContext context, AppStore store, CardProject project) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: ListenableBuilder(
        listenable: store.albums,
        builder: (_, __) {
          final albums = store.albums.items;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text('Add to album', style: TextStyle(fontSize: 18)),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final album in albums)
                      CheckboxListTile(
                        value: album.cardIds.contains(project.id),
                        title: Text(album.name),
                        onChanged: (_) => store.albums.toggleCard(album.id, project.id),
                      ),
                    ListTile(
                      leading: const Icon(Icons.add),
                      title: const Text('New album'),
                      onTap: () async {
                        final name = await promptNameDialog(
                          sheetContext,
                          title: 'New album',
                          hint: 'Album name',
                          action: 'Create',
                        );
                        if (name == null) return;
                        final album = await store.albums.create(name);
                        await store.albums.toggleCard(album.id, project.id);
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

/// Sheet to put several cards into one album (an existing one or a new one).
/// Returns true when the cards were added.
Future<bool> showAddCardsToAlbumSheet(
  BuildContext context,
  AppStore store,
  List<String> ids,
) async {
  final albumId = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: ListenableBuilder(
        listenable: store.albums,
        builder: (_, __) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                ids.length == 1 ? 'Add 1 card to album' : 'Add ${ids.length} cards to album',
                style: const TextStyle(fontSize: 18),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final album in store.albums.items)
                    ListTile(
                      leading: const Icon(Icons.collections_bookmark_outlined),
                      title: Text(album.name),
                      subtitle: Text('${album.cardIds.length} cards'),
                      onTap: () => Navigator.pop(sheetContext, album.id),
                    ),
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('New album'),
                    onTap: () async {
                      final name = await promptNameDialog(
                        sheetContext,
                        title: 'New album',
                        hint: 'Album name',
                        action: 'Create',
                      );
                      if (name == null) return;
                      final album = await store.albums.create(name);
                      if (sheetContext.mounted) Navigator.pop(sheetContext, album.id);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (albumId == null) return false;
  await store.albums.addCards(albumId, ids);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ids.length == 1 ? 'Added to album' : 'Added ${ids.length} cards to album')),
    );
  }
  return true;
}
