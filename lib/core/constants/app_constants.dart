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
  // SECURITY: Never use hardcoded fallback values for sensitive credentials
  // All credentials MUST be provided via environment variables
  static String get supabaseUrl {
    final url = dotenv.env['SUPABASE_URL'];
    if (url == null || url.isEmpty) {
      throw Exception(
        'SUPABASE_URL not found in environment variables. '
        'Please ensure .env file is properly configured.',
      );
    }
    return url;
  }

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
  // SECURITY: API keys must be provided via environment variables only
  static String get serpApiKey {
    final key = dotenv.env['SERPAPI_API_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception(
        'SERPAPI_API_KEY not found in environment variables. '
        'Please ensure .env file is properly configured.',
      );
    }
    return key;
  }

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
    if (isLocal) {
      // Development mode - use local server
      return 'http://10.0.0.25:8000/detect';
    }

    // SECURITY: Production endpoint should be configured via environment variable
    // This is a temporary fallback - replace with your production endpoint
    final endpoint = dotenv.env['DETECT_ENDPOINT'];
    if (endpoint != null && endpoint.isNotEmpty) {
      return endpoint;
    }

    throw Exception(
      'DETECT_ENDPOINT not configured. Please set DETECT_ENDPOINT in .env file.',
    );
  }

  static String _defaultDetectAndSearchEndpoint() {
    const bool isLocal = bool.fromEnvironment(
      'USE_LOCAL_API',
      defaultValue: false,
    );
    if (isLocal) {
      // Development mode - use local server
      return 'http://10.0.0.25:8000/detect-and-search';
    }

    // SECURITY: Production endpoint should be configured via environment variable
    final endpoint = dotenv.env['DETECT_AND_SEARCH_ENDPOINT'];
    if (endpoint != null && endpoint.isNotEmpty) {
      return endpoint;
    }

    throw Exception(
      'DETECT_AND_SEARCH_ENDPOINT not configured. Please set in .env file.',
    );
  }

  // === 🐝 ScrapingBee Keys ===
  // SECURITY: ScrapingBee API key must be provided via environment variable
  static String get scrapingBeeApiKey {
    final key = dotenv.env['SCRAPINGBEE_API_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception(
        'SCRAPINGBEE_API_KEY not found in environment variables. '
        'Please ensure .env file is properly configured.',
      );
    }
    return key;
  }
}
