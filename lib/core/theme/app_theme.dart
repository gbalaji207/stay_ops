import 'dart:ui';
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
  });

  final Color background;
  final Color surface;
  final Color accent;
  final Color success;
  final Color warning;
  final Color danger;

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? accent,
    Color? success,
    Color? warning,
    Color? danger,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      accent: accent ?? this.accent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
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
    );
  }
}

class AppTheme {
  static const _lightColors = AppColors(
    background: Color(0xFFF5F5F7),
    surface: Color(0xFFFFFFFF),
    accent: Color(0xFF534AB7),
    success: Color(0xFF1D9E75),
    warning: Color(0xFFD4820A),
    danger: Color(0xFFC0392B),
  );

  static const _darkColors = AppColors(
    background: Color(0xFF0D0F1A),
    surface: Color(0xFF1C1F2E),
    accent: Color(0xFF7F77DD),
    success: Color(0xFF5DCAA5),
    warning: Color(0xFFEF9F27),
    danger: Color(0xFFE24B4A),
  );

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.light(
          primary: _lightColors.accent,
          surface: _lightColors.surface,
          error: _lightColors.danger,
        ),
        scaffoldBackgroundColor: _lightColors.background,
        extensions: const [_lightColors],
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: _darkColors.accent,
          surface: _darkColors.surface,
          error: _darkColors.danger,
        ),
        scaffoldBackgroundColor: _darkColors.background,
        extensions: const [_darkColors],
      );
}
