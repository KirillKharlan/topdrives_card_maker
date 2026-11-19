import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/album.dart';
import '../storage/json_file_store.dart';

/// Stores the user's own albums in albums.json.
class AlbumRepository extends ChangeNotifier {
  late final File _file;
  final List<Album> _items = [];

  List<Album> get items => List.unmodifiable(_items);

  Future<void> init(Directory root) async {
    _file = File('${root.path}/albums.json');
    final data = await readJsonFile(_file);
    if (data is Map<String, dynamic>) {
      final list = data['albums'];
      if (list is List) {
        for (final e in list) {
          if (e is Map<String, dynamic>) _items.add(Album.fromJson(e));
        }
      }
    }
  }

  Album? byId(String id) {
    for (final a in _items) {
      if (a.id == id) return a;
    }
    return null;
  }

  Future<Album> create(String name) async {
    final album = Album(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim().isEmpty ? 'Album' : name.trim(),
    );
    _items.add(album);
    await _save();
    notifyListeners();
    return album;
  }

  Future<void> rename(String id, String name) async {
    final album = byId(id);
    final value = name.trim();
    if (album == null || value.isEmpty) return;
    album.name = value;
    await _save();
    notifyListeners();
  }

  Future<void> delete(String id) async {
    _items.removeWhere((a) => a.id == id);
    await _save();
    notifyListeners();
  }

  /// Adds the card when it is not in the album, removes it when it is.
  Future<void> toggleCard(String albumId, String cardId) async {
    final album = byId(albumId);
    if (album == null) return;
    if (!album.cardIds.remove(cardId)) album.cardIds.add(cardId);
    await _save();
    notifyListeners();
  }

  Future<void> removeCard(String albumId, String cardId) async {
    final album = byId(albumId);
    if (album == null) return;
    album.cardIds.remove(cardId);
    await _save();
    notifyListeners();
  }

  /// Replaces the album's content with [ids]; cards that stay keep their order,
  /// new ones go to the end.
  Future<void> setCards(String albumId, Iterable<String> ids) async {
    final album = byId(albumId);
    if (album == null) return;
    final wanted = ids.toSet();
    final next = album.cardIds.where(wanted.contains).toList();
    for (final id in ids) {
      if (!next.contains(id)) next.add(id);
    }
    album.cardIds
      ..clear()
      ..addAll(next);
    await _save();
    notifyListeners();
  }

  /// Called when a card is deleted.
  Future<void> removeCardEverywhere(String cardId) async {
    var changed = false;
    for (final a in _items) {
      if (a.cardIds.remove(cardId)) changed = true;
    }
    if (!changed) return;
    await _save();
    notifyListeners();
  }

  Future<void> _save() => writeJsonFile(_file, {
        'albums': _items.map((a) => a.toJson()).toList(),
      });
}
