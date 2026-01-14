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
  primary: Color(0xFF0B0B0D), // Near-black background
  onPrimary: Color(0xFFF5F7FA), // Light text on dark
  primaryContainer: Color(0xFF16181D), // Dark surface
  onPrimaryContainer: Color(0xFFF5F7FA),
  secondary: Color(0xFFF2003C), // Munsell red accent
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFF1D2026),
  onSecondaryContainer: Color(0xFFF5F7FA),
  tertiary: Color(0xFF1D2026),
  onTertiary: Color(0xFFF5F7FA),
  tertiaryContainer: Color(0xFF16181D),
  onTertiaryContainer: Color(0xFFF5F7FA),
  error: Color(0xFFEF4444),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFF3A0B12),
  onErrorContainer: Color(0xFFF5D7DB),
  surface: Color(0xFF16181D),
  onSurface: Color(0xFFF5F7FA),
  surfaceContainerHighest: Color(0xFF1D2026),
  onSurfaceVariant: Color(0xFFC1C6CF),
  outline: Color(0xFF2A2E36),
  outlineVariant: Color(0xFF2A2E36),
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
  inverseSurface: Color(0xFFF5F7FA),
  onInverseSurface: Color(0xFF0B0B0D),
  inversePrimary: Color(0xFFF2003C),
  surfaceVariant: Color(0xFF1D2026),
);
