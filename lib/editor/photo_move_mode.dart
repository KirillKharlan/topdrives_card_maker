/// How a finger drag moves the photo on the card.
enum PhotoMoveMode {
  /// Any direction.
  free('Free'),

  /// The first part of the drag decides: mostly sideways locks the move to the
  /// X axis, mostly up or down locks it to the Y axis, until the finger is lifted.
  auto('Auto axis'),

  /// Only left and right.
  horizontal('X only'),

  /// Only up and down.
  vertical('Y only');

  const PhotoMoveMode(this.label);

  final String label;
}
