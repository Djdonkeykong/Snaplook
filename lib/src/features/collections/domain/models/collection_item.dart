class CollectionItem {
  final String id;
  final String collectionId;
  final String productId;
  final String productName;
  final String brand;
  final double price;
  final String imageUrl;
  final String? purchaseUrl;
  final String category;
  final DateTime addedAt;

  const CollectionItem({
    required this.id,
    required this.collectionId,
    required this.productId,
    required this.productName,
    required this.brand,
    required this.price,
    required this.imageUrl,
    this.purchaseUrl,
    required this.category,
    required this.addedAt,
  });

  factory CollectionItem.fromJson(Map<String, dynamic> json) {
    return CollectionItem(
      id: json['id'] as String,
      collectionId: json['collection_id'] as String,
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
      brand: json['brand'] as String,
      price: (json['price'] as num).toDouble(),
      imageUrl: json['image_url'] as String,
      purchaseUrl: json['purchase_url'] as String?,
      category: json['category'] as String,
      addedAt: DateTime.parse(json['added_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'collection_id': collectionId,
      'product_id': productId,
      'product_name': productName,
      'brand': brand,
      'price': price,
      'image_url': imageUrl,
      'purchase_url': purchaseUrl,
      'category': category,
      'added_at': addedAt.toIso8601String(),
    };
  }
}
