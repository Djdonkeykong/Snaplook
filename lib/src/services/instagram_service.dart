import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_constants.dart';

class InstagramService {
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  // ScrapingBee API configuration
  static const String _scrapingBeeApiUrl =
      'https://app.scrapingbee.com/api/v1/';

  static const String _jinaProxyBase = 'https://r.jina.ai/';

  static const _ScrapingBeeAttempt _defaultScrapingBeeAttempt =
      _ScrapingBeeAttempt(
        waitMilliseconds: 2000,
        timeout: Duration(seconds: 8),
      );

  static const _ScrapingBeeAttempt _premiumScrapingBeeAttempt =
      _ScrapingBeeAttempt(
        waitMilliseconds: 3500,
        timeout: Duration(seconds: 14),
        usePremiumProxy: true,
      );

  /// ScrapingBee Instagram scraper with smart image quality detection.
  /// Returns a single high-quality image to match the iOS share extension behaviour.
  static Future<List<XFile>> _scrapingBeeInstagramScraper(
    String instagramUrl,
  ) async {
    print('Attempting ScrapingBee Instagram scraper for URL: $instagramUrl');

    final uri = Uri.parse(_scrapingBeeApiUrl);
    final attemptConfigs = <_ScrapingBeeAttempt>[
      _defaultScrapingBeeAttempt,
      _premiumScrapingBeeAttempt,
    ];

    for (var i = 0; i < attemptConfigs.length; i++) {
      final attempt = attemptConfigs[i];
      final queryParams = {
        'api_key': AppConstants.scrapingBeeApiKey,
        'url': instagramUrl,
        'render_js': 'true',
        'wait': attempt.waitMilliseconds.toString(),
      };
      if (attempt.usePremiumProxy) {
        queryParams['premium_proxy'] = 'true';
        queryParams['country_code'] = 'us';
      }

      final requestUri = uri.replace(queryParameters: queryParams);
      print(
        'ScrapingBee attempt ${i + 1}/${attemptConfigs.length} (wait=${attempt.waitMilliseconds}ms, premium=${attempt.usePremiumProxy})',
      );

      http.Response response;
      try {
        response = await http.get(requestUri).timeout(attempt.timeout);
      } on TimeoutException {
        print(
          'ScrapingBee attempt ${i + 1} timed out after ${attempt.timeout.inSeconds}s',
        );
        continue;
      } catch (error) {
        print(
          'ScrapingBee attempt ${i + 1} request error: ${error.toString()}',
        );
        continue;
      }

      if (response.statusCode != 200) {
        print(
          'ScrapingBee attempt ${i + 1} failed with status ${response.statusCode}',
        );
        print('Response: ${response.body}');
        continue;
      }

      final htmlContent = response.body;
      print(
        'ScrapingBee response received on attempt ${i + 1}, HTML length: ${htmlContent.length} chars',
      );

      final images = await _extractImagesFromInstagramHtml(htmlContent);
      if (images.isNotEmpty) {
        return images;
      }

      print('No usable images extracted on attempt ${i + 1}');
    }

    print('ScrapingBee attempts exhausted - trying Jina AI fallback');
    final jinaImages = await _scrapeInstagramViaJina(instagramUrl);
    if (jinaImages.isNotEmpty) {
      return jinaImages;
    }

    print('No image URL found in ScrapingBee results');
    return [];
  }

  static Future<List<XFile>> _extractImagesFromInstagramHtml(
    String htmlContent,
  ) async {
    final document = html_parser.parse(htmlContent);
    final candidateUrls = <String>[];
    final seenCandidates = <String>{};

    void enqueueCandidate(String? rawUrl, String reason) {
      if (rawUrl == null || rawUrl.isEmpty) {
        return;
      }
      final sanitized = _sanitizeInstagramUrl(rawUrl);
      if (sanitized.isEmpty) {
        return;
      }
      if (seenCandidates.add(sanitized)) {
        candidateUrls.add(sanitized);
        print(
          'Queueing Instagram image candidate ($reason): ${_previewUrl(sanitized)}',
        );
      }
    }

    final allListItems = document.querySelectorAll('li');
    final carouselItems = allListItems
        .where((li) => li.attributes['style']?.contains('translateX') == true)
        .toList();

    print('Found ${carouselItems.length} carousel items with translateX');

    if (carouselItems.length >= 2) {
      print(
        'Detected carousel post with ${carouselItems.length} potential images',
      );

      for (int i = 0; i < carouselItems.length; i++) {
        final carouselItem = carouselItems[i];
        final style = carouselItem.attributes['style'] ?? '';

        if (style.contains('width: 1px')) {
          print('Skipping navigation placeholder item ${i + 1}');
          continue;
        }

        final img = carouselItem.querySelector('img');
        if (img != null) {
          final src = img.attributes['src'];
          if (src != null &&
              src.contains('.jpg') &&
              !src.contains('150x150') &&
              !src.contains('profile')) {
            enqueueCandidate(src, 'carousel translateX item ${i + 1}');
          }
        }
      }
    }

    if (candidateUrls.isEmpty) {
      print('No translateX carousel found, trying li._acaz fallback');
      final acazItems = document.querySelectorAll('li._acaz');
      print('Found ${acazItems.length} li._acaz items');

      for (int i = 0; i < acazItems.length; i++) {
        final carouselItem = acazItems[i];
        final img = carouselItem.querySelector('img');

        if (img != null) {
          final src = img.attributes['src'];
          if (src != null &&
              src.contains('.jpg') &&
              !src.contains('150x150') &&
              !src.contains('profile')) {
            enqueueCandidate(src, 'carousel _acaz item ${i + 1}');
          }
        }
      }
    }

    if (candidateUrls.isEmpty) {
      print('No carousel detected, looking for single image');

      final imgElements = document.querySelectorAll('img');
      print('Found ${imgElements.length} img tags');

      String? bestImageUrl;
      int bestQualityScore = 0;

      for (final img in imgElements) {
        final src = img.attributes['src'];
        if (src != null) {
          var qualityScore = 0;

          if (src.contains('?')) qualityScore += 5;

          if (src.contains('1440x') || src.contains('1080x'))
            qualityScore += 100;
          if (src.contains('800x') || src.contains('640x')) qualityScore += 50;
          if (src.contains('150x150')) qualityScore -= 100;

          if (src.contains('instagram.') || src.contains('fbcdn.net'))
            qualityScore += 20;

          if (src.length > 200) qualityScore += 10;

          if (src.contains('profile')) qualityScore -= 50;

          print(
            'ScrapingBee img quality score: $qualityScore for ${src.substring(0, 80)}...',
          );

          if (qualityScore > bestQualityScore) {
            bestQualityScore = qualityScore;
            bestImageUrl = src;
          }
        }
      }

      if (bestImageUrl != null) {
        print(
          'ScrapingBee found single high-quality img (score $bestQualityScore)',
        );
        enqueueCandidate(
          bestImageUrl,
          'single image (score $bestQualityScore)',
        );
      }
    }

    if (candidateUrls.isNotEmpty) {
      for (int i = 0; i < candidateUrls.length; i++) {
        final imageUrl = candidateUrls[i];
        print(
          'Downloading Instagram candidate ${i + 1}/${candidateUrls.length}: ${_previewUrl(imageUrl)}',
        );

        final downloadedImage = await _downloadImage(imageUrl);
        if (downloadedImage != null) {
          print(
            'ScrapingBee selected candidate ${i + 1}/${candidateUrls.length}',
          );
          return [downloadedImage];
        }

        print(
          'Candidate ${i + 1}/${candidateUrls.length} failed - trying next',
        );
      }
    }

    final scriptElements = document.querySelectorAll('script');
    for (final script in scriptElements) {
      final scriptContent = script.text;

      if (scriptContent.contains('"display_url"')) {
        final displayUrlMatch = RegExp(
          r'"display_url":"([^"]+)"',
        ).firstMatch(scriptContent);
        if (displayUrlMatch != null) {
          var imageUrl = displayUrlMatch.group(1);
          if (imageUrl != null) {
            imageUrl = _sanitizeInstagramUrl(imageUrl.replaceAll(r'&', '&'));
            if (imageUrl.isEmpty) {
              continue;
            }
            if (!seenCandidates.add(imageUrl)) {
              continue;
            }
            print(
              'ScrapingBee found display_url in script (fallback): ${_previewUrl(imageUrl)}',
            );
            final fallbackImage = await _downloadImage(imageUrl);
            if (fallbackImage != null) {
              return [fallbackImage];
            }
          }
        }
      }
    }

    final ogImageElement = document.querySelector('meta[property="og:image"]');
    if (ogImageElement != null) {
      final imageUrl = ogImageElement.attributes['content'];
      if (imageUrl != null) {
        final sanitized = _sanitizeInstagramUrl(imageUrl);
        if (sanitized.isEmpty) {
          print('ScrapingBee og:image content was empty after sanitizing');
        } else if (!seenCandidates.add(sanitized)) {
          print('ScrapingBee og:image matched previously attempted URL');
        } else {
          print(
            'ScrapingBee found og:image (last resort): ${_previewUrl(sanitized)}',
          );
          final lastResortImage = await _downloadImage(sanitized);
          if (lastResortImage != null) {
            return [lastResortImage];
          }
        }
      }
    }

    return [];
  }

  static Future<List<XFile>> _scrapeInstagramViaJina(
    String instagramUrl,
  ) async {
    try {
      final proxyUri = Uri.parse('$_jinaProxyBase$instagramUrl');
      final response = await http
          .get(proxyUri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        print('Jina fallback failed with status ${response.statusCode}');
        return [];
      }

      print('Jina fallback response length: ${response.body.length} chars');
      final images = await _extractImagesFromInstagramHtml(response.body);
      if (images.isNotEmpty) {
        print('Jina fallback succeeded using ${images.length} image(s)');
      }
      return images;
    } on TimeoutException {
      print('Jina fallback timed out');
      return [];
    } catch (error) {
      print('Jina fallback error: ${error.toString()}');
      return [];
    }
  }

  static String _previewUrl(String url) {
    return url.length <= 80 ? url : '${url.substring(0, 80)}...';
  }

  static String _sanitizeInstagramUrl(String value) {
    var sanitized = value
        .replaceAll('\\u0026', '&')
        .replaceAll('\\/', '/')
        .replaceAll('&amp;', '&')
        .trim();
    if (sanitized.isEmpty) {
      return '';
    }

    if (sanitized.contains('ig_cache_key')) {
      return sanitized;
    }

    return _normalizeInstagramCdnUrl(sanitized);
  }

  static String _normalizeInstagramCdnUrl(String url) {
    var normalized = url;
    normalized = normalized.replaceAll('c288.0.864.864a_', '');
    normalized = normalized.replaceAll('s640x640_', '');
    normalized = normalized.replaceAll(RegExp(r'_s\d+x\d+'), '');
    return normalized;
  }

  /// Download image from URL and return as XFile
  static Future<XFile?> downloadExternalImage(String imageUrl) =>
      _downloadImage(imageUrl);

  static Future<XFile?> _downloadImage(String imageUrl) async {
    try {
      print('Downloading image from: $imageUrl');

      final imageResponse = await http
          .get(
            Uri.parse(imageUrl),
            headers: {
              'User-Agent': _userAgent,
              'Referer': 'https://www.instagram.com/',
            },
          )
          .timeout(const Duration(seconds: 10)); // Timeout for image download

      if (imageResponse.statusCode != 200) {
        print('Failed to download image: ${imageResponse.statusCode}');
        return null;
      }

      print(
        'Image downloaded successfully, size: ${imageResponse.bodyBytes.length} bytes',
      );

      // Save image to temporary file
      final tempDir = Directory.systemTemp;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'instagram_image_$timestamp.jpg';
      final file = File('${tempDir.path}/$fileName');

      await file.writeAsBytes(imageResponse.bodyBytes);
      print('Image saved to: ${file.path}');

      return XFile(file.path);
    } catch (e) {
      print('Error downloading image: $e');
      return null;
    }
  }

  /// Extracts image URLs from Instagram post URL and downloads the images
  /// Returns a list of XFile objects - single item for regular posts, multiple items for carousels
  static Future<List<XFile>> downloadImageFromInstagramUrl(
    String instagramUrl,
  ) async {
    try {
      print('Fetching Instagram post using ScrapingBee API: $instagramUrl');

      final apiKey = AppConstants.scrapingBeeApiKey;
      if (apiKey.isEmpty ||
          apiKey.startsWith('your_') ||
          apiKey.contains('***')) {
        print('❌ ScrapingBee API key not configured');
        return [];
      }

      final result = await _scrapingBeeInstagramScraper(instagramUrl);
      if (result.isNotEmpty) {
        print(
          '✅ Successfully extracted ${result.length} image(s) using ScrapingBee!',
        );
        return result;
      }

      print('❌ ScrapingBee failed to extract images');
      return [];
    } catch (e) {
      print('❌ Error downloading Instagram images: $e');
      return [];
    }
  }

  /// Checks if a URL is an Instagram post URL
  static bool isInstagramUrl(String url) {
    return url.contains('instagram.com/p/') ||
        url.contains('instagram.com/reel/');
  }
}

class _ScrapingBeeAttempt {
  const _ScrapingBeeAttempt({
    required this.waitMilliseconds,
    required this.timeout,
    this.usePremiumProxy = false,
  });

  final int waitMilliseconds;
  final Duration timeout;
  final bool usePremiumProxy;
}
