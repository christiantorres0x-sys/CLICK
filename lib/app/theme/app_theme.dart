import 'package:flutter/material.dart';

/// CLICK's dark palette (SRS FR-UI-01). Text colors keep at least WCAG AA
/// contrast against the background and surface colors (NFR-UX).
class ClickColors {
  static const background = Color(0xFF0A0A0F);
  static const surface = Color(0xFF14141C);
  static const surfaceHigh = Color(0xFF1E1E2A);
  static const accent = Color(0xFF8B7CFF);
  static const onAccent = Color(0xFF0A0A0F);
  static const textPrimary = Color(0xFFF4F4F8);
  static const textSecondary = Color(0xFFA9A9BC);
  static const outline = Color(0xFF2E2E3E);
  static const error = Color(0xFFFF8A80);
  static const onError = Color(0xFF0A0A0F);
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

ThemeData buildClickTheme() {
  const scheme = ColorScheme.dark(
    primary: ClickColors.accent,
    onPrimary: ClickColors.onAccent,
    secondary: ClickColors.accent,
    onSecondary: ClickColors.onAccent,
    surface: ClickColors.surface,
    onSurface: ClickColors.textPrimary,
    error: ClickColors.error,
    onError: ClickColors.onError,
    outline: ClickColors.outline,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: ClickColors.background,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: ClickColors.textPrimary,
      displayColor: ClickColors.textPrimary,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: ClickColors.surface,
      indicatorColor: Color(0x338B7CFF),
    ),
    sliderTheme: const SliderThemeData(
      trackHeight: 4,
      activeTrackColor: ClickColors.accent,
      inactiveTrackColor: ClickColors.outline,
      thumbColor: ClickColors.textPrimary,
    ),
    dividerColor: ClickColors.outline,
  );
}
