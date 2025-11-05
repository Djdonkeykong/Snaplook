// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'color_schemes.dart';
import 'text_themes.dart';
import 'theme_extensions.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    const colorScheme = lightColorScheme;
    final baseSnackTextStyle =
        AppTextThemes.textTheme.bodyMedium ?? const TextStyle(fontFamily: 'PlusJakartaSans');

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      canvasColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        titleTextStyle: AppTextThemes.textTheme.titleMedium?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.secondary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.surface,
        contentTextStyle: baseSnackTextStyle.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: AppColors.secondary,
        behavior: SnackBarBehavior.floating,
      ),
      textTheme: AppTextThemes.textTheme,
      extensions: const [
        AppSpacingExtension.standard,
        AppRadiusExtension.standard,
      ],
    );
  }

  static ThemeData get darkTheme {
    const colorScheme = darkColorScheme;
    final baseSnackTextStyle =
        AppTextThemes.textTheme.bodyMedium ?? const TextStyle(fontFamily: 'PlusJakartaSans');

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      canvasColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        titleTextStyle: AppTextThemes.textTheme.titleMedium?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.secondary,
        unselectedItemColor: colorScheme.onSurface,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Colors.white,
        contentTextStyle: baseSnackTextStyle.copyWith(
          color: Colors.black,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: AppColors.secondary,
        behavior: SnackBarBehavior.floating,
      ),
      textTheme: AppTextThemes.textTheme.apply(
        bodyColor: colorScheme.onBackground,
        displayColor: colorScheme.onBackground,
      ),
      extensions: const [
        AppSpacingExtension.standard,
        AppRadiusExtension.standard,
      ],
    );
  }
}
