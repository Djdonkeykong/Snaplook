import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:image/image.dart' as img;
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

    // Standard proxy only (5 credits) - no premium retry
    final queryParams = {
      'api_key': AppConstants.scrapingBeeApiKey,
      'url': instagramUrl,
      'render_js': 'true',
      'wait': '1500',
    };

    final requestUri = uri.replace(queryParameters: queryParams);
    print('ScrapingBee Instagram request (wait=1500ms, timeout=12s)');

    http.Response response;
    try {
      response =
          await http.get(requestUri).timeout(const Duration(seconds: 12));
    } on TimeoutException {
      print('ScrapingBee Instagram request timed out');
      return [];
    } catch (error) {
      print('ScrapingBee Instagram request error: ${error.toString()}');
      return [];
    }

    if (response.statusCode != 200) {
      print('ScrapingBee Instagram failed with status ${response.statusCode}');
      print('Response: ${response.body}');
      return [];
    }

    final htmlContent = response.body;
    print(
        'ScrapingBee Instagram response received, HTML length: ${htmlContent.length} chars');

    final images = await _extractImagesFromInstagramHtml(htmlContent);
    if (images.isNotEmpty) {
      return images;
    }

    print('No usable images extracted - trying Jina AI fallback');
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
    final seenUrls = <String>{};

    Future<XFile?> tryDownload(String? url, {String label = ''}) async {
      if (url == null || url.isEmpty) return null;
      final sanitized = _sanitizeInstagramUrl(url);
      if (sanitized.isEmpty ||
          seenUrls.contains(sanitized) ||
          sanitized.contains('150x150') ||
          sanitized.contains('profile')) {
        return null;
      }
      seenUrls.add(sanitized);
      if (label.isNotEmpty) {
        print('$label: ${_previewUrl(sanitized)}');
      }
      return await _downloadImage(sanitized);
    }

    // Fast path: first ig_cache_key in JSON
    final cacheKeyMatch = RegExp(
      r'"src":"(https:\\/\\/scontent[^"]+?ig_cache_key[^"]*)"',
    ).firstMatch(htmlContent);
    final cacheDownload =
        await tryDownload(cacheKeyMatch?.group(1), label: 'Found ig_cache_key URL (priority)');
    if (cacheDownload != null) return [cacheDownload];

    // Fast path: first display_url
    final displayMatch = RegExp(
      r'"display_url"\s*:\s*"([^"]+)"',
    ).firstMatch(htmlContent);
    final displayDownload =
        await tryDownload(displayMatch?.group(1), label: 'Found display_url');
    if (displayDownload != null) return [displayDownload];

    // img tags (limit to first 5 matches) - only take ig_cache_key variants to avoid low-quality/blocked URLs
    final imgPattern = RegExp(
      r'<img[^>]+src="([^"]+)"',
      caseSensitive: false,
    );
    final imgMatches = imgPattern.allMatches(htmlContent).take(5).toList();
    for (final match in imgMatches) {
      final url = match.group(1);
      final isCache = url != null && url.contains('ig_cache_key');
      if (!isCache) continue;
      final download = await tryDownload(
        url,
        label: 'Found img ig_cache_key URL (priority)',
      );
      if (download != null) return [download];
    }

    // Pattern 4: og:image meta tag (fallback, matches iOS)
    final ogImagePattern = RegExp(
      r'<meta property="og:image" content="([^"]+)"',
      caseSensitive: false,
    );
    final ogMatch = ogImagePattern.firstMatch(htmlContent);
    if (ogMatch != null) {
      final url = ogMatch.group(1);
      final download =
          await tryDownload(url, label: 'Found og:image (fallback)');
      if (download != null) {
        return [download];
      }
    }

    return [];
  }

  static Future<List<XFile>> _scrapeInstagramViaJina(
    String instagramUrl,
  ) async {
    try {
      final proxyUri = Uri.parse('$_jinaProxyBase$instagramUrl');
      final response = await http.get(proxyUri, headers: {
        'User-Agent': _userAgent
      }).timeout(const Duration(seconds: 10));

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

  static String _sanitizeTikTokUrl(String value) {
    return value
        .replaceAll('\\u0026', '&')
        .replaceAll('\\/', '/')
        .replaceAll('&amp;', '&')
        .trim();
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

  static Future<XFile?> _downloadImage(
    String imageUrl, {
    double? cropToAspectRatio,
  }) async {
    try {
      print('Downloading image from: $imageUrl');

      final uri = Uri.tryParse(imageUrl);
      final host = uri?.host.toLowerCase() ?? '';
      String refererHeader = 'https://www.instagram.com/';
      if (!host.contains('insta')) {
        refererHeader = uri != null ? '${uri.scheme}://${uri.host}/' : '';
      }

      final imageResponse = await http.get(
        Uri.parse(imageUrl),
        headers: {
          'User-Agent': _userAgent,
          if (refererHeader.isNotEmpty) 'Referer': refererHeader,
        },
      ).timeout(const Duration(seconds: 10)); // Timeout for image download

      if (imageResponse.statusCode != 200) {
        print('Failed to download image: ${imageResponse.statusCode}');
        return null;
      }

      print(
        'Image downloaded successfully, size: ${imageResponse.bodyBytes.length} bytes',
      );

      // Optionally crop to a target aspect ratio (e.g., 9:16 for Shorts thumbnails)
      Uint8List imageBytes = Uint8List.fromList(imageResponse.bodyBytes);
      if (cropToAspectRatio != null) {
        final decoded = img.decodeImage(imageBytes);
        if (decoded != null && decoded.width > 0 && decoded.height > 0) {
          final currentAspect = decoded.width / decoded.height;
          if ((currentAspect - cropToAspectRatio).abs() > 0.01) {
            // Too wide: crop width; too tall: crop height.
            int cropWidth = decoded.width;
            int cropHeight = decoded.height;
            int offsetX = 0;
            int offsetY = 0;

            if (currentAspect > cropToAspectRatio) {
              cropWidth = (decoded.height * cropToAspectRatio).round();
              offsetX = ((decoded.width - cropWidth) / 2)
                  .round()
                  .clamp(0, decoded.width - cropWidth)
                  .toInt();
            } else {
              cropHeight = (decoded.width / cropToAspectRatio).round();
              offsetY = ((decoded.height - cropHeight) / 2)
                  .round()
                  .clamp(0, decoded.height - cropHeight)
                  .toInt();
            }

            final cropped = img.copyCrop(
              decoded,
              x: offsetX,
              y: offsetY,
              width: cropWidth,
              height: cropHeight,
            );
            imageBytes = Uint8List.fromList(
              img.encodeJpg(cropped, quality: 90),
            );
            print(
              'Cropped image to aspect ${cropToAspectRatio.toStringAsFixed(2)} -> ${cropWidth}x$cropHeight',
            );
          }
        } else {
          print('Skipping crop: unable to decode image');
        }
      }

      // Save image to temporary file
      final tempDir = Directory.systemTemp;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'instagram_image_$timestamp.jpg';
      final file = File('${tempDir.path}/$fileName');

      await file.writeAsBytes(imageBytes);
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

  /// Checks if a URL is a TikTok video URL
  static bool isTikTokUrl(String url) {
    final lowercased = url.toLowerCase();
    return lowercased.contains('tiktok.com/') &&
        (lowercased.contains('/video/') ||
            lowercased.contains('/@') ||
            lowercased.contains('/t/'));
  }

  /// Checks if a URL is a Pinterest pin URL
  static bool isPinterestUrl(String url) {
    final lowercased = url.toLowerCase();
    return lowercased.contains('pinterest.com/pin/') ||
        lowercased.contains('pin.it/');
  }

  /// Checks if a URL is a YouTube Shorts/Video URL
  static bool isYouTubeUrl(String url) {
    final lowercased = url.toLowerCase();
    if (!lowercased.contains('youtube.com') &&
        !lowercased.contains('youtu.be')) {
      return false;
    }

    return lowercased.contains('/shorts/') ||
        lowercased.contains('watch?v=') ||
        lowercased.contains('youtu.be/') ||
        lowercased.contains('/embed/');
  }

  /// Downloads image from TikTok video URL using ScrapingBee
  /// Uses priority-based extraction to get the video thumbnail
  static Future<List<XFile>> downloadImageFromTikTokUrl(
    String tiktokUrl,
  ) async {
    final resolvedUrl = await _resolveTikTokRedirect(tiktokUrl) ?? tiktokUrl;

    // Free path: TikTok oEmbed exposes a direct thumbnail without credits.
    final oembedThumb = await _fetchTikTokOembedThumbnail(resolvedUrl);
    if (oembedThumb != null) {
      final oembedImage = await _downloadImage(
        oembedThumb,
        cropToAspectRatio: 9 / 16,
      );
      if (oembedImage != null) {
        print('Successfully downloaded TikTok thumbnail via oEmbed');
        return [oembedImage];
      } else {
        print('TikTok oEmbed thumbnail download failed, falling back to ScrapingBee');
      }
    }

    // Free fallback: fetch via Jina proxy and parse HTML.
    final jinaImages = await _scrapeTikTokViaJina(resolvedUrl);
    if (jinaImages.isNotEmpty) {
      return jinaImages;
    }

    print('No usable TikTok images extracted');
    return [];
  }

  static Future<String?> _fetchTikTokOembedThumbnail(String tiktokUrl) async {
    try {
      final resolvedUrl = await _resolveTikTokRedirect(tiktokUrl) ?? tiktokUrl;

      final oembedUri = Uri.https(
        'www.tiktok.com',
        '/oembed',
        {'url': resolvedUrl},
      );
      final response = await http
          .get(
            oembedUri,
            headers: {
              'User-Agent': _userAgent,
            },
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        print('TikTok oEmbed request failed with ${response.statusCode}');
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final thumb = (decoded['thumbnail_url'] ??
                decoded['thumbnailUrl'] ??
                decoded['thumbnailURL'])
            as String?;
        if (thumb != null && thumb.isNotEmpty) {
          final sanitized = _sanitizeTikTokUrl(thumb);
          print('TikTok oEmbed thumbnail: ${_previewUrl(sanitized)}');
          return sanitized;
        }
      }
    } on TimeoutException {
      print('TikTok oEmbed request timed out');
    } catch (e) {
      print('TikTok oEmbed error: $e');
    }
    return null;
  }

  static Future<List<XFile>> _scrapeTikTokViaJina(String tiktokUrl) async {
    try {
      final proxyUri = Uri.parse('$_jinaProxyBase$tiktokUrl');
      final response = await http.get(proxyUri, headers: {
        'User-Agent': _userAgent,
      }).timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        print('TikTok Jina fallback failed with status ${response.statusCode}');
        return [];
      }

      print('TikTok Jina fallback response length: ${response.body.length} chars');
      final images = await _extractImagesFromTikTokHtml(response.body);
      if (images.isNotEmpty) {
        print('TikTok Jina fallback succeeded using ${images.length} image(s)');
      }
      return images;
    } on TimeoutException {
      print('TikTok Jina fallback timed out');
      return [];
    } catch (e) {
      print('TikTok Jina fallback error: $e');
      return [];
    }
  }

  static Future<String?> _resolveTikTokRedirect(String url) async {
    try {
      final uri = Uri.parse(url);
      final request = http.Request('GET', uri);
      request.followRedirects = true;
      request.maxRedirects = 5;
      final client = http.Client();
      final response = await client.send(request).timeout(const Duration(seconds: 8));
      client.close();
      final finalUrl = response.request?.url.toString();
      if (finalUrl != null && finalUrl.isNotEmpty && finalUrl != url) {
        print('Resolved TikTok URL redirect: ${_previewUrl(finalUrl)}');
        return finalUrl;
      }
    } catch (e) {
      print('TikTok redirect resolution failed: $e');
    }
    return null;
  }

  /// Extract images from TikTok HTML with priority-based selection
  /// Matches iOS share extension patterns that work successfully
  static Future<List<XFile>> _extractImagesFromTikTokHtml(
    String htmlContent,
  ) async {
    final priorityResults = <String>[];
    final fallbackResults = <String>[];
    final seenUrls = <String>{};

    // Pattern 1: High-quality tplv-tiktokx-origin.image with src attribute (highest priority)
    // Matches iOS pattern: src="(https://[^"]*tiktokcdn[^"]*tplv-tiktokx-origin\.image[^"]*)"
    final originPattern = RegExp(
      r'src="(https://[^"]*tiktokcdn[^"]*tplv-tiktokx-origin\.image[^"]*)"',
    );
    final originMatches = originPattern.allMatches(htmlContent).toList();
    print(
        'Pattern 1 (src + tplv-tiktokx-origin): ${originMatches.length} matches');
    for (final match in originMatches) {
      var url = match.group(1);
      if (url != null) {
        // Sanitize HTML entities in URL
        url = _sanitizeTikTokUrl(url);
        if (!seenUrls.contains(url)) {
          // Filter out avatars and small images
          if (!url.contains('avt-') &&
              !url.contains('100x100') &&
              !url.contains('cropcenter') &&
              !url.contains('music')) {
            seenUrls.add(url);
            priorityResults.add(url);
            print('Found priority TikTok image: ${_previewUrl(url)}');
          }
        }
      }
    }

    // If we found high-quality images, use them
    if (priorityResults.isNotEmpty) {
      for (final imageUrl in priorityResults.take(1)) {
        final downloadedImage = await _downloadImage(imageUrl);
        if (downloadedImage != null) {
          return [downloadedImage];
        }
      }
    }

    // Pattern 2: poster attribute with tiktokcdn URL
    // Matches iOS pattern: poster="(https://[^"]*tiktokcdn[^"]*)"
    final posterPattern = RegExp(
      r'poster="(https://[^"]*tiktokcdn[^"]*)"',
    );
    final posterMatches = posterPattern.allMatches(htmlContent).toList();
    print('Pattern 2 (poster + tiktokcdn): ${posterMatches.length} matches');
    for (final match in posterMatches) {
      var url = match.group(1);
      if (url != null) {
        url = _sanitizeTikTokUrl(url);
        if (!seenUrls.contains(url)) {
          if (!url.contains('avt-') &&
              !url.contains('100x100') &&
              !url.contains('cropcenter') &&
              !url.contains('music')) {
            seenUrls.add(url);
            // Poster images are high priority (video thumbnails)
            priorityResults.add(url);
            print('Found poster TikTok image: ${_previewUrl(url)}');
          }
        }
      }
    }

    // Try poster images if we have them
    if (priorityResults.isNotEmpty) {
      for (final imageUrl in priorityResults) {
        final downloadedImage = await _downloadImage(imageUrl);
        if (downloadedImage != null) {
          return [downloadedImage];
        }
      }
    }

    // Pattern 3: img tag with src containing tiktokcdn
    // Matches iOS pattern: <img[^>]+src="(https://[^"]*tiktokcdn[^"]+)"
    final imgPattern = RegExp(
      r'<img[^>]+src="(https://[^"]*tiktokcdn[^"]+)"',
    );
    final imgMatches = imgPattern.allMatches(htmlContent).toList();
    print('Pattern 3 (img src + tiktokcdn): ${imgMatches.length} matches');
    for (final match in imgMatches) {
      var url = match.group(1);
      if (url != null) {
        url = _sanitizeTikTokUrl(url);
        if (!seenUrls.contains(url)) {
          if (!url.contains('avt-') &&
              !url.contains('100x100') &&
              !url.contains('cropcenter') &&
              !url.contains('music')) {
            seenUrls.add(url);
            fallbackResults.add(url);
            print('Found img src TikTok image: ${_previewUrl(url)}');
          }
        }
      }
    }

    // Check if tiktokcdn exists at all in the HTML
    if (htmlContent.contains('tiktokcdn')) {
      print('HTML contains "tiktokcdn" - checking for patterns');
      // Debug: show sample of how tiktokcdn appears in the HTML
      final contextPattern = RegExp(r'.{0,40}tiktokcdn.{0,80}');
      final contextMatches =
          contextPattern.allMatches(htmlContent).take(3).toList();
      for (final match in contextMatches) {
        print('  Context: ${match.group(0)}');
      }
    } else {
      print('HTML does NOT contain "tiktokcdn"');
    }

    // Pattern 4: og:image meta tag - try both attribute orders
    print('Checking for og:image in HTML...');
    if (htmlContent.contains('og:image')) {
      print('HTML contains "og:image"');
    } else {
      print('HTML does NOT contain "og:image"');
    }
    final ogImagePatterns = [
      RegExp(r'property="og:image"\s*content="([^"]+)"'),
      RegExp(r'content="([^"]+)"\s*property="og:image"'),
      RegExp(r"property='og:image'\s*content='([^']+)'"),
      RegExp(r"content='([^']+)'\s*property='og:image'"),
    ];
    for (final pattern in ogImagePatterns) {
      final ogMatch = pattern.firstMatch(htmlContent);
      if (ogMatch != null) {
        final url = ogMatch.group(1);
        if (url != null && !seenUrls.contains(url)) {
          seenUrls.add(url);
          fallbackResults.add(url);
          print('Found og:image TikTok image: ${_previewUrl(url)}');
          break;
        }
      }
    }

    // Pattern 5: JSON-LD thumbnailUrl (TikTok often uses this)
    print('Checking for thumbnailUrl in HTML...');
    if (htmlContent.contains('thumbnailUrl')) {
      print('HTML contains "thumbnailUrl"');
    } else {
      print('HTML does NOT contain "thumbnailUrl"');
    }
    final thumbnailPattern = RegExp(
      r'"thumbnailUrl"\s*:\s*\[\s*"([^"]+)"',
    );
    final thumbMatch = thumbnailPattern.firstMatch(htmlContent);
    if (thumbMatch != null) {
      final url = thumbMatch.group(1);
      if (url != null && !seenUrls.contains(url)) {
        seenUrls.add(url);
        fallbackResults.add(url);
        print('Found JSON-LD thumbnail TikTok image: ${_previewUrl(url)}');
      }
    }

    // Pattern 6: contentUrl from JSON-LD
    final contentUrlPattern = RegExp(
      r'"contentUrl"\s*:\s*"([^"]+)"',
    );
    final contentMatch = contentUrlPattern.firstMatch(htmlContent);
    if (contentMatch != null) {
      final url = contentMatch.group(1);
      if (url != null && !seenUrls.contains(url) && url.contains('tiktokcdn')) {
        seenUrls.add(url);
        fallbackResults.add(url);
        print('Found JSON-LD contentUrl TikTok image: ${_previewUrl(url)}');
      }
    }

    print(
        'TikTok extraction results: ${priorityResults.length} priority, ${fallbackResults.length} fallback');

    // Pattern 7: Jina markdown/plaintext tiktokcdn URLs (photomode, etc.)
    // Pattern 7: Markdown/plaintext tiktokcdn URLs (photo mode, may lack file extension)
    // Pattern 7: Markdown/plaintext tiktokcdn URLs (photo mode, may lack extension)
    final markdownCdnPattern = RegExp(
      r'https?://\S*tiktokcdn\S*',
      caseSensitive: false,
    );
    final markdownMatches = markdownCdnPattern.allMatches(htmlContent).toList();
    if (markdownMatches.isNotEmpty) {
      print('Markdown/plaintext tiktokcdn URLs found: ${markdownMatches.length}');
    }
    for (final match in markdownMatches) {
      final url = match.group(0);
      if (url != null) {
        final sanitized = _sanitizeTikTokUrl(url);
        if (sanitized.isNotEmpty &&
            !seenUrls.contains(sanitized) &&
            !sanitized.contains('avt-') &&
            !sanitized.contains('100x100') &&
            !sanitized.contains('cropcenter') &&
            !sanitized.contains('music')) {
          seenUrls.add(sanitized);
          fallbackResults.add(sanitized);
          print('Found markdown TikTok image: ${_previewUrl(sanitized)}');
        }
      }
    }

    // Pattern 8: Markdown image syntax ![](url) capturing tiktokcdn URLs specifically
    final markdownImagePattern = RegExp(
      r'!\[[^\]]*\]\((https?://[^)]+tiktokcdn[^)]+)\)',
      caseSensitive: false,
    );
    final mdImageMatches = markdownImagePattern.allMatches(htmlContent).toList();
    if (mdImageMatches.isNotEmpty) {
      print('Markdown image tiktokcdn URLs found: ${mdImageMatches.length}');
    }
    for (final match in mdImageMatches) {
      final url = match.group(1);
      if (url != null) {
        final sanitized = _sanitizeTikTokUrl(url);
        if (sanitized.isNotEmpty &&
            !seenUrls.contains(sanitized) &&
            !sanitized.contains('avt-') &&
            !sanitized.contains('100x100') &&
            !sanitized.contains('cropcenter') &&
            !sanitized.contains('music')) {
          seenUrls.add(sanitized);
          fallbackResults.add(sanitized);
          print('Found markdown image TikTok URL: ${_previewUrl(sanitized)}');
        }
      }
    }

    // Try fallback images
    for (final imageUrl in fallbackResults.take(5)) {
      final downloadedImage = await _downloadImage(imageUrl);
      if (downloadedImage != null) {
        return [downloadedImage];
      }
    }

    return [];
  }

  /// Downloads image from Pinterest pin URL using ScrapingBee
  static Future<List<XFile>> downloadImageFromPinterestUrl(
    String pinterestUrl,
  ) async {
    try {
      print('Fetching Pinterest pin using ScrapingBee API: $pinterestUrl');

      final apiKey = AppConstants.scrapingBeeApiKey;
      if (apiKey.isEmpty ||
          apiKey.startsWith('your_') ||
          apiKey.contains('***')) {
        print('ScrapingBee API key not configured');
        return [];
      }

      final result = await _scrapingBeePinterestScraper(pinterestUrl);
      if (result.isNotEmpty) {
        print(
          'Successfully extracted ${result.length} image(s) from Pinterest using ScrapingBee!',
        );
        return result;
      }

      print('ScrapingBee failed to extract Pinterest images');
      return [];
    } catch (e) {
      print('Error downloading Pinterest images: $e');
      return [];
    }
  }

  /// ScrapingBee Pinterest scraper
  static Future<List<XFile>> _scrapingBeePinterestScraper(
    String pinterestUrl,
  ) async {
    print('Attempting ScrapingBee Pinterest scraper for URL: $pinterestUrl');

    final uri = Uri.parse(_scrapingBeeApiUrl);

    // Standard proxy with wait for Pinterest
    final queryParams = {
      'api_key': AppConstants.scrapingBeeApiKey,
      'url': pinterestUrl,
      'render_js': 'true',
      'wait': '2000',
    };

    final requestUri = uri.replace(queryParameters: queryParams);
    print('ScrapingBee Pinterest request (wait=2000ms)');

    http.Response response;
    try {
      response =
          await http.get(requestUri).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      print('ScrapingBee Pinterest request timed out');
      return [];
    } catch (error) {
      print('ScrapingBee Pinterest request error: ${error.toString()}');
      return [];
    }

    if (response.statusCode != 200) {
      print('ScrapingBee Pinterest failed with status ${response.statusCode}');
      print('Response: ${response.body}');
      return [];
    }

    final htmlContent = response.body;
    print(
        'ScrapingBee Pinterest response received, HTML length: ${htmlContent.length} chars');

    final images = await _extractImagesFromPinterestHtml(htmlContent);
    if (images.isNotEmpty) {
      return images;
    }

    print('No usable Pinterest images extracted');
    return [];
  }

  /// Extract images from Pinterest HTML
  static Future<List<XFile>> _extractImagesFromPinterestHtml(
    String htmlContent,
  ) async {
    final results = <String>[];
    final seenUrls = <String>{};

    // Pattern 1: High-resolution pinimg URLs (originals folder has highest quality)
    final originalsPattern = RegExp(
      r'src="(https://i\.pinimg\.com/originals/[^"]+)"',
    );
    for (final match in originalsPattern.allMatches(htmlContent)) {
      final url = match.group(1);
      if (url != null && !seenUrls.contains(url)) {
        seenUrls.add(url);
        results.add(url);
        print('Found Pinterest originals image: ${_previewUrl(url)}');
      }
    }

    // Pattern 2: 736x resolution (good quality, commonly used)
    final hdPattern = RegExp(
      r'src="(https://i\.pinimg\.com/736x/[^"]+)"',
    );
    for (final match in hdPattern.allMatches(htmlContent)) {
      final url = match.group(1);
      if (url != null && !seenUrls.contains(url)) {
        seenUrls.add(url);
        results.add(url);
        print('Found Pinterest 736x image: ${_previewUrl(url)}');
      }
    }

    // Pattern 3: 564x resolution (medium quality fallback)
    final medPattern = RegExp(
      r'src="(https://i\.pinimg\.com/564x/[^"]+)"',
    );
    for (final match in medPattern.allMatches(htmlContent)) {
      final url = match.group(1);
      if (url != null && !seenUrls.contains(url)) {
        seenUrls.add(url);
        results.add(url);
        print('Found Pinterest 564x image: ${_previewUrl(url)}');
      }
    }

    // Pattern 4: Any pinimg URL as fallback
    final anyPinimgPattern = RegExp(
      r'src="(https://i\.pinimg\.com/[^"]+\.(?:jpg|jpeg|png|webp))"',
    );
    for (final match in anyPinimgPattern.allMatches(htmlContent)) {
      final url = match.group(1);
      if (url != null && !seenUrls.contains(url)) {
        seenUrls.add(url);
        results.add(url);
        print('Found Pinterest pinimg image: ${_previewUrl(url)}');
      }
    }

    // Pattern 5: og:image meta tag
    final ogImagePattern = RegExp(
      r'<meta[^>]+property="og:image"[^>]+content="([^"]+)"',
      caseSensitive: false,
    );
    final ogMatch = ogImagePattern.firstMatch(htmlContent);
    if (ogMatch != null) {
      final url = ogMatch.group(1);
      if (url != null && !seenUrls.contains(url)) {
        seenUrls.add(url);
        results.add(url);
        print('Found Pinterest og:image: ${_previewUrl(url)}');
      }
    }

    print('Pinterest extraction results: ${results.length} images found');

    // Try to download images in order of quality
    for (final imageUrl in results.take(5)) {
      final downloadedImage = await _downloadImage(imageUrl);
      if (downloadedImage != null) {
        return [downloadedImage];
      }
    }

    return [];
  }

  /// Downloads image from a YouTube video/short by fetching thumbnails directly
  static Future<List<XFile>> downloadImageFromYouTubeUrl(
    String youtubeUrl,
  ) async {
    final shouldCropToPortrait = _isYouTubeShortsUrl(youtubeUrl);
    final videoId = _extractYouTubeVideoId(youtubeUrl);
    if (videoId == null || videoId.isEmpty) {
      print('Unable to extract YouTube video ID from $youtubeUrl');
      return [];
    }

    final thumbnailCandidates = _buildYouTubeThumbnailCandidates(videoId);
    print(
      'Attempting to download YouTube thumbnail for $videoId with ${thumbnailCandidates.length} candidates',
    );

    for (final candidate in thumbnailCandidates) {
      print('Trying YouTube thumbnail candidate: ${_previewUrl(candidate)}');
      final downloadedImage = await _downloadImage(
        candidate,
        cropToAspectRatio: shouldCropToPortrait ? 9 / 16 : null,
      );
      if (downloadedImage != null) {
        print(
            'Successfully downloaded YouTube thumbnail: ${_previewUrl(candidate)}');
        return [downloadedImage];
      }
    }

    print('Failed to download any YouTube thumbnail for video $videoId');
    return [];
  }

  static List<String> _buildYouTubeThumbnailCandidates(String videoId) {
    final jpgHosts = [
      'https://i.ytimg.com/vi',
      'https://img.youtube.com/vi',
    ];

    final jpgVariants = [
      'maxresdefault.jpg',
      'maxres1.jpg',
      'maxres2.jpg',
      'maxres3.jpg',
      'sddefault.jpg',
      'hq720.jpg',
      'hqdefault.jpg',
      'mqdefault.jpg',
    ];

    final candidates = <String>[];

    for (final host in jpgHosts) {
      for (final variant in jpgVariants) {
        candidates.add('$host/$videoId/$variant');
      }
    }

    // Live thumbnails sometimes use a dedicated suffix
    candidates.add('https://i.ytimg.com/vi/$videoId/maxresdefault_live.jpg');

    // WebP variants are added last as a final fallback
    candidates.add('https://i.ytimg.com/vi_webp/$videoId/maxresdefault.webp');
    candidates.add('https://i.ytimg.com/vi_webp/$videoId/hqdefault.webp');

    return candidates;
  }

  static bool _isYouTubeShortsUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('/shorts');
  }

  static String? _extractYouTubeVideoId(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();
      final segments =
          uri.pathSegments.where((segment) => segment.isNotEmpty).toList();

      if (host.contains('youtu.be')) {
        return segments.isNotEmpty ? segments.first : null;
      }

      if (uri.queryParameters.containsKey('v')) {
        return uri.queryParameters['v'];
      }

      final shortsIndex = segments.indexOf('shorts');
      if (shortsIndex != -1 && shortsIndex + 1 < segments.length) {
        return segments[shortsIndex + 1];
      }

      final embedIndex = segments.indexOf('embed');
      if (embedIndex != -1 && embedIndex + 1 < segments.length) {
        return segments[embedIndex + 1];
      }

      // Direct path /live/<id> etc (ignore /watch with no query)
      if (segments.isNotEmpty) {
        final candidate = segments.last;
        if (candidate.toLowerCase() != 'watch') {
          return candidate;
        }
      }
    } catch (e) {
      print('Error parsing YouTube URL $url: $e');
    }
    return null;
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
