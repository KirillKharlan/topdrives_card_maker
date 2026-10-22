import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/card_project.dart';
import '../models/photo_transform.dart';
import '../storage/json_file_store.dart';

/// Stores every card project as its own JSON file.
class ProjectRepository extends ChangeNotifier {
  late final Directory _dir;
  final List<CardProject> _items = [];

  List<CardProject> get items => List.unmodifiable(_items);

  Future<void> init(Directory root) async {
    _dir = Directory('${root.path}/projects');
    await _dir.create(recursive: true);
    for (final entity in _dir.listSync()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final json = jsonDecode(await entity.readAsString()) as Map<String, dynamic>;
        _items.add(CardProject.fromJson(json));
      } catch (_) {}
    }
    _sort();
  }

  File _fileOf(String id) => File('${_dir.path}/$id.json');

  void _sort() => _items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  /// [notify] = false is used by autosave so the home grid is not rebuilt
  /// while the editor is open.
  Future<void> save(CardProject project, {bool notify = true}) async {
    await writeJsonFile(_fileOf(project.id), project.toJson());
    if (!_items.any((p) => p.id == project.id)) _items.add(project);
    _sort();
    if (notify) notifyListeners();
  }

  Future<void> delete(String id) async {
    _items.removeWhere((p) => p.id == id);
    final file = _fileOf(id);
    if (await file.exists()) await file.delete();
    notifyListeners();
  }

  Future<void> duplicate(CardProject source) async {
    final copy = CardProject.fromJson(source.toJson())
      ..id = CardProject.newId()
      ..name = '${source.name} copy'
      ..updatedAt = DateTime.now();
    await save(copy);
  }

  int countUsingPhoto(String photoId) => _items.where((p) => p.photoId == photoId).length;

  int countUsingLogo(String logoId) => _items.where((p) => p.logoId == logoId).length;

  /// Called before a photo is deleted from the library: the cards stay, the
  /// photo slot just becomes empty.
  Future<void> detachPhoto(String photoId) async {
    for (final p in _items.where((p) => p.photoId == photoId).toList()) {
      p.photoId = null;
      p.photoTransform = PhotoTransform.identity;
      await save(p, notify: false);
    }
    notifyListeners();
  }

  Future<void> detachLogo(String logoId) async {
    for (final p in _items.where((p) => p.logoId == logoId).toList()) {
      p.logoId = null;
      await save(p, notify: false);
    }
    notifyListeners();
  }
}
