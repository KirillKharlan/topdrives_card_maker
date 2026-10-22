import 'package:flutter/services.dart';

/// Ready-made series tags bundled in assets/tags/.
class TagCatalog {
  TagCatalog._();

  static List<String>? _cache;

  static Future<List<String>> list() async {
    if (_cache != null) return _cache!;
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final tags = manifest
        .listAssets()
        .where((p) => p.startsWith('assets/tags/') && p.endsWith('.png'))
        .toList()
      ..sort();
    return _cache = tags;
  }

  static String nameOf(String path) => path.split('/').last.replaceAll('.png', '');
}
