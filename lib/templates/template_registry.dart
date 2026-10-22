import 'dart:convert';

import 'package:flutter/services.dart';

import 'template_spec.dart';

/// Lists the bundled templates. To add one: drop <id>.json into
/// assets/templates/ and add the id here.
class TemplateRegistry {
  TemplateRegistry._();

  static const _ids = ['standard'];

  static Future<Map<String, TemplateSpec>> loadAll() async {
    final result = <String, TemplateSpec>{};
    for (final id in _ids) {
      final raw = await rootBundle.loadString('assets/templates/$id.json');
      result[id] = TemplateSpec.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }
    return result;
  }
}
