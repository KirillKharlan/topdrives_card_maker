import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/app_constants.dart';
import '../storage/json_file_store.dart';

/// User-level settings. For now: custom country codes.
class SettingsRepository extends ChangeNotifier {
  late final File _file;
  final List<String> _customCountries = [];

  List<String> get customCountries => List.unmodifiable(_customCountries);

  Future<void> init(Directory root) async {
    _file = File('${root.path}/settings.json');
    final data = await readJsonFile(_file);
    if (data is Map<String, dynamic>) {
      final list = data['customCountries'];
      if (list is List) _customCountries.addAll(list.whereType<String>());
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

  Future<void> _save() => writeJsonFile(_file, {'customCountries': _customCountries});
}
