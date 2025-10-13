import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_constants.dart';
import 'instagram_service.dart';

class LinkScraperService {
  static const String _scrapingBeeApiHost = 'app.scrapingbee.com';

  /// Attempts to scrape generic web pages for <img> tags and downloads the images.
  /// Returns a list of locally saved [XFile]s.
  static Future<List<XFile>> downloadImagesFromUrl(String url) async {
    final apiKey = AppConstants.scrapingBeeApiKey;
    if (apiKey.isEmpty) {
      print('[LINK SCRAPER] ScrapingBee API key is missing');
      return [];
    }

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
        'url': url,
        'extract_rules': extractRules,
        'json_response': 'true',
        'render_js': 'false',
      });

      print('[LINK SCRAPER] Requesting ScrapingBee for $url');
      final response = await http
          .get(requestUri)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        print(
          '[LINK SCRAPER] ScrapingBee request failed: ${response.statusCode}',
        );
        print('[LINK SCRAPER] Body: ${response.body}');
        return [];
      }

      final Map<String, dynamic> data = jsonDecode(response.body);
      final List<dynamic>? images = data['images'] as List<dynamic>?;

      if (images == null || images.isEmpty) {
        print('[LINK SCRAPER] No images found for $url');
        return [];
      }

      final baseUri = Uri.parse(url);
      final resolvedUrls = <String>{};

      for (final item in images) {
        if (item is Map<String, dynamic>) {
          final rawSrc = item['src'] as String?;
          if (rawSrc == null || rawSrc.isEmpty) {
            continue;
          }
          if (rawSrc.startsWith('data:')) {
            // Skip inline images (icons, svgs, etc.)
            continue;
          }
          Uri? resolved;
          try {
            resolved = baseUri.resolve(rawSrc);
          } catch (_) {
            continue;
          }
          if (resolved != null &&
              (resolved.scheme == 'http' || resolved.scheme == 'https')) {
            resolvedUrls.add(resolved.toString());
          }
        }
      }

      if (resolvedUrls.isEmpty) {
        print('[LINK SCRAPER] No valid HTTP image URLs resolved for $url');
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
      print('[LINK SCRAPER] Error scraping $url -> $e');
      return [];
    }
  }
}
