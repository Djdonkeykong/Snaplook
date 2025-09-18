import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../models/detection_result.dart';
import '../../../../core/constants/app_constants.dart';

class DetectionService {
  static const String _replicateEndpoint = '${AppConstants.baseApiUrl}/predictions';

  // Comprehensive fashion analysis system prompt from working Python code
  static const String _fashionAnalysisPrompt = '''You are a comprehensive fashion analyst. Analyze this image and detect ALL fashion items visible.

MANDATORY CATEGORIES TO CHECK:
- bag, wallet, purse, handbag, backpack, tote, clutch
- belt
- cardigan, sweater
- coat, jacket, blazer
- dress
- glasses, sunglasses
- headband, hat, cap, beanie, head covering, hair accessory
- jeans, pants, trousers
- jumpsuit, romper
- scarf
- shirt, blouse, top, t-shirt, sweatshirt
- shoes (sandals, sneakers, heels, boots, flats, loafers, pumps)
- shorts
- skirt
- swimwear
- tie
- vest

EXCLUSIONS: Ignore all jewelry items including necklaces, earrings, bracelets, rings, watches, brooches, body jewelry.

Return JSON with detected fashion items for product matching.''';

  Future<List<DetectionResult>> analyzeImage(XFile image) async {
    try {
      // First, upload image to Replicate
      final imageBytes = await image.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      // Create prediction request
      final response = await http.post(
        Uri.parse(_replicateEndpoint),
        headers: {
          'Authorization': 'Token ${AppConstants.replicateApiKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'version': AppConstants.replicateModelVersion,
          'input': {
            'image': 'data:image/jpeg;base64,$base64Image',
            'prompt': _fashionAnalysisPrompt,
            'system_prompt': _fashionAnalysisPrompt,
          },
        }),
      );

      if (response.statusCode != 201) {
        throw Exception('Failed to create prediction: ${response.body}');
      }

      final predictionData = jsonDecode(response.body);
      final predictionId = predictionData['id'];

      // Poll for results
      return await _pollForResults(predictionId);
    } catch (e) {
      throw Exception('Image analysis failed: $e');
    }
  }

  Future<List<DetectionResult>> _pollForResults(String predictionId) async {
    const maxAttempts = 30;
    const pollInterval = Duration(seconds: 2);

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      await Future.delayed(pollInterval);

      final response = await http.get(
        Uri.parse('$_replicateEndpoint/$predictionId'),
        headers: {
          'Authorization': 'Token ${AppConstants.replicateApiKey}',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to get prediction status');
      }

      final data = jsonDecode(response.body);
      final status = data['status'];

      if (status == 'succeeded') {
        final output = data['output'];
        return await _searchSimilarProducts(output);
      } else if (status == 'failed') {
        throw Exception('Prediction failed: ${data['error']}');
      }
    }

    throw Exception('Prediction timeout');
  }

  Future<List<DetectionResult>> _searchSimilarProducts(String analysis) async {
    // TODO: Implement Supabase search based on analysis
    // For now, return mock data
    await Future.delayed(const Duration(seconds: 1));

    return [
      DetectionResult(
        id: '1',
        productName: 'Claudie Pierlot Midi Dress',
        brand: 'Claudie Pierlot',
        price: 329.95,
        imageUrl: 'https://example.com/dress1.jpg',
        category: 'Dresses',
        confidence: 0.95,
        description: 'Elegant midi dress in vibrant green',
        tags: ['midi', 'green', 'elegant', 'dress'],
        purchaseUrl: 'https://example.com/buy/dress1',
      ),
      DetectionResult(
        id: '2',
        productName: 'Good American Pink Blazer',
        brand: 'Good American',
        price: 189.00,
        imageUrl: 'https://example.com/blazer1.jpg',
        category: 'Blazers',
        confidence: 0.88,
        description: 'Oversized pink blazer with structured shoulders',
        tags: ['blazer', 'pink', 'oversized', 'structured'],
        purchaseUrl: 'https://example.com/buy/blazer1',
      ),
      DetectionResult(
        id: '3',
        productName: 'ASOS High Waisted Trousers',
        brand: 'ASOS',
        price: 45.00,
        imageUrl: 'https://example.com/trousers1.jpg',
        category: 'Trousers',
        confidence: 0.82,
        description: 'High waisted tailored trousers in pink',
        tags: ['trousers', 'high-waisted', 'tailored', 'pink'],
        purchaseUrl: 'https://example.com/buy/trousers1',
      ),
    ];
  }
}