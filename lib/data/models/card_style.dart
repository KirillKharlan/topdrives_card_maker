/// Which look a card follows. It changes only sizes and positions, never what
/// is shown: the size of the brand and model text and where the prize marker
/// sits. A long model name is fitted (shrunk or wrapped) the same way in both.
/// The numbers for each look live in assets/templates/standard.json
/// (`titleStyles` and `prizeStyles`).
enum CardStyle {
  /// Text sizes and prize marker position of fan-made cards.
  fan('Fan-made', 'Larger title text and the prize marker like on fan-made cards.'),

  /// Text sizes and prize marker position of the game itself.
  game('Game (official)', 'Smaller title text and the prize marker placed as in the game.');

  const CardStyle(this.label, this.hint);

  final String label;
  final String hint;
}

CardStyle parseCardStyle(String? name) => CardStyle.values.firstWhere(
      (s) => s.name == name,
      orElse: () => CardStyle.fan,
    );
