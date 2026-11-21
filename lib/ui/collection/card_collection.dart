import 'package:flutter/material.dart';

import '../../data/iso_countries.dart';
import '../../data/models/card_project.dart';
import '../../data/repositories/app_store.dart';
import '../common/search_field.dart';
import '../home/project_tile.dart';
import 'collection_controller.dart';

/// Search box, sort and filter chips and the grid of cards. The cards come from
/// the parent ([cards]); everything the user picks lives in [controller], so the
/// parent can build its app bar (multi-select) from the same controller.
class CardCollection extends StatefulWidget {
  const CardCollection({
    super.key,
    required this.store,
    required this.controller,
    required this.cards,
    this.emptyText = 'No cards here yet.',
    this.albumId,
    this.bottomPadding = 12,
  });

  final AppStore store;
  final CollectionController controller;
  final List<CardProject> cards;
  final String emptyText;

  /// Set inside a user's album: cards get Remove from album and Set as cover.
  final String? albumId;
  final double bottomPadding;

  @override
  State<CardCollection> createState() => _CardCollectionState();
}

class _CardCollectionState extends State<CardCollection> {
  final _search = TextEditingController();

  CollectionController get c => widget.controller;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final shown = c.apply(widget.cards);
        c.visibleIds = [for (final p in shown) p.id];
        // Cards that are gone (deleted) can not stay selected.
        final present = {for (final p in widget.cards) p.id};
        c.selected.removeWhere((id) => !present.contains(id));
        return Column(
          children: [
            SearchField(
              controller: _search,
              hint: 'Search by brand, model or name',
              onChanged: c.setQuery,
            ),
            if (widget.cards.isNotEmpty) _FilterBar(controller: c, cards: widget.cards),
            Expanded(
              child: shown.isEmpty
                  ? Center(
                      child: Text(widget.cards.isEmpty ? widget.emptyText : 'Nothing found.'),
                    )
                  : GridView.builder(
                      padding: EdgeInsets.fromLTRB(12, 8, 12, widget.bottomPadding),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.3,
                      ),
                      itemCount: shown.length,
                      itemBuilder: (_, i) {
                        final card = shown[i];
                        final albumId = widget.albumId;
                        return ProjectTile(
                          key: ValueKey(card.id),
                          store: widget.store,
                          project: card,
                          selected: c.selected.contains(card.id),
                          onTap: c.selecting ? () => c.toggle(card.id) : null,
                          onStartSelect: () {
                            c.startSelecting();
                            c.toggle(card.id);
                          },
                          onRemoveFromAlbum: albumId == null
                              ? null
                              : () => widget.store.albums.removeCard(albumId, card.id),
                          onSetCover: albumId == null
                              ? null
                              : () => widget.store.albums.setCover(albumId, card.id),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// One scrolling row: order, class, country, favorites only, clear.
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.controller, required this.cards});

  final CollectionController controller;
  final List<CardProject> cards;

  static const _any = '*';

  Widget _chip(
    BuildContext context, {
    required String label,
    required bool active,
    IconData? icon,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      avatar: icon == null ? null : Icon(icon, size: 18),
      label: Text(label),
      visualDensity: VisualDensity.compact,
      backgroundColor: active ? scheme.primaryContainer : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final classes = {
      for (final p in cards)
        if (p.carClass.isNotEmpty) p.carClass,
    }.toList()
      ..sort();
    final countries = {
      for (final p in cards)
        if (p.country.trim().isNotEmpty) p.country.trim().toUpperCase(),
    }.toList()
      ..sort((a, b) => (IsoCountries.nameOf(a) ?? a).compareTo(IsoCountries.nameOf(b) ?? b));
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          PopupMenuButton<CardSort>(
            tooltip: 'Order',
            onSelected: c.setSort,
            itemBuilder: (_) => [
              for (final s in CardSort.values)
                CheckedPopupMenuItem(value: s, checked: s == c.sort, child: Text(s.label)),
            ],
            child: _chip(
              context,
              label: c.sort == CardSort.standard ? 'Order' : c.sort.label,
              active: c.sort != CardSort.standard,
              icon: Icons.sort,
            ),
          ),
          const SizedBox(width: 8),
          if (classes.isNotEmpty) ...[
            PopupMenuButton<String>(
              tooltip: 'Class',
              onSelected: (v) => c.setClass(v == _any ? '' : v),
              itemBuilder: (_) => [
                const PopupMenuItem(value: _any, child: Text('Any class')),
                for (final k in classes) PopupMenuItem(value: k, child: Text('Class $k')),
              ],
              child: _chip(
                context,
                label: c.carClass.isEmpty ? 'Class' : 'Class ${c.carClass}',
                active: c.carClass.isNotEmpty,
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (countries.isNotEmpty) ...[
            PopupMenuButton<String>(
              tooltip: 'Country',
              onSelected: (v) => c.setCountry(v == _any ? '' : v),
              itemBuilder: (_) => [
                const PopupMenuItem(value: _any, child: Text('Any country')),
                for (final k in countries)
                  PopupMenuItem(value: k, child: Text('$k  ${IsoCountries.nameOf(k) ?? ''}'.trim())),
              ],
              child: _chip(
                context,
                label: c.country.isEmpty ? 'Country' : c.country,
                active: c.country.isNotEmpty,
              ),
            ),
            const SizedBox(width: 8),
          ],
          FilterChip(
            avatar: const Icon(Icons.star, size: 18),
            label: const Text('Favorites'),
            visualDensity: VisualDensity.compact,
            selected: c.favoritesOnly,
            onSelected: c.setFavoritesOnly,
          ),
          if (c.hasFilter) ...[
            const SizedBox(width: 8),
            ActionChip(
              avatar: const Icon(Icons.close, size: 18),
              label: const Text('Clear filters'),
              visualDensity: VisualDensity.compact,
              onPressed: c.clearFilters,
            ),
          ],
        ],
      ),
    );
  }
}
