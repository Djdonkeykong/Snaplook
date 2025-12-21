import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  AppConstants._();

  static const List<MapEntry<String, String>> _detectEndpointKeyCandidates = [
    MapEntry('DETECT_ENDPOINT', 'DETECT_ENDPOINT'),
    MapEntry('DETECTOR_ENDPOINT', 'DETECTOR_ENDPOINT'),
    MapEntry('SEARCHAPI_DETECT_ENDPOINT', 'SEARCHAPI_DETECT_ENDPOINT'),
    MapEntry('SEARCH_DETECT_ENDPOINT', 'SEARCH_DETECT_ENDPOINT'),
    MapEntry('SERP_DETECT_ENDPOINT', 'SERP_DETECT_ENDPOINT'),
  ];

  static const List<MapEntry<String, String>>
  _detectAndSearchEndpointKeyCandidates = [
    MapEntry('DETECT_AND_SEARCH_ENDPOINT', 'DETECT_AND_SEARCH_ENDPOINT'),
    MapEntry('DETECTOR_AND_SEARCH_ENDPOINT', 'DETECTOR_AND_SEARCH_ENDPOINT'),
    MapEntry(
      'SEARCHAPI_DETECT_AND_SEARCH_ENDPOINT',
      'SEARCHAPI_DETECT_AND_SEARCH_ENDPOINT',
    ),
    MapEntry(
      'SEARCH_DETECT_AND_SEARCH_ENDPOINT',
      'SEARCH_DETECT_AND_SEARCH_ENDPOINT',
    ),
    MapEntry(
      'SERP_DETECT_AND_SEARCH_ENDPOINT',
      'SERP_DETECT_AND_SEARCH_ENDPOINT',
    ),
    MapEntry('SERP_DETECTOR_ENDPOINT', 'SERP_DETECTOR_ENDPOINT'),
  ];

  // === 🔐 Supabase Configuration ===
  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? 'https://tlqpkoknwfptfzejpchy.supabase.co';

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
      'pvMfH1LTuQ37BdoA9wzamK5G';

  static String get apifyApiToken =>
      dotenv.env['APIFY_API_TOKEN'] ?? '';

  static String? get searchApiLocation {
    final value = dotenv.env['SEARCHAPI_LOCATION'];
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  static String? get cloudinaryCloudName {
    final value = dotenv.env['CLOUDINARY_CLOUD_NAME'];
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static String? get cloudinaryApiKey {
    final value = dotenv.env['CLOUDINARY_API_KEY'];
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static String? get cloudinaryApiSecret {
    final value = dotenv.env['CLOUDINARY_API_SECRET'];
    if (value == null || value.isEmpty) return null;
    return value;
  }

  // === 🧠 Smart Detector Endpoints ===
  static String get serpDetectEndpoint {
    final detect = _firstEndpoint(_detectEndpointKeyCandidates);
    if (detect != null) return detect;

    final fromDetectAndSearch = _firstEndpoint(
      _detectAndSearchEndpointKeyCandidates,
    );
    if (fromDetectAndSearch != null) {
      if (fromDetectAndSearch.endsWith('/detect-and-search')) {
        return fromDetectAndSearch.replaceFirst(
          '/detect-and-search',
          '/detect',
        );
      }
      return fromDetectAndSearch;
    }

    return _defaultDetectEndpoint();
  }

  static String get serpDetectAndSearchEndpoint {
    final detectSearch = _firstEndpoint(_detectAndSearchEndpointKeyCandidates);
    if (detectSearch != null) return detectSearch;

    final detectOnly = _firstEndpoint(_detectEndpointKeyCandidates);
    if (detectOnly != null) {
      if (detectOnly.endsWith('/detect')) {
        final base = detectOnly.substring(
          0,
          detectOnly.length - '/detect'.length,
        );
        return '$base/detect-and-search';
      }
      return detectOnly;
    }

    return _defaultDetectAndSearchEndpoint();
  }

  static String get serpDetectorEndpoint => serpDetectEndpoint;

  static String? _maybeEndpoint({
    required String defineKey,
    required String envKey,
  }) {
    final defineValue = String.fromEnvironment(defineKey, defaultValue: '');
    if (defineValue.isNotEmpty) return defineValue;

    final envValue = dotenv.env[envKey];
    if (envValue != null && envValue.isNotEmpty) return envValue;

    return null;
  }

  static String? _firstEndpoint(List<MapEntry<String, String>> candidates) {
    for (final candidate in candidates) {
      final resolved = _maybeEndpoint(
        defineKey: candidate.key,
        envKey: candidate.value,
      );
      if (resolved != null) return resolved;
    }
    return null;
  }

  static String _defaultDetectEndpoint() {
    const bool isLocal = bool.fromEnvironment(
      'USE_LOCAL_API',
      defaultValue: false,
    );
    return isLocal
        ? 'http://10.0.0.25:8000/detect'
        : 'https://1baf8c472238.ngrok-free.app/detect';
  }

  static String _defaultDetectAndSearchEndpoint() {
    const bool isLocal = bool.fromEnvironment(
      'USE_LOCAL_API',
      defaultValue: false,
    );
    return isLocal
        ? 'http://10.0.0.25:8000/detect-and-search'
        : 'https://1baf8c472238.ngrok-free.app/detect-and-search';
  }

  // === 🐝 ScrapingBee Keys ===
  static const List<String> _scrapingBeeKeyPriority = [
    'JZ123377KP6AIVDKOSDZOXYCY5VGAPNFJRFAJR0PA7DNOCO2VQ2MYARURP80689586DKWMXG9SJJDRCH',
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
