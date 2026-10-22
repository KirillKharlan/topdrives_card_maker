/// An image stored in the app library (car photo or brand logo).
class MediaItem {
  const MediaItem({required this.id, required this.fileName, required this.addedAt});

  final String id;
  final String fileName;
  final DateTime addedAt;

  Map<String, dynamic> toJson() =>
      {'id': id, 'fileName': fileName, 'addedAt': addedAt.toIso8601String()};

  factory MediaItem.fromJson(Map<String, dynamic> j) => MediaItem(
        id: j['id'] as String,
        fileName: j['fileName'] as String,
        addedAt: DateTime.tryParse(j['addedAt'] as String? ?? '') ?? DateTime.now(),
      );
}
