class AppConstants {
  AppConstants._();

  // Supabase Configuration
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://your-project.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'your-anon-key-here',
  );

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

  // API
  static const String baseApiUrl = String.fromEnvironment(
    'REPLICATE_BASE_URL',
    defaultValue: 'https://api.replicate.com/v1',
  );

  static const String replicateApiKey = String.fromEnvironment(
    'REPLICATE_API_KEY',
    defaultValue: 'your-replicate-api-key-here',
  );

  static const String replicateModelVersion = String.fromEnvironment(
    'REPLICATE_MODEL_VERSION',
    defaultValue: 'default-model-version',
  );
}