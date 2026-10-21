import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const Color primary = Color(0xFFFF6A00);
  static const Color primaryLight = Color(0xFFFF8A33);
  static const Color primaryDark = Color(0xFFE65F00);
  static const Color onPrimary = Color(0xFFFFFFFF);

  static const Color black = Color(0xFF0A0A0A);
  static const Color white = Color(0xFFFFFFFF);

  static const Color gray50 = Color(0xFFFAFAFA);
  static const Color gray100 = Color(0xFFF5F5F5);
  static const Color gray200 = Color(0xFFE5E5E5);
  static const Color gray300 = Color(0xFFD4D4D4);
  static const Color gray400 = Color(0xFFA3A3A3);
  static const Color gray500 = Color(0xFF737373);
  static const Color gray600 = Color(0xFF525252);
  static const Color gray700 = Color(0xFF404040);
  static const Color gray800 = Color(0xFF262626);
  static const Color gray850 = Color(0xFF1F1F1F);
  static const Color gray900 = Color(0xFF171717);
  static const Color gray950 = Color(0xFF0F0F0F);

  static const Color lightBackground = Color.fromARGB(255, 236, 235, 235);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFF8F8F8);
  static const Color lightSurfaceRaised = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE8E8E8);
  static const Color lightDivider = Color(0xFFEDEDED);
  static const Color lightTextPrimary = Color(0xFF0A0A0A);
  static const Color lightTextSecondary = Color(0xFF525252);
  static const Color lightTextMuted = Color(0xFF737373);

  static const Color darkBackground = Color(0xFF0F0E0B);
  static const Color darkSurface = Color.fromARGB(255, 39, 39, 39);
  static const Color darkSurfaceAlt = Color(0xFF1A1A1A);
  static const Color darkSurfaceRaised = Color(0xFF202020);
  static const Color darkBorder = Color(0xFF2E2E2E);
  static const Color darkDivider = Color(0xFF262626);
  static const Color darkTextPrimary = Color(0xFFF5F5F5);
  static const Color darkTextSecondary = Color(0xFFD4D4D4);
  static const Color darkTextMuted = Color(0xFFA3A3A3);

  static const Color success = Color(0xFF4BB543);
  static const Color successDark = Color(0xFF34D399);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFe50914);
  static const Color info = Color(0xFF3B82F6);
  static const Color rating = Color(0xFFF59E0B);

  static Color background(Brightness brightness) {
    return brightness == Brightness.dark ? darkBackground : lightBackground;
  }

  static Color surface(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color.fromARGB(255, 27, 26, 26)
        : const Color.fromARGB(255, 202, 202, 202);
  }

  static Color surfaceAlt(Brightness brightness) {
    return brightness == Brightness.dark ? darkSurfaceAlt : lightSurfaceAlt;
  }

  static Color surfaceRaised(Brightness brightness) {
    return brightness == Brightness.dark
        ? darkSurfaceRaised
        : lightSurfaceRaised;
  }

  static Color border(Brightness brightness) {
    return brightness == Brightness.dark ? darkBorder : lightBorder;
  }

  static Color divider(Brightness brightness) {
    return brightness == Brightness.dark ? darkDivider : lightDivider;
  }

  static Color textPrimary(Brightness brightness) {
    return brightness == Brightness.dark ? darkTextPrimary : lightTextPrimary;
  }

  static Color textSecondary(Brightness brightness) {
    return brightness == Brightness.dark
        ? darkTextSecondary
        : lightTextSecondary;
  }

  static Color textMuted(Brightness brightness) {
    return brightness == Brightness.dark ? darkTextMuted : lightTextMuted;
  }

  static Color online(Brightness brightness) {
    return brightness == Brightness.dark ? successDark : success;
  }
}
