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
