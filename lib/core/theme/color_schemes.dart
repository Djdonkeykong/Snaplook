import 'package:flutter/material.dart';

const lightColorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFFFFFFFF), // Pure white primary
  onPrimary: Color(0xFF1c1c25), // Dark text on white
  primaryContainer: Color(0xFFFAFAFA), // Very light gray container
  onPrimaryContainer: Color(0xFF1c1c25), // Dark text
  secondary: Color(0xFF080808), // Black accent
  onSecondary: Color(0xFFFFFFFF), // White text on black
  secondaryContainer: Color(0xFF333333), // Dark gray container
  onSecondaryContainer: Color(0xFF1c1c25), // Dark text
  tertiary: Color(0xFF1c1c25), // Dark navy tertiary
  onTertiary: Color(0xFFFFFFFF), // White text on dark
  tertiaryContainer: Color(0xFF2c2c35), // Dark container
  onTertiaryContainer: Color(0xFFE8E8EA), // Light text
  error: Color(0xFFEF4444),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFFEF2F2),
  onErrorContainer: Color(0xFF7F1D1D),
  surface: Color(0xFFFFFFFF), // Pure white surface
  onSurface: Color(0xFF1c1c25), // Dark text on white surface
  surfaceContainerHighest: Color(0xFFF9F9F9), // Very light gray
  onSurfaceVariant: Color(0xFF6B7280), // Gray text
  outline: Color(0xFFE5E7EB), // Light gray borders
  outlineVariant: Color(0xFFF3F4F6), // Even lighter borders
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
  inverseSurface: Color(0xFF1c1c25), // Dark for inverse
  onInverseSurface: Color(0xFFFFFFFF), // White on dark
  inversePrimary: Color(0xFF080808), // Black as inverse primary
  surfaceVariant: Color(0xFFF3F4F6),
);

const darkColorScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF000000), // True black primary
  onPrimary: Color(0xFFFFFFFF), // White text on dark
  primaryContainer: Color(0xFF16161A), // Deep charcoal container
  onPrimaryContainer: Color(0xFFE8E8EA), // Light text
  secondary: Color(0xFF080808), // Black accent (same)
  onSecondary: Color(0xFFFFFFFF), // White text on black
  secondaryContainer: Color(0xFF1E1E23), // Dark gray container
  onSecondaryContainer: Color(0xFFFFFFFF), // White text
  tertiary: Color(0xFFFFFFFF), // White tertiary for dark theme
  onTertiary: Color(0xFF1c1c25), // Dark text on white
  tertiaryContainer: Color(0xFFF5F5F5), // Light container
  onTertiaryContainer: Color(0xFF1c1c25), // Dark text
  error: Color(0xFFEF4444),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFF7F1D1D),
  onErrorContainer: Color(0xFFFEF2F2),
  surface: Color(0xFF09090D), // Near-black surface
  onSurface: Color(0xFFF5F5F5), // Light text on dark surface (whiter)
  surfaceContainerHighest: Color(0xFF16161A), // Lighter dark
  onSurfaceVariant: Color(0xFFD4D4D4), // Muted light text (whiter)
  outline: Color(0xFF2D2D33), // Dark borders
  outlineVariant: Color(0xFF1F1F24), // Darker borders
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
  inverseSurface: Color(0xFFFFFFFF), // White for inverse
  onInverseSurface: Color(0xFF1c1c25), // Dark on white
  inversePrimary: Color(0xFF080808), // Black as inverse primary
);
