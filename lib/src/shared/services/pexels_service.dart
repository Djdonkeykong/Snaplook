import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PexelsService {
  static const String _baseUrl = 'https://api.pexels.com/v1';
  final String _apiKey = dotenv.env['PEXELS_API_KEY'] ?? '';

  static const List<String> fashionQueries = [
    'fashion',
    'street style',
    'outfit',
    'style',
    'streetwear',
    'fashion model',
  ];

  Future<List<Map<String, dynamic>>> fetchFashionPhotos({
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      // Rotate through different fashion queries
      final query = fashionQueries[page % fashionQueries.length];

      final response = await http.get(
        Uri.parse('$_baseUrl/search').replace(queryParameters: {
          'query': query,
          'page': page.toString(),
          'per_page': perPage.toString(),
          'orientation': 'portrait',
        }),
        headers: {
          'Authorization': _apiKey,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['photos'] as List;

        return results.map((photo) {
          return {
            'id': photo['id'].toString(),
            'external_id': photo['id'].toString(),
            'source': 'pexels',
            'image_url': photo['src']['large2x'],
            'thumbnail_url': photo['src']['medium'],
            'photographer_name': photo['photographer'],
            'photographer_url': photo['photographer_url'],
            'description': photo['alt'] ?? 'Fashion Photo',
            'width': photo['width'],
            'height': photo['height'],
            'title': photo['alt'] ?? 'Fashion Inspiration',
          };
        }).toList();
      } else {
        print('Pexels API error: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error fetching Pexels photos: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchCuratedFashion({
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/curated').replace(queryParameters: {
          'page': page.toString(),
          'per_page': perPage.toString(),
        }),
        headers: {
          'Authorization': _apiKey,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['photos'] as List;

        return results.map((photo) {
          return {
            'id': photo['id'].toString(),
            'external_id': photo['id'].toString(),
            'source': 'pexels',
            'image_url': photo['src']['large2x'],
            'thumbnail_url': photo['src']['medium'],
            'photographer_name': photo['photographer'],
            'photographer_url': photo['photographer_url'],
            'description': photo['alt'] ?? 'Fashion Photo',
            'width': photo['width'],
            'height': photo['height'],
            'title': photo['alt'] ?? 'Fashion Inspiration',
          };
        }).toList();
      } else {
        print('Pexels API error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching Pexels curated photos: $e');
      return [];
    }
  }
}
