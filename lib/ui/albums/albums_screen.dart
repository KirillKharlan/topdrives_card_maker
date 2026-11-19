import 'package:flutter/material.dart';

import '../../data/brand_groups.dart';
import '../../data/repositories/app_store.dart';
import '../common/dialogs.dart';
import 'album_screen.dart';

/// Two tabs: built-in albums (one per brand, made automatically) and the
/// user's own albums.
class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  AppStore get store => widget.store;

  @override
  void dispose() {
    _tabs.dispose();
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
    _tabs.animateTo(1);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AlbumScreen.custom(store, album.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([store.projects, store.albums]),
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Albums'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'New album',
              onPressed: _newAlbum,
            ),
          ],
          bottom: TabBar(
            controller: _tabs,
            tabs: const [Tab(text: 'By brand'), Tab(text: 'My albums')],
          ),
        ),
        body: TabBarView(
          controller: _tabs,
          children: [_brandList(context), _myList(context)],
        ),
      ),
    );
  }

  Widget _brandList(BuildContext context) {
    final groups = groupByBrand(store.projects.items);
    if (groups.isEmpty) {
      return const Center(child: Text('No cards yet. Albums by brand appear here.'));
    }
    return ListView.builder(
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
    );
  }

  Widget _myList(BuildContext context) {
    final albums = store.albums.items;
    if (albums.isEmpty) {
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
    final existing = {for (final p in store.projects.items) p.id};
    return ListView.builder(
      itemCount: albums.length,
      itemBuilder: (_, i) {
        final album = albums[i];
        final count = album.cardIds.where(existing.contains).length;
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.collections_bookmark_outlined)),
          title: Text(album.name),
          subtitle: Text(_cardsText(count)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AlbumScreen.custom(store, album.id)),
          ),
        );
      },
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
