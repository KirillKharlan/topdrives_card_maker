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
    this.tagAsset,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();

  factory CardProject.create() => CardProject(id: newId());

  String id;
  String name;
  String templateId;
  String? photoId;
  PhotoTransform photoTransform;
  String? logoId;
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
  String? tagAsset;
  DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'templateId': templateId,
        'photoId': photoId,
        'photoTransform': photoTransform.toJson(),
        'logoId': logoId,
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
        'tagAsset': tagAsset,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory CardProject.fromJson(Map<String, dynamic> j) {
    String s(String key, String fallback) => (j[key] as String?) ?? fallback;
    return CardProject(
      id: j['id'] as String,
      name: s('name', 'New card'),
      templateId: s('templateId', 'standard'),
      photoId: j['photoId'] as String?,
      photoTransform: PhotoTransform.fromJson(j['photoTransform'] as Map<String, dynamic>?),
      logoId: j['logoId'] as String?,
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
      tagAsset: j['tagAsset'] as String?,
      updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? ''),
    );
  }
}
