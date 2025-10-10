import 'dart:ui';

class DetectedItem {
  final String id;
  final int? productId;
  final String itemType;
  final BoundingBox bbox;
  final double confidence;
  final List<double>? embedding;

  DetectedItem({
    required this.id,
    this.productId,
    required this.itemType,
    required this.bbox,
    required this.confidence,
    this.embedding,
  });

  factory DetectedItem.fromJson(Map<String, dynamic> json) {
    List<double>? embedding;
    if (json['embedding'] != null) {
      if (json['embedding'] is List) {
        embedding = (json['embedding'] as List)
            .map((e) => (e as num).toDouble())
            .toList();
      } else if (json['embedding'] is String) {
        // Parse string representation: "[1.0, 2.0, 3.0]"
        final str = json['embedding'] as String;
        final cleaned = str.substring(1, str.length - 1); // Remove [ ]
        embedding = cleaned
            .split(',')
            .map((e) => double.parse(e.trim()))
            .toList();
      }
    }

    return DetectedItem(
      id: json['id'] as String,
      productId: json['product_id'] as int?,
      itemType: json['item_type'] as String,
      bbox: BoundingBox.fromJson(json['bbox'] as Map<String, dynamic>),
      confidence: (json['confidence'] as num).toDouble(),
      embedding: embedding,
    );
  }
}

class BoundingBox {
  final double x1;
  final double y1;
  final double x2;
  final double y2;

  BoundingBox({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  factory BoundingBox.fromJson(Map<String, dynamic> json) {
    return BoundingBox(
      x1: (json['x1'] as num).toDouble(),
      y1: (json['y1'] as num).toDouble(),
      x2: (json['x2'] as num).toDouble(),
      y2: (json['y2'] as num).toDouble(),
    );
  }

  double get width => x2 - x1;
  double get height => y2 - y1;

  // Convert to dart:ui Rect
  Rect toRect() {
    return Rect.fromLTRB(x1, y1, x2, y2);
  }
}
