import 'package:flutter/material.dart';

import '../../core/app_constants.dart';

TextStyle cardTextStyle(double size, {bool bold = false}) => TextStyle(
      fontFamily: AppConstants.fontFamily,
      fontSize: size,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      color: Colors.white,
      height: 1.0,
      decoration: TextDecoration.none,
    );
