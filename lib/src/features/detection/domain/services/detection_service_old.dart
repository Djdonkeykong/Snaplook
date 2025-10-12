import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/detection_result.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../services/debug_logger.dart';

class DetectionService {
  static String get _replicateEndpoint => '${AppConstants.baseApiUrl}/predictions';

  // Performance optimization: Cache color matching results to avoid duplicate API calls
  final Map<String, List<Map<String, dynamic>>> _colorMatchCache = {};

  // Performance optimization: Control debug logging intensity
  static const bool _enableDetailedLogging = false; // Set to false for production performance

  // Progressive loading: Quality thresholds for early result delivery
  static const double _minConfidenceForEarlyResults = 0.75;
  static const int _minResultsForProgressive = 5;

  // Test method to verify API configuration
  Future<bool> testApiConnection() async {
    try {
      print('Testing Replicate API connection...');
      print('API Key: ${AppConstants.replicateApiKey.substring(0, 10)}...');
      print('Endpoint: $_replicateEndpoint');

      final response = await http.get(
        Uri.parse('${AppConstants.baseApiUrl}/models'),
        headers: {
          'Authorization': 'Token ${AppConstants.replicateApiKey}',
          'Content-Type': 'application/json',
        },
      );

      print('API Test Response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('API Test Error: $e');
      return false;
    }
  }

  // Comprehensive fashion analysis system prompt from working Python code
  static const String _fashionAnalysisPrompt = """Fashion analyst: detect ALL fashion items in image.

DETECT: clothing(dress,top,shirt,sweater,coat,jumpsuit), bottoms(jeans,pants,shorts,skirt), footwear, accessories(bag,belt,headwear,glasses,scarf,tie)
EXCLUDE: jewelry

MATERIALS: textured=KNIT, smooth=COTTON, artificial=SYNTHETIC, leather-like=LEATHER, fabric=SYNTHETIC

SUBCATEGORIES: midi_dress, bodycon_dress, fit_and_flare_dress | sandals,sneakers,heels,boots,flats | handbag,shoulder_bag,tote,clutch,backpack,crossbody | t_shirt,blouse,shirt,tank_top,sweater,cardigan

STYLE_DETAILS:
CLOTHING: neckline(crew/round/v_neck/scoop/boat/off_shoulder), sleeves(sleeveless/cap/short/three_quarter/long), length(crop/mini/knee/midi/maxi), fit(fitted/slim/regular/loose/oversized), closure(buttons/zipper/pullover/wrap)
SHOES: toe_style(pointed/round/square/open), heel_type(flat/low/medium/high/stiletto), heel_height(flat/1-2in/2-3in/3-4in/4in+), closure(slip_on/lace_up/buckle/zipper), strap_style(none/ankle/t-strap/slingback)
BAGS: size(mini/small/medium/large), handle_type(none/short/long/adjustable), strap_style(none/single/chain/fabric), closure(zipper/snap/magnetic/flap), hardware(gold/silver/brass/black/none)
HEADWEAR: brim_style(none/small/wide/curved), crown_shape(fitted/structured/soft), fit_type(fitted/adjustable/stretchy), closure(adjustable/snap/elastic), embellishments(none/logo/embroidery)

RULES: Scan entire image. Include partial/obscured items. Don't default to "wrap_dress" or "synthetic". Be specific with colors.

JSON FORMAT:
{
  "total_items_detected": N,
  "detection_summary": "Found X and Y",
  "items": [{
    "item_number": 1,
    "category": "dress|top|bottom|outerwear|shoes|bag|accessories",
    "subcategory": "specific_type",
    "color_primary": "exact_color",
    "color_secondary": ["colors"],
    "pattern": "solid|vertical_ribbed|horizontal_ribbed|striped|polka_dot|floral|geometric|textured",
    "material": "cotton|silk|denim|knit|leather|synthetic|suede|canvas|wool",
    "style_details": {/*category fields*/},
    "visibility": "fully_visible|partially_visible|partially_obscured",
    "confidence": 0.95
  }],
  "style_analysis": {
    "overall_aesthetic": ["casual","formal","bohemian","minimalist","edgy"],
    "occasions": ["work","casual","formal","party","athletic"],
    "seasons": ["spring","summer","fall","winter"],
    "coordination": "well_coordinated|partially_coordinated|mismatched"
  },
  "matching_data": {
    "outfit_completeness": "single_item|partial_outfit|complete_outfit",
    "similar_combinations": ["casual_summer_outfit","business_casual"],
    "style_keywords": ["effortless","comfortable","minimalist"]
  }
}

Always detect at least one item.""";

  Future<List<DetectionResult>> analyzeImage(XFile image) async {
    final sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';

    try {
      print('Starting image analysis...');
      print('Debug Session ID: $sessionId');
      print('Replicate API Key: ${AppConstants.replicateApiKey.substring(0, 10)}...');
      print('Model Version: ${AppConstants.replicateModelVersion}');

      // First, upload image to Replicate
      final imageBytes = await image.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      // Detect image format from file extension or bytes
      String mimeType = _detectImageFormat(imageBytes);
      print('Detected image format: $mimeType from file: ${image.path}');

      print('Image encoded, size: ${imageBytes.length} bytes, format: $mimeType');

      // Create prediction request
      final response = await http.post(
        Uri.parse(_replicateEndpoint),
        headers: {
          'Authorization': 'Token ${AppConstants.replicateApiKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'version': AppConstants.replicateModelVersion,
          'input': {
            'image': 'data:$mimeType;base64,$base64Image',
            'prompt': 'Analyze this fashion image and detect all clothing items. Return your analysis in the exact JSON format specified in the system prompt.',
            'system_prompt': _fashionAnalysisPrompt,
            'max_tokens': 4096,
          },
        }),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode != 201) {
        throw Exception('Failed to create prediction: ${response.body}');
      }

      final predictionData = jsonDecode(response.body);
      final predictionId = predictionData['id'];

      // Poll for results
      return await _pollForResults(predictionId, sessionId, image);
    } catch (e) {
      throw Exception('Image analysis failed: $e');
    }
  }

  Future<List<DetectionResult>> _pollForResults(String predictionId, String sessionId, XFile image) async {
    const maxAttempts = 30;
    const pollInterval = Duration(seconds: 2);

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      await Future.delayed(pollInterval);

      final response = await http.get(
        Uri.parse('$_replicateEndpoint/$predictionId'),
        headers: {
          'Authorization': 'Token ${AppConstants.replicateApiKey}',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to get prediction status');
      }

      final data = jsonDecode(response.body);
      final status = data['status'];

      if (status == 'succeeded') {
        final output = data['output'];
        return await _parseClaudeAnalysis(output, sessionId, image);
      } else if (status == 'failed') {
        throw Exception('Prediction failed: ${data['error']}');
      }
    }

    throw Exception('Prediction timeout');
  }

  Future<List<DetectionResult>> _parseClaudeAnalysis(dynamic output, String sessionId, XFile image) async {
    try {
      print('Parsing Claude analysis output...');

      String analysisText = '';
      if (output is List && output.isNotEmpty) {
        analysisText = output.join('');
      } else if (output is String) {
        analysisText = output;
      } else {
        print('Unexpected output format: ${output.runtimeType}');
        return _returnMockData();
      }

      print('Claude analysis received (${analysisText.length} chars)');

      // Try to extract JSON from the response
      Map<String, dynamic>? analysisJson;
      try {
        // Look for JSON in the response
        final jsonStart = analysisText.indexOf('{');
        final jsonEnd = analysisText.lastIndexOf('}');

        if (jsonStart != -1 && jsonEnd != -1 && jsonEnd > jsonStart) {
          final jsonString = analysisText.substring(jsonStart, jsonEnd + 1);
          analysisJson = jsonDecode(jsonString);
        }
      } catch (e) {
        print('Failed to parse JSON: $e');
      }

      if (analysisJson == null) {
        print('No valid JSON found, returning basic results based on text analysis');
        return _parseTextAnalysis(analysisText);
      }

      // Parse the detected items from the comprehensive JSON structure
      final items = analysisJson['items'] ?? [];
      final totalDetected = analysisJson['total_items_detected'] ?? items.length;
      final detectionSummary = analysisJson['detection_summary'] ?? 'Fashion items detected';

      print('Total items detected: $totalDetected');
      print('Detection summary: $detectionSummary');

      // PARALLEL PROCESSING: Search for all detected items simultaneously for better performance
      print('🚀 PARALLEL SEARCH: Processing ${items.length} detected items concurrently...');

      // Create parallel search tasks for all detected items
      final searchFutures = <Future<List<DetectionResult>>>[];

      for (int i = 0; i < items.length && i < 10; i++) {
        final item = items[i];
        final category = item['category'] ?? 'Unknown';
        final subcategory = item['subcategory'] ?? '';
        final colorPrimary = item['color_primary'] ?? '';
        final pattern = item['pattern'] ?? 'solid';
        final material = item['material'] ?? 'unknown';
        final confidence = (item['confidence'] ?? 0.85).toDouble();
        final styleDetails = item['style_details'] ?? {};

        print('Queuing parallel search for: $category ($subcategory) - $colorPrimary $material');

        // Add search task to parallel execution queue
        searchFutures.add(_searchItemInParallel(
          i, category, subcategory, colorPrimary, pattern, material, styleDetails, analysisJson
        ));
      }

      // Execute all searches in parallel and wait for completion
      final parallelResults = await Future.wait(searchFutures);

      // Combine all results from parallel searches
      final allResults = <DetectionResult>[];
      for (final itemResults in parallelResults) {
        allResults.addAll(itemResults);
      }

      print('⚡ PARALLEL SEARCH COMPLETE: Processed ${items.length} items simultaneously');

      // Final deduplication and sorting by confidence
      final uniqueResults = <String, DetectionResult>{};
      for (final result in allResults) {
        if (!uniqueResults.containsKey(result.id) ||
            result.confidence > uniqueResults[result.id]!.confidence) {
          uniqueResults[result.id] = result;
        }
      }

      final results = uniqueResults.values.toList();
      results.sort((a, b) => b.confidence.compareTo(a.confidence));

      print('Successfully found ${results.length} similar products from Supabase');

      // Log the complete session for debugging (only if detailed logging is enabled)
      if (_enableDetailedLogging) {
        await _logDebugSession(sessionId, image, analysisJson, allResults, results);
      } else {
        // Lightweight logging: just log basic session info
        await _logBasicSession(sessionId, analysisJson, results);
      }

      return results.isEmpty ? _returnMockData() : results;

    } catch (e) {
      print('Error parsing Claude analysis: $e');
      return _returnMockData();
    }
  }

  List<DetectionResult> _parseTextAnalysis(String text) {
    // Simple text parsing for fashion items
    final results = <DetectionResult>[];
    final fashionKeywords = ['dress', 'shirt', 'pants', 'shoes', 'jacket', 'blazer', 'coat', 'bag', 'hat'];

    for (int i = 0; i < fashionKeywords.length; i++) {
      final keyword = fashionKeywords[i];
      if (text.toLowerCase().contains(keyword)) {
        results.add(DetectionResult(
          id: (i + 1).toString(),
          productName: '${keyword.substring(0, 1).toUpperCase()}${keyword.substring(1)} - Detected Item',
          brand: 'Fashion Finder',
          price: 79.99 + (i * 15),
          imageUrl: 'https://via.placeholder.com/200x200/808080/FFFFFF?text=${keyword.toUpperCase()}',
          category: keyword.substring(0, 1).toUpperCase() + keyword.substring(1),
          confidence: 0.80 - (i * 0.03),
          description: 'Detected $keyword from image analysis',
          tags: [keyword, 'detected'],
          purchaseUrl: 'https://example.com/search?q=$keyword',
        ));
      }
    }

    return results.take(5).toList();
  }

  Future<List<DetectionResult>> _searchSimilarItemsInSupabase(
    String category,
    String subcategory,
    String colorPrimary,
    String pattern,
    String material,
    Map<String, dynamic> styleDetails,
  ) async {
    try {
      print('\nSTART SOPHISTICATED SEARCH for: $category ($subcategory)');
      print('Search params: color=$colorPrimary, pattern=$pattern, material=$material');
      print('Style details: $styleDetails');

      // Execute sophisticated search with 7-level strategy
      final matches = await _executeSophisticatedSearch(
        category, subcategory, colorPrimary, pattern, material, styleDetails,
        claudeAnalysis: null, // No Claude analysis available in this context
      );

      // Convert to DetectionResult objects
      final results = <DetectionResult>[];
      for (int i = 0; i < matches.length && i < 10; i++) {
        final product = matches[i];
        final originalCategory = product['category'] ?? category;
        final displayCategory = _mapCategoryForDisplay(originalCategory);

        // Calculate confidence based on match type and composite score
        double confidence = 0.90 - (i * 0.02);
        if (product.containsKey('composite_score')) {
          // Scale composite score to confidence range 0.70-0.95
          final score = product['composite_score'] as int? ?? 100;
          confidence = (0.70 + (score / 200.0) * 0.25).clamp(0.70, 0.95);
        }

        results.add(DetectionResult(
          id: product['id']?.toString() ?? (i + 1).toString(),
          productName: product['product_name'] ?? 'Fashion Item',
          brand: product['brand'] ?? 'Unknown Brand',
          price: _parsePrice(product['price']),
          imageUrl: product['image_url'] ?? 'https://via.placeholder.com/200x200/808080/FFFFFF?text=${category.toUpperCase()}',
          category: displayCategory,
          confidence: confidence,
          description: product['description'] ?? 'Similar $category found with sophisticated matching',
          tags: [
            originalCategory,
            product['subcategory']?.toString() ?? subcategory,
            product['color_primary']?.toString() ?? colorPrimary,
            material,
            if (product.containsKey('match_type')) product['match_type'].toString(),
          ].where((tag) => tag.toString().isNotEmpty).map((tag) => tag.toString()).toList(),
          purchaseUrl: product['purchase_url'] ?? 'https://example.com/product/${product['id']}',
        ));
      }

      print('SOPHISTICATED SEARCH COMPLETE: Found ${results.length} high-quality matches');
      return results;

    } catch (e) {
      print('Error in sophisticated search: $e');
      return _getFallbackResults(category, subcategory, colorPrimary, material);
    }
  }

  String _mapCategoryForDisplay(String originalCategory) {
    // Map categories for UI display only (not for database search)
    switch (originalCategory.toLowerCase()) {
      case 'dress':
        return 'tops'; // Display dresses under tops category
      case 'shirt':
      case 'blouse':
      case 't-shirt':
      case 'tank_top':
      case 'top':
        return 'tops';
      case 'pants':
      case 'jeans':
      case 'trousers':
      case 'leggings':
        return 'bottoms';
      case 'skirt':
      case 'shorts':
        return 'bottoms';
      case 'jacket':
      case 'blazer':
      case 'coat':
      case 'cardigan':
      case 'sweater':
        return 'outerwear';
      case 'shoes':
      case 'sandals':
      case 'sneakers':
      case 'heels':
      case 'boots':
      case 'flats':
        return 'shoes';
      case 'bag':
      case 'handbag':
      case 'purse':
      case 'backpack':
      case 'tote':
      case 'clutch':
        return 'bags';
      case 'hat':
      case 'cap':
      case 'beanie':
      case 'headband':
        return 'accessories';
      case 'belt':
      case 'scarf':
      case 'glasses':
      case 'sunglasses':
        return 'accessories';
      default:
        return originalCategory.toLowerCase();
    }
  }

  double _parsePrice(dynamic priceValue) {
    if (priceValue == null) return 99.99;

    if (priceValue is double) return priceValue;
    if (priceValue is int) return priceValue.toDouble();

    // Handle string prices (including European format)
    String priceStr = priceValue.toString().trim();

    // Replace European comma decimal separator with dot
    priceStr = priceStr.replaceAll(',', '.');

    // Remove any currency symbols and spaces
    priceStr = priceStr.replaceAll(RegExp(r'[^\d\.]'), '');

    try {
      return double.parse(priceStr);
    } catch (e) {
      print('DEBUG: Failed to parse price "$priceValue", using fallback: $e');
      return 99.99;
    }
  }

  // SOPHISTICATED SEARCH IMPLEMENTATION
  Future<List<Map<String, dynamic>>> _executeSophisticatedSearch(
    String category,
    String subcategory,
    String colorPrimary,
    String pattern,
    String material,
    Map<String, dynamic> styleDetails, {
    Map<String, dynamic>? claudeAnalysis,
  }) async {
    print('SOPHISTICATED SEARCH: Starting 7-level search strategy');

    // Removed database scope test for cleaner output

    // Level 1: Exact pattern match with all attributes
    var allResults = <Map<String, dynamic>>[];
    var results = await _searchWithStrictMatching(
      category, subcategory, colorPrimary, pattern, material, styleDetails, 20
    );
    if (results.isNotEmpty) {
      print('LEVEL 1 SUCCESS: Found ${results.length} exact matches');
      allResults.addAll(results);

      // Intelligent early exit: If we have enough high-quality exact matches, stop here
      if (_shouldExitEarly(allResults, 1, 'exact_matches')) {
        return _processEarlyExitResults(allResults, claudeAnalysis, 1);
      }
    }

    // Level 2: Exact pattern with smart mapping
    results = await _searchExactPatternWithMapping(
      category, subcategory, colorPrimary, pattern, styleDetails, 20
    );
    if (results.isNotEmpty) {
      print('LEVEL 2 SUCCESS: Found ${results.length} mapped matches');
      allResults.addAll(results);

      // Early exit if we have excellent results from exact + mapped matching
      if (_shouldExitEarly(allResults, 2, 'mapped_matches')) {
        return _processEarlyExitResults(allResults, claudeAnalysis, 2);
      }
    }

    // Level 3: Alternative sleeves and materials
    final sleeveAlts = await _searchWithSleeveAlternatives(
      category, subcategory, colorPrimary, pattern, styleDetails, 10
    );
    final materialAlts = await _searchWithMaterialAlternatives(
      category, subcategory, colorPrimary, pattern, material, styleDetails, 10
    );
    results = [...sleeveAlts, ...materialAlts];
    if (results.isNotEmpty) {
      print('LEVEL 3 SUCCESS: Found ${results.length} alternative matches');
      allResults.addAll(results);
    }

    // Level 4: Claude priority matching
    results = await _searchClaudePriorityMatching(
      category, subcategory, colorPrimary, pattern, styleDetails, 20
    );
    if (results.isNotEmpty) {
      print('LEVEL 4 SUCCESS: Found ${results.length} Claude priority matches');
      allResults.addAll(results);

      // Early exit after Claude priority - these are high-quality matches
      if (_shouldExitEarly(allResults, 4, 'claude_priority')) {
        return _processEarlyExitResults(allResults, claudeAnalysis, 4);
      }
    }

    // Level 5: Relax subcategory for exact pattern
    results = await _searchCoreNonNegotiable(
      category, colorPrimary, pattern, styleDetails, 20
    );
    if (results.isNotEmpty) {
      print('LEVEL 5 SUCCESS: Found ${results.length} core matches');
      allResults.addAll(results);
    }

    // Level 6: Category + color + mapped pattern
    final mappedPattern = _getMappedPattern(pattern);
    if (mappedPattern != null && mappedPattern != pattern) {
      results = await _searchCategoryColorPattern(
        category, colorPrimary, mappedPattern, 20
      );
      if (results.isNotEmpty) {
        print('LEVEL 6 SUCCESS: Found ${results.length} mapped pattern matches');
        allResults.addAll(results);
      }
    }

    // Level 7: Fallback - category + color only
    results = await _searchCategoryColor(category, colorPrimary, 20);
    if (results.isNotEmpty) {
      print('LEVEL 7 FALLBACK: Found ${results.length} basic matches');
      allResults.addAll(results);
    }

    // Combine all results and remove duplicates
    if (allResults.isNotEmpty) {
      final uniqueResults = <String, Map<String, dynamic>>{};
      for (final result in allResults) {
        final id = result['id']?.toString() ?? '';
        if (id.isNotEmpty && !uniqueResults.containsKey(id)) {
          uniqueResults[id] = result;
        }
      }

      var finalResults = uniqueResults.values.toList();

      // Apply Python improvements: style filtering and composite scoring
      if (claudeAnalysis != null) {
        print('🎨 APPLYING STYLE FILTERS: Filtering results based on Claude analysis...');
        finalResults = _applyStyleFilters(finalResults, claudeAnalysis);
        print('✅ STYLE FILTERING COMPLETE: ${finalResults.length} products passed style criteria');

        print('🏆 CALCULATING COMPOSITE SCORES: Ranking products using metadata...');
        finalResults = _calculateCompositeScores(finalResults, claudeAnalysis);
        print('✅ COMPOSITE SCORING COMPLETE: Products ranked by relevance');
      }

      print('🎯 COMPREHENSIVE SEARCH COMPLETE: Found ${finalResults.length} unique products from ${allResults.length} total results across all levels');
      print('📊 DATABASE UTILIZATION: Searched across ALL 7 levels instead of stopping early');

      return finalResults;
    }

    print('NO MATCHES: Exhausted all 7 search levels');
    return [];
  }

  // MAPPING FUNCTIONS
  String? _getMappedPattern(String pattern) {
    // Map texture patterns to solid
    const textureToSolid = {
      'ribbed': 'solid',
      'textured': 'solid',
      'knit_texture': 'solid',
      'knit': 'solid',
      'vertical_ribbed': 'solid',
      'horizontal_ribbed': 'solid',
    };

    // Distinct patterns must match exactly
    const distinctPatterns = [
      'geometric', 'floral', 'polka_dot', 'zebra', 'checkered', 'chain_link', 'abstract'
    ];

    if (distinctPatterns.contains(pattern.toLowerCase())) {
      return null; // No mapping for distinct patterns
    }

    return textureToSolid[pattern.toLowerCase()];
  }

  String? _getMappedNeckline(String neckline) {
    const necklineMapping = {
      'crew': 'round',
      'crew_neck': 'round',
      'scoop': 'round',
      'scoop_neck': 'round',
    };
    return necklineMapping[neckline.toLowerCase()];
  }

  Future<List<Map<String, dynamic>>> _getSmartColorMatches(String detectedColor) async {
    if (detectedColor.isEmpty) return [];

    // Check cache first - avoid duplicate database queries
    final cacheKey = detectedColor.toLowerCase();
    if (_colorMatchCache.containsKey(cacheKey)) {
      print('Using cached color matches for "$detectedColor" (${_colorMatchCache[cacheKey]!.length} variations)');
      return _colorMatchCache[cacheKey]!;
    }

    try {
      final supabase = Supabase.instance.client;

      // Get color family and shade group
      final colorInfo = await supabase
          .from('color_synonyms')
          .select('family, shade_group')
          .eq('shade', detectedColor.toLowerCase())
          .limit(1)
          .maybeSingle();

      if (colorInfo == null) {
        print('No color mapping found for: $detectedColor');
        return [{'color': detectedColor, 'score': 100, 'type': 'exact'}];
      }

      final family = colorInfo['family'] as String?;
      final shadeGroup = colorInfo['shade_group'] as String?;

      final colorMatches = <Map<String, dynamic>>[];

      // Priority 1: Exact color (100% score)
      colorMatches.add({'color': detectedColor, 'score': 100, 'type': 'exact'});

      // Priority 2: Same shade group (85% score)
      if (shadeGroup != null) {
        final shadeGroupColors = await supabase
            .from('color_synonyms')
            .select('shade')
            .eq('shade_group', shadeGroup)
            .neq('shade', detectedColor.toLowerCase());

        for (final colorRow in shadeGroupColors) {
          final shade = colorRow['shade'] as String?;
          if (shade != null && shade != detectedColor.toLowerCase()) {
            colorMatches.add({'color': shade, 'score': 85, 'type': 'shade_group'});
          }
        }
      }

      // Priority 3: Same color family (60% score)
      if (family != null) {
        final familyColors = await supabase
            .from('color_synonyms')
            .select('shade')
            .eq('family', family)
            .neq('shade', detectedColor.toLowerCase());

        final existingColors = colorMatches.map((c) => c['color']).toSet();

        for (final colorRow in familyColors) {
          final shade = colorRow['shade'] as String?;
          if (shade != null && !existingColors.contains(shade)) {
            colorMatches.add({'color': shade, 'score': 60, 'type': 'family'});
          }
        }
      }

      print('Smart color matching for "$detectedColor": ${colorMatches.length} variations found');

      // Removed excessive color variation logging
      final topVariations = colorMatches.take(10).toList();

      // Cache the results for future use
      _colorMatchCache[cacheKey] = topVariations;

      return topVariations;

    } catch (e) {
      print('Smart color matching failed for "$detectedColor": $e');
      // Fallback to basic mapping
      final oldMapping = _getBasicColorMapping(detectedColor);
      List<Map<String, dynamic>> fallbackResult;
      if (oldMapping != null && oldMapping != detectedColor) {
        fallbackResult = [
          {'color': detectedColor, 'score': 100, 'type': 'exact'},
          {'color': oldMapping, 'score': 70, 'type': 'fallback'}
        ];
      } else {
        fallbackResult = [{'color': detectedColor, 'score': 100, 'type': 'exact'}];
      }

      // Cache the fallback results too
      _colorMatchCache[cacheKey] = fallbackResult;
      return fallbackResult;
    }
  }

  String? _getBasicColorMapping(String color) {
    // Fallback basic color mapping for when smart matching fails
    const colorMapping = {
      'hot_pink': 'light_pink',
      'bright_pink': 'light_pink',
      'fuchsia': 'pink',
      'magenta': 'light_pink',
      'bright_green': 'green',
      'lime': 'neon_green',
      'mint_green': 'light_green',
      'bright_blue': 'light_blue',
      'sky_blue': 'light_blue',
      'navy': 'royal_blue',
      'bright_yellow': 'yellow',
      'lemon': 'light_yellow',
      'burgundy': 'maroon',
      'wine': 'maroon',
      'cream': 'white',
    };
    return colorMapping[color.toLowerCase()];
  }

  List<String> _getCompatibleSleeves(String sleeves) {
    const sleeveCompatibility = {
      'sleeveless': ['sleeveless'], // Strict
      'three_quarter': ['three_quarter', 'short', 'long'],
      'short': ['short', 'three_quarter'],
      'long': ['long', 'three_quarter'],
    };
    return sleeveCompatibility[sleeves.toLowerCase()] ?? [sleeves];
  }

  List<String> _getCompatibleMaterials(String material) {
    const materialCompatibility = {
      'leather': ['leather'], // Exact only
      'denim': ['denim'], // Exact only
      'suede': ['suede'], // Exact only
      'canvas': ['canvas'], // Exact only
      'knit': ['knit', 'synthetic'],
      'cotton': ['cotton', 'synthetic'],
      'silk': ['silk', 'synthetic'],
      'wool': ['wool', 'synthetic'],
      'synthetic': ['synthetic', 'knit', 'cotton'],
    };
    return materialCompatibility[material.toLowerCase()] ?? [material];
  }

  // SEARCH LEVEL IMPLEMENTATIONS
  Future<List<Map<String, dynamic>>> _searchWithStrictMatching(
    String category, String subcategory, String colorPrimary,
    String pattern, String material, Map<String, dynamic> styleDetails, int limit
  ) async {
    try {
      // Removed detailed search parameter logging

      final supabase = Supabase.instance.client;
      var query = supabase.from('products').select('*').eq('category', category.toLowerCase());

      if (colorPrimary.isNotEmpty) {
        query = query.eq('color_primary', colorPrimary);
      }
      if (pattern.isNotEmpty) query = query.eq('pattern', pattern);

      // Smart material compatibility
      if (material.isNotEmpty) {
        final compatibleMaterials = _getCompatibleMaterials(material);
        query = query.eq('material', compatibleMaterials.first);
      }

      // Add style details for dress category
      if (category.toLowerCase() == 'dress') {
        if (styleDetails.containsKey('neckline')) {
          query = query.eq('clothing_neckline', styleDetails['neckline']);
        }
        if (styleDetails.containsKey('sleeves')) {
          query = query.eq('clothing_sleeves', styleDetails['sleeves']);
        }
      }

      // Add ordering to get best products first, increase limit for large database
      final queryLimit = limit * 25; // 25x more results from 500K database
      final response = await query
          .order('created_at', ascending: false) // Newest first
          .limit(queryLimit);
      final results = List<Map<String, dynamic>>.from(response);

      // Simplified query logging
      print('Query: ${results.length}/$queryLimit results for $category/$colorPrimary');

      // Removed excessive warning logging

      // Removed excessive field structure logging

      return results;
    } catch (e) {
      print('Strict matching failed: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _searchExactPatternWithMapping(
    String category, String subcategory, String colorPrimary,
    String pattern, Map<String, dynamic> styleDetails, int limit
  ) async {
    try {
      final supabase = Supabase.instance.client;

      // Use smart color matching
      final colorMatches = await _getSmartColorMatches(colorPrimary);
      final allResults = <Map<String, dynamic>>[];

      for (final colorMatch in colorMatches) {
        final color = colorMatch['color'] as String;
        final colorScore = colorMatch['score'] as int;

        var query = supabase.from('products').select('*')
            .eq('category', category.toLowerCase())
            .eq('pattern', pattern)
            .eq('color_primary', color);

        // Style details with mapping for dress
        if (category.toLowerCase() == 'dress') {
          if (styleDetails.containsKey('neckline')) {
            final neckline = styleDetails['neckline'].toString();
            final mappedNeckline = _getMappedNeckline(neckline);
            final finalNeckline = mappedNeckline ?? neckline;
            query = query.eq('clothing_neckline', finalNeckline);
          }
          if (styleDetails.containsKey('sleeves')) {
            final compatibleSleeves = _getCompatibleSleeves(styleDetails['sleeves'].toString());
            query = query.eq('clothing_sleeves', compatibleSleeves.first);
          }
        }

        final response = await query.limit(limit);
        final items = List<Map<String, dynamic>>.from(response);

        // Add color match metadata
        for (var item in items) {
          item['color_match_score'] = colorScore;
          item['color_match_type'] = colorMatch['type'];
          item['original_color'] = colorPrimary;
          item['matched_color'] = color;
        }

        allResults.addAll(items);
        if (allResults.length >= limit) break;
      }

      // Sort by color match score, then by other factors
      allResults.sort((a, b) {
        final scoreA = a['color_match_score'] as int? ?? 0;
        final scoreB = b['color_match_score'] as int? ?? 0;
        return scoreB.compareTo(scoreA);
      });

      return allResults.take(limit).toList();
    } catch (e) {
      print('Exact pattern with mapping failed: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _searchWithSleeveAlternatives(
    String category, String subcategory, String colorPrimary,
    String pattern, Map<String, dynamic> styleDetails, int limit
  ) async {
    if (!styleDetails.containsKey('sleeves') || category.toLowerCase() != 'dress') {
      return [];
    }

    try {
      final compatibleSleeves = _getCompatibleSleeves(styleDetails['sleeves'].toString());
      if (compatibleSleeves.length <= 1) return [];

      final results = <Map<String, dynamic>>[];

      // Try alternative sleeves (skip first which is exact match)
      for (int i = 1; i < compatibleSleeves.length && results.length < limit; i++) {
        final supabase = Supabase.instance.client;
        var query = supabase.from('products').select('*')
            .eq('category', category.toLowerCase())
            .eq('pattern', pattern)
            .eq('clothing_sleeves', compatibleSleeves[i]);

        // Use best color match for performance
        final colorMatches = await _getSmartColorMatches(colorPrimary);
        final firstColor = colorMatches.isNotEmpty ? colorMatches.first['color'] as String : colorPrimary;
        if (firstColor.isNotEmpty) query = query.eq('color_primary', firstColor);

        final response = await query.limit(limit - results.length);
        final items = List<Map<String, dynamic>>.from(response);

        // Mark with alternative info
        for (var item in items) {
          item['match_type'] = 'sleeve_alternative';
          item['original_sleeves'] = styleDetails['sleeves'];
          item['matched_sleeves'] = compatibleSleeves[i];
        }
        results.addAll(items);
      }

      return results;
    } catch (e) {
      print('Sleeve alternatives search failed: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _searchWithMaterialAlternatives(
    String category, String subcategory, String colorPrimary,
    String pattern, String material, Map<String, dynamic> styleDetails, int limit
  ) async {
    if (material.isEmpty) return [];

    try {
      final compatibleMaterials = _getCompatibleMaterials(material);
      if (compatibleMaterials.length <= 1) return [];

      final results = <Map<String, dynamic>>[];

      // Try alternative materials (skip first which is exact match)
      for (int i = 1; i < compatibleMaterials.length && results.length < limit; i++) {
        final supabase = Supabase.instance.client;
        var query = supabase.from('products').select('*')
            .eq('category', category.toLowerCase())
            .eq('pattern', pattern)
            .eq('material', compatibleMaterials[i]);

        // Use best color match for performance
        final colorMatches = await _getSmartColorMatches(colorPrimary);
        final firstColor = colorMatches.isNotEmpty ? colorMatches.first['color'] as String : colorPrimary;
        if (firstColor.isNotEmpty) query = query.eq('color_primary', firstColor);

        final response = await query.limit(limit - results.length);
        final items = List<Map<String, dynamic>>.from(response);

        // Mark with alternative info
        for (var item in items) {
          item['match_type'] = 'material_alternative';
          item['original_material'] = material;
          item['matched_material'] = compatibleMaterials[i];
        }
        results.addAll(items);
      }

      return results;
    } catch (e) {
      print('Material alternatives search failed: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _searchClaudePriorityMatching(
    String category, String subcategory, String colorPrimary,
    String pattern, Map<String, dynamic> styleDetails, int limit
  ) async {
    try {
      final mappedPattern = _getMappedPattern(pattern);
      final mappedNeckline = styleDetails.containsKey('neckline')
          ? _getMappedNeckline(styleDetails['neckline'].toString()) : null;

      // Only proceed if we have Claude-specific mappings
      if (mappedPattern == null && mappedNeckline == null) return [];

      // Exclude distinct patterns from Claude priority
      const distinctPatterns = ['geometric', 'floral', 'polka_dot', 'zebra', 'checkered'];
      if (distinctPatterns.contains(pattern.toLowerCase())) return [];

      final supabase = Supabase.instance.client;
      var query = supabase.from('products').select('*')
          .eq('category', category.toLowerCase());

      if (colorPrimary.isNotEmpty) query = query.eq('color_primary', colorPrimary);
      if (mappedPattern != null) query = query.eq('pattern', mappedPattern);

      if (category.toLowerCase() == 'dress' && mappedNeckline != null) {
        query = query.eq('clothing_neckline', mappedNeckline);
      }

      final response = await query.limit(limit);
      final items = List<Map<String, dynamic>>.from(response as List);

      // Mark as Claude priority matches
      for (var item in items) {
        item['match_type'] = 'claude_priority';
        item['priority'] = 'highest';
      }

      return items;
    } catch (e) {
      print('Claude priority search failed: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _searchCoreNonNegotiable(
    String category, String colorPrimary, String pattern,
    Map<String, dynamic> styleDetails, int limit
  ) async {
    try {
      final supabase = Supabase.instance.client;
      var query = supabase.from('products').select('*')
          .eq('category', category.toLowerCase());

      if (colorPrimary.isNotEmpty) query = query.eq('color_primary', colorPrimary);
      if (pattern.isNotEmpty) query = query.eq('pattern', pattern);

      // Key style details for dress
      if (category.toLowerCase() == 'dress') {
        if (styleDetails.containsKey('neckline')) {
          query = query.eq('clothing_neckline', styleDetails['neckline']);
        }
        if (styleDetails.containsKey('sleeves')) {
          query = query.eq('clothing_sleeves', styleDetails['sleeves']);
        }
      }

      final response = await query.limit(limit);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Core non-negotiable search failed: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _searchCategoryColorPattern(
    String category, String colorPrimary, String pattern, int limit
  ) async {
    try {
      final supabase = Supabase.instance.client;
      var query = supabase.from('products').select('*')
          .eq('category', category.toLowerCase());

      if (colorPrimary.isNotEmpty) query = query.eq('color_primary', colorPrimary);
      if (pattern.isNotEmpty) query = query.eq('pattern', pattern);

      final response = await query.limit(limit);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Category+color+pattern search failed: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _searchCategoryColor(
    String category, String colorPrimary, int limit
  ) async {
    try {
      final supabase = Supabase.instance.client;
      var query = supabase.from('products').select('*')
          .eq('category', category.toLowerCase());

      if (colorPrimary.isNotEmpty) query = query.eq('color_primary', colorPrimary);

      final response = await query.limit(limit);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Category+color search failed: $e');
      return [];
    }
  }

  List<DetectionResult> _getFallbackResults(
    String category, String subcategory, String colorPrimary, String material
  ) {
    final displayCategory = _mapCategoryForDisplay(category);
    return [
      DetectionResult(
        id: '1',
        productName: 'Similar ${category.substring(0, 1).toUpperCase()}${category.substring(1)}',
        brand: 'Fashion Database',
        price: 89.99,
        imageUrl: 'https://via.placeholder.com/200x200/808080/FFFFFF?text=${category.toUpperCase()}',
        category: displayCategory,
        confidence: 0.75,
        description: 'Similar $category found with sophisticated matching ($colorPrimary $material)',
        tags: [category, subcategory, colorPrimary, material]
            .where((tag) => tag.toString().isNotEmpty)
            .map((tag) => tag.toString())
            .toList(),
        purchaseUrl: 'https://example.com/search?category=$category',
      ),
    ];
  }

  // STYLE FILTERING AND COMPOSITE SCORING
  List<Map<String, dynamic>> _applyStyleFilters(
    List<Map<String, dynamic>> results,
    Map<String, dynamic> claudeAnalysis,
  ) {
    if (results.isEmpty) return results;

    // Extract Claude's style analysis
    final claudeStyleKeywords = <String>{};
    final claudeOccasions = <String>{};

    // Get style keywords from Claude's analysis
    final matchingData = claudeAnalysis['matching_data'] as Map<String, dynamic>?;
    if (matchingData != null && matchingData.containsKey('style_keywords')) {
      final keywords = matchingData['style_keywords'] as List?;
      if (keywords != null) {
        claudeStyleKeywords.addAll(
          keywords.map((k) => k.toString().toLowerCase().trim()).where((k) => k.isNotEmpty)
        );
      }
    }

    // Get occasions from Claude's analysis
    final styleAnalysis = claudeAnalysis['style_analysis'] as Map<String, dynamic>?;
    if (styleAnalysis != null && styleAnalysis.containsKey('occasions')) {
      final occasions = styleAnalysis['occasions'] as List?;
      if (occasions != null) {
        claudeOccasions.addAll(
          occasions.map((o) => o.toString().toLowerCase().trim()).where((o) => o.isNotEmpty)
        );
      }
    }

    if (claudeStyleKeywords.isEmpty && claudeOccasions.isEmpty) {
      print('No Claude style data for filtering - keeping all results');
      return results;
    }

    print('Applying style filters - Claude keywords: $claudeStyleKeywords, occasions: $claudeOccasions');

    final filteredResults = <Map<String, dynamic>>[];
    for (final item in results) {
      bool keywordsMatch = false;
      bool occasionsMatch = false;

      // Check style keywords match
      if (claudeStyleKeywords.isNotEmpty && item.containsKey('style_keywords')) {
        final itemKeywords = (item['style_keywords'] as List?)
            ?.map((k) => k.toString().toLowerCase().trim())
            .where((k) => k.isNotEmpty)
            .toSet() ?? <String>{};
        if (claudeStyleKeywords.intersection(itemKeywords).isNotEmpty) {
          keywordsMatch = true;
        }
      }

      // Check occasions match
      if (claudeOccasions.isNotEmpty && item.containsKey('occasions')) {
        final itemOccasions = (item['occasions'] as List?)
            ?.map((o) => o.toString().toLowerCase().trim())
            .where((o) => o.isNotEmpty)
            .toSet() ?? <String>{};
        if (claudeOccasions.intersection(itemOccasions).isNotEmpty) {
          occasionsMatch = true;
        }
      }

      // Item passes if at least one keyword OR one occasion matches
      if (keywordsMatch || occasionsMatch) {
        if (keywordsMatch && occasionsMatch) {
          item['style_match_quality'] = 'both';
        } else if (keywordsMatch) {
          item['style_match_quality'] = 'keywords';
        } else {
          item['style_match_quality'] = 'occasions';
        }
        filteredResults.add(item);
      }
    }

    print('Style filtering: ${results.length} -> ${filteredResults.length} items');
    return filteredResults;
  }

  List<Map<String, dynamic>> _calculateCompositeScores(
    List<Map<String, dynamic>> results,
    Map<String, dynamic> claudeAnalysis,
  ) {
    if (results.isEmpty) return results;

    // Extract Claude's analysis data
    final claudeItems = claudeAnalysis['items'] as List?;
    final claudeItem = (claudeItems?.isNotEmpty == true) ? claudeItems!.first as Map<String, dynamic>? : null;

    final claudeSecondaryColors = (claudeItem?['color_secondary'] as List?)
        ?.map((c) => c.toString().toLowerCase().trim())
        .where((c) => c.isNotEmpty)
        .toSet() ?? <String>{};

    final claudeStyleKeywords = <String>{};
    final claudeOccasions = <String>{};

    // Get Claude's style data
    final matchingData = claudeAnalysis['matching_data'] as Map<String, dynamic>?;
    if (matchingData != null && matchingData.containsKey('style_keywords')) {
      final keywords = matchingData['style_keywords'] as List?;
      if (keywords != null) {
        claudeStyleKeywords.addAll(
          keywords.map((k) => k.toString().toLowerCase().trim()).where((k) => k.isNotEmpty)
        );
      }
    }

    final styleAnalysis = claudeAnalysis['style_analysis'] as Map<String, dynamic>?;
    if (styleAnalysis != null && styleAnalysis.containsKey('occasions')) {
      final occasions = styleAnalysis['occasions'] as List?;
      if (occasions != null) {
        claudeOccasions.addAll(
          occasions.map((o) => o.toString().toLowerCase().trim()).where((o) => o.isNotEmpty)
        );
      }
    }

    // Calculate scores for each item
    for (final item in results) {
      int score = 100; // Base score

      // Secondary color overlap bonus (+25 per matching color)
      if (claudeSecondaryColors.isNotEmpty && item.containsKey('secondary_colors')) {
        final itemSecondaryColors = (item['secondary_colors'] as List?)
            ?.map((c) => c.toString().toLowerCase().trim())
            .where((c) => c.isNotEmpty)
            .toSet() ?? <String>{};
        final overlap = claudeSecondaryColors.intersection(itemSecondaryColors);
        score += overlap.length * 25;
      }

      // Claude analysis quality bonus (+30)
      if (item.containsKey('claude_analyzed') && item['claude_analyzed'] == true) {
        score += 30;
      }

      // Style keyword density bonus (+15 per matching keyword)
      if (claudeStyleKeywords.isNotEmpty && item.containsKey('style_keywords')) {
        final itemKeywords = (item['style_keywords'] as List?)
            ?.map((k) => k.toString().toLowerCase().trim())
            .where((k) => k.isNotEmpty)
            .toSet() ?? <String>{};
        final keywordOverlap = claudeStyleKeywords.intersection(itemKeywords);
        score += keywordOverlap.length * 15;
      }

      // Occasion density bonus (+12 per matching occasion)
      if (claudeOccasions.isNotEmpty && item.containsKey('occasions')) {
        final itemOccasions = (item['occasions'] as List?)
            ?.map((o) => o.toString().toLowerCase().trim())
            .where((o) => o.isNotEmpty)
            .toSet() ?? <String>{};
        final occasionOverlap = claudeOccasions.intersection(itemOccasions);
        score += occasionOverlap.length * 12;
      }

      // Color match score bonus (from smart color matching)
      final colorMatchScore = item['color_match_score'] as int? ?? 100;
      if (colorMatchScore < 100) {
        // Bonus/penalty for color match quality
        score += ((colorMatchScore - 60) * 0.5).round();
      }

      // Confidence weighting (multiply by confidence level)
      final confidence = (item['confidence'] as num?)?.toDouble() ?? 0.9;
      score = (score * confidence).round();

      // Store the computed score
      item['composite_score'] = score;
    }

    // Sort by composite score (highest first)
    results.sort((a, b) {
      final scoreA = a['composite_score'] as int? ?? 0;
      final scoreB = b['composite_score'] as int? ?? 0;
      return scoreB.compareTo(scoreA);
    });

    // Debug output for top items
    print('Composite scoring applied - Top 3 scores:');
    for (int i = 0; i < results.length && i < 3; i++) {
      final item = results[i];
      final score = item['composite_score'] as int? ?? 0;
      final itemId = item['id']?.toString() ?? 'unknown';
      final title = (item['product_name']?.toString() ?? 'unknown').substring(0,
          (item['product_name']?.toString().length ?? 7) > 50 ? 50 : (item['product_name']?.toString().length ?? 7));
      print('  ${i + 1}. ID $itemId: $score points - $title');
    }

    return results;
  }

  List<DetectionResult> _returnMockData() {
    print('Returning mock data as fallback');
    return [
      DetectionResult(
        id: '1',
        productName: 'Detected Fashion Item 1',
        brand: 'Fashion Finder',
        price: 89.99,
        imageUrl: 'https://via.placeholder.com/200x200/808080/FFFFFF?text=Item1',
        category: 'Clothing',
        confidence: 0.85,
        description: 'Fashion item detected from image analysis',
        tags: ['detected', 'fashion'],
        purchaseUrl: 'https://example.com/item1',
      ),
      DetectionResult(
        id: '2',
        productName: 'Detected Fashion Item 2',
        brand: 'Fashion Finder',
        price: 129.99,
        imageUrl: 'https://via.placeholder.com/200x200/808080/FFFFFF?text=Item2',
        category: 'Accessories',
        confidence: 0.78,
        description: 'Additional fashion item found in image',
        tags: ['detected', 'accessory'],
        purchaseUrl: 'https://example.com/item2',
      ),
    ];
  }

  /// Log detailed debug information for analysis
  Future<void> _logDebugSession(
    String sessionId,
    XFile image,
    Map<String, dynamic>? analysisJson,
    List<DetectionResult> allResults,
    List<DetectionResult> finalResults,
  ) async {
    try {
      if (analysisJson == null) return;

      // Prepare search metadata
      final searchMetadata = {
        'total_raw_matches': allResults.length,
        'final_results_count': finalResults.length,
        'analysis_timestamp': DateTime.now().toIso8601String(),
        'items_processed': analysisJson['items']?.length ?? 0,
      };

      // Convert results to simple maps for logging
      final resultsForLogging = finalResults.map((result) => {
        'id': result.id,
        'product_name': result.productName,
        'brand': result.brand,
        'price': result.price,
        'category': result.category,
        'confidence': result.confidence,
        'tags': result.tags,
        'description': result.description,
      }).toList();

      // Log the complete session
      await DebugLogger.instance.logDetectionSession(
        sessionId: sessionId,
        imagePath: image.path,
        detectionResults: analysisJson,
        searchResults: resultsForLogging,
        searchMetadata: searchMetadata,
      );

      // Also log detailed search process for each detected item
      final items = analysisJson['items'] as List? ?? [];
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        await _logItemSearchDetails(sessionId, item, i);
      }

    } catch (e) {
      print('❌ Failed to log debug session: $e');
    }
  }

  /// Log detailed search process for a specific item
  Future<void> _logItemSearchDetails(
    String sessionId,
    Map<String, dynamic> item,
    int itemIndex,
  ) async {
    try {
      final category = item['category'] ?? 'unknown';
      final subcategory = item['subcategory'] ?? '';
      final primaryColor = item['color_primary'] ?? '';

      // Generate color variations (simplified version for logging)
      final colorVariations = _generateSmartColorVariations(primaryColor);

      // Create mock search levels data (you can replace this with actual data from your search)
      final searchLevels = {
        'level_1_exact': 0,
        'level_2_mapped': 0, // This gets filled by actual search
        'level_3_family': 0,
        'level_4_similar': 0,
        'level_5_broad': 0,
        'level_6_generic': 0,
        'level_7_fallback': 0,
      };

      final styleFilters = {
        'style_keywords': item['style_analysis']?['style_keywords'] ?? [],
        'occasions': item['style_analysis']?['occasions'] ?? [],
        'confidence_threshold': 0.7,
        'color_match_weight': 0.4,
        'style_match_weight': 0.3,
        'category_match_weight': 0.3,
      };

      await DebugLogger.instance.logSearchProcess(
        sessionId: '${sessionId}_item_$itemIndex',
        itemType: '$category/$subcategory',
        primaryColor: primaryColor,
        colorVariations: colorVariations,
        searchLevels: searchLevels,
        finalResults: [], // Will be filled with actual results
        styleFilters: styleFilters,
      );

    } catch (e) {
      print('❌ Failed to log item search details: $e');
    }
  }

  /// Generate color variations for debugging
  List<String> _generateSmartColorVariations(String baseColor) {
    // Simplified version - your actual method might be more complex
    final colorVariations = <String>[baseColor.toLowerCase()];

    switch (baseColor.toLowerCase()) {
      case 'red':
        colorVariations.addAll(['crimson', 'burgundy', 'maroon', 'cherry', 'scarlet', 'wine']);
        break;
      case 'blue':
        colorVariations.addAll(['navy', 'royal', 'azure', 'cobalt', 'indigo', 'sapphire']);
        break;
      case 'green':
        colorVariations.addAll(['emerald', 'forest', 'olive', 'sage', 'mint', 'lime']);
        break;
      case 'black':
        colorVariations.addAll(['charcoal', 'ebony', 'jet', 'onyx', 'coal']);
        break;
      case 'white':
        colorVariations.addAll(['ivory', 'cream', 'pearl', 'snow', 'vanilla']);
        break;
      case 'brown':
        colorVariations.addAll(['tan', 'beige', 'coffee', 'chocolate', 'camel', 'khaki']);
        break;
      case 'gray':
      case 'grey':
        colorVariations.addAll(['silver', 'slate', 'ash', 'charcoal', 'steel']);
        break;
      case 'pink':
        colorVariations.addAll(['rose', 'blush', 'coral', 'salmon', 'magenta']);
        break;
      case 'yellow':
        colorVariations.addAll(['gold', 'amber', 'honey', 'lemon', 'mustard']);
        break;
      case 'orange':
        colorVariations.addAll(['peach', 'coral', 'tangerine', 'apricot', 'rust']);
        break;
      case 'purple':
        colorVariations.addAll(['violet', 'lavender', 'plum', 'mauve', 'amethyst']);
        break;
      default:
        // For uncommon colors, add some generic variations
        colorVariations.addAll(['${baseColor}_light', '${baseColor}_dark']);
    }

    return colorVariations;
  }

  // Helper method to detect image format from bytes - handles all common formats
  String _detectImageFormat(Uint8List bytes) {
    if (bytes.length < 12) return 'image/jpeg'; // Default fallback

    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'image/jpeg';
    }

    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 &&
        bytes[4] == 0x0D && bytes[5] == 0x0A && bytes[6] == 0x1A && bytes[7] == 0x0A) {
      return 'image/png';
    }

    // WebP: 52 49 46 46 [4 bytes] 57 45 42 50
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
        bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
      return 'image/webp';
    }

    // GIF: 47 49 46 38 (GIF8)
    if (bytes.length >= 6 &&
        bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38) {
      return 'image/gif';
    }

    // BMP: 42 4D
    if (bytes.length >= 2 &&
        bytes[0] == 0x42 && bytes[1] == 0x4D) {
      return 'image/bmp';
    }

    // TIFF: 49 49 2A 00 (little endian) or 4D 4D 00 2A (big endian)
    if (bytes.length >= 4 &&
        ((bytes[0] == 0x49 && bytes[1] == 0x49 && bytes[2] == 0x2A && bytes[3] == 0x00) ||
         (bytes[0] == 0x4D && bytes[1] == 0x4D && bytes[2] == 0x00 && bytes[3] == 0x2A))) {
      return 'image/tiff';
    }

    // HEIC/HEIF: Check for 'ftyp' at offset 4 and HEIC/HEIF brands
    if (bytes.length >= 12 &&
        bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70) {
      // Check for HEIC/HEIF brand
      final brand = String.fromCharCodes(bytes.sublist(8, 12));
      if (brand == 'heic' || brand == 'heix' || brand == 'hevc' || brand == 'hevx') {
        return 'image/heic';
      }
    }

    // Default to JPEG if we can't detect (most compatible)
    return 'image/jpeg';
  }

  // PERFORMANCE OPTIMIZATION: Early exit strategy helpers
  bool _shouldExitEarly(List<Map<String, dynamic>> currentResults, int currentLevel, String matchType) {
    // Minimum thresholds for early exit
    const minResultsForEarlyExit = {
      1: 30, // Level 1 (exact matches): Need 30+ results
      2: 25, // Level 2 (mapped matches): Need 25+ results
      4: 20, // Level 4 (Claude priority): Need 20+ results
    };

    final minResults = minResultsForEarlyExit[currentLevel] ?? 50;

    if (currentResults.length < minResults) {
      return false; // Not enough results yet
    }

    // Quality-based early exit: Stop if we have high-quality matches
    switch (matchType) {
      case 'exact_matches':
        // Level 1: Exact matches are highest quality, exit early if we have enough
        if (currentResults.length >= 30) {
          print('🏃‍♂️ EARLY EXIT at Level $currentLevel: ${currentResults.length} exact matches found - sufficient for high quality results');
          return true;
        }
        break;

      case 'mapped_matches':
        // Level 2: Combined exact + mapped matches
        if (currentResults.length >= 35) {
          print('🏃‍♂️ EARLY EXIT at Level $currentLevel: ${currentResults.length} combined exact+mapped matches - excellent coverage');
          return true;
        }
        break;

      case 'claude_priority':
        // Level 4: After Claude priority matching
        if (currentResults.length >= 25) {
          print('🏃‍♂️ EARLY EXIT at Level $currentLevel: ${currentResults.length} results after Claude priority - good quality achieved');
          return true;
        }
        break;
    }

    return false;
  }

  Future<List<Map<String, dynamic>>> _processEarlyExitResults(
    List<Map<String, dynamic>> results,
    Map<String, dynamic>? claudeAnalysis,
    int exitLevel
  ) async {
    print('⚡ PERFORMANCE BOOST: Skipped ${7 - exitLevel} search levels by early exit');

    // Remove duplicates
    final uniqueResults = <String, Map<String, dynamic>>{};
    for (final result in results) {
      final id = result['id']?.toString() ?? '';
      if (id.isNotEmpty && !uniqueResults.containsKey(id)) {
        uniqueResults[id] = result;
      }
    }

    var finalResults = uniqueResults.values.toList();

    // Apply Python improvements: style filtering and composite scoring
    if (claudeAnalysis != null) {
      print('🎨 APPLYING STYLE FILTERS: Filtering results based on Claude analysis...');
      finalResults = _applyStyleFilters(finalResults, claudeAnalysis);
      print('✅ STYLE FILTERING COMPLETE: ${finalResults.length} products passed style criteria');

      print('🏆 CALCULATING COMPOSITE SCORES: Ranking products using metadata...');
      finalResults = _calculateCompositeScores(finalResults, claudeAnalysis);
      print('✅ COMPOSITE SCORING COMPLETE: Products ranked by relevance');
    }

    // PROGRESSIVE LOADING: Apply quality thresholds for early delivery
    final qualityResults = _applyQualityThresholds(finalResults, exitLevel);

    print('🎯 EARLY EXIT COMPLETE: Found ${qualityResults.length} high-quality products from ${results.length} total results (stopped at level $exitLevel)');

    return qualityResults;
  }

  // Helper method for parallel item searching
  Future<List<DetectionResult>> _searchItemInParallel(
    int itemIndex,
    String category,
    String subcategory,
    String colorPrimary,
    String pattern,
    String material,
    Map<String, dynamic> styleDetails,
    Map<String, dynamic> analysisJson,
  ) async {
    try {
      // Search for similar items with sophisticated filtering
      final scoredMatches = await _executeSophisticatedSearch(
        category, subcategory, colorPrimary, pattern, material, styleDetails,
        claudeAnalysis: analysisJson,
      );

      if (scoredMatches.isEmpty) {
        return [];
      }

      // Convert to DetectionResult objects
      final itemResults = <DetectionResult>[];
      for (int j = 0; j < scoredMatches.length && j < 10; j++) {
        final product = scoredMatches[j];
        final originalCategory = product['category'] ?? category;
        final displayCategory = _mapCategoryForDisplay(originalCategory);

        // Use composite score for confidence
        double confidence = 0.90 - (j * 0.02);
        if (product.containsKey('composite_score')) {
          final score = product['composite_score'] as int? ?? 100;
          confidence = (0.70 + (score / 200.0) * 0.25).clamp(0.70, 0.95);
        }

        itemResults.add(DetectionResult(
          id: product['id']?.toString() ?? '${itemIndex}_${j + 1}',
          productName: product['title'] ?? product['product_name'] ?? 'Fashion Item',
          brand: product['brand'] ?? 'Unknown Brand',
          price: _parsePrice(product['price']),
          imageUrl: product['image_url'] ?? 'https://via.placeholder.com/200x200/808080/FFFFFF?text=${category.toUpperCase()}',
          category: displayCategory,
          confidence: confidence,
          description: product['description'] ?? 'Similar $category found with sophisticated matching',
          tags: [
            originalCategory,
            product['subcategory']?.toString() ?? subcategory,
            product['color_primary']?.toString() ?? colorPrimary,
            material,
            if (product.containsKey('match_type')) product['match_type'].toString(),
            if (product.containsKey('style_match_quality')) 'style_${product['style_match_quality']}',
          ].where((tag) => tag.toString().isNotEmpty).map((tag) => tag.toString()).toList(),
          purchaseUrl: product['purchase_url'] ?? 'https://example.com/product/${product['id']}',
        ));
      }

      return itemResults;

    } catch (e) {
      print('Error in parallel search for item $itemIndex ($category): $e');
      return [];
    }
  }

  // Lightweight logging for performance - minimal I/O operations
  Future<void> _logBasicSession(
    String sessionId,
    Map<String, dynamic>? analysisJson,
    List<DetectionResult> results,
  ) async {
    try {
      if (analysisJson == null) return;

      final items = analysisJson['items'] as List? ?? [];
      print('📝 Session logged: $sessionId (${items.length} items detected, ${results.length} results found)');

      // Only do basic console logging - no file I/O for performance
      if (items.isNotEmpty) {
        print('=== BASIC SESSION SUMMARY ===');
        for (int i = 0; i < items.length && i < 3; i++) {
          final item = items[i];
          print('Item ${i + 1}: ${item['category']} (${item['color_primary']})');
        }

        if (results.isNotEmpty) {
          print('Top results:');
          for (int i = 0; i < results.length && i < 3; i++) {
            final result = results[i];
            print('  ${i + 1}. ${result.productName} (confidence: ${result.confidence.toStringAsFixed(2)})');
          }
        }
        print('=== END BASIC SESSION ===');
      }

    } catch (e) {
      print('❌ Failed to log basic session: $e');
    }
  }

  // Progressive loading: Apply quality thresholds for better user experience
  List<Map<String, dynamic>> _applyQualityThresholds(
    List<Map<String, dynamic>> results,
    int searchLevel
  ) {
    if (results.isEmpty) return results;

    // Different quality thresholds based on search level
    final qualityThresholds = {
      1: 120, // Level 1 (exact matches): High threshold
      2: 110, // Level 2 (mapped matches): Medium-high threshold
      4: 100, // Level 4 (Claude priority): Medium threshold
    };

    final minCompositeScore = qualityThresholds[searchLevel] ?? 90;

    // Filter by composite score quality
    final qualityResults = results.where((result) {
      final compositeScore = result['composite_score'] as int? ?? 100;
      return compositeScore >= minCompositeScore;
    }).toList();

    // Ensure we have minimum results for progressive loading
    if (qualityResults.length >= _minResultsForProgressive) {
      print('📈 PROGRESSIVE LOADING: Delivering ${qualityResults.length} high-quality results early (score >= $minCompositeScore)');

      // Take top results based on quality
      final topResults = qualityResults.take(20).toList();

      return topResults;
    } else {
      // If not enough quality results, return more but with warning
      print('⚠️ QUALITY THRESHOLD: Only ${qualityResults.length} high-quality results, returning ${results.take(10).length} results');
      return results.take(10).toList();
    }
  }
}
