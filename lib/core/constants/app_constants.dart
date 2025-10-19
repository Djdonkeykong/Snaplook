import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  AppConstants._();

  // === 🔐 Supabase Configuration ===
  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ??
      'https://tlqpkoknwfptfzejpchy.supabase.co';

  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ??
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
      'eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRscXBrb2tud2ZwdGZ6ZWpwY2h5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQwMzMzNzEsImV4cCI6MjA2OTYwOTM3MX0.'
      'oHT9O_Aak8sUiAKX7P1J036ZSYIBDNveZqS1EMCLcJA';

  // === 🎨 UI constants ===
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;

  static const double borderRadius = 12.0;
  static const double largeBorderRadius = 16.0;
  static const double smallBorderRadius = 8.0;

  static const Duration mediumAnimation = Duration(milliseconds: 300);

  // === 🌐 API Keys ===
  static String get serpApiKey =>
      dotenv.env['SERPAPI_API_KEY'] ??
      'e65af8658648b412e968ab84fe28e44c98867bc7e1667de031837e5acf356fd6';

  static String get imgbbApiKey =>
      dotenv.env['IMGBB_API_KEY'] ??
      'd7e1d857e4498c2e28acaa8d943ccea8';

  // === 🧠 Smart Detector Endpoints ===
  static String get serpDetectEndpoint {
    final detect = _maybeEndpoint(
      defineKey: 'SERP_DETECT_ENDPOINT',
      envKey: 'SERP_DETECT_ENDPOINT',
    );
    if (detect != null) return detect;

    final legacy = _maybeEndpoint(
      defineKey: 'SERP_DETECTOR_ENDPOINT',
      envKey: 'SERP_DETECTOR_ENDPOINT',
    );
    if (legacy != null) {
      if (legacy.endsWith('/detect-and-search')) {
        return legacy.replaceFirst('/detect-and-search', '/detect');
      }
      return legacy;
    }

    return _defaultDetectEndpoint();
  }

  static String get serpDetectAndSearchEndpoint {
    final detectSearch = _maybeEndpoint(
      defineKey: 'SERP_DETECT_AND_SEARCH_ENDPOINT',
      envKey: 'SERP_DETECT_AND_SEARCH_ENDPOINT',
    );
    if (detectSearch != null) return detectSearch;

    final legacy = _maybeEndpoint(
      defineKey: 'SERP_DETECTOR_ENDPOINT',
      envKey: 'SERP_DETECTOR_ENDPOINT',
    );
    if (legacy != null) {
      if (legacy.endsWith('/detect')) {
        final base = legacy.substring(0, legacy.length - '/detect'.length);
        return '$base/detect-and-search';
      }
      return legacy;
    }

    return _defaultDetectAndSearchEndpoint();
  }

  static String get serpDetectorEndpoint => serpDetectEndpoint;

  static String? _maybeEndpoint({
    required String defineKey,
    required String envKey,
  }) {
    const defineValue = String.fromEnvironment(defineKey, defaultValue: '');
    if (defineValue.isNotEmpty) return defineValue;

    final envValue = dotenv.env[envKey];
    if (envValue != null && envValue.isNotEmpty) return envValue;

    return null;
  }

  static String _defaultDetectEndpoint() {
    const bool isLocal =
        bool.fromEnvironment('USE_LOCAL_API', defaultValue: false);
    return isLocal
        ? 'http://10.0.0.25:8000/detect'
        : 'https://snaplook-fastapi-detector.onrender.com/detect';
  }

  static String _defaultDetectAndSearchEndpoint() {
    const bool isLocal =
        bool.fromEnvironment('USE_LOCAL_API', defaultValue: false);
    return isLocal
        ? 'http://10.0.0.25:8000/detect-and-search'
        : 'https://snaplook-fastapi-detector.onrender.com/detect-and-search';
  }

  // === 🐝 ScrapingBee Keys ===
  static const List<String> _scrapingBeeKeyPriority = [
    'MBVJU10S1A0YUDAMPSUBIVSPGPA6MIJ5R1HNXZBSRQSDD06JH6K8UK74XZF9N8AISFWXTOLQH3U37NZF',
  ];

  static List<String> _parseScrapingBeeEnv(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    return raw
        .split(RegExp(r'[,\s;]+'))
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toList(growable: false);
  }

  static String get scrapingBeeApiKey {
    final envValue = dotenv.env['SCRAPINGBEE_API_KEY'];
    final envCandidates = _parseScrapingBeeEnv(envValue);

    for (final preferred in _scrapingBeeKeyPriority) {
      if (envCandidates.contains(preferred)) return preferred;
    }

    if (envCandidates.isNotEmpty) return envCandidates.first;
    for (final preferred in _scrapingBeeKeyPriority) {
      if (preferred.isNotEmpty) return preferred;
    }

    return '';
  }
}