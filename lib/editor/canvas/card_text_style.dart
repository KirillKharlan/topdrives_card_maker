import 'package:flutter/material.dart';

import '../../core/app_constants.dart';

/// The card font. Pass [foreground] to draw an outline (it replaces the colour).
TextStyle cardTextStyle(
  double size, {
  bool bold = false,
  double? letterSpacing,
  Paint? foreground,
}) =>
    TextStyle(
      fontFamily: AppConstants.fontFamily,
      fontSize: size,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      color: foreground == null ? Colors.white : null,
      foreground: foreground,
      letterSpacing: letterSpacing,
      height: 1.0,
      decoration: TextDecoration.none,
    );
