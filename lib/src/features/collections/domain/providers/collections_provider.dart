import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/collection.dart';
import '../models/collection_item.dart';
import '../services/collections_service.dart';

// Service provider
final collectionsServiceProvider = Provider((ref) => CollectionsService());

// Collections list provider
final collectionsProvider = StateNotifierProvider<CollectionsNotifier, AsyncValue<List<Collection>>>(
  (ref) => CollectionsNotifier(ref.watch(collectionsServiceProvider)),
);

class CollectionsNotifier extends StateNotifier<AsyncValue<List<Collection>>> {
  final CollectionsService _service;

  CollectionsNotifier(this._service) : super(const AsyncValue.loading()) {
    loadCollections();
  }

  Future<void> loadCollections() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return await _service.getCollections();
    });
  }

  Future<void> createCollection({
    required String name,
    String? description,
  }) async {
    try {
      final collection = await _service.createCollection(
        name: name,
        description: description,
      );

      state.whenData((collections) {
        state = AsyncValue.data([collection, ...collections]);
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateCollection({
    required String collectionId,
    String? name,
    String? description,
  }) async {
    try {
      final updated = await _service.updateCollection(
        collectionId: collectionId,
        name: name,
        description: description,
      );

      state.whenData((collections) {
        final updatedList = collections.map((c) {
          return c.id == collectionId ? updated : c;
        }).toList();
        state = AsyncValue.data(updatedList);
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteCollection(String collectionId) async {
    try {
      await _service.deleteCollection(collectionId);

      state.whenData((collections) {
        final updatedList = collections.where((c) => c.id != collectionId).toList();
        state = AsyncValue.data(updatedList);
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> refresh() async {
    final result = await AsyncValue.guard(() async {
      return await _service.getCollections();
    });
    state = result;
  }
}

// Collection items provider (for a specific collection)
final collectionItemsProvider = StateNotifierProvider.family<CollectionItemsNotifier, AsyncValue<List<CollectionItem>>, String>(
  (ref, collectionId) => CollectionItemsNotifier(ref.watch(collectionsServiceProvider), collectionId),
);

class CollectionItemsNotifier extends StateNotifier<AsyncValue<List<CollectionItem>>> {
  final CollectionsService _service;
  final String collectionId;

  CollectionItemsNotifier(this._service, this.collectionId) : super(const AsyncValue.loading()) {
    loadItems();
  }

  Future<void> loadItems() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return await _service.getCollectionItems(collectionId);
    });
  }

  Future<void> addItem({
    required String productId,
    required String productName,
    required String brand,
    required double price,
    required String imageUrl,
    String? purchaseUrl,
    required String category,
  }) async {
    try {
      final item = await _service.addItemToCollection(
        collectionId: collectionId,
        productId: productId,
        productName: productName,
        brand: brand,
        price: price,
        imageUrl: imageUrl,
        purchaseUrl: purchaseUrl,
        category: category,
      );

      state.whenData((items) {
        state = AsyncValue.data([item, ...items]);
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> removeItem(String itemId) async {
    try {
      await _service.removeItemFromCollection(
        collectionId: collectionId,
        itemId: itemId,
      );

      state.whenData((items) {
        final updatedList = items.where((item) => item.id != itemId).toList();
        state = AsyncValue.data(updatedList);
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> refresh() async {
    final result = await AsyncValue.guard(() async {
      return await _service.getCollectionItems(collectionId);
    });
    state = result;
  }
}
