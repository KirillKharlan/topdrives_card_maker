import 'package:flutter/material.dart';

import '../../data/models/card_project.dart';
import '../../data/repositories/app_store.dart';
import '../albums/add_to_album_sheet.dart';
import '../albums/album_export_sheet.dart';
import '../common/dialogs.dart';
import 'collection_controller.dart';

/// The app bar while cards are being selected: how many, select all, star,
/// add to album, export, and delete (or remove from the album when [albumId] is set).
AppBar selectionAppBar(
  BuildContext context, {
  required AppStore store,
  required CollectionController controller,
  required String exportName,
  String? albumId,
}) {
  List<CardProject> picked() =>
      store.projects.items.where((p) => controller.selected.contains(p.id)).toList();
  final count = controller.selected.length;
  final none = count == 0;

  Future<void> toggleFavorite() async {
    final cards = picked();
    if (cards.isEmpty) return;
    await store.projects.setFavorite(
      cards.map((p) => p.id),
      !cards.every((p) => p.favorite),
    );
  }

  Future<void> addToAlbum() async {
    final added = await showAddCardsToAlbumSheet(context, store, controller.selected.toList());
    if (added) controller.stopSelecting();
  }

  Future<void> removeOrDelete() async {
    final cards = picked();
    if (cards.isEmpty) return;
    if (albumId != null) {
      for (final p in cards) {
        await store.albums.removeCard(albumId, p.id);
      }
      controller.stopSelecting();
      return;
    }
    final ok = await confirmDialog(
      context,
      title: cards.length == 1 ? 'Delete card?' : 'Delete ${cards.length} cards?',
      message: 'The cards will be removed. Library images are kept.',
    );
    if (!ok) return;
    for (final p in cards) {
      await store.deleteProject(p);
    }
    controller.stopSelecting();
  }

  return AppBar(
    leading: IconButton(
      icon: const Icon(Icons.close),
      tooltip: 'Cancel selection',
      onPressed: controller.stopSelecting,
    ),
    title: Text(none ? 'Select cards' : '$count selected'),
    actions: [
      IconButton(
        icon: const Icon(Icons.select_all),
        tooltip: 'Select all',
        onPressed: () => controller.selectAll(controller.visibleIds),
      ),
      IconButton(
        icon: const Icon(Icons.star_outline),
        tooltip: 'Favorite',
        onPressed: none ? null : toggleFavorite,
      ),
      IconButton(
        icon: const Icon(Icons.collections_bookmark_outlined),
        tooltip: 'Add to album',
        onPressed: none ? null : addToAlbum,
      ),
      IconButton(
        icon: const Icon(Icons.ios_share),
        tooltip: 'Export',
        onPressed: none ? null : () => showAlbumExportSheet(context, store, picked(), name: exportName),
      ),
      IconButton(
        icon: Icon(albumId != null ? Icons.remove_circle_outline : Icons.delete_outline),
        tooltip: albumId != null ? 'Remove from album' : 'Delete',
        onPressed: none ? null : removeOrDelete,
      ),
    ],
  );
}
