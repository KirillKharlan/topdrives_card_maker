/// A tag above the card: a ready-made picture from assets/tags/ ([asset]), a picture the
/// user made a tag from ([image]; [text] is its name) or a custom one built from [text]
/// and a border colour.
class CardTag {
  const CardTag({this.asset, this.text, this.colorValue, this.image});

  final String? asset;
  final String? text;

  /// File name of the picture in the app's `tag_images` folder (a tag made from a photo).
  final String? image;

  /// ARGB colour of the border (the fill is derived from it).
  final int? colorValue;

  /// Built in code from text and a colour.
  bool get isCustom => asset == null && image == null;

  /// Made from a picture of the phone.
  bool get isImage => image != null;

  @override
  bool operator ==(Object other) =>
      other is CardTag &&
      other.asset == asset &&
      other.image == image &&
      other.text == text &&
      other.colorValue == colorValue;

  @override
  int get hashCode => Object.hash(asset, image, text, colorValue);

  CardTag copyWith({String? text, int? colorValue}) =>
      CardTag(text: text ?? this.text, colorValue: colorValue ?? this.colorValue);

  /// The same tag made from a picture, under a new name.
  CardTag renamed(String name) => CardTag(image: image, text: name);

  Map<String, dynamic> toJson() {
    if (isImage) return {'image': image, 'text': text};
    return isCustom ? {'text': text, 'color': colorValue} : {'asset': asset};
  }

  factory CardTag.fromJson(Map<String, dynamic> j) {
    final asset = j['asset'];
    if (asset is String) return CardTag(asset: asset);
    final image = j['image'];
    if (image is String) return CardTag(image: image, text: (j['text'] as String?) ?? '');
    return CardTag(
      text: (j['text'] as String?) ?? '',
      colorValue: (j['color'] as num?)?.toInt() ?? 0xFFF2C21B,
    );
  }
}
