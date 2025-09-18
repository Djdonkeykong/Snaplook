class AppConstants {
  // Supabase Configuration
  static const String supabaseUrl = 'https://tlqpkoknwfptfzejpchy.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRscXBrb2tud2ZwdGZ6ZWpwY2h5Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NDAzMzM3MSwiZXhwIjoyMDY5NjA5MzcxfQ._oMzqi-ikCHrJmcXI-D5M0d-6PakOWzVYDBehoW27Ow';

  // Replicate Configuration
  static const String replicateApiKey = 'YOUR_REPLICATE_API_KEY';
  static const String replicateModelVersion = 'YOUR_CLAUDE_SONNET_4_MODEL_VERSION';

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