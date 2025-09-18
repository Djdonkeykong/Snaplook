class AppConstants {
  // Supabase Configuration - Use environment variables for production
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://tlqpkoknwfptfzejpchy.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'YOUR_SUPABASE_ANON_KEY_HERE',
  );

  // Replicate Configuration
  static const String replicateApiKey = String.fromEnvironment(
    'REPLICATE_API_KEY',
    defaultValue: 'YOUR_REPLICATE_API_KEY',
  );
  static const String replicateModelVersion = String.fromEnvironment(
    'REPLICATE_MODEL_VERSION',
    defaultValue: 'YOUR_CLAUDE_SONNET_4_MODEL_VERSION',
  );

  // App Configuration
  static const String appName = 'Snaplook';
  static const String appVersion = '1.0.0';

  // API Endpoints
  static const String baseApiUrl = 'https://api.replicate.com/v1';

  // Image Configuration
  static const int maxImageSize = 5 * 1024 * 1024; // 5MB
  static const List<String> supportedImageFormats = ['jpg', 'jpeg', 'png', 'webp'];

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double borderRadius = 12.0;
  static const double largeBorderRadius = 20.0;

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);
}