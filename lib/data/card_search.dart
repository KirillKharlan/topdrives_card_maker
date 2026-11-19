import 'models/card_project.dart';

/// True when every word of [query] occurs in the card's brand, model or name
/// (case ignored). An empty query matches everything.
bool cardMatches(CardProject p, String query) {
  final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.isEmpty) return true;
  final text = '${p.brand} ${p.model} ${p.name}'.toLowerCase();
  return words.every(text.contains);
}

/// True when every word of [query] occurs in [text] (case ignored).
bool textMatches(String text, String query) {
  final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  final lower = text.toLowerCase();
  return words.every(lower.contains);
}
