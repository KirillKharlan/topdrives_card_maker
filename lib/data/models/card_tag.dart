/// A tag above the card: either a ready-made picture from assets/tags/
/// ([asset]) or a custom one built from [text] and a border colour.
class CardTag {
  const CardTag({this.asset, this.text, this.colorValue});

  final String? asset;
  final String? text;

  /// ARGB colour of the border (the fill is derived from it).
  final int? colorValue;

  bool get isCustom => asset == null;

  @override
  bool operator ==(Object other) =>
      other is CardTag &&
      other.asset == asset &&
      other.text == text &&
      other.colorValue == colorValue;

  @override
  int get hashCode => Object.hash(asset, text, colorValue);

  CardTag copyWith({String? text, int? colorValue}) =>
      CardTag(text: text ?? this.text, colorValue: colorValue ?? this.colorValue);

  Map<String, dynamic> toJson() =>
      isCustom ? {'text': text, 'color': colorValue} : {'asset': asset};

  factory CardTag.fromJson(Map<String, dynamic> j) {
    final asset = j['asset'];
    if (asset is String) return CardTag(asset: asset);
    return CardTag(
      text: (j['text'] as String?) ?? '',
      colorValue: (j['color'] as num?)?.toInt() ?? 0xFFF2C21B,
    );
  }
}
