import 'package:uuid/uuid.dart';
import '../models/collection.dart';
import '../models/collection_item.dart';

class CollectionsService {
  final _uuid = const Uuid();

  // Mock storage - in production, this would use Supabase
  final List<Collection> _collections = [];
  final Map<String, List<CollectionItem>> _collectionItems = {};

  /// Get all collections for the current user
  Future<List<Collection>> getCollections() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.from(_collections);
  }

  /// Create a new collection
  Future<Collection> createCollection({
    required String name,
    String? description,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final now = DateTime.now();
    final collection = Collection(
      id: _uuid.v4(),
      userId: 'current_user',
      name: name,
      description: description,
      createdAt: now,
      updatedAt: now,
      itemCount: 0,
    );

    _collections.insert(0, collection);
    _collectionItems[collection.id] = [];

    return collection;
  }

  /// Update collection name/description
  Future<Collection> updateCollection({
    required String collectionId,
    String? name,
    String? description,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final index = _collections.indexWhere((c) => c.id == collectionId);
    if (index == -1) {
      throw Exception('Collection not found');
    }

    final updated = _collections[index].copyWith(
      name: name,
      description: description,
      updatedAt: DateTime.now(),
    );

    _collections[index] = updated;
    return updated;
  }

  /// Delete a collection
  Future<void> deleteCollection(String collectionId) async {
    await Future.delayed(const Duration(milliseconds: 300));

    _collections.removeWhere((c) => c.id == collectionId);
    _collectionItems.remove(collectionId);
  }

  /// Get items in a collection
  Future<List<CollectionItem>> getCollectionItems(String collectionId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.from(_collectionItems[collectionId] ?? []);
  }

  /// Add item to collection
  Future<CollectionItem> addItemToCollection({
    required String collectionId,
    required String productId,
    required String productName,
    required String brand,
    required double price,
    required String imageUrl,
    String? purchaseUrl,
    required String category,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final item = CollectionItem(
      id: _uuid.v4(),
      collectionId: collectionId,
      productId: productId,
      productName: productName,
      brand: brand,
      price: price,
      imageUrl: imageUrl,
      purchaseUrl: purchaseUrl,
      category: category,
      addedAt: DateTime.now(),
    );

    _collectionItems[collectionId] = [
      item,
      ...(_collectionItems[collectionId] ?? []),
    ];

    // Update collection item count and cover image
    final collectionIndex = _collections.indexWhere((c) => c.id == collectionId);
    if (collectionIndex != -1) {
      final items = _collectionItems[collectionId]!;
      _collections[collectionIndex] = _collections[collectionIndex].copyWith(
        itemCount: items.length,
        coverImageUrl: items.isNotEmpty ? items.first.imageUrl : null,
        updatedAt: DateTime.now(),
      );
    }

    return item;
  }

  /// Remove item from collection
  Future<void> removeItemFromCollection({
    required String collectionId,
    required String itemId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final items = _collectionItems[collectionId];
    if (items != null) {
      items.removeWhere((item) => item.id == itemId);

      // Update collection item count and cover image
      final collectionIndex = _collections.indexWhere((c) => c.id == collectionId);
      if (collectionIndex != -1) {
        _collections[collectionIndex] = _collections[collectionIndex].copyWith(
          itemCount: items.length,
          coverImageUrl: items.isNotEmpty ? items.first.imageUrl : null,
          updatedAt: DateTime.now(),
        );
      }
    }
  }

  /// Check if product is in any collection
  Future<List<String>> getCollectionsForProduct(String productId) async {
    await Future.delayed(const Duration(milliseconds: 100));

    final collectionIds = <String>[];
    _collectionItems.forEach((collectionId, items) {
      if (items.any((item) => item.productId == productId)) {
        collectionIds.add(collectionId);
      }
    });

    return collectionIds;
  }
}
