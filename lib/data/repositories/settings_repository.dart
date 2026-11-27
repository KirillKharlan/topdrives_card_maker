import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/app_constants.dart';
import '../../core/layout_tweaks.dart';
import '../models/card_tag.dart';
import '../storage/json_file_store.dart';

/// User-level settings: custom country codes, drives, tyres and tags, tyre-name tuning.
class SettingsRepository extends ChangeNotifier {
  late final File _file;
  final List<String> _customCountries = [];
  final List<String> _customDrives = [];
  final List<String> _customTyres = [];
  final List<CardTag> _customTags = [];
  double _tyreNameOffset = 0;
  bool _betaMatches = false;
  String _fillEngine = 'patchmatch';

  List<String> get customCountries => List.unmodifiable(_customCountries);

  /// Drives and tyre types the user added next to the built-in ones.
  List<String> get customDrives => List.unmodifiable(_customDrives);
  List<String> get customTyres => List.unmodifiable(_customTyres);

  /// Tags the user built; offered in the tag picker next to the ready-made ones.
  List<CardTag> get customTags => List.unmodifiable(_customTags);

  /// Show "Closest in the beta game" in the editor of beta-template cards.
  /// Off until the person turns it on in the menu of the home screen.
  bool get betaMatchesEnabled => _betaMatches;

  /// How the empty areas around a photo are filled: 'patchmatch' (fast, offline) or 'lama'
  /// (neural network, needs the downloaded model).
  String get fillEngine => _fillEngine;

  Future<void> setFillEngine(String value) async {
    if (value != 'patchmatch' && value != 'lama') return;
    if (_fillEngine == value) return;
    _fillEngine = value;
    await _save();
    notifyListeners();
  }

  Future<void> setBetaMatches(bool value) async {
    if (_betaMatches == value) return;
    _betaMatches = value;
    await _save();
    notifyListeners();
  }

  Future<void> init(Directory root) async {
    _file = File('${root.path}/settings.json');
    final data = await readJsonFile(_file);
    if (data is Map<String, dynamic>) {
      final list = data['customCountries'];
      if (list is List) _customCountries.addAll(list.whereType<String>());
      final drives = data['customDrives'];
      if (drives is List) _customDrives.addAll(drives.whereType<String>());
      final tyres = data['customTyres'];
      if (tyres is List) _customTyres.addAll(tyres.whereType<String>());
      final offset = data['tyreNameOffset'];
      if (offset is num) {
        _tyreNameOffset = offset.toDouble();
        LayoutTweaks.tyreNameOffset.value = _tyreNameOffset;
      }
      final beta = data['betaMatches'];
      if (beta is bool) _betaMatches = beta;
      final engine = data['fillEngine'];
      if (engine == 'lama') _fillEngine = 'lama';
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

  /// Adds a custom drive (any short text; the card draws its first letter before "WD").
  /// Returns the stored value, or null when it is empty.
  Future<String?> addDrive(String raw) async {
    final value = raw.trim().toUpperCase();
    if (value.isEmpty) return null;
    if (!AppConstants.drives.contains(value) && !_customDrives.contains(value)) {
      _customDrives.add(value);
      await _save();
      notifyListeners();
    }
    return value;
  }

  Future<void> removeDrive(String value) async {
    _customDrives.remove(value);
    await _save();
    notifyListeners();
  }

  /// Adds a custom tyre type. Returns the stored value, or null when it is empty.
  Future<String?> addTyre(String raw) async {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final known = [...AppConstants.tyres, ..._customTyres].any((t) => t.toLowerCase() == value.toLowerCase());
    if (!known) {
      _customTyres.add(value);
      await _save();
      notifyListeners();
    }
    return value;
  }

  Future<void> removeTyre(String value) async {
    _customTyres.remove(value);
    await _save();
    notifyListeners();
  }

  double get tyreNameOffset => _tyreNameOffset;

  Future<void> setTyreNameOffset(double value) async {
    _tyreNameOffset = value;
    LayoutTweaks.tyreNameOffset.value = value;
    await _save();
  }

  Future<void> addCustomTag(CardTag tag) async {
    if (tag.asset != null || _customTags.contains(tag)) return;
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
        'customDrives': _customDrives,
        'customTyres': _customTyres,
        'customTags': _customTags.map((t) => t.toJson()).toList(),
        'tyreNameOffset': _tyreNameOffset,
        'betaMatches': _betaMatches,
        'fillEngine': _fillEngine,
      });
}
