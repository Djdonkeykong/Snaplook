// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'color_schemes.dart';
import 'text_themes.dart';
import 'theme_extensions.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: lightColorScheme,
      textTheme: AppTextThemes.textTheme,
      extensions: [
        AppSpacingExtension.standard,
        AppRadiusExtension.standard,
      ],
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: darkColorScheme,
      textTheme: AppTextThemes.textTheme,
      extensions: [
        AppSpacingExtension.standard,
        AppRadiusExtension.standard,
      ],
    );
  }
}