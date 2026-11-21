import 'package:flutter/material.dart';

import '../../data/brand_groups.dart';
import '../../data/models/card_project.dart';
import '../../data/repositories/app_store.dart';
import '../collection/card_collection.dart';
import '../collection/collection_controller.dart';
import '../collection/selection_app_bar.dart';
import '../common/dialogs.dart';
import 'album_export_sheet.dart';
import 'pick_cards_screen.dart';

/// The cards of one album. Either a built-in album (by brand or by country:
/// read-only, it follows the Brand / Country fields of the cards) or one of the
/// user's own albums (cards can be added and removed, the album can be renamed,
/// given a cover card or deleted). Search, order, filters, multi-select and
/// export work in all of them.
class AlbumScreen extends StatefulWidget {
  const AlbumScreen._({
    super.key,
    required this.store,
    this.brandKey,
    this.countryKey,
    this.title,
    this.albumId,
  });

  factory AlbumScreen.brand(AppStore store, String brandKey, String title, {Key? key}) =>
      AlbumScreen._(key: key, store: store, brandKey: brandKey, title: title);

  factory AlbumScreen.country(AppStore store, String countryKey, String title, {Key? key}) =>
      AlbumScreen._(key: key, store: store, countryKey: countryKey, title: title);

  factory AlbumScreen.custom(AppStore store, String albumId, {Key? key}) =>
      AlbumScreen._(key: key, store: store, albumId: albumId);

  final AppStore store;
  final String? brandKey;
  final String? countryKey;
  final String? title;
  final String? albumId;

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  final _controller = CollectionController();

  AppStore get store => widget.store;
  bool get _isCustom => widget.albumId != null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<CardProject> _cards() {
    if (widget.brandKey != null) {
      return [
        for (final g in groupByBrand(store.projects.items))
          if (g.key == widget.brandKey) ...g.cards,
      ];
    }
    if (widget.countryKey != null) {
      return [
        for (final g in groupByCountry(store.projects.items))
          if (g.key == widget.countryKey) ...g.cards,
      ];
    }
    final album = store.albums.byId(widget.albumId!);
    if (album == null) return const [];
    final byId = {for (final p in store.projects.items) p.id: p};
    return [
      for (final id in album.cardIds)
        if (byId[id] != null) byId[id]!,
    ];
  }

  String _title() =>
      _isCustom ? (store.albums.byId(widget.albumId!)?.name ?? 'Album') : (widget.title ?? '');

  Future<void> _rename() async {
    final album = store.albums.byId(widget.albumId!);
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

  Future<void> _deleteAlbum() async {
    final album = store.albums.byId(widget.albumId!);
    if (album == null) return;
    final ok = await confirmDialog(
      context,
      title: 'Delete album?',
      message: '"${album.name}" will be removed. The cards themselves are kept.',
    );
    if (!ok) return;
    if (mounted) Navigator.pop(context);
    await store.albums.delete(album.id);
  }

  Future<void> _addCards() {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PickCardsScreen(store: store, albumId: widget.albumId!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([store.projects, store.albums, _controller]),
      builder: (context, _) {
        final cards = _cards();
        final title = _title();
        return Scaffold(
          appBar: _controller.selecting
              ? selectionAppBar(
                  context,
                  store: store,
                  controller: _controller,
                  exportName: title,
                  albumId: widget.albumId,
                )
              : AppBar(
                  title: Text(title),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.checklist),
                      tooltip: 'Select cards',
                      onPressed: cards.isEmpty ? null : _controller.startSelecting,
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'export') showAlbumExportSheet(context, store, cards, name: title);
                        if (value == 'rename') _rename();
                        if (value == 'delete') _deleteAlbum();
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'export', child: Text('Export album')),
                        if (_isCustom) ...const [
                          PopupMenuItem(value: 'rename', child: Text('Rename')),
                          PopupMenuItem(value: 'delete', child: Text('Delete album')),
                        ],
                      ],
                    ),
                  ],
                ),
          floatingActionButton: _isCustom && !_controller.selecting
              ? FloatingActionButton.extended(
                  onPressed: _addCards,
                  icon: const Icon(Icons.add),
                  label: const Text('Add cars'),
                )
              : null,
          body: CardCollection(
            store: store,
            controller: _controller,
            cards: cards,
            albumId: widget.albumId,
            emptyText: _isCustom
                ? 'This album is empty. Tap "Add cars".'
                : widget.countryKey != null
                    ? 'No cards with this country.'
                    : 'No cards with this brand.',
            bottomPadding: _isCustom ? 88 : 12,
          ),
        );
      },
    );
  }
}
