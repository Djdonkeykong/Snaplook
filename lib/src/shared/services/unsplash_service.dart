import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class UnsplashService {
  static const String _baseUrl = 'https://api.unsplash.com';
  final String _accessKey = dotenv.env['UNSPLASH_ACCESS_KEY'] ?? '';

  static const List<String> fashionQueries = [
    'fashion',
    'streetwear',
    'outfit',
    'style',
    'clothing',
    'streetstyle',
  ];

  Future<List<Map<String, dynamic>>> fetchFashionPhotos({
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      // Rotate through different fashion queries for variety
      final query = fashionQueries[page % fashionQueries.length];

      final response = await http.get(
        Uri.parse('$_baseUrl/search/photos').replace(queryParameters: {
          'query': query,
          'page': page.toString(),
          'per_page': perPage.toString(),
          'orientation': 'portrait',
          'content_filter': 'high',
        }),
        headers: {
          'Authorization': 'Client-ID $_accessKey',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List;

        return results.map((photo) {
          return {
            'id': photo['id'],
            'external_id': photo['id'],
            'source': 'unsplash',
            'image_url': photo['urls']['regular'],
            'thumbnail_url': photo['urls']['small'],
            'photographer_name': photo['user']['name'],
            'photographer_url': photo['user']['links']['html'],
            'description': photo['description'] ?? photo['alt_description'],
            'width': photo['width'],
            'height': photo['height'],
            'title': photo['alt_description'] ?? 'Fashion Inspiration',
          };
        }).toList();
      } else {
        print('Unsplash API error: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error fetching Unsplash photos: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchCuratedFashion({
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      // Unsplash curated photos endpoint
      final response = await http.get(
        Uri.parse('$_baseUrl/photos').replace(queryParameters: {
          'page': page.toString(),
          'per_page': perPage.toString(),
          'order_by': 'popular',
        }),
        headers: {
          'Authorization': 'Client-ID $_accessKey',
        },
      );

      if (response.statusCode == 200) {
        final results = json.decode(response.body) as List;

        return results.map((photo) {
          return {
            'id': photo['id'],
            'external_id': photo['id'],
            'source': 'unsplash',
            'image_url': photo['urls']['regular'],
            'thumbnail_url': photo['urls']['small'],
            'photographer_name': photo['user']['name'],
            'photographer_url': photo['user']['links']['html'],
            'description': photo['description'] ?? photo['alt_description'],
            'width': photo['width'],
            'height': photo['height'],
            'title': photo['alt_description'] ?? 'Fashion Inspiration',
          };
        }).toList();
      } else {
        print('Unsplash API error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching Unsplash curated photos: $e');
      return [];
    }
  }
}
