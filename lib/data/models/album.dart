/// A user-made album: a named list of cards (by project id).
/// Built-in albums (by brand, by country, favorites) are not stored, they are computed.
class Album {
  Album({required this.id, required this.name, List<String>? cardIds, this.coverId})
      : cardIds = cardIds ?? <String>[];

  factory Album.fromJson(Map<String, dynamic> json) {
    final ids = json['cardIds'];
    return Album(
      id: (json['id'] as String?) ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: (json['name'] as String?) ?? 'Album',
      cardIds: ids is List ? ids.whereType<String>().toList() : null,
      coverId: json['coverId'] as String?,
    );
  }

  final String id;
  String name;
  final List<String> cardIds;

  /// The card whose picture stands for the album in the list (must be in [cardIds]).
  String? coverId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'cardIds': cardIds,
        if (coverId != null) 'coverId': coverId,
      };
}
