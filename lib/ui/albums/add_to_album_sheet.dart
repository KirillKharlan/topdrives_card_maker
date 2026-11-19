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
