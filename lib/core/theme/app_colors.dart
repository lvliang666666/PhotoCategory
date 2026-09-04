import 'package:flutter/material.dart';

/// Pastel Clay Album design tokens.
class AppColors {
  AppColors._();

  static const cream = Color(0xFFFFF6EC);
  static const warmWhite = Color(0xFFFFF9F3);
  static const coral = Color(0xFFF39A82);
  static const lavender = Color(0xFFB9A0DD);
  static const mint = Color(0xFFA8D7B5);
  static const butter = Color(0xFFF4CB68);
  static const sky = Color(0xFF9ECBE8);
  static const apricot = Color(0xFFF6B985);
  static const ink = Color(0xFF4A4140);
  static const mutedInk = Color(0xFF887D78);
  static const divider = Color(0xFFEFE4DA);
  static const softError = Color(0xFFD97868);

  static const darkBackground = Color(0xFF282321);
  static const darkSurface = Color(0xFF342E2B);
  static const darkSurfaceHigh = Color(0xFF423A36);
  static const darkInk = Color(0xFFF8EEE6);
  static const darkMutedInk = Color(0xFFC8BBB4);

  static const categoryPalette = <Color>[
    coral,
    mint,
    butter,
    sky,
    lavender,
    apricot,
  ];

  static Color tint(Color color, {double amount = .82}) =>
      Color.lerp(color, warmWhite, amount)!;
}
