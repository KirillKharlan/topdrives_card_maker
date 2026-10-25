import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/app_constants.dart';
import '../models/card_tag.dart';
import '../storage/json_file_store.dart';

/// User-level settings. For now: custom country codes.
class SettingsRepository extends ChangeNotifier {
  late final File _file;
  final List<String> _customCountries = [];
  final List<CardTag> _customTags = [];

  List<String> get customCountries => List.unmodifiable(_customCountries);

  /// Tags the user built; offered in the tag picker next to the ready-made ones.
  List<CardTag> get customTags => List.unmodifiable(_customTags);

  Future<void> init(Directory root) async {
    _file = File('${root.path}/settings.json');
    final data = await readJsonFile(_file);
    if (data is Map<String, dynamic>) {
      final list = data['customCountries'];
      if (list is List) _customCountries.addAll(list.whereType<String>());
      final tags = data['customTags'];
      if (tags is List) {
        for (final e in tags) {
          if (e is Map<String, dynamic>) _customTags.add(CardTag.fromJson(e));
        }
      }
    }
  }

  Future<void> addCountry(String raw) async {
    final code = raw.trim().toUpperCase();
    if (code.isEmpty ||
        AppConstants.builtInCountries.contains(code) ||
        _customCountries.contains(code)) {
      return;
    }
    _customCountries.add(code);
    await _save();
    notifyListeners();
  }

  Future<void> removeCountry(String code) async {
    _customCountries.remove(code);
    await _save();
    notifyListeners();
  }

  Future<void> addCustomTag(CardTag tag) async {
    if (!tag.isCustom || _customTags.contains(tag)) return;
    _customTags.add(tag);
    await _save();
    notifyListeners();
  }

  Future<void> updateCustomTag(CardTag old, CardTag next) async {
    final index = _customTags.indexOf(old);
    if (index < 0) {
      await addCustomTag(next);
      return;
    }
    _customTags[index] = next;
    await _save();
    notifyListeners();
  }

  Future<void> removeCustomTag(CardTag tag) async {
    _customTags.remove(tag);
    await _save();
    notifyListeners();
  }

  Future<void> _save() => writeJsonFile(_file, {
        'customCountries': _customCountries,
        'customTags': _customTags.map((t) => t.toJson()).toList(),
      });
}
