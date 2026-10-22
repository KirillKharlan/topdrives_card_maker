/// Non-destructive crop: the photo is first "cover"-fitted to the card, then
/// scaled around the centre and shifted. [dx]/[dy] are fractions of the card
/// width/height. The original image file is never modified.
class PhotoTransform {
  const PhotoTransform({this.scale = 1, this.dx = 0, this.dy = 0});

  static const identity = PhotoTransform();
  static const maxScale = 6.0;

  final double scale;
  final double dx;
  final double dy;

  /// Keeps the photo covering the whole card (no empty edges).
  PhotoTransform clamped() {
    final s = scale.clamp(1.0, maxScale).toDouble();
    final limit = (s - 1) / 2;
    return PhotoTransform(
      scale: s,
      dx: dx.clamp(-limit, limit).toDouble(),
      dy: dy.clamp(-limit, limit).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {'scale': scale, 'dx': dx, 'dy': dy};

  factory PhotoTransform.fromJson(Map<String, dynamic>? j) {
    if (j == null) return identity;
    return PhotoTransform(
      scale: (j['scale'] as num?)?.toDouble() ?? 1,
      dx: (j['dx'] as num?)?.toDouble() ?? 0,
      dy: (j['dy'] as num?)?.toDouble() ?? 0,
    ).clamped();
  }
}
