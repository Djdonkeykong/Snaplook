import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';

class InstagramServiceZyteBackup {
  static const String _userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  // Zyte API configuration (primary method)
  static const String _zyteApiToken = 'b91b55a75fdf41069a2879c573e6d74e';
  static const String _zyteApiUrl = 'https://api.zyte.com/v1/extract';

  /// Zyte API Instagram scraper with speed optimizations
  static Future<XFile?> _zyteInstagramScraper(String instagramUrl) async {
    try {
      print('Attempting Zyte API Instagram scraper for URL: $instagramUrl');

      final requestBody = {
        'url': instagramUrl,
        'browserHtml': true, // Instagram needs JS rendering
        'actions': [
          {
            'action': 'waitForTimeout',
            'timeout': 3, // Back to original 3s that was working
          }
        ],
      };

      final response = await http.post(
        Uri.parse(_zyteApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic ${base64Encode(utf8.encode('$_zyteApiToken:'))}',
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 8)); // 8 second total timeout for speed

      if (response.statusCode != 200) {
        print('Failed to get Zyte API response: ${response.statusCode}');
        print('Response: ${response.body}');
        return null;
      }

      final responseData = json.decode(response.body);
      final htmlContent = responseData['browserHtml'];

      if (htmlContent == null) {
        print('No HTML content found in Zyte response');
        return null;
      }

      // Parse HTML to extract Instagram image
      final document = html_parser.parse(htmlContent);

      // PRIORITY 1: Look for display_url in script tags (full quality image)
      final scriptElements = document.querySelectorAll('script');
      for (final script in scriptElements) {
        final scriptContent = script.text;

        // Look for display_url pattern (highest quality)
        if (scriptContent.contains('"display_url"')) {
          final displayUrlMatch = RegExp(r'"display_url":"([^"]+)"').firstMatch(scriptContent);
          if (displayUrlMatch != null) {
            var imageUrl = displayUrlMatch.group(1);
            if (imageUrl != null) {
              imageUrl = imageUrl.replaceAll(r'\u0026', '&');
              print('Zyte API found display_url in script: $imageUrl');
              return await _downloadImage(imageUrl);
            }
          }
        }

        // Alternative: Look for displayUrl pattern
        if (scriptContent.contains('"displayUrl"')) {
          final displayUrlMatch = RegExp(r'"displayUrl":"([^"]+)"').firstMatch(scriptContent);
          if (displayUrlMatch != null) {
            var imageUrl = displayUrlMatch.group(1);
            if (imageUrl != null) {
              imageUrl = imageUrl.replaceAll(r'\u0026', '&');
              print('Zyte API found displayUrl in script: $imageUrl');
              return await _downloadImage(imageUrl);
            }
          }
        }

        // Alternative: Look for src pattern in media objects
        if (scriptContent.contains('edge_media_to_caption') && scriptContent.contains('"src"')) {
          final srcMatches = RegExp(r'"src":"([^"]*\.jpg[^"]*)"').allMatches(scriptContent);
          for (final match in srcMatches) {
            var imageUrl = match.group(1);
            if (imageUrl != null && imageUrl.contains('instagram') && !imageUrl.contains('150x150')) {
              imageUrl = imageUrl.replaceAll(r'\u0026', '&');
              print('Zyte API found src in media script: $imageUrl');
              return await _downloadImage(imageUrl);
            }
          }
        }
      }

      // PRIORITY 2: Look for high-res images in img tags
      final imgElements = document.querySelectorAll('img');
      for (final img in imgElements) {
        final src = img.attributes['src'] ?? img.attributes['srcset'];
        if (src != null && src.contains('instagram') && src.contains('.jpg') && !src.contains('150x150') && !src.contains('profile')) {
          print('Zyte API found img src: $src');
          return await _downloadImage(src);
        }
      }

      print('No image URL found in Zyte API results');
      return null;

    } catch (e) {
      print('Zyte API Instagram scraper error: $e');
      return null;
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

  /// Extracts image URL from Instagram post URL and downloads the image
  static Future<XFile?> downloadImageFromInstagramUrl(String instagramUrl) async {
    try {
      print('Fetching Instagram post using Zyte API: $instagramUrl');

      if (_zyteApiToken.isEmpty || _zyteApiToken.startsWith('your_') || _zyteApiToken.contains('***')) {
        print('❌ Zyte API token not configured');
        return null;
      }

      final result = await _zyteInstagramScraper(instagramUrl);
      if (result != null) {
        print('✅ Successfully extracted image using Zyte API!');
        return result;
      }

      print('❌ Zyte API failed to extract image');
      return null;

    } catch (e) {
      print('❌ Error downloading Instagram image: $e');
      return null;
    }
  }


  /// Checks if a URL is an Instagram post URL
  static bool isInstagramUrl(String url) {
    return url.contains('instagram.com/p/') || url.contains('instagram.com/reel/');
  }
}