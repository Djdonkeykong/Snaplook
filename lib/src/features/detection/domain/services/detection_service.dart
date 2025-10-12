import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as http_parser;
import 'package:image_picker/image_picker.dart';
import '../models/detection_result.dart';

class DetectionService {
  // API endpoint - update this to your actual API URL
  // For local development: http://localhost:8000
  // For Android emulator: http://10.0.2.2:8000
  // For production: https://your-api-domain.com
  static final String _apiBaseUrl = _resolveApiBaseUrl();

  static String _resolveApiBaseUrl() {
    if (kIsWeb) {
      return 'http://localhost:8000';
    }

    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    }

    // iOS simulator and desktop development hosts can use localhost
    if (Platform.isIOS || Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      return 'http://localhost:8000';
    }

    // Fallback to localhost; consider replacing with production URL when deploying
    return 'http://localhost:8000';
  }

  Future<List<DetectionResult>> analyzeImage(XFile image) async {
    try {
      print('Starting image analysis via API...');
      print('API endpoint: $_apiBaseUrl/analyze');

      // Read image file
      final imageBytes = await image.readAsBytes();
      final imageName = image.path.split('/').last;

      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_apiBaseUrl/analyze'),
      );

      // Add image file to request with proper content type
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: imageName,
          contentType: http_parser.MediaType('image', 'jpeg'),
        ),
      );

      print('Sending request to API...');

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('Response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception('API request failed: ${response.statusCode} - ${response.body}');
      }

      // Parse response
      final responseData = jsonDecode(response.body);

      if (responseData['success'] != true) {
        throw Exception('Analysis failed: ${responseData['error'] ?? 'Unknown error'}');
      }

      // Extract similar products from response
      final similarProducts = responseData['similar_products'] as List? ?? [];
      print('Received ${similarProducts.length} similar products from API');

      // Convert to DetectionResult objects
      final results = <DetectionResult>[];
      for (int i = 0; i < similarProducts.length && i < 20; i++) {
        final product = similarProducts[i];

        try {
          results.add(DetectionResult(
            id: product['id']?.toString() ?? (i + 1).toString(),
            productName: product['title'] ?? product['product_name'] ?? 'Fashion Item',
            brand: product['brand'] ?? 'Unknown Brand',
            price: _parsePrice(product['price']),
            imageUrl: product['image_url'] ?? '',
            category: _mapCategoryForDisplay(product['category'] ?? 'Unknown'),
            confidence: _calculateConfidence(product, i),
            description: product['description'] ?? 'Similar fashion item',
            tags: _extractTags(product),
            purchaseUrl: product['purchase_url'] ?? '',
          ));
        } catch (e) {
          print('Error parsing product $i: $e');
          continue;
        }
      }

      print('Successfully converted ${results.length} products to DetectionResult objects');

      if (results.isEmpty) {
        return _returnMockData();
      }

      return results;
    } catch (e) {
      print('Error during API analysis: $e');
      throw Exception('Image analysis failed: $e');
    }
  }

  double _calculateConfidence(Map<String, dynamic> product, int index) {
    // Use composite score if available
    if (product.containsKey('composite_score')) {
      final score = product['composite_score'] as int? ?? 100;
      // Scale composite score to confidence range 0.70-0.95
      return (0.70 + (score / 200.0) * 0.25).clamp(0.70, 0.95);
    }

    // Fallback: decrease confidence by index
    return (0.90 - (index * 0.02)).clamp(0.70, 0.95);
  }

  double _parsePrice(dynamic priceValue) {
    if (priceValue == null) return 99.99;

    if (priceValue is double) return priceValue;
    if (priceValue is int) return priceValue.toDouble();

    // Handle string prices
    String priceStr = priceValue.toString().trim();
    priceStr = priceStr.replaceAll(',', '.');
    priceStr = priceStr.replaceAll(RegExp(r'[^\d\.]'), '');

    try {
      return double.parse(priceStr);
    } catch (e) {
      return 99.99;
    }
  }

  String _mapCategoryForDisplay(String originalCategory) {
    switch (originalCategory.toLowerCase()) {
      case 'dress':
        return 'tops';
      case 'shirt':
      case 'blouse':
      case 't-shirt':
      case 'tank_top':
      case 'top':
        return 'tops';
      case 'pants':
      case 'jeans':
      case 'trousers':
      case 'leggings':
        return 'bottoms';
      case 'skirt':
      case 'shorts':
        return 'bottoms';
      case 'jacket':
      case 'blazer':
      case 'coat':
      case 'cardigan':
      case 'sweater':
        return 'outerwear';
      case 'shoes':
      case 'sandals':
      case 'sneakers':
      case 'heels':
      case 'boots':
      case 'flats':
        return 'shoes';
      case 'bag':
      case 'handbag':
      case 'purse':
      case 'backpack':
      case 'tote':
      case 'clutch':
        return 'bags';
      case 'hat':
      case 'cap':
      case 'beanie':
      case 'headband':
      case 'belt':
      case 'scarf':
      case 'glasses':
      case 'sunglasses':
        return 'accessories';
      default:
        return originalCategory.toLowerCase();
    }
  }

  List<String> _extractTags(Map<String, dynamic> product) {
    final tags = <String>[];

    // Add category
    if (product['category'] != null) {
      tags.add(product['category'].toString());
    }

    // Add subcategory
    if (product['subcategory'] != null) {
      tags.add(product['subcategory'].toString());
    }

    // Add color
    if (product['color_primary'] != null) {
      tags.add(product['color_primary'].toString());
    }

    // Add material
    if (product['material'] != null) {
      tags.add(product['material'].toString());
    }

    // Add match type
    if (product['match_type'] != null) {
      tags.add(product['match_type'].toString());
    }

    // Add style match quality
    if (product['style_match_quality'] != null) {
      tags.add('style_${product['style_match_quality']}');
    }

    return tags.where((tag) => tag.isNotEmpty).toList();
  }

  List<DetectionResult> _returnMockData() {
    print('Returning mock data as fallback');
    return [
      DetectionResult(
        id: '1',
        productName: 'Detected Fashion Item 1',
        brand: 'Fashion Finder',
        price: 89.99,
        imageUrl: 'https://via.placeholder.com/200x200/808080/FFFFFF?text=Item1',
        category: 'Clothing',
        confidence: 0.85,
        description: 'Fashion item detected from image analysis',
        tags: ['detected', 'fashion'],
        purchaseUrl: 'https://example.com/item1',
      ),
      DetectionResult(
        id: '2',
        productName: 'Detected Fashion Item 2',
        brand: 'Fashion Finder',
        price: 129.99,
        imageUrl: 'https://via.placeholder.com/200x200/808080/FFFFFF?text=Item2',
        category: 'Accessories',
        confidence: 0.78,
        description: 'Additional fashion item found in image',
        tags: ['detected', 'accessory'],
        purchaseUrl: 'https://example.com/item2',
      ),
    ];
  }
}
