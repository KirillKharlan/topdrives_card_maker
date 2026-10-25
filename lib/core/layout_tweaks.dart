import 'package:flutter/foundation.dart';

/// Small user-adjustable corrections that the card renderer reads. They live
/// here (and are saved in settings.json) so a change shows up on every card
/// at once, without rebuilding the app.
class LayoutTweaks {
  LayoutTweaks._();

  /// Moves the tyre name down (+) or up (-), in card units, to line it up with
  /// the "Tyres" word that is part of the frame.
  static final tyreNameOffset = ValueNotifier<double>(0);
}
