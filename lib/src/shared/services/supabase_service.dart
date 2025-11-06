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
      print(
        '[SupabaseService] getUserSearches user=$userId limit=$limit offset=$offset',
      );

      final response = await client
          .from('user_searches')
          .select(
            'id, user_id, search_type, source_url, source_username, created_at, image_cache_id, '
            'saved:user_saved_searches!left (id)',
          )
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final searches = List<Map<String, dynamic>>.from(response);
      final mapped = <Map<String, dynamic>>[];

      for (final search in searches) {
        final cacheId = search['image_cache_id'] as String?;
        Map<String, dynamic> cacheData = {};
        int totalResults = 0;
        List<dynamic>? detectedGarments;
        List<dynamic>? searchResults;

        if (cacheId != null) {
          try {
            final cacheResponse = await client
                .from('image_cache')
                .select(
                  'cloudinary_url, total_results, detected_garments, search_results',
                )
                .eq('id', cacheId)
                .maybeSingle();

            if (cacheResponse != null) {
              print(
                '[SupabaseService] cache response for $cacheId -> $cacheResponse',
              );
              cacheData = Map<String, dynamic>.from(cacheResponse);
              totalResults =
                  (cacheData['total_results'] as num?)?.toInt() ?? 0;
              detectedGarments =
                  cacheData['detected_garments'] as List<dynamic>?;
              searchResults =
                  cacheData['search_results'] as List<dynamic>?;
            } else {
              print('[SupabaseService] cache miss for $cacheId');
            }
          } catch (e) {
            print('Error fetching cache entry $cacheId: $e');
          }
        }

        final savedEntries = (search['saved'] as List<dynamic>?);

        print(
          '[SupabaseService] mapped search id=${search['id']} cache=$cacheId '
          'cloudinary=${cacheData['cloudinary_url']} total=$totalResults',
        );

        mapped.add({
          'id': search['id'],
          'user_id': search['user_id'],
          'search_type': search['search_type'],
          'source_url': search['source_url'],
          'source_username': search['source_username'],
          'created_at': search['created_at'],
          'image_cache_id': cacheId,
          'cloudinary_url': cacheData['cloudinary_url'],
          'total_results': totalResults,
          'detected_garments': detectedGarments,
          'search_results': searchResults,
          'is_saved': savedEntries != null && savedEntries.isNotEmpty,
        });
      }

      print(
        '[SupabaseService] getUserSearches returned ${mapped.length} rows',
      );

      return mapped;
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
