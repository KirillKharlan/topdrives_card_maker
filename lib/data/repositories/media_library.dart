import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../models/media_item.dart';
import '../storage/json_file_store.dart';

/// A folder of user images (car photos or logos) with a small JSON index.
/// Originals are stored untouched; cropping lives in the card project.
class MediaLibrary extends ChangeNotifier {
  MediaLibrary(this.folderName);

  final String folderName;
  late final Directory _dir;
  late final File _index;
  final List<MediaItem> _items = [];

  List<MediaItem> get items => List.unmodifiable(_items);

  Future<void> init(Directory root) async {
    _dir = Directory('${root.path}/$folderName');
    await _dir.create(recursive: true);
    _index = File('${_dir.path}/index.json');
    final data = await readJsonFile(_index);
    if (data is List) {
      for (final e in data) {
        try {
          _items.add(MediaItem.fromJson(e as Map<String, dynamic>));
        } catch (_) {}
      }
    }
    _items.removeWhere((i) => !File('${_dir.path}/${i.fileName}').existsSync());
  }

  File? fileOf(String? id) {
    if (id == null) return null;
    for (final item in _items) {
      if (item.id == id) return File('${_dir.path}/${item.fileName}');
    }
    return null;
  }

  Future<MediaItem> addFromPath(String sourcePath) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final dot = sourcePath.lastIndexOf('.');
    final ext = (dot >= 0 && sourcePath.length - dot <= 5)
        ? sourcePath.substring(dot).toLowerCase()
        : '.jpg';
    final fileName = '$id$ext';
    await File(sourcePath).copy('${_dir.path}/$fileName');
    final item = MediaItem(id: id, fileName: fileName, addedAt: DateTime.now());
    _items.insert(0, item);
    await _save();
    notifyListeners();
    return item;
  }

  /// Stores already-processed image bytes (e.g. a logo with the background removed).
  Future<MediaItem> addFromBytes(Uint8List bytes, {String ext = '.png'}) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final fileName = '$id$ext';
    await File('${_dir.path}/$fileName').writeAsBytes(bytes, flush: true);
    final item = MediaItem(id: id, fileName: fileName, addedAt: DateTime.now());
    _items.insert(0, item);
    await _save();
    notifyListeners();
    return item;
  }

  Future<void> delete(String id) async {
    final file = fileOf(id);
    _items.removeWhere((i) => i.id == id);
    if (file != null && await file.exists()) await file.delete();
    await _save();
    notifyListeners();
  }

  Future<void> _save() => writeJsonFile(_index, _items.map((i) => i.toJson()).toList());
}
