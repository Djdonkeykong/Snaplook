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

  // === 🧠 Smart Detector Endpoint ===
  static String get serpDetectorEndpoint {
    // 🧩 Priority 1: dart-define (used in Codemagic)
    const defineUrl = String.fromEnvironment(
      'SERP_DETECTOR_ENDPOINT',
      defaultValue: '',
    );
    if (defineUrl.isNotEmpty) return defineUrl;

    // 🧩 Priority 2: .env file (used in local dev)
    final envUrl = dotenv.env['SERP_DETECTOR_ENDPOINT'];
    if (envUrl != null && envUrl.isNotEmpty) return envUrl;

    // 🧩 Priority 3: Local LAN (for debugging)
    const localIP = 'http://10.0.0.25:8000/detect';

    // 🧩 Priority 4: Production fallback
    const renderUrl =
        'https://snaplook-fastapi-detector.onrender.com/detect-and-search';

    // Optional override flag for dev
    const bool isLocal =
        bool.fromEnvironment('USE_LOCAL_API', defaultValue: false);

    return isLocal ? localIP : renderUrl;
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
