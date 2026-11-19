/// A user-made album: a named list of cards (by project id).
/// Built-in brand albums are not stored, they are computed (see brand_groups.dart).
class Album {
  Album({required this.id, required this.name, List<String>? cardIds})
      : cardIds = cardIds ?? <String>[];

  factory Album.fromJson(Map<String, dynamic> json) {
    final ids = json['cardIds'];
    return Album(
      id: (json['id'] as String?) ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: (json['name'] as String?) ?? 'Album',
      cardIds: ids is List ? ids.whereType<String>().toList() : null,
    );
  }

  final String id;
  String name;
  final List<String> cardIds;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'cardIds': cardIds};
}
