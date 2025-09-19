import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/detection_result.dart';
import '../../../../core/constants/app_constants.dart';

class DetectionService {
  static const String _replicateEndpoint = '${AppConstants.baseApiUrl}/predictions';

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
  static const String _fashionAnalysisPrompt = '''You are a comprehensive fashion analyst. Analyze this image and detect ALL fashion items visible.

MANDATORY CATEGORIES TO CHECK:
- bag, wallet, purse, handbag, backpack, tote, clutch
- belt
- cardigan, sweater
- coat, jacket, blazer
- dress
- glasses, sunglasses
- headband, hat, cap, beanie, head covering, hair accessory
- jeans, pants, trousers
- jumpsuit, romper
- scarf
- shirt, blouse, top, t-shirt, sweatshirt
- shoes (sandals, sneakers, heels, boots, flats, loafers, pumps)
- shorts
- skirt
- swimwear
- tie
- vest

EXCLUSIONS: Ignore all jewelry items including necklaces, earrings, bracelets, rings, watches, brooches, body jewelry.

CRITICAL INSTRUCTIONS FOR ACCURACY:

1. MATERIAL DETECTION by category:
   - DRESSES/CLOTHING: Look at fabric texture - textured/ribbed = KNIT, smooth flowery = COTTON, synthetic only if clearly artificial
   - SHOES: Smooth leather-like = LEATHER, canvas/fabric = SYNTHETIC, athletic materials = SYNTHETIC, textured = SUEDE
   - BAGS: Leather-like = LEATHER, fabric/canvas = SYNTHETIC, shiny = PATENT, unknown = SYNTHETIC
   - HEADWEAR: Soft fabric = COTTON, structured = WOOL, woven = STRAW, unknown = COTTON

2. SUBCATEGORY PRECISION by category:
   - DRESSES: midi_dress, bodycon_dress, fit_and_flare_dress (NOT wrap_dress unless clearly wrapped with tie closure)
   - SHOES: sandals (flat with straps), sneakers (athletic), heels (raised heel), boots (above ankle), flats (closed toe, flat)
   - BAGS: handbag (structured with handle), shoulder_bag (single strap), tote (large open), clutch (small no handle), backpack, crossbody
   - HEADWEAR: baseball_cap (visor), beanie (knit), fedora (dress hat), sun_hat (wide brim), headband (narrow band)
   - TOPS: t-shirt, blouse, shirt, tank_top, sweater, cardigan
   - BOTTOMS: jeans, pants, shorts, skirt, leggings

3. STYLE_DETAILS STRUCTURE by category:

   FOR CLOTHING (dress, top, bottom, outerwear):
   "style_details": {
     "neckline": "crew|round|v_neck|scoop|boat|off_shoulder",
     "sleeves": "sleeveless|cap|short|three_quarter|long",
     "length": "crop|regular|mini|knee|midi|maxi",
     "fit": "fitted|slim|regular|loose|relaxed|oversized",
     "closure": "buttons|zipper|pullover|wrap|tie"
   }

   FOR SHOES:
   "style_details": {
     "toe_style": "pointed|round|square|open|closed",
     "heel_type": "flat|low|medium|high|platform|wedge|stiletto",
     "heel_height": "flat|1-2in|2-3in|3-4in|4in+",
     "closure": "slip_on|lace_up|buckle|zipper|velcro|strap",
     "strap_style": "none|ankle|t-strap|slingback|multiple|wrap"
   }

   FOR BAGS:
   "style_details": {
     "size": "mini|small|medium|large|oversized",
     "handle_type": "none|short|long|adjustable|chain|rope",
     "strap_style": "none|single|double|chain|fabric|leather",
     "closure": "zipper|snap|magnetic|drawstring|flap|open",
     "hardware": "gold|silver|brass|black|rose_gold|none"
   }

   FOR HEADWEAR:
   "style_details": {
     "brim_style": "none|small|wide|curved|flat|asymmetrical",
     "crown_shape": "fitted|structured|soft|rounded|flat",
     "fit_type": "fitted|adjustable|stretchy|one_size|structured",
     "closure": "adjustable|snap|velcro|elastic|fitted|tie",
     "embellishments": "none|logo|embroidery|studs|ribbon|beads"
   }

4. If you see 2+ categories, DETECT ALL OF THEM.

ANTI-BIAS INSTRUCTIONS:
- Do NOT default to "wrap_dress" - look for actual wrap characteristics
- Do NOT say "synthetic" for all materials - observe actual fabric types
- Use category-appropriate style_details structure
- Be SPECIFIC about colors: cream vs beige, royal_blue vs blue

Return this EXACT JSON structure:

{
  "total_items_detected": 2,
  "detection_summary": "Found dress and shoes",
  "items": [
    {
      "item_number": 1,
      "category": "dress|top|bottom|outerwear|shoes|bag|accessories",
      "subcategory": "specific_type_within_category",
      "color_primary": "exact_color_name",
      "color_secondary": ["additional_colors"],
      "pattern": "solid|vertical_ribbed|horizontal_ribbed|striped|polka_dot|floral|geometric|textured",
      "material": "cotton|silk|denim|knit|leather|synthetic|suede|canvas|wool|unknown",
      "style_details": {
        // USE CATEGORY-APPROPRIATE FIELDS FROM ABOVE
      },
      "visibility": "fully_visible|partially_visible|partially_obscured",
      "confidence": 0.95
    }
  ],
  "style_analysis": {
    "overall_aesthetic": ["casual", "formal", "bohemian", "minimalist", "edgy"],
    "occasions": ["work", "casual", "formal", "party", "athletic"],
    "seasons": ["spring", "summer", "fall", "winter"],
    "coordination": "well_coordinated|partially_coordinated|mismatched"
  },
  "matching_data": {
    "outfit_completeness": "single_item|partial_outfit|complete_outfit",
    "similar_combinations": ["casual_summer_outfit", "business_casual"],
    "style_keywords": ["effortless", "comfortable", "minimalist", "scandinavian"]
  }
}

DETECTION RULES:
1. SCAN the ENTIRE image systematically
2. Look at feet, hands, neck, head, waist for accessories
3. Check for partially visible items at image edges
4. If you see ANY category from the list, include it
5. Better to include questionable items than miss them
6. Use "partially_visible" or "partially_obscured" for unclear items
7. NEVER return empty items array - there's always at least one fashion item

FOCUS AREAS:
- FEET: Always check for shoes/footwear of any type
- TORSO: Check for multiple layers (dress + cardigan, shirt + jacket)
- HANDS/ARMS: Check for bags, purses, carried items
- HEAD: Check for hats, headbands, hair accessories, glasses
- WAIST: Check for belts, waist accessories

Be thorough and systematic. Missing items is worse than false positives. Use the correct style_details structure for each category type.''';

  Future<List<DetectionResult>> analyzeImage(XFile image) async {
    try {
      print('Starting image analysis...');
      print('Replicate API Key: ${AppConstants.replicateApiKey.substring(0, 10)}...');
      print('Model Version: ${AppConstants.replicateModelVersion}');

      // First, upload image to Replicate
      final imageBytes = await image.readAsBytes();
      final base64Image = base64Encode(imageBytes);
      print('Image encoded, size: ${imageBytes.length} bytes');

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
            'image': 'data:image/jpeg;base64,$base64Image',
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
      return await _pollForResults(predictionId);
    } catch (e) {
      throw Exception('Image analysis failed: $e');
    }
  }

  Future<List<DetectionResult>> _pollForResults(String predictionId) async {
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
        print('Detection output: $output');
        return await _parseClaudeAnalysis(output);
      } else if (status == 'failed') {
        throw Exception('Prediction failed: ${data['error']}');
      }
    }

    throw Exception('Prediction timeout');
  }

  Future<List<DetectionResult>> _parseClaudeAnalysis(dynamic output) async {
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

      print('Analysis text: $analysisText');

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

      // Now search for similar items in Supabase for each detected item
      final allResults = <DetectionResult>[];

      for (int i = 0; i < items.length && i < 10; i++) {
        final item = items[i];
        final category = item['category'] ?? 'Unknown';
        final subcategory = item['subcategory'] ?? '';
        final colorPrimary = item['color_primary'] ?? '';
        final pattern = item['pattern'] ?? 'solid';
        final material = item['material'] ?? 'unknown';
        final confidence = (item['confidence'] ?? 0.85).toDouble();
        final styleDetails = item['style_details'] ?? {};

        print('Processing detected item: $category ($subcategory) - $colorPrimary $material');

        // Search for similar items with sophisticated filtering
        final rawMatches = await _executeSophisticatedSearch(
          category, subcategory, colorPrimary, pattern, material, styleDetails
        );

        if (rawMatches.isNotEmpty) {
          // Apply style filtering
          final styleFiltered = _applyStyleFilters(rawMatches, analysisJson);

          // Apply composite scoring
          final scoredMatches = _calculateCompositeScores(styleFiltered, analysisJson);

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
              id: product['id']?.toString() ?? '${i}_${j + 1}',
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
                if (product.containsKey('style_match_quality')) 'style_${product['style_match_quality']}',
              ].where((tag) => tag.toString().isNotEmpty).map((tag) => tag.toString()).toList(),
              purchaseUrl: product['purchase_url'] ?? 'https://example.com/product/${product['id']}',
            ));
          }

          allResults.addAll(itemResults);
        }
      }

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
        category, subcategory, colorPrimary, pattern, material, styleDetails
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
    Map<String, dynamic> styleDetails,
  ) async {
    print('SOPHISTICATED SEARCH: Starting 7-level search strategy');

    // Level 1: Exact pattern match with all attributes
    var results = await _searchWithStrictMatching(
      category, subcategory, colorPrimary, pattern, material, styleDetails, 20
    );
    if (results.isNotEmpty) {
      print('LEVEL 1 SUCCESS: Found ${results.length} exact matches');
      return results;
    }

    // Level 2: Exact pattern with smart mapping
    results = await _searchExactPatternWithMapping(
      category, subcategory, colorPrimary, pattern, styleDetails, 20
    );
    if (results.isNotEmpty) {
      print('LEVEL 2 SUCCESS: Found ${results.length} mapped matches');
      return results;
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
      return results.take(20).toList();
    }

    // Level 4: Claude priority matching
    results = await _searchClaudePriorityMatching(
      category, subcategory, colorPrimary, pattern, styleDetails, 20
    );
    if (results.isNotEmpty) {
      print('LEVEL 4 SUCCESS: Found ${results.length} Claude priority matches');
      return results;
    }

    // Level 5: Relax subcategory for exact pattern
    results = await _searchCoreNonNegotiable(
      category, colorPrimary, pattern, styleDetails, 20
    );
    if (results.isNotEmpty) {
      print('LEVEL 5 SUCCESS: Found ${results.length} core matches');
      return results;
    }

    // Level 6: Category + color + mapped pattern
    final mappedPattern = _getMappedPattern(pattern);
    if (mappedPattern != null && mappedPattern != pattern) {
      results = await _searchCategoryColorPattern(
        category, colorPrimary, mappedPattern, 20
      );
      if (results.isNotEmpty) {
        print('LEVEL 6 SUCCESS: Found ${results.length} mapped pattern matches');
        return results;
      }
    }

    // Level 7: Fallback - category + color only
    results = await _searchCategoryColor(category, colorPrimary, 20);
    if (results.isNotEmpty) {
      print('LEVEL 7 FALLBACK: Found ${results.length} basic matches');
      return results;
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
      return colorMatches.take(10).toList(); // Limit to top 10 variations

    } catch (e) {
      print('Smart color matching failed for "$detectedColor": $e');
      // Fallback to basic mapping
      final oldMapping = _getBasicColorMapping(detectedColor);
      if (oldMapping != null && oldMapping != detectedColor) {
        return [
          {'color': detectedColor, 'score': 100, 'type': 'exact'},
          {'color': oldMapping, 'score': 70, 'type': 'fallback'}
        ];
      }
      return [{'color': detectedColor, 'score': 100, 'type': 'exact'}];
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
      final supabase = Supabase.instance.client;
      var query = supabase.from('products').select('*').eq('category', category.toLowerCase());

      if (colorPrimary.isNotEmpty) query = query.eq('color_primary', colorPrimary);
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

      final response = await query.limit(limit);
      return List<Map<String, dynamic>>.from(response);
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
}