import 'package:flutter/foundation.dart';

import '../../data/card_search.dart';
import '../../data/models/card_project.dart';

/// How a list of cards is ordered. [standard] keeps the order the list
/// already has (newest first on the home screen, album order in an album).
enum CardSort {
  standard('Default order'),
  oldest('Oldest first'),
  brand('Brand A-Z'),
  rq('RQ high to low');

  const CardSort(this.label);

  final String label;
}

/// Search text, order, filters and the multi-select state of one card list
/// (the home screen, an album, the Favorites tab).
class CollectionController extends ChangeNotifier {
  String query = '';
  CardSort sort = CardSort.standard;

  /// Empty = any.
  String carClass = '';
  String country = '';
  bool favoritesOnly = false;

  bool selecting = false;
  final Set<String> selected = <String>{};

  /// The cards on screen right now (after search and filters); set by the list.
  List<String> visibleIds = const [];

  bool get hasFilter => carClass.isNotEmpty || country.isNotEmpty || favoritesOnly;

  void setQuery(String value) {
    query = value;
    notifyListeners();
  }

  void setSort(CardSort value) {
    sort = value;
    notifyListeners();
  }

  void setClass(String value) {
    carClass = value;
    notifyListeners();
  }

  void setCountry(String value) {
    country = value;
    notifyListeners();
  }

  void setFavoritesOnly(bool value) {
    favoritesOnly = value;
    notifyListeners();
  }

  void clearFilters() {
    carClass = '';
    country = '';
    favoritesOnly = false;
    notifyListeners();
  }

  void startSelecting() {
    selecting = true;
    notifyListeners();
  }

  void stopSelecting() {
    selecting = false;
    selected.clear();
    notifyListeners();
  }

  void toggle(String id) {
    if (!selected.remove(id)) selected.add(id);
    notifyListeners();
  }

  void selectAll(Iterable<String> ids) {
    selected
      ..clear()
      ..addAll(ids);
    notifyListeners();
  }

  /// Search, filters and order applied to [items].
  List<CardProject> apply(List<CardProject> items) {
    final list = items.where((p) {
      if (!cardMatches(p, query)) return false;
      if (carClass.isNotEmpty && p.carClass != carClass) return false;
      if (country.isNotEmpty && p.country.trim().toUpperCase() != country) return false;
      if (favoritesOnly && !p.favorite) return false;
      return true;
    }).toList();
    switch (sort) {
      case CardSort.standard:
        break;
      case CardSort.oldest:
        list.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
      case CardSort.brand:
        list.sort((a, b) {
          final ab = a.brand.trim().toLowerCase();
          final bb = b.brand.trim().toLowerCase();
          if (ab.isEmpty != bb.isEmpty) return ab.isEmpty ? 1 : -1;
          final byBrand = ab.compareTo(bb);
          return byBrand != 0
              ? byBrand
              : a.model.trim().toLowerCase().compareTo(b.model.trim().toLowerCase());
        });
      case CardSort.rq:
        list.sort((a, b) {
          final byRq = rqOf(b).compareTo(rqOf(a));
          return byRq != 0 ? byRq : b.updatedAt.compareTo(a.updatedAt);
        });
    }
    return list;
  }

  /// The RQ number of a card; a card without a number counts as -1 (goes last).
  static int rqOf(CardProject p) => int.tryParse(p.rq.trim()) ?? -1;
}
