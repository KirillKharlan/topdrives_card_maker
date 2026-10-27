import 'card_tag.dart';
import 'photo_fill.dart';
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
    this.photoFill = PhotoFill.smart,
    this.fillFileName,
    this.fillSignature,
    this.logoId,
    this.logoScale = 1.0,
    this.logoDx = 0.0,
    this.logoDy = 0.0,
    this.titleScale = 1.0,
    this.yearScale = 1.0,
    this.tagScale = 1.0,
    this.brand = 'Brand',
    this.model = 'Model',
    this.year = '',
    this.country = 'DE',
    this.topSpeed = '',
    this.accel = '',
    this.handling = '',
    this.drive = 'RWD',
    this.tyre = 'Standard',
    this.carClass = 'B',
    this.rq = '',
    this.prize = false,
    this.prizeText = defaultPrizeText,
    List<CardTag>? tags,
    DateTime? updatedAt,
  })  : tags = tags ?? <CardTag>[],
        updatedAt = updatedAt ?? DateTime.now();

  static const defaultPrizeText = 'This car is only available by winning certain events.';

  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();

  factory CardProject.create() => CardProject(id: newId());

  String id;
  String name;
  String templateId;
  String? photoId;
  PhotoTransform photoTransform;
  PhotoFill photoFill;

  /// The generated content-aware fill and the framing it was made for.
  String? fillFileName;
  String? fillSignature;
  String? logoId;

  /// Logo size inside its slot on the card (1.0 = fit the slot).
  double logoScale;

  /// Logo shift inside its slot, as a fraction of the slot size.
  double logoDx;
  double logoDy;

  /// Per-card size multipliers (1.0 = the template's size).
  double titleScale;
  double yearScale;
  double tagScale;
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
  /// Tags shown above the card, left to right (ready-made or custom).
  List<CardTag> tags;
  DateTime updatedAt;

  /// A car whose top speed is below 60 mph never reaches 60 mph, the game
  /// then shows N/A instead of the acceleration time.
  /// Identifies the framing a content-aware fill belongs to; a fill is only
  /// used while this still matches.
  String get fillSignatureNow {
    String r(double v) => v.toStringAsFixed(4);
    final t = photoTransform;
    return '$photoId|${r(t.scale)}|${r(t.dx)}|${r(t.dy)}|${r(t.rotation)}';
  }

  bool get accelIsNotApplicable {
    final speed = double.tryParse(topSpeed.trim().replaceAll(',', '.'));
    return speed != null && speed < 60;
  }

  String get accelDisplay => accelIsNotApplicable ? 'N/A' : accel;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'templateId': templateId,
        'photoId': photoId,
        'photoTransform': photoTransform.toJson(),
        'photoFill': photoFill.name,
        'fillFileName': fillFileName,
        'fillSignature': fillSignature,
        'logoId': logoId,
        'logoScale': logoScale,
        'logoDx': logoDx,
        'logoDy': logoDy,
        'titleScale': titleScale,
        'yearScale': yearScale,
        'tagScale': tagScale,
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
        'tags': tags.map((t) => t.toJson()).toList(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory CardProject.fromJson(Map<String, dynamic> j) {
    String s(String key, String fallback) => (j[key] as String?) ?? fallback;
    final tags = <CardTag>[];
    final rawTags = j['tags'];
    final legacyList = j['tagAssets']; // saved by older versions
    if (rawTags is List) {
      for (final e in rawTags) {
        if (e is Map<String, dynamic>) tags.add(CardTag.fromJson(e));
      }
    } else if (legacyList is List) {
      tags.addAll(legacyList.whereType<String>().map((p) => CardTag(asset: p)));
    } else if (j['tagAsset'] is String) {
      tags.add(CardTag(asset: j['tagAsset'] as String));
    }
    return CardProject(
      id: j['id'] as String,
      name: s('name', 'New card'),
      templateId: s('templateId', 'standard'),
      photoId: j['photoId'] as String?,
      photoTransform: PhotoTransform.fromJson(j['photoTransform'] as Map<String, dynamic>?),
      photoFill: parsePhotoFill(j['photoFill'] as String?),
      fillFileName: j['fillFileName'] as String?,
      fillSignature: j['fillSignature'] as String?,
      logoId: j['logoId'] as String?,
      logoScale: (j['logoScale'] as num?)?.toDouble() ?? 1.0,
      logoDx: (j['logoDx'] as num?)?.toDouble() ?? 0.0,
      logoDy: (j['logoDy'] as num?)?.toDouble() ?? 0.0,
      titleScale: (j['titleScale'] as num?)?.toDouble() ?? 1.0,
      yearScale: (j['yearScale'] as num?)?.toDouble() ?? 1.0,
      tagScale: (j['tagScale'] as num?)?.toDouble() ?? 1.0,
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
      tags: tags,
      updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? ''),
    );
  }
}
