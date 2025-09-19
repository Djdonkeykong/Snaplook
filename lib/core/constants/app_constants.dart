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

  // API
  static const String baseApiUrl = 'https://api.example.com';
}