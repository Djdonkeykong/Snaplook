import 'package:flutter_riverpod/flutter_riverpod.dart';

// Style direction - "Which styles do you like?" (multi-select)
// Options: Streetwear, Minimal, Casual, Classic, Bold
final styleDirectionProvider = StateProvider<List<String>>((ref) => []);

// What you want - "What are you mostly looking for?" (multi-select)
// Options: Outfits, Shoes, Tops, Accessories, Everything
final whatYouWantProvider = StateProvider<List<String>>((ref) => []);

// Budget - "What price range feels right?" (single select)
// Options: Affordable, Mid-range, Premium, It varies
final budgetProvider = StateProvider<String?>((ref) => null);
