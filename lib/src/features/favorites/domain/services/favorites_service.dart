import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/favorite_item.dart';
import '../../../detection/domain/models/detection_result.dart';

class FavoritesService {
  final _supabase = Supabase.instance.client;

  /// Get current user ID
  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// Fetch all favorites for current user
  Future<List<FavoriteItem>> getFavorites() async {
    if (_currentUserId == null) {
      // If not authenticated, return empty list instead of erroring so UI can stay calm
      return [];
    }

    try {
      final response = await _supabase
          .from('favorites')
          .select('*')
          .eq('user_id', _currentUserId!)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => FavoriteItem.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching favorites: $e');
      rethrow;
    }
  }

  /// Add a product to favorites
  Future<FavoriteItem> addFavorite(DetectionResult product) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      print('DEBUG: Adding favorite for user: $_currentUserId, product: ${product.id}');
      final favoriteData = {
        'user_id': _currentUserId!,
        'product_id': product.id,
        'product_name': product.productName,
        'brand': product.brand,
        'price': product.price,
        'image_url': product.imageUrl,
        'purchase_url': product.purchaseUrl,
        'category': product.category,
      };

      print('DEBUG: Inserting data: $favoriteData');
      final response = await _supabase
          .from('favorites')
          .insert(favoriteData)
          .select()
          .single();

      print('DEBUG: Favorite added successfully: $response');
      return FavoriteItem.fromJson(response);
    } catch (e) {
      print('DEBUG: Error adding favorite: $e');
      rethrow;
    }
  }

  /// Remove a product from favorites by product ID
  Future<void> removeFavorite(String productId) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      await _supabase
          .from('favorites')
          .delete()
          .eq('user_id', _currentUserId!)
          .eq('product_id', productId);
    } catch (e) {
      print('Error removing favorite: $e');
      rethrow;
    }
  }

  /// Check if a product is favorited
  Future<bool> isFavorite(String productId) async {
    if (_currentUserId == null) {
      return false;
    }

    try {
      final response = await _supabase
          .from('favorites')
          .select('id')
          .eq('user_id', _currentUserId!)
          .eq('product_id', productId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error checking favorite status: $e');
      return false;
    }
  }

  /// Get favorites count for current user
  Future<int> getFavoritesCount() async {
    if (_currentUserId == null) {
      return 0;
    }

    try {
      final response = await _supabase
          .from('favorites')
          .select('id')
          .eq('user_id', _currentUserId!);

      return (response as List).length;
    } catch (e) {
      print('Error getting favorites count: $e');
      return 0;
    }
  }

  /// Get favorites by category
  Future<List<FavoriteItem>> getFavoritesByCategory(String category) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final response = await _supabase
          .from('favorites')
          .select('*')
          .eq('user_id', _currentUserId!)
          .eq('category', category)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => FavoriteItem.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching favorites by category: $e');
      rethrow;
    }
  }
}
