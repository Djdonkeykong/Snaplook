import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  AppConstants._();

  // Supabase Configuration - reads from .env file at runtime
  static String get supabaseUrl =>
    dotenv.env['SUPABASE_URL'] ?? 'https://your-project.supabase.co';

  static String get supabaseAnonKey =>
    dotenv.env['SUPABASE_ANON_KEY'] ?? 'your-anon-key-here';

  // Spacing
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;

  // Border Radius
  static const double borderRadius = 12.0;
  static const double largeBorderRadius = 16.0;
  static const double smallBorderRadius = 8.0;

  // Animation
  static const Duration mediumAnimation = Duration(milliseconds: 300);

  // API - reads from .env file at runtime
  static String get baseApiUrl =>
    dotenv.env['REPLICATE_BASE_URL'] ?? 'https://api.replicate.com/v1';

  static String get replicateApiKey =>
    dotenv.env['REPLICATE_API_KEY'] ?? 'your-replicate-api-key-here';

  static String get replicateModelVersion =>
    dotenv.env['REPLICATE_MODEL_VERSION'] ?? 'default-model-version';
}