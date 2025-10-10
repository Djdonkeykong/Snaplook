import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/favorite_item.dart';
import '../services/favorites_service.dart';
import '../../../detection/domain/models/detection_result.dart';

// Service provider
final favoritesServiceProvider = Provider((ref) => FavoritesService());

// State notifier for favorites list
class FavoritesNotifier extends StateNotifier<AsyncValue<List<FavoriteItem>>> {
  final FavoritesService _service;

  // Cache of favorite product IDs for quick lookup
  Set<String> _favoriteIds = {};

  FavoritesNotifier(this._service) : super(const AsyncValue.loading()) {
    loadFavorites();
  }

  Set<String> get favoriteIds => _favoriteIds;

  /// Load all favorites from Supabase
  Future<void> loadFavorites() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final favorites = await _service.getFavorites();
      _favoriteIds = favorites.map((f) => f.productId).toSet();
      return favorites;
    });
  }

  /// Add a product to favorites (optimistic update)
  Future<void> addFavorite(DetectionResult product) async {
    // Optimistic update - add to local state immediately
    _favoriteIds.add(product.id);

    state.whenData((favorites) {
      // Create a temporary favorite item for immediate UI update
      final tempFavorite = FavoriteItem(
        id: 'temp_${product.id}',
        userId: 'temp',
        productId: product.id,
        productName: product.productName,
        brand: product.brand,
        price: product.price,
        imageUrl: product.imageUrl,
        purchaseUrl: product.purchaseUrl,
        category: product.category,
        createdAt: DateTime.now(),
      );

      state = AsyncValue.data([tempFavorite, ...favorites]);
    });

    // Sync with Supabase in background
    try {
      final newFavorite = await _service.addFavorite(product);

      // Update with real data from Supabase
      state.whenData((favorites) {
        final updatedFavorites = favorites
            .where((f) => f.id != 'temp_${product.id}')
            .toList();
        state = AsyncValue.data([newFavorite, ...updatedFavorites]);
      });
    } catch (e) {
      // Rollback optimistic update on error
      _favoriteIds.remove(product.id);
      state.whenData((favorites) {
        final rollbackFavorites = favorites
            .where((f) => f.productId != product.id)
            .toList();
        state = AsyncValue.data(rollbackFavorites);
      });
      rethrow;
    }
  }

  /// Remove a product from favorites (optimistic update)
  Future<void> removeFavorite(String productId) async {
    // Optimistic update - remove from local state immediately
    _favoriteIds.remove(productId);

    final previousState = state;
    state.whenData((favorites) {
      final updatedFavorites = favorites
          .where((f) => f.productId != productId)
          .toList();
      state = AsyncValue.data(updatedFavorites);
    });

    // Sync with Supabase in background
    try {
      await _service.removeFavorite(productId);
    } catch (e) {
      // Rollback optimistic update on error
      _favoriteIds.add(productId);
      state = previousState;
      rethrow;
    }
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(DetectionResult product) async {
    if (isFavorite(product.id)) {
      await removeFavorite(product.id);
    } else {
      await addFavorite(product);
    }
  }

  /// Check if a product is favorited (local check, instant)
  bool isFavorite(String productId) {
    return _favoriteIds.contains(productId);
  }

  /// Refresh favorites from server
  Future<void> refresh() async {
    await loadFavorites();
  }
}

// Provider for favorites state
final favoritesProvider = StateNotifierProvider<FavoritesNotifier, AsyncValue<List<FavoriteItem>>>(
  (ref) => FavoritesNotifier(ref.watch(favoritesServiceProvider)),
);

// Provider to check if a specific product is favorited
final isFavoriteProvider = Provider.family<bool, String>((ref, productId) {
  final favoritesState = ref.watch(favoritesProvider);
  return favoritesState.maybeWhen(
    data: (favorites) => favorites.any((f) => f.productId == productId),
    orElse: () => false,
  );
});

// Provider for favorites count
final favoritesCountProvider = Provider<int>((ref) {
  return ref.watch(favoritesProvider).maybeWhen(
        data: (favorites) => favorites.length,
        orElse: () => 0,
      );
});
