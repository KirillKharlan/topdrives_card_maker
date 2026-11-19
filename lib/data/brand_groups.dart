import 'models/card_project.dart';

/// A built-in album: all cards with the same brand (case and spaces ignored).
class BrandGroup {
  BrandGroup({required this.key, required this.name, required this.cards});

  /// Lower-case trimmed brand; empty for cards without a brand.
  final String key;
  final String name;
  final List<CardProject> cards;
}

String brandKeyOf(CardProject p) => p.brand.trim().toLowerCase();

/// Groups [items] by brand: brands A-Z, cards without a brand last.
/// Inside a brand cards are sorted by model.
List<BrandGroup> groupByBrand(List<CardProject> items) {
  final byKey = <String, BrandGroup>{};
  for (final p in items) {
    final key = brandKeyOf(p);
    final group = byKey.putIfAbsent(
      key,
      () => BrandGroup(
        key: key,
        name: key.isEmpty ? 'No brand' : p.brand.trim(),
        cards: [],
      ),
    );
    group.cards.add(p);
  }
  for (final g in byKey.values) {
    g.cards.sort((a, b) => a.model.trim().toLowerCase().compareTo(b.model.trim().toLowerCase()));
  }
  final groups = byKey.values.toList()
    ..sort((a, b) {
      if (a.key.isEmpty != b.key.isEmpty) return a.key.isEmpty ? 1 : -1;
      return a.key.compareTo(b.key);
    });
  return groups;
}
