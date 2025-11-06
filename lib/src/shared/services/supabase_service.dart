import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get client => Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getUserSearches({
    required String userId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      print('[SupabaseService] getUserSearches user=$userId limit=$limit offset=$offset');
      final response = await client
          .from('v_user_recent_searches')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      print('[SupabaseService] getUserSearches returned ${response.length} rows');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching user searches: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getUserFavorites({
    required String userId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await client
          .from('v_user_favorites_enriched')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching user favorites: $e');
      return [];
    }
  }

  Future<bool> removeFavorite(String favoriteId) async {
    try {
      await client
          .from('user_favorites')
          .delete()
          .eq('id', favoriteId);

      return true;
    } catch (e) {
      print('Error removing favorite: $e');
      return false;
    }
  }

  Future<bool> saveSearch({
    required String userId,
    required String searchId,
    String? name,
  }) async {
    try {
      await client.from('user_saved_searches').insert({
        'user_id': userId,
        'search_id': searchId,
        'name': name,
      });

      return true;
    } catch (e) {
      print('Error saving search: $e');
      return false;
    }
  }

  Future<bool> removeSavedSearch(String savedSearchId) async {
    try {
      await client
          .from('user_saved_searches')
          .delete()
          .eq('id', savedSearchId);

      return true;
    } catch (e) {
      print('Error removing saved search: $e');
      return false;
    }
  }
}
