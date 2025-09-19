import 'package:flutter/material.dart';

/// Design System Colors
/// Clean white theme with golden accents and dark tertiary
class AppColors {
  AppColors._();

  // Primary Colors (Clean White Scale)
  static const Color primary = Color(0xFFF8F8F8); // Clean off-white
  static const Color primaryLight = Color(0xFFFFFFFF); // Pure white
  static const Color primaryDark = Color(0xFFF0F0F0); // Slightly darker white

  // Secondary Colors (Black Scale) - Accent color
  static const Color secondary = Color(0xFF000000); // Black
  static const Color secondaryLight = Color(0xFF333333); // Lighter black
  static const Color secondaryDark = Color(0xFF000000); // Darker black

  // Tertiary Colors (Dark Scale) - Former primary, now tertiary
  static const Color tertiary = Color(0xFF1c1c25); // Dark Navy
  static const Color tertiaryLight = Color(0xFF2a2a35); // Lighter dark
  static const Color tertiaryDark = Color(0xFF141419); // Darker variant

  // Neutral Colors (Light Theme)
  static const Color surface = Color(0xFFFFFFFF); // White surface for cards
  static const Color surfaceVariant = Color(0xFFF5F5F5); // Light gray variant
  static const Color background = Color(0xFFF8F8F8); // Clean background (primary)
  static const Color outline = Color(0xFFE5E7EB); // Light gray borders
  static const Color outlineVariant = Color(0xFFF3F4F6); // Even lighter borders

  // Text Colors (Dark on Light)
  static const Color onSurface = Color(0xFF1c1c25); // Dark text on light
  static const Color onSurfaceVariant = Color(0xFF6B7280); // Muted gray text
  static const Color onBackground = Color(0xFF111827); // Primary dark text

  // State Colors
  static const Color error = Color(0xFFEF4444); // Red 500
  static const Color errorContainer = Color(0xFFFEF2F2); // Red 50
  static const Color onError = Color(0xFFFFFFFF);
  static const Color onErrorContainer = Color(0xFF991B1B); // Red 800

  static const Color success = Color(0xFF22C55E); // Green 500
  static const Color successContainer = Color(0xFFF0FDF4); // Green 50
  static const Color warning = Color(0xFFF59E0B); // Amber 500
  static const Color warningContainer = Color(0xFFFFFBEB); // Amber 50

  // Overlay Colors
  static const Color scrim = Color(0x80000000);
  static const Color shadow = Color(0x1A000000);

  // Component-specific Colors
  static const Color cardBackground = surface;
  static const Color bottomSheetBackground = surface;
  static const Color appBarBackground = surface;

  // Navigation Colors
  static const Color navigationBackground = Color(0xFFFFFFFF); // Clean white
  static const Color navigationSelected = secondary; // Golden yellow for active
  static const Color navigationUnselected = Color(0xFF9CA3AF); // Light gray for inactive

  // Category Colors for Fashion Items (Light Theme Compatible)
  static const Color categoryTops = Color(0xFFDDD6FE); // Light purple
  static const Color categoryBottoms = Color(0xFFFEF3C7); // Light amber
  static const Color categoryShoes = Color(0xFFFCE7F3); // Light pink
  static const Color categoryAccessories = Color(0xFFDBEAFE); // Light blue
  static const Color categoryOuterwear = Color(0xFFE0E7FF); // Light indigo
}