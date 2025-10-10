import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../detection/domain/models/detection_result.dart';

class TutorialService {
  final _supabase = Supabase.instance.client;

  Future<List<DetectionResult>> getTutorialProducts({String scenario = 'Instagram'}) async {
    try {
      final response = await _supabase
          .from('tutorial_products')
          .select('*')
          .eq('tutorial_scenario', scenario);

      if (response.isEmpty) {
        return [];
      }

      return response.map<DetectionResult>((product) {
        return DetectionResult(
          id: product['id'] as String,
          productName: product['product_name'] as String,
          brand: product['brand'] as String,
          price: (product['price'] as num).toDouble(),
          confidence: 0.92, // Default high confidence for tutorial
          category: product['category'] as String,
          imageUrl: product['image_url'] as String,
          purchaseUrl: product['purchase_url'] as String?,
        );
      }).toList();
    } catch (e) {
      print('Error fetching tutorial products: $e');
      // Return fallback data if database fails
      return _getFallbackResults();
    }
  }

  List<DetectionResult> _getFallbackResults() {
    return [
      DetectionResult(
        id: '1',
        productName: 'Oversized Wool Coat',
        brand: 'ZARA',
        price: 129.99,
        confidence: 0.92,
        category: 'Outerwear',
        imageUrl: 'https://static.zara.net/photos//2023/V/0/1/p/2753/221/700/2/w/850/2753221700_6_1_1.jpg?ts=1697026800943',
        purchaseUrl: 'https://www.zara.com/us/en/oversized-wool-coat-p02753221.html',
      ),
      DetectionResult(
        id: '2',
        productName: 'Pleated Mini Skirt',
        brand: 'H&M',
        price: 24.99,
        confidence: 0.88,
        category: 'Bottoms',
        imageUrl: 'https://lp2.hm.com/hmgoepprod?set=quality%5B79%5D%2Csource%5B%2F13%2F21%2F13219f8c8b1a4c9c8a0e5f1b8c9b8e7c2f4d5e6f.jpg%5D%2Corigin%5Bdam%5D%2Ccategory%5B%5D%2Ctype%5BLOOKBOOK%5D%2Cres%5Bm%5D%2Chmver%5B1%5D&call=url[file:/product/main]',
        purchaseUrl: 'https://www2.hm.com/en_us/productpage.0713218001.html',
      ),
    ];
  }
}