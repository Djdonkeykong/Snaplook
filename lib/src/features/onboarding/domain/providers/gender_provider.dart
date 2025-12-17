import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Supported gender options captured during onboarding.
enum Gender { male, female, other }

/// Stores the user's selected gender throughout the onboarding flow.
final selectedGenderProvider = StateProvider<Gender?>((ref) => null);
