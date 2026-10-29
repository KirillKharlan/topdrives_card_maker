import 'card_style.dart';
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
    this.videoId,
    this.videoStartMs = 0,
    this.videoLengthMs = defaultVideoLengthMs,
    this.videoDurationMs = 0,
    this.videoPosterMs = 0,
    this.fillFileName,
    this.fillSignature,
    this.logoId,
    this.logoScale = 1.0,
    this.logoDx = 0.0,
    this.logoDy = 0.0,
    this.brandScale = 1.0,
    this.modelScale = 1.0,
    this.cardStyle = CardStyle.fan,
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

  /// Longest clip of a video card and the one chosen for a new video.
  static const maxVideoLengthMs = 10000;
  static const defaultVideoLengthMs = 6000;
  static const minVideoLengthMs = 1000;

  static const defaultPrizeText = 'This car is only available by winning certain events.';

  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();

  factory CardProject.create() => CardProject(id: newId());

  String id;
  String name;
  String templateId;
  String? photoId;
  PhotoTransform photoTransform;
  PhotoFill photoFill;

  /// A video card: the video takes the place of the photo ([photoId] is then
  /// null) and is framed with the same [photoTransform]. [videoStartMs] and
  /// [videoLengthMs] are the clip, [videoDurationMs] the whole video, and
  /// [videoPosterMs] the time of the still frame that stands in for the photo
  /// (previews, the home grid, exported pictures).
  String? videoId;
  int videoStartMs;
  int videoLengthMs;
  int videoDurationMs;
  int videoPosterMs;

  bool get hasVideo => videoId != null;

  /// A photo or a video is chosen.
  bool get hasMedia => photoId != null || videoId != null;

  /// The generated content-aware fill and the framing it was made for.
  String? fillFileName;
  String? fillSignature;
  String? logoId;

  /// Logo size inside its slot on the card (1.0 = fit the slot).
  double logoScale;

  /// Logo shift inside its slot, as a fraction of the slot size.
  double logoDx;
  double logoDy;

  /// Per-card size multipliers (1.0 = the template's size). [brandScale] is the
  /// exact brand size; [modelScale] is the largest size the model may have, a long
  /// model is shrunk (or wrapped, in the game style) to fit.
  double brandScale;
  double modelScale;
  double yearScale;
  double tagScale;

  /// Fan-made or official (game) look of the title.
  CardStyle cardStyle;
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
        'videoId': videoId,
        'videoStartMs': videoStartMs,
        'videoLengthMs': videoLengthMs,
        'videoDurationMs': videoDurationMs,
        'videoPosterMs': videoPosterMs,
        'fillFileName': fillFileName,
        'fillSignature': fillSignature,
        'logoId': logoId,
        'logoScale': logoScale,
        'logoDx': logoDx,
        'logoDy': logoDy,
        'brandScale': brandScale,
        'modelScale': modelScale,
        'cardStyle': cardStyle.name,
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
    final legacyTitleScale = (j['titleScale'] as num?)?.toDouble() ?? 1.0;
    return CardProject(
      id: j['id'] as String,
      name: s('name', 'New card'),
      templateId: s('templateId', 'standard'),
      photoId: j['photoId'] as String?,
      photoTransform: PhotoTransform.fromJson(j['photoTransform'] as Map<String, dynamic>?),
      photoFill: parsePhotoFill(j['photoFill'] as String?),
      videoId: j['videoId'] as String?,
      videoStartMs: (j['videoStartMs'] as num?)?.toInt() ?? 0,
      videoLengthMs: (j['videoLengthMs'] as num?)?.toInt() ?? defaultVideoLengthMs,
      videoDurationMs: (j['videoDurationMs'] as num?)?.toInt() ?? 0,
      videoPosterMs: (j['videoPosterMs'] as num?)?.toInt() ?? 0,
      fillFileName: j['fillFileName'] as String?,
      fillSignature: j['fillSignature'] as String?,
      logoId: j['logoId'] as String?,
      logoScale: (j['logoScale'] as num?)?.toDouble() ?? 1.0,
      logoDx: (j['logoDx'] as num?)?.toDouble() ?? 0.0,
      logoDy: (j['logoDy'] as num?)?.toDouble() ?? 0.0,
      // Cards saved before brand and model were split have one `titleScale`.
      brandScale: (j['brandScale'] as num?)?.toDouble() ?? legacyTitleScale,
      modelScale: (j['modelScale'] as num?)?.toDouble() ?? legacyTitleScale,
      cardStyle: parseCardStyle(j['cardStyle'] as String?),
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
