import 'package:flutter/material.dart';

import '../../data/brand_groups.dart';
import '../../data/card_search.dart';
import '../../data/models/card_project.dart';
import '../../data/repositories/app_store.dart';
import '../collection/card_collection.dart';
import '../collection/collection_controller.dart';
import '../collection/selection_app_bar.dart';
import '../common/card_thumb.dart';
import '../common/country_flag_thumb.dart';
import '../common/dialogs.dart';
import '../common/search_field.dart';
import 'album_screen.dart';

/// Four tabs: built-in albums by brand and by country (made automatically),
/// the Favorites album (starred cards) and the user's own albums.
class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);
  final _brandSearch = TextEditingController();
  final _countrySearch = TextEditingController();
  final _albumSearch = TextEditingController();
  final _favorites = CollectionController();
  String _brandQuery = '';
  String _countryQuery = '';
  String _albumQuery = '';

  AppStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _brandSearch.dispose();
    _countrySearch.dispose();
    _albumSearch.dispose();
    _favorites.dispose();
    super.dispose();
  }

  Future<void> _newAlbum() async {
    final name = await promptNameDialog(
      context,
      title: 'New album',
      hint: 'Album name',
      action: 'Create',
    );
    if (name == null || !mounted) return;
    final album = await store.albums.create(name);
    if (!mounted) return;
    _tabs.animateTo(3);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AlbumScreen.custom(store, album.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([store.projects, store.albums, _favorites]),
      builder: (context, _) {
        final selecting = _favorites.selecting && _tabs.index == 2;
        return Scaffold(
          appBar: selecting
              ? selectionAppBar(
                  context,
                  store: store,
                  controller: _favorites,
                  exportName: 'Favorites',
                )
              : AppBar(
                  title: const Text('Albums'),
                  actions: [
                    if (_tabs.index == 2)
                      IconButton(
                        icon: const Icon(Icons.checklist),
                        tooltip: 'Select cards',
                        onPressed: _favoriteCards().isEmpty ? null : _favorites.startSelecting,
                      ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: 'New album',
                      onPressed: _newAlbum,
                    ),
                  ],
                  bottom: TabBar(
                    controller: _tabs,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: const [
                      Tab(text: 'By brand'),
                      Tab(text: 'By country'),
                      Tab(text: 'Favorites'),
                      Tab(text: 'My albums'),
                    ],
                  ),
                ),
          body: TabBarView(
            controller: _tabs,
            children: [
              _brandList(context),
              _countryList(context),
              CardCollection(
                store: store,
                controller: _favorites,
                cards: _favoriteCards(),
                emptyText: 'No favorites yet. Star a card in its menu.',
              ),
              _myList(context),
            ],
          ),
        );
      },
    );
  }

  List<CardProject> _favoriteCards() => [
        for (final p in store.projects.items)
          if (p.favorite) p,
      ];

  Widget _brandList(BuildContext context) {
    final all = groupByBrand(store.projects.items);
    if (all.isEmpty) {
      return const Center(child: Text('No cards yet. Albums by brand appear here.'));
    }
    final groups = all.where((g) => textMatches(g.name, _brandQuery)).toList();
    return Column(
      children: [
        SearchField(
          controller: _brandSearch,
          hint: 'Search by brand',
          onChanged: (v) => setState(() => _brandQuery = v),
        ),
        Expanded(
          child: groups.isEmpty
              ? const Center(child: Text('Nothing found.'))
              : ListView.builder(
                  itemCount: groups.length,
                  itemBuilder: (_, i) {
                    final group = groups[i];
                    return ListTile(
                      leading: _BrandAvatar(store: store, group: group),
                      title: Text(group.name),
                      subtitle: Text(_cardsText(group.cards.length)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AlbumScreen.brand(store, group.key, group.name),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _countryList(BuildContext context) {
    final all = groupByCountry(store.projects.items);
    if (all.isEmpty) {
      return const Center(child: Text('No cards yet. Albums by country appear here.'));
    }
    final groups = all.where((g) => textMatches('${g.key} ${g.name}', _countryQuery)).toList();
    return Column(
      children: [
        SearchField(
          controller: _countrySearch,
          hint: 'Search by country or code',
          onChanged: (v) => setState(() => _countryQuery = v),
        ),
        Expanded(
          child: groups.isEmpty
              ? const Center(child: Text('Nothing found.'))
              : ListView.builder(
                  itemCount: groups.length,
                  itemBuilder: (_, i) {
                    final group = groups[i];
                    return ListTile(
                      leading: group.key.isEmpty
                          ? const CircleAvatar(child: Icon(Icons.public))
                          : CountryFlagThumb(code: group.key, width: 40, height: 27),
                      title: Text(group.key.isEmpty || group.name == group.key
                          ? group.name
                          : '${group.name} (${group.key})'),
                      subtitle: Text(_cardsText(group.cards.length)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AlbumScreen.country(store, group.key, group.name),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _myList(BuildContext context) {
    final all = store.albums.items;
    if (all.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No albums yet.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _newAlbum,
              icon: const Icon(Icons.add),
              label: const Text('New album'),
            ),
          ],
        ),
      );
    }
    final albums = all.where((a) => textMatches(a.name, _albumQuery)).toList();
    final byId = {for (final p in store.projects.items) p.id: p};
    return Column(
      children: [
        SearchField(
          controller: _albumSearch,
          hint: 'Search albums by name',
          onChanged: (v) => setState(() => _albumQuery = v),
        ),
        Expanded(
          child: albums.isEmpty
              ? const Center(child: Text('Nothing found.'))
              : ListView.builder(
                  itemCount: albums.length,
                  itemBuilder: (_, i) {
                    final album = albums[i];
                    final count = album.cardIds.where(byId.containsKey).length;
                    final cover = album.coverId == null ? null : byId[album.coverId];
                    return ListTile(
                      leading: cover == null
                          ? const CircleAvatar(child: Icon(Icons.collections_bookmark_outlined))
                          : CardThumb(store: store, project: cover, height: 44),
                      title: Text(album.name),
                      subtitle: Text(_cardsText(count)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AlbumScreen.custom(store, album.id)),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

String _cardsText(int n) => n == 1 ? '1 card' : '$n cards';

/// The logo of the first card of the brand that has one, else the first letter.
class _BrandAvatar extends StatelessWidget {
  const _BrandAvatar({required this.store, required this.group});

  final AppStore store;
  final BrandGroup group;

  @override
  Widget build(BuildContext context) {
    final letter = Text(group.key.isEmpty ? '?' : group.name.substring(0, 1).toUpperCase());
    String? logoId;
    for (final c in group.cards) {
      if (c.logoId != null) {
        logoId = c.logoId;
        break;
      }
    }
    final file = store.logos.fileOf(logoId);
    return CircleAvatar(
      backgroundColor: const Color(0xFF2A2A2A),
      child: file == null
          ? letter
          : Padding(
              padding: const EdgeInsets.all(6),
              child: Image.file(
                file,
                fit: BoxFit.contain,
                cacheWidth: 96,
                errorBuilder: (_, __, ___) => letter,
              ),
            ),
    );
  }
}
