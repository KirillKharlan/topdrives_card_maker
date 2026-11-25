import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'models/card_project.dart';

/// One car in an export: the picture and the card's data.
class PhysicsItem {
  PhysicsItem({required this.project, required this.png});

  final CardProject project;
  final Uint8List png;
}

/// The ZIP with the cards and their physics numbers, for the fan builds of the game.
/// One picture and one json per car (same name), plus cars.json (all cars in one list)
/// when there is more than one.
class PhysicsExport {
  PhysicsExport._();

  /// The card's own data and the typed-in physics numbers of one car.
  static Map<String, dynamic> carOf(CardProject p) => {
        'card': {
          'name': p.name,
          'brand': p.brand,
          'model': p.model,
          'year': p.year,
          'country': p.country,
          'class': p.carClass,
          'rq': p.rq,
          'topSpeed': p.topSpeed,
          'zero60': p.accel,
          'weight': p.weight,
          'grip': p.handling,
          'drive': p.drive,
          'tyre': p.tyre,
        },
        'physics': p.physics.toExport(),
      };

  static const _encoder = JsonEncoder.withIndent('  ');

  static String jsonOf(CardProject p) => _encoder.convert(carOf(p));

  static String _safe(String text) => text.replaceAll(RegExp(r'[^\w\-]+'), '_');

  /// A file name for the car: brand and model, else the name of the card.
  static String baseName(CardProject p) {
    final title = '${p.brand} ${p.model}'.trim();
    final safe = _safe(title.isEmpty ? p.name : title).replaceAll(RegExp(r'_+'), '_');
    return safe.isEmpty || safe == '_' ? 'card' : safe;
  }

  /// The names of the cars in the zip: the same car twice becomes name, name_2, ...
  static List<String> names(List<CardProject> cars) {
    final used = <String, int>{};
    return [
      for (final p in cars)
        () {
          final base = baseName(p);
          final n = (used[base] ?? 0) + 1;
          used[base] = n;
          return n == 1 ? base : '${base}_$n';
        }(),
    ];
  }

  static List<int> zip(List<PhysicsItem> items) {
    final archive = Archive();
    final base = names([for (final i in items) i.project]);
    void add(String name, List<int> bytes) =>
        archive.addFile(ArchiveFile(name, bytes.length, bytes));
    for (var i = 0; i < items.length; i++) {
      add('${base[i]}.png', items[i].png);
      add('${base[i]}.json', utf8.encode(jsonOf(items[i].project)));
    }
    if (items.length > 1) {
      final all = [
        for (var i = 0; i < items.length; i++) {'file': base[i], ...carOf(items[i].project)},
      ];
      add('cars.json', utf8.encode(_encoder.convert(all)));
    }
    final bytes = ZipEncoder().encode(archive);
    if (bytes == null) throw StateError('could not pack the zip');
    return bytes;
  }
}
