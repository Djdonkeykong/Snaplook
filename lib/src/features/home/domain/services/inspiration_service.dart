import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../shared/services/unsplash_service.dart';
import '../../../../shared/services/pexels_service.dart';
import '../../../../shared/services/pixabay_service.dart';

class InspirationService {
  static const int _itemsPerPage = 20;
  final UnsplashService _unsplashService = UnsplashService();
  final PexelsService _pexelsService = PexelsService();
  final PixabayService _pixabayService = PixabayService();

  /// Check if an image URL indicates high quality based on common patterns
  bool isHighQualityImage(String imageUrl) {
    try {
      final uri = Uri.parse(imageUrl);
      final path = uri.path.toLowerCase();
      final query = uri.query.toLowerCase();

      // Check for common high-quality indicators in URLs

      // 1. Look for size parameters in query string
      final sizePatterns = [
        RegExp(r'w=(\d+)'), // width parameter
        RegExp(r'width=(\d+)'),
        RegExp(r'h=(\d+)'), // height parameter
        RegExp(r'height=(\d+)'),
        RegExp(r'size=(\d+)'),
        RegExp(r's=(\d+)'),
      ];

      for (final pattern in sizePatterns) {
        final match = pattern.firstMatch(query);
        if (match != null) {
          final size = int.tryParse(match.group(1) ?? '0') ?? 0;
          if (size >= 400) return true; // Minimum 400px dimension
          if (size > 0 && size < 200) return false; // Reject small images
        }
      }

      // 2. Look for dimensions in filename (e.g., image_800x600.jpg)
      final filenamePattern = RegExp(r'_(\d+)x(\d+)\.');
      final filenameMatch = filenamePattern.firstMatch(path);
      if (filenameMatch != null) {
        final width = int.tryParse(filenameMatch.group(1) ?? '0') ?? 0;
        final height = int.tryParse(filenameMatch.group(2) ?? '0') ?? 0;
        if (width >= 400 && height >= 400) return true;
        if (width < 300 || height < 300) return false;
      }

      // 3. Check for quality indicators in path
      if (path.contains('thumb') ||
          path.contains('small') ||
          path.contains('mini') ||
          path.contains('xs') ||
          path.contains('_s.') ||
          path.contains('_small.')) {
        return false; // Reject thumbnails/small images
      }

      if (path.contains('large') ||
          path.contains('big') ||
          path.contains('full') ||
          path.contains('hd') ||
          path.contains('_l.') ||
          path.contains('_large.') ||
          path.contains('original')) {
        return true; // Accept large/full-size images
      }

      // 4. Default: accept if no clear indicators (let it through)
      return true;

    } catch (e) {
      // If URL parsing fails, default to accepting the image
      return true;
    }
  }

  /// Fetch fashion inspiration images from external APIs (Unsplash, Pexels, Pixabay)
  Future<List<Map<String, dynamic>>> fetchInspirationImages({
    int page = 0,
    Set<String>? excludeImageUrls, // URLs to exclude (already seen)
  }) async {
    try {
      print('DEBUG: Fetching from external APIs (page $page)...');

      // Mix results from all three sources for variety
      // Rotate which API gets more images each page
      final apiRotation = page % 3;
      List<Map<String, dynamic>> allImages = [];

      // Calculate unique page numbers for each API to avoid duplicates
      final unsplashPage = (page * 3) + 1;
      final pexelsPage = (page * 3) + 2;
      final pixabayPage = (page * 3) + 3;

      // Fetch from all three APIs in parallel
      final futures = <Future<List<Map<String, dynamic>>>>[];

      if (apiRotation == 0) {
        // Page 0,3,6... : More from Unsplash
        futures.add(_unsplashService.fetchFashionPhotos(page: unsplashPage, perPage: 10));
        futures.add(_pexelsService.fetchFashionPhotos(page: pexelsPage, perPage: 6));
        futures.add(_pixabayService.fetchFashionPhotos(page: pixabayPage, perPage: 4));
      } else if (apiRotation == 1) {
        // Page 1,4,7... : More from Pexels
        futures.add(_unsplashService.fetchFashionPhotos(page: unsplashPage, perPage: 6));
        futures.add(_pexelsService.fetchFashionPhotos(page: pexelsPage, perPage: 10));
        futures.add(_pixabayService.fetchFashionPhotos(page: pixabayPage, perPage: 4));
      } else {
        // Page 2,5,8... : More from Pixabay
        futures.add(_unsplashService.fetchFashionPhotos(page: unsplashPage, perPage: 6));
        futures.add(_pexelsService.fetchFashionPhotos(page: pexelsPage, perPage: 4));
        futures.add(_pixabayService.fetchFashionPhotos(page: pixabayPage, perPage: 10));
      }

      final results = await Future.wait(futures);

      // Combine all results
      for (final result in results) {
        allImages.addAll(result);
      }

      print('DEBUG: Got ${allImages.length} images from external APIs');

      // Remove duplicates based on external_id + source (more reliable than just URL)
      final uniqueData = <String, Map<String, dynamic>>{};
      for (final item in allImages) {
        final externalId = item['external_id'] as String?;
        final source = item['source'] as String?;
        final imageUrl = item['image_url'] as String?;

        // Create unique key from source + external_id
        final uniqueKey = '${source}_${externalId}';

        if (externalId != null &&
            source != null &&
            imageUrl != null &&
            !uniqueData.containsKey(uniqueKey) &&
            !(excludeImageUrls?.contains(imageUrl) ?? false)) {
          uniqueData[uniqueKey] = item;
        }
      }

      final finalData = uniqueData.values.toList();

      // Shuffle for variety
      finalData.shuffle(Random(DateTime.now().millisecondsSinceEpoch + page));

      // Take up to _itemsPerPage images
      final data = finalData.take(_itemsPerPage).toList();

      print('DEBUG: Returning ${data.length} unique images');
      return data;

    } catch (e) {
      print('DEBUG: External API fetch failed: $e');
      return [];
    }
  }

  /// Fetch trending/featured images (high-quality curated content)
  Future<List<Map<String, dynamic>>> fetchTrendingImages() async {
    try {
      final supabase = Supabase.instance.client;

      // Get trending items based on engagement or featured status
      final response = await supabase
          .from('products')
          .select('id, title, image_url, category, subcategory, color_primary, brand')
          .neq('image_url', '')
          .order('created_at', ascending: false)
          .limit(50); // Get more for better variety

      final data = List<Map<String, dynamic>>.from(response);

      // Shuffle for variety in trending section
      data.shuffle();

      print('🔥 Fetched ${data.length} trending images');
      return data.take(20).toList();

    } catch (e) {
      print('❌ Failed to fetch trending images: $e');
      return [];
    }
  }

  /// Search inspiration by category or style
  Future<List<Map<String, dynamic>>> searchInspirationImages(String query) async {
    try {
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('products')
          .select('id, title, image_url, category, subcategory, color_primary, brand')
          .neq('image_url', '')
          .or('category.ilike.%$query%,subcategory.ilike.%$query%,color_primary.ilike.%$query%')
          .order('created_at', ascending: false)
          .limit(30);

      final data = List<Map<String, dynamic>>.from(response);

      print('🔍 Found ${data.length} inspiration images for "$query"');
      return data;

    } catch (e) {
      print('❌ Failed to search inspiration images: $e');
      return [];
    }
  }
}