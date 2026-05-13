import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.accent,
    required this.success,
    required this.warning,
    required this.danger,
    required this.nav,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.accentSubtle,
    required this.successSubtle,
    required this.warningSubtle,
    required this.dangerSubtle,
    required this.sheetHandle,
  });

  final Color background;
  final Color surface;
  final Color accent;
  final Color success;
  final Color warning;
  final Color danger;
  final Color nav;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;
  final Color accentSubtle;
  final Color successSubtle;
  final Color warningSubtle;
  final Color dangerSubtle;
  final Color sheetHandle;

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? accent,
    Color? success,
    Color? warning,
    Color? danger,
    Color? nav,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textHint,
    Color? accentSubtle,
    Color? successSubtle,
    Color? warningSubtle,
    Color? dangerSubtle,
    Color? sheetHandle,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      accent: accent ?? this.accent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      nav: nav ?? this.nav,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textHint: textHint ?? this.textHint,
      accentSubtle: accentSubtle ?? this.accentSubtle,
      successSubtle: successSubtle ?? this.successSubtle,
      warningSubtle: warningSubtle ?? this.warningSubtle,
      dangerSubtle: dangerSubtle ?? this.dangerSubtle,
      sheetHandle: sheetHandle ?? this.sheetHandle,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      nav: Color.lerp(nav, other.nav, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textHint: Color.lerp(textHint, other.textHint, t)!,
      accentSubtle: Color.lerp(accentSubtle, other.accentSubtle, t)!,
      successSubtle: Color.lerp(successSubtle, other.successSubtle, t)!,
      warningSubtle: Color.lerp(warningSubtle, other.warningSubtle, t)!,
      dangerSubtle: Color.lerp(dangerSubtle, other.dangerSubtle, t)!,
      sheetHandle: Color.lerp(sheetHandle, other.sheetHandle, t)!,
    );
  }
}

class AppTheme {
  static const _light = AppColors(
    background:   Color(0xFFF5F5F7),
    surface:      Color(0xFFFFFFFF),
    accent:       Color(0xFF534AB7),
    success:      Color(0xFF1D9E75),
    warning:      Color(0xFFD4820A),
    danger:       Color(0xFFC0392B),
    nav:          Color(0xFFFFFFFF),
    border:       Color(0x14000000),
    textPrimary:  Color(0xFF111118),
    textSecondary:Color(0xFF6B6C7E),
    textHint:     Color(0xFFB0B1C0),
    accentSubtle: Color(0x1F534AB7),
    successSubtle:Color(0x1F1D9E75),
    warningSubtle:Color(0x1FD4820A),
    dangerSubtle: Color(0x1AC0392B),
    sheetHandle:  Color(0xFFD1D1DB),
  );

  static const _dark = AppColors(
    background:   Color(0xFF0D0F1A),
    surface:      Color(0xFF1C1F2E),
    accent:       Color(0xFF7F77DD),
    success:      Color(0xFF5DCAA5),
    warning:      Color(0xFFEF9F27),
    danger:       Color(0xFFE24B4A),
    nav:          Color(0xFF131520),
    border:       Color(0x0FFFFFFF),
    textPrimary:  Color(0xFFE8E8F0),
    textSecondary:Color(0xFF9395A5),
    textHint:     Color(0xFF5A5C70),
    accentSubtle: Color(0x33534AB7),
    successSubtle:Color(0x331D9E75),
    warningSubtle:Color(0x26EF9F27),
    dangerSubtle: Color(0x26E24B4A),
    sheetHandle:  Color(0xFF2E3045),
  );

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.light(
          primary: _light.accent,
          surface: _light.surface,
          error: _light.danger,
        ),
        scaffoldBackgroundColor: _light.background,
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: _light.nav,
          selectedItemColor: _light.accent,
          unselectedItemColor: _light.textSecondary,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        extensions: const [_light],
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: _dark.accent,
          surface: _dark.surface,
          error: _dark.danger,
        ),
        scaffoldBackgroundColor: _dark.background,
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: _dark.nav,
          selectedItemColor: _dark.accent,
          unselectedItemColor: _dark.textSecondary,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        extensions: const [_dark],
      );
}
