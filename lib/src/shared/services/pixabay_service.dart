import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PixabayService {
  static const String _baseUrl = 'https://pixabay.com/api/';
  final String _apiKey = dotenv.env['PIXABAY_API_KEY'] ?? '';

  static const List<String> fashionQueries = [
    'fashion',
    'street+style',
    'outfit',
    'clothing',
    'style',
    'streetwear',
  ];

  Future<List<Map<String, dynamic>>> fetchFashionPhotos({
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      // Rotate through different fashion queries
      final query = fashionQueries[page % fashionQueries.length];

      final response = await http.get(
        Uri.parse(_baseUrl).replace(queryParameters: {
          'key': _apiKey,
          'q': query,
          'page': page.toString(),
          'per_page': perPage.toString(),
          'orientation': 'vertical',
          'category': 'fashion',
          'image_type': 'photo',
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['hits'] as List;

        return results.map((photo) {
          return {
            'id': photo['id'].toString(),
            'external_id': photo['id'].toString(),
            'source': 'pixabay',
            'image_url': photo['largeImageURL'],
            'thumbnail_url': photo['webformatURL'],
            'photographer_name': photo['user'],
            'photographer_url': 'https://pixabay.com/users/${photo['user']}-${photo['user_id']}',
            'description': photo['tags'] ?? 'Fashion Photo',
            'width': photo['imageWidth'],
            'height': photo['imageHeight'],
            'title': photo['tags'] ?? 'Fashion Inspiration',
          };
        }).toList();
      } else {
        print('Pixabay API error: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error fetching Pixabay photos: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchPopularFashion({
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(_baseUrl).replace(queryParameters: {
          'key': _apiKey,
          'q': 'fashion',
          'page': page.toString(),
          'per_page': perPage.toString(),
          'orientation': 'vertical',
          'category': 'fashion',
          'image_type': 'photo',
          'order': 'popular',
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['hits'] as List;

        return results.map((photo) {
          return {
            'id': photo['id'].toString(),
            'external_id': photo['id'].toString(),
            'source': 'pixabay',
            'image_url': photo['largeImageURL'],
            'thumbnail_url': photo['webformatURL'],
            'photographer_name': photo['user'],
            'photographer_url': 'https://pixabay.com/users/${photo['user']}-${photo['user_id']}',
            'description': photo['tags'] ?? 'Fashion Photo',
            'width': photo['imageWidth'],
            'height': photo['imageHeight'],
            'title': photo['tags'] ?? 'Fashion Inspiration',
          };
        }).toList();
      } else {
        print('Pixabay API error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching Pixabay popular photos: $e');
      return [];
    }
  }
}
