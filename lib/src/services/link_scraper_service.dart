import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_constants.dart';
import 'instagram_service.dart';

class LinkScraperService {
  static const String _scrapingBeeApiHost = 'app.scrapingbee.com';
  static const String _userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  /// Attempts to scrape generic web pages for <img> tags and downloads the images.
  /// Returns a list of locally saved [XFile]s.
  static Future<List<XFile>> downloadImagesFromUrl(String url) async {
    final decodedUrl = _safeDecode(url);
    if (isGoogleImageResultUrl(url) ||
        (decodedUrl != null && isGoogleImageResultUrl(decodedUrl))) {
      return downloadImageFromGoogleImageResult(decodedUrl ?? url);
    }

    final apiKey = AppConstants.scrapingBeeApiKey;
    if (apiKey.isEmpty) {
      print('[LINK SCRAPER] ScrapingBee API key is missing');
      return [];
    }

    final resolvedUrl = await _resolveFinalUrl(url) ?? url;
    print('[LINK SCRAPER] Resolved shared URL -> $resolvedUrl');

    try {
      final extractRules = jsonEncode({
        'images': {
          'selector': 'img',
          'type': 'list',
          'output': {'src': 'img@src'},
        },
      });

      final requestUri = Uri.https(_scrapingBeeApiHost, '/api/v1/', {
        'api_key': apiKey,
        'url': resolvedUrl,
        'extract_rules': extractRules,
        'json_response': 'true',
        'render_js': 'true',
        'wait': '1500',
      });

      print('[LINK SCRAPER] Requesting ScrapingBee for $resolvedUrl');
      final response =
          await http.get(requestUri).timeout(const Duration(seconds: 15));

      Map<String, dynamic>? data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        data = null;
      }

      if (response.statusCode != 200 && data == null) {
        print(
          '[LINK SCRAPER] ScrapingBee request failed: ${response.statusCode}',
        );
        print('[LINK SCRAPER] Body: ${response.body}');
        return [];
      }

      final body = (data?['body'] ?? data) as Map<String, dynamic>?;
      final images = body?['images'] as List<dynamic>? ?? [];

      if (images.isEmpty) {
        print('[LINK SCRAPER] No images found for $resolvedUrl');
        return [];
      }

      final baseUri = Uri.parse(resolvedUrl);
      final resolvedUrls = <String>{};

      for (final item in images) {
        if (item is Map<String, dynamic>) {
          final rawSrc = item['src'] as String?;
          if (rawSrc == null || rawSrc.isEmpty || rawSrc.startsWith('data:')) {
            continue;
          }
          Uri? resolved;
          try {
            resolved = baseUri.resolve(rawSrc);
          } catch (_) {
            resolved = null;
          }
          if (resolved != null &&
              (resolved.scheme == 'http' || resolved.scheme == 'https')) {
            resolvedUrls.add(resolved.toString());
          }
        }
      }

      if (resolvedUrls.isEmpty) {
        print(
          '[LINK SCRAPER] No valid HTTP image URLs resolved for $resolvedUrl',
        );
        return [];
      }

      final List<XFile> downloaded = [];
      for (final imageUrl in resolvedUrls.take(5)) {
        final file = await InstagramService.downloadExternalImage(imageUrl);
        if (file != null) {
          downloaded.add(file);
        }
      }

      print(
        '[LINK SCRAPER] Downloaded ${downloaded.length} image(s) for generic URL',
      );
      return downloaded;
    } catch (e) {
      print('[LINK SCRAPER] Error scraping $resolvedUrl -> $e');
      return [];
    }
  }

  static Future<String?> _resolveFinalUrl(String url) async {
    try {
      Uri? current = Uri.tryParse(url);
      if (current == null) return null;

      final client = http.Client();
      try {
        for (int i = 0; i < 5; i++) {
          final uri = current;
          if (uri == null) break;

          final request = http.Request('GET', uri)
            ..followRedirects = false
            ..headers['User-Agent'] = _userAgent;
          final response = await client.send(request);

          if (response.isRedirect) {
            final location = response.headers['location'];
            if (location == null) break;
            current = uri.resolve(location);
            continue;
          }

          return response.request?.url.toString() ?? uri.toString();
        }
      } finally {
        client.close();
      }
    } catch (e) {
      print('[LINK SCRAPER] Failed to resolve redirects: $e');
    }
    return null;
  }

  static bool isGoogleImageResultUrl(String url) {
    final lower = url.toLowerCase().trim();
    final hasGoogleHost = lower.contains('://www.google.') ||
        lower.contains('://google.') ||
        lower.startsWith('www.google.') ||
        lower.startsWith('google.');
    if (!hasGoogleHost) return false;
    final hasImgresPath =
        lower.contains('/imgres') || lower.contains('/search');
    if (!hasImgresPath) return false;
    return lower.contains('imgurl=');
  }

  static Future<List<XFile>> downloadImageFromGoogleImageResult(
      String url) async {
    final rawImageUrl = _extractImgUrlFromGoogleUrl(url);
    if (rawImageUrl == null || rawImageUrl.isEmpty) {
      print('[LINK SCRAPER] Could not parse imgurl from Google link');
      return [];
    }

    final cleanedUrl =
        rawImageUrl.startsWith('http') ? rawImageUrl : 'https://$rawImageUrl';

    final XFile? file =
        await InstagramService.downloadExternalImage(cleanedUrl);
    if (file == null) {
      return [];
    }
    print('[LINK SCRAPER] Downloaded image directly from Google imgurl');
    return [file];
  }

  static String? _extractImgUrlFromGoogleUrl(String url) {
    final lower = url.toLowerCase();
    final index = lower.indexOf('imgurl=');
    if (index == -1) return null;

    final raw = url.substring(index + 7);
    final endIndex = raw.indexOf('&');
    final candidate = endIndex == -1 ? raw : raw.substring(0, endIndex);
    final decoded = Uri.decodeFull(candidate);
    return decoded.trim();
  }

  static String? _safeDecode(String value) {
    try {
      return Uri.decodeFull(value);
    } catch (_) {
      return null;
    }
  }
}
