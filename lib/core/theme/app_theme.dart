// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'color_schemes.dart';
import 'text_themes.dart';
import 'theme_extensions.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    const colorScheme = lightColorScheme;
    final baseSnackTextStyle = (AppTextThemes.textTheme.bodyMedium ??
            const TextStyle())
        .copyWith(fontFamily: 'PlusJakartaSans');

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
        backgroundColor: Colors.black,
        contentTextStyle: baseSnackTextStyle.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: AppColors.secondary,
        behavior: SnackBarBehavior.fixed,
        elevation: 0,
      ),
      textTheme: AppTextThemes.textTheme,
      extensions: const [
        AppSpacingExtension.standard,
        AppRadiusExtension.standard,
        AppNavigationExtension.light,
      ],
    );
  }
}
