import 'photo_transform.dart';

/// One fan-made card. Photos/logos are referenced by library id, so a project
/// survives when its photo is replaced, removed or deleted from the library.
class CardProject {
  CardProject({
    required this.id,
    this.name = 'New card',
    this.templateId = 'standard',
    this.photoId,
    this.photoTransform = PhotoTransform.identity,
    this.logoId,
    this.logoScale = 1.0,
    this.brand = 'Brand',
    this.model = 'Model',
    this.year = '2020',
    this.country = 'DE',
    this.topSpeed = '150',
    this.accel = '5.0',
    this.handling = '75',
    this.drive = 'RWD',
    this.tyre = 'Standard',
    this.carClass = 'B',
    this.rq = '50',
    this.prize = false,
    this.prizeText = defaultPrizeText,
    List<String>? tagAssets,
    DateTime? updatedAt,
  })  : tagAssets = tagAssets ?? <String>[],
        updatedAt = updatedAt ?? DateTime.now();

  static const defaultPrizeText = 'This car is only available by winning certain events.';

  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();

  factory CardProject.create() => CardProject(id: newId());

  String id;
  String name;
  String templateId;
  String? photoId;
  PhotoTransform photoTransform;
  String? logoId;

  /// Logo size inside its slot on the card (1.0 = fit the slot).
  double logoScale;
  String brand;
  String model;
  String year;
  String country;
  String topSpeed;
  String accel;
  String handling;
  String drive;
  String tyre;
  String carClass;
  String rq;
  bool prize;
  String prizeText;
  /// Series tags shown above the card, left to right.
  List<String> tagAssets;
  DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'templateId': templateId,
        'photoId': photoId,
        'photoTransform': photoTransform.toJson(),
        'logoId': logoId,
        'logoScale': logoScale,
        'brand': brand,
        'model': model,
        'year': year,
        'country': country,
        'topSpeed': topSpeed,
        'accel': accel,
        'handling': handling,
        'drive': drive,
        'tyre': tyre,
        'carClass': carClass,
        'rq': rq,
        'prize': prize,
        'prizeText': prizeText,
        'tagAssets': tagAssets,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory CardProject.fromJson(Map<String, dynamic> j) {
    String s(String key, String fallback) => (j[key] as String?) ?? fallback;
    final tags = <String>[];
    final rawTags = j['tagAssets'];
    if (rawTags is List) {
      tags.addAll(rawTags.whereType<String>());
    } else if (j['tagAsset'] is String) {
      tags.add(j['tagAsset'] as String); // projects saved by older versions
    }
    return CardProject(
      id: j['id'] as String,
      name: s('name', 'New card'),
      templateId: s('templateId', 'standard'),
      photoId: j['photoId'] as String?,
      photoTransform: PhotoTransform.fromJson(j['photoTransform'] as Map<String, dynamic>?),
      logoId: j['logoId'] as String?,
      logoScale: (j['logoScale'] as num?)?.toDouble() ?? 1.0,
      brand: s('brand', ''),
      model: s('model', ''),
      year: s('year', ''),
      country: s('country', ''),
      topSpeed: s('topSpeed', ''),
      accel: s('accel', ''),
      handling: s('handling', ''),
      drive: s('drive', 'RWD'),
      tyre: s('tyre', 'Standard'),
      carClass: s('carClass', 'B'),
      rq: s('rq', ''),
      prize: (j['prize'] as bool?) ?? false,
      prizeText: s('prizeText', defaultPrizeText),
      tagAssets: tags,
      updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? ''),
    );
  }
}
