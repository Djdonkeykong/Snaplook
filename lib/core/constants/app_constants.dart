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

  static String get serpApiKey =>
    dotenv.env['SERPAPI_API_KEY'] ??
    'e65af8658648b412e968ab84fe28e44c98867bc7e1667de031837e5acf356fd6';

  static String get imgbbApiKey =>
    dotenv.env['IMGBB_API_KEY'] ?? 'd7e1d857e4498c2e28acaa8d943ccea8';

  static String get serpDetectorEndpoint =>
    dotenv.env['SERP_DETECTOR_ENDPOINT'] ?? 'http://127.0.0.1:8000/detect';

// ScrapingBee API for Instagram downloads
  static const List<String> _scrapingBeeKeyPriority = [
    '66DHI1P6O02ODFE3EZCHWKCFUTAYM3JAK4LITASV0OMDW6MIVXUON5944IHBJ2M57G9VRVFUWDXZV6U1',
    'MBVJU10S1A0YUDAMPSUBIVSPGPA6MIJ5R1HNXZBSRQSDD06JH6K8UK74XZF9N8AISFWXTOLQH3U37NZF',
  ];

  static List<String> _parseScrapingBeeEnv(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const [];
    }
    return raw
        .split(RegExp(r'[,\s;]+'))
        .map((candidate) => candidate.trim())
        .where((candidate) => candidate.isNotEmpty)
        .toList(growable: false);
  }

  static String get scrapingBeeApiKey {
    final envValue = dotenv.env['SCRAPINGBEE_API_KEY'];
    final envCandidates = _parseScrapingBeeEnv(envValue);

    for (final preferred in _scrapingBeeKeyPriority) {
      if (envCandidates.contains(preferred)) {
        return preferred;
      }
    }

    if (envCandidates.isNotEmpty) {
      return envCandidates.first;
    }

    for (final preferred in _scrapingBeeKeyPriority) {
      if (preferred.isNotEmpty) {
        return preferred;
      }
    }

    return '';
  }
}
