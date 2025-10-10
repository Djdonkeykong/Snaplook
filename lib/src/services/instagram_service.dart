import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';

class InstagramService {
  static const String _userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  // ScrapingBee API configuration
  static const String _scrapingBeeApiKey = 'MBVJU10S1A0YUDAMPSUBIVSPGPA6MIJ5R1HNXZBSRQSDD06JH6K8UK74XZF9N8AISFWXTOLQH3U37NZF';
  static const String _scrapingBeeApiUrl = 'https://app.scrapingbee.com/api/v1/';

  /// ScrapingBee Instagram scraper with smart image quality detection
  /// Returns a list of XFile objects for carousel posts, or single item list for single posts
  static Future<List<XFile>> _scrapingBeeInstagramScraper(String instagramUrl) async {
    try {
      print('Attempting ScrapingBee Instagram scraper for URL: $instagramUrl');

      final uri = Uri.parse(_scrapingBeeApiUrl);
      final queryParams = {
        'api_key': _scrapingBeeApiKey,
        'url': instagramUrl,
        'render_js': 'true', // Instagram needs JS rendering
        'wait': '2000', // Optimal 2s wait for best speed/reliability balance
        // Removed premium_proxy and country_code to save 80% on costs (5 vs 25 credits)
      };

      final requestUri = uri.replace(queryParameters: queryParams);
      final response = await http.get(requestUri).timeout(const Duration(seconds: 8)); // Reduced timeout for faster failures

      if (response.statusCode != 200) {
        print('Failed to get ScrapingBee API response: ${response.statusCode}');
        print('Response: ${response.body}');
        return [];
      }

      final htmlContent = response.body;
      print('ScrapingBee response received, HTML length: ${htmlContent.length} chars');

      // Parse HTML to extract Instagram image
      final document = html_parser.parse(htmlContent);

      // PRIORITY 1: Look for carousel images using comprehensive approach
      List<String> carouselImageUrls = [];

      // Method 1: Find all li elements with translateX transform (more comprehensive)
      final allListItems = document.querySelectorAll('li');
      final carouselItems = allListItems.where((li) =>
        li.attributes['style']?.contains('translateX') == true
      ).toList();

      print('Found ${carouselItems.length} carousel items with translateX');

      if (carouselItems.length >= 2) {
        // Multi-image carousel post
        print('Detected carousel post with ${carouselItems.length} potential images');

        for (int i = 0; i < carouselItems.length; i++) {
          final carouselItem = carouselItems[i];
          final style = carouselItem.attributes['style'] ?? '';

          // Skip the first item if it's a navigation placeholder (width: 1px)
          if (style.contains('width: 1px')) {
            print('Skipping navigation placeholder item ${i + 1}');
            continue;
          }

          final img = carouselItem.querySelector('img');
          if (img != null) {
            final src = img.attributes['src'];
            if (src != null && src.contains('.jpg') && !src.contains('150x150') && !src.contains('profile')) {
              carouselImageUrls.add(src);
              print('Carousel image ${carouselImageUrls.length}: ${src.substring(0, 80)}...');
            }
          }
        }
      }

      // Fallback: If no carousel found with translateX, try original li._acaz method
      if (carouselImageUrls.isEmpty) {
        print('No translateX carousel found, trying li._acaz fallback');
        final acazItems = document.querySelectorAll('li._acaz');
        print('Found ${acazItems.length} li._acaz items');

        for (int i = 0; i < acazItems.length; i++) {
          final carouselItem = acazItems[i];
          final img = carouselItem.querySelector('img');

          if (img != null) {
            final src = img.attributes['src'];
            if (src != null && src.contains('.jpg') && !src.contains('150x150') && !src.contains('profile')) {
              carouselImageUrls.add(src);
              print('Fallback carousel image ${i + 1}: ${src.substring(0, 80)}...');
            }
          }
        }
      }

      // If no carousel found, fall back to single image detection
      if (carouselImageUrls.isEmpty) {
        print('No carousel detected, looking for single image');

        final imgElements = document.querySelectorAll('img');
        print('Found ${imgElements.length} img tags');

        // Find the best quality image from img tags using smart scoring
        String? bestImageUrl;
        int bestQualityScore = 0;

        for (final img in imgElements) {
          final src = img.attributes['src'];
          if (src != null && src.contains('.jpg')) {
            // Score image quality based on URL patterns
            int qualityScore = 0;

            // High resolution indicators in URL
            if (src.contains('1440x') || src.contains('1080x')) qualityScore += 100;
            if (src.contains('800x') || src.contains('640x')) qualityScore += 50;
            if (src.contains('150x150')) qualityScore -= 100; // Avoid thumbnails

            // Instagram CDN URLs are good
            if (src.contains('instagram.') || src.contains('fbcdn.net')) qualityScore += 20;

            // Longer URLs often have more parameters (higher quality)
            if (src.length > 200) qualityScore += 10;

            // Avoid profile pictures
            if (src.contains('profile')) qualityScore -= 50;

            print('ScrapingBee img quality score: $qualityScore for ${src.substring(0, 80)}...');

            if (qualityScore > bestQualityScore) {
              bestQualityScore = qualityScore;
              bestImageUrl = src;
            }
          }
        }

        if (bestImageUrl != null) {
          carouselImageUrls.add(bestImageUrl);
          print('ScrapingBee found single high-quality img (score $bestQualityScore)');
        }
      }

      // Download all found images
      if (carouselImageUrls.isNotEmpty) {
        List<XFile> downloadedImages = [];

        for (int i = 0; i < carouselImageUrls.length; i++) {
          final imageUrl = carouselImageUrls[i];
          print('Downloading image ${i + 1}/${carouselImageUrls.length}: ${imageUrl.substring(0, 80)}...');

          final downloadedImage = await _downloadImage(imageUrl);
          if (downloadedImage != null) {
            downloadedImages.add(downloadedImage);
          }
        }

        if (downloadedImages.isNotEmpty) {
          print('ScrapingBee successfully downloaded ${downloadedImages.length} images');
          return downloadedImages;
        }
      }

      // PRIORITY 2: Look for display_url in script tags as fallback
      final scriptElements = document.querySelectorAll('script');
      for (final script in scriptElements) {
        final scriptContent = script.text;

        if (scriptContent.contains('"display_url"')) {
          final displayUrlMatch = RegExp(r'"display_url":"([^"]+)"').firstMatch(scriptContent);
          if (displayUrlMatch != null) {
            var imageUrl = displayUrlMatch.group(1);
            if (imageUrl != null) {
              imageUrl = imageUrl.replaceAll(r'\u0026', '&');
              print('ScrapingBee found display_url in script (fallback): $imageUrl');
              final fallbackImage = await _downloadImage(imageUrl);
              if (fallbackImage != null) {
                return [fallbackImage];
              }
            }
          }
        }
      }

      // PRIORITY 3: og:image as last resort
      final ogImageElement = document.querySelector('meta[property="og:image"]');
      if (ogImageElement != null) {
        final imageUrl = ogImageElement.attributes['content'];
        if (imageUrl != null) {
          print('ScrapingBee found og:image (last resort): $imageUrl');
          final lastResortImage = await _downloadImage(imageUrl);
          if (lastResortImage != null) {
            return [lastResortImage];
          }
        }
      }

      print('No image URL found in ScrapingBee results');
      return [];

    } catch (e) {
      print('ScrapingBee Instagram scraper error: $e');
      return [];
    }
  }



  /// Download image from URL and return as XFile
  static Future<XFile?> _downloadImage(String imageUrl) async {
    try {
      print('Downloading image from: $imageUrl');

      final imageResponse = await http.get(
        Uri.parse(imageUrl),
        headers: {
          'User-Agent': _userAgent,
          'Referer': 'https://www.instagram.com/',
        },
      ).timeout(const Duration(seconds: 10)); // Timeout for image download

      if (imageResponse.statusCode != 200) {
        print('Failed to download image: ${imageResponse.statusCode}');
        return null;
      }

      print('Image downloaded successfully, size: ${imageResponse.bodyBytes.length} bytes');

      // Save image to temporary file
      final tempDir = await getTemporaryDirectory();
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
  static Future<List<XFile>> downloadImageFromInstagramUrl(String instagramUrl) async {
    try {
      print('Fetching Instagram post using ScrapingBee API: $instagramUrl');

      if (_scrapingBeeApiKey.isEmpty || _scrapingBeeApiKey.startsWith('your_') || _scrapingBeeApiKey.contains('***')) {
        print('❌ ScrapingBee API key not configured');
        return [];
      }

      final result = await _scrapingBeeInstagramScraper(instagramUrl);
      if (result.isNotEmpty) {
        print('✅ Successfully extracted ${result.length} image(s) using ScrapingBee!');
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
    return url.contains('instagram.com/p/') || url.contains('instagram.com/reel/');
  }
}