class DetectionResult {
  final String id;
  final String productName;
  final String brand;
  final double price;
  final String imageUrl;
  final String category;
  final double confidence;
  final String? description;
  final List<String> tags;
  final String? purchaseUrl;
  final String? colorMatchType;
  final double? colorMatchScore;
  final List<String>? matchedColors;

  const DetectionResult({
    required this.id,
    required this.productName,
    required this.brand,
    required this.price,
    required this.imageUrl,
    required this.category,
    required this.confidence,
    this.description,
    this.tags = const [],
    this.purchaseUrl,
    this.colorMatchType,
    this.colorMatchScore,
    this.matchedColors,
  });

  factory DetectionResult.fromJson(Map<String, dynamic> json) {
    return DetectionResult(
      id: json['id'] as String,
      productName: json['product_name'] as String,
      brand: json['brand'] as String,
      price: (json['price'] as num).toDouble(),
      imageUrl: json['image_url'] as String,
      category: json['category'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      description: json['description'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      purchaseUrl: json['purchase_url'] as String?,
      colorMatchType: json['color_match_type'] as String?,
      colorMatchScore: (json['color_match_score'] as num?)?.toDouble(),
      matchedColors: (json['matched_colors'] as List<dynamic>?)?.cast<String>(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_name': productName,
      'brand': brand,
      'price': price,
      'image_url': imageUrl,
      'category': category,
      'confidence': confidence,
      'description': description,
      'tags': tags,
      'purchase_url': purchaseUrl,
      'color_match_type': colorMatchType,
      'color_match_score': colorMatchScore,
      'matched_colors': matchedColors,
    };
  }
}