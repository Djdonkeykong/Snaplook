// lib/core/theme/theme_extensions.dart
import 'package:flutter/material.dart';

@immutable
class AppSpacingExtension extends ThemeExtension<AppSpacingExtension> {
  const AppSpacingExtension({
    required this.xs,
    required this.s,
    required this.m,
    required this.l,
    required this.xl,
    required this.xxl,
  });

  final double xs;
  final double s;
  final double m;
  final double l;
  final double xl;
  final double xxl;

  double get sm => s;

  static const AppSpacingExtension standard = AppSpacingExtension(
    xs: 4.0,
    s: 8.0,
    m: 16.0,
    l: 24.0,
    xl: 32.0,
    xxl: 48.0,
  );

  @override
  AppSpacingExtension copyWith({
    double? xs,
    double? s,
    double? m,
    double? l,
    double? xl,
    double? xxl,
  }) {
    return AppSpacingExtension(
      xs: xs ?? this.xs,
      s: s ?? this.s,
      m: m ?? this.m,
      l: l ?? this.l,
      xl: xl ?? this.xl,
      xxl: xxl ?? this.xxl,
    );
  }

  @override
  AppSpacingExtension lerp(AppSpacingExtension? other, double t) {
    if (other is! AppSpacingExtension) return this;
    return AppSpacingExtension(
      xs: xs + (other.xs - xs) * t,
      s: s + (other.s - s) * t,
      m: m + (other.m - m) * t,
      l: l + (other.l - l) * t,
      xl: xl + (other.xl - xl) * t,
      xxl: xxl + (other.xxl - xxl) * t,
    );
  }
}

@immutable
class AppRadiusExtension extends ThemeExtension<AppRadiusExtension> {
  const AppRadiusExtension({
    required this.small,
    required this.medium,
    required this.large,
    required this.full,
  });

  final double small;
  final double medium;
  final double large;
  final double full;

  static const AppRadiusExtension standard = AppRadiusExtension(
    small: 8.0,
    medium: 12.0,
    large: 16.0,
    full: 999.0,   // <--- already set to 999.0
  );

  @override
  AppRadiusExtension copyWith({
    double? small,
    double? medium,
    double? large,
    double? full,
  }) {
    return AppRadiusExtension(
      small: small ?? this.small,
      medium: medium ?? this.medium,
      large: large ?? this.large,
      full: full ?? this.full,
    );
  }

  @override
  AppRadiusExtension lerp(AppRadiusExtension? other, double t) {
    if (other is! AppRadiusExtension) return this;
    return AppRadiusExtension(
      small: small + (other.small - small) * t,
      medium: medium + (other.medium - medium) * t,
      large: large + (other.large - large) * t,
      full: full + (other.full - full) * t,
    );
  }
}

extension ThemeExtensions on BuildContext {
  AppSpacingExtension get spacing => Theme.of(this).extension<AppSpacingExtension>()!;
  AppRadiusExtension get radius => Theme.of(this).extension<AppRadiusExtension>()!;
}
