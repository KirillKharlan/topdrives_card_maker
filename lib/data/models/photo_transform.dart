import 'dart:math' as math;

/// Non-destructive framing of the car photo. The photo is first fitted to the
/// card (cover), then scaled and turned around its own centre and shifted.
/// [dx]/[dy] are fractions of the card width/height, [rotation] is in radians.
/// The original image file is never modified.
class PhotoTransform {
  const PhotoTransform({this.scale = 1, this.dx = 0, this.dy = 0, this.rotation = 0});

  static const identity = PhotoTransform();

  /// Below 1 the photo is smaller than the card (the rest is filled in).
  static const minScale = 0.4;
  static const maxScale = 6.0;

  /// How far the photo centre may travel from the card centre (in card sizes).
  static const maxShift = 1.0;

  final double scale;
  final double dx;
  final double dy;
  final double rotation;

  PhotoTransform copyWith({double? scale, double? dx, double? dy, double? rotation}) =>
      PhotoTransform(
        scale: scale ?? this.scale,
        dx: dx ?? this.dx,
        dy: dy ?? this.dy,
        rotation: rotation ?? this.rotation,
      );

  PhotoTransform clamped() {
    var turn = rotation % (2 * math.pi);
    if (turn > math.pi) turn -= 2 * math.pi;
    return PhotoTransform(
      scale: scale.clamp(minScale, maxScale).toDouble(),
      dx: dx.clamp(-maxShift, maxShift).toDouble(),
      dy: dy.clamp(-maxShift, maxShift).toDouble(),
      rotation: turn,
    );
  }

  Map<String, dynamic> toJson() =>
      {'scale': scale, 'dx': dx, 'dy': dy, 'rotation': rotation};

  factory PhotoTransform.fromJson(Map<String, dynamic>? j) {
    if (j == null) return identity;
    return PhotoTransform(
      scale: (j['scale'] as num?)?.toDouble() ?? 1,
      dx: (j['dx'] as num?)?.toDouble() ?? 0,
      dy: (j['dy'] as num?)?.toDouble() ?? 0,
      rotation: (j['rotation'] as num?)?.toDouble() ?? 0,
    ).clamped();
  }

  @override
  bool operator ==(Object other) =>
      other is PhotoTransform &&
      other.scale == scale &&
      other.dx == dx &&
      other.dy == dy &&
      other.rotation == rotation;

  @override
  int get hashCode => Object.hash(scale, dx, dy, rotation);
}
