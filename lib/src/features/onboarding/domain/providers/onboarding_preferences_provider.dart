import 'package:flutter_riverpod/flutter_riverpod.dart';

// User goals (multi-select)
final userGoalsProvider = StateProvider<List<String>>((ref) => []);

// Age range (single select)
final ageRangeProvider = StateProvider<String?>((ref) => null);

// Style preferences (multi-select)
final stylePreferencesProvider = StateProvider<List<String>>((ref) => []);

// Preferred retailers (multi-select)
final preferredRetailersProvider = StateProvider<List<String>>((ref) => []);

// Price range (single select)
final priceRangeProvider = StateProvider<String?>((ref) => null);

// Category interests (multi-select)
final categoryInterestsProvider = StateProvider<List<String>>((ref) => []);

// Shopping frequency (single select)
final shoppingFrequencyProvider = StateProvider<String?>((ref) => null);
