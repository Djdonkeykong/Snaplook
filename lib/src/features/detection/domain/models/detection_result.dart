class DetectionResult {
  final String id;
  final String productName;
  final String brand;
  final double price;
  final String? priceDisplay;
  final String? currencyCode;
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
    this.currencyCode,
    required this.imageUrl,
    required this.category,
    required this.confidence,
    this.description,
    this.tags = const [],
    this.purchaseUrl,
    this.colorMatchType,
    this.colorMatchScore,
    this.matchedColors,
    this.priceDisplay,
  });

  factory DetectionResult.fromJson(Map<String, dynamic> json) {
    // Handle price which can be either a num, a Map with extracted_value/display, or a raw string
    double priceValue = 0.0;
    String? currencyCode;
    String? priceDisplay;
    final priceData = json['price'];
    if (priceData is num) {
      priceValue = priceData.toDouble();
    } else if (priceData is Map<String, dynamic>) {
      priceValue = (priceData['extracted_value'] as num?)?.toDouble() ?? 0.0;
      currencyCode = (priceData['currency'] as String?)?.toUpperCase();
      priceDisplay = (priceData['display'] as String?) ??
          (priceData['text'] as String?) ??
          (priceData['raw'] as String?) ??
          (priceData['formatted'] as String?);
    } else if (priceData is String) {
      priceDisplay = priceData.trim().isNotEmpty ? priceData.trim() : null;
      final parsed = _parseNumericPriceFromString(priceData);
      if (parsed != null) {
        priceValue = parsed;
      }
    }
    priceDisplay ??= (json['price_display'] as String?) ??
        (json['price_text'] as String?) ??
        (json['price_raw'] as String?);
    currencyCode ??= (json['currency'] as String?)?.toUpperCase();

    return DetectionResult(
      id: json['id'] as String,
      productName: json['product_name'] as String,
      brand: json['brand'] as String,
      price: priceValue,
      priceDisplay: priceDisplay,
      currencyCode: currencyCode,
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
      'price_display': priceDisplay,
      'currency': currencyCode,
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

double? _parseNumericPriceFromString(String value) {
  final cleaned = value.replaceAll(RegExp(r'[^0-9.,]'), '');
  if (cleaned.isEmpty) return null;
  // Treat commas as thousand separators by stripping them, then parse
  final normalized = cleaned.replaceAll(',', '');
  final parsed = double.tryParse(normalized);
  return parsed;
}
