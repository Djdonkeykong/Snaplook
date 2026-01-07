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

  static String get supabaseAnonKey {
    final key = dotenv.env['SUPABASE_ANON_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception(
        'SUPABASE_ANON_KEY not found in environment variables. '
        'Please ensure .env file is properly configured.',
      );
    }
    return key;
  }

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
      dotenv.env['SEARCHAPI_KEY'] ??
      'ug8vjazGBpVXMXiar47rdqJM';

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
        : 'https://snaplook-fashion-detector.onrender.com/detect';
  }

  static String _defaultDetectAndSearchEndpoint() {
    const bool isLocal = bool.fromEnvironment(
      'USE_LOCAL_API',
      defaultValue: false,
    );
    return isLocal
        ? 'http://10.0.0.25:8000/detect-and-search'
        : 'https://snaplook-fashion-detector.onrender.com/detect-and-search';
  }

  // === 🐝 ScrapingBee Keys ===
  // SECURITY: No hardcoded keys - use environment variables only
  static String get scrapingBeeApiKey {
    final envValue = dotenv.env['SCRAPINGBEE_API_KEY'];
    if (envValue == null || envValue.isEmpty) {
      throw Exception(
        'SCRAPINGBEE_API_KEY not found in environment variables. '
        'Please ensure .env file is properly configured.',
      );
    }
    return envValue;
  }
}
