/// What is drawn where the photo does not reach the edges of the card.
enum PhotoFill {
  /// Content-aware fill: the missing area is built from patches of the photo
  /// itself (press "Generate fill" once the framing is final). Until it is
  /// generated, or after the framing changes, the mirror mode is shown.
  smart('Content-aware'),

  /// The photo is mirrored beyond its edges and blurred: sky, road and grass
  /// simply "continue".
  mirror('Mirror + blur'),

  /// A big blurred copy of the photo behind it.
  blur('Blurred backdrop'),

  /// Plain colour.
  none('Flat colour');

  const PhotoFill(this.label);

  final String label;
}

PhotoFill parsePhotoFill(String? name) => PhotoFill.values.firstWhere(
      (f) => f.name == name,
      orElse: () => PhotoFill.mirror,
    );
