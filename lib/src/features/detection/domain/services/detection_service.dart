import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../core/constants/trusted_domains.dart';
import '../models/detection_result.dart';
import '../../../../core/constants/category_rules.dart';

/// Detection pipeline powered by local YOLOS + SerpAPI Google Lens.
class DetectionService {
  DetectionService({
    http.Client? client,
    this.strictMode = true, // ✅ Strict mode ON by default
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final bool strictMode;

  static const int _maxGarments = 5;
  static const int _maxResultsPerGarment = 25; // allow more per query since we paginate
  static const int _maxPerDomain = 3;

  // serp cache keyed by imageUrl + textQuery
  static final Map<String, List<Map<String, dynamic>>> _serpCache = {};

  /// Main entrypoint — detect garments, upload crops, and fetch SerpAPI matches.
  Future<List<DetectionResult>> analyzeImage(XFile image) async {
    try {
      debugPrint('🧠 Starting garment detection pipeline (strict=$strictMode)...');
      final batch = await _runLocalDetector(image);

      // Sort crops by detector score (desc)
      final sortedCrops = batch.crops.take(_maxGarments).toList()
        ..sort((a, b) => b.score.compareTo(a.score));

      // Build query order: best crop → original (context) → remaining crops
      final labelByUrl = {for (final crop in sortedCrops) crop.url: crop.label};
      final urls = <String>[];
      if (sortedCrops.isNotEmpty) urls.add(sortedCrops.first.url);
      if (batch.originalUrl.isNotEmpty) urls.add(batch.originalUrl);
      urls.addAll(sortedCrops.skip(1).map((c) => c.url));

      if (urls.isEmpty) {
        final fallbackUrl = batch.originalUrl.isNotEmpty
            ? batch.originalUrl
            : await _uploadImageToImgbb(image);
        if (fallbackUrl.isNotEmpty) {
          urls.add(fallbackUrl);
        } else {
          throw Exception('No usable image crops produced.');
        }
      }

      debugPrint('🔍 Querying SerpAPI for ${urls.length} image URLs (best-first)...');

      // Try to derive a helpful text query from the best crop label
      final labelHint = sortedCrops.isNotEmpty ? sortedCrops.first.label : '';
      final textQuery = _guessTextQuery(labelHint);

      // Run queries (in parallel) with pagination + fallback broaden
      final futures = urls.map((url) async {
        try {
          final matches = await _fetchSerpResults(url, textQuery: textQuery);
          final seen = <String>{};
          final uniqueMatches = matches.where((m) {
            final link = (m['link'] as String?) ?? '';
            final title = (m['title'] as String?) ?? '';
            final key = '$link|$title';
            if (seen.contains(key)) return false;
            seen.add(key);
            return true;
          }).take(_maxResultsPerGarment).toList();
          return _mapToDetectionResults(
            uniqueMatches,
            url,
            detectionLabel: labelByUrl[url],
          );
        } catch (e) {
          debugPrint('⚠️ Search failed for image crop (continuing with others): $e');
          return <DetectionResult>[]; // Return empty list instead of throwing
        }
      }).toList();

      // Flatten
      var allResults = (await Future.wait(futures)).expand((x) => x).toList();

      // Drop generic collection/landing pages when we have enough PDPs
      final pdpCount = allResults.where((r) => !_looksLikeCollection(r.productName, r.purchaseUrl ?? '')).length;
      if (pdpCount >= 10) {
        final before = allResults.length;
        allResults.removeWhere((r) => _looksLikeCollection(r.productName, r.purchaseUrl ?? ''));
        debugPrint('🧽 Removed ${before - allResults.length} generic collection pages (kept PDPs)');
      }

      final deduped = _deduplicateAndLimitByDomain(allResults);

      if (deduped.isEmpty) {
        throw Exception('No shoppable results found. Try a clearer garment image.');
      }

      debugPrint('✅ Pipeline complete. Returning ${deduped.length} verified results.');
      return deduped;
    } catch (error, stackTrace) {
      debugPrint('❌ Detection failed: $error\n$stackTrace');
      rethrow;
    }
  }

  /// Step 1 — Call local YOLOS FastAPI detection server
  Future<_SerpImageBatch> _runLocalDetector(XFile image) async {
    final endpoint = AppConstants.serpDetectorEndpoint;
    try {
      final bytes = await image.readAsBytes();
      final payload = jsonEncode({
        'image_base64': base64Encode(bytes),
        'max_crops': _maxGarments,
        'imbb_api_key': AppConstants.imgbbApiKey,
        'upload_to_imgbb': true,
        'serp_api_key': AppConstants.serpApiKey,
      });

      debugPrint('🚀 Sending image to local detector: $endpoint');
      final response = await _client.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: payload,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final originalUrl = (data['original_url'] as String?) ?? '';
        final cropsRaw = (data['results'] as List<dynamic>? ?? const [])
            .map((e) => e as Map<String, dynamic>)
            .toList();

        final crops = cropsRaw
            .map(
              (crop) => _SerpCrop(
                url: (crop['imgbb_url'] as String?) ?? (crop['url'] as String?) ?? '',
                score: (crop['score'] as num?)?.toDouble() ?? 0.0,
                label: (crop['label'] as String?) ?? 'unknown',
              ),
            )
            .where((crop) => crop.url.isNotEmpty)
            .toList();

        crops.sort((a, b) => b.score.compareTo(a.score));
        debugPrint('👕 ${crops.length} garment crops detected.');
        return _SerpImageBatch(originalUrl: originalUrl, crops: crops);
      }

      throw Exception('Detector server responded with ${response.statusCode}: ${response.body}');
    } catch (error) {
      debugPrint('⚠️ Detector unavailable: $error');
      final fallbackUrl = await _uploadImageToImgbb(image);
      return _SerpImageBatch(originalUrl: fallbackUrl, crops: const []);
    }
  }

  /// Upload fallback image to ImgBB
  Future<String> _uploadImageToImgbb(XFile file) async {
    final imageBytes = await file.readAsBytes();
    final response = await _client.post(
      Uri.https('api.imgbb.com', '/1/upload'),
      body: {'key': AppConstants.imgbbApiKey, 'image': base64Encode(imageBytes)},
    );

    if (response.statusCode != 200) throw Exception('ImgBB upload failed.');
    final data = jsonDecode(response.body);
    return (data['data']?['url'] ?? '') as String;
  }

  /// Step 2 — Search via SerpAPI (Google Lens), with pagination + optional text query and a fallback broadening pass.
  Future<List<Map<String, dynamic>>> _fetchSerpResults(
    String imageUrl, {
    String? textQuery,
  }) async {
    // Primary pass (possibly with textQuery)
    List<Map<String, dynamic>> primary = [];
    try {
      primary = await _fetchSerpResultsOnce(imageUrl, textQuery: textQuery);
    } catch (e) {
      debugPrint('⚠️ Primary search failed: $e');
      // Continue to broadening pass
    }

    // If the hint over-filters, broaden with a second pass (no textQuery)
    if ((textQuery == null || textQuery.isEmpty) || primary.length >= 15) {
      return primary;
    }

    List<Map<String, dynamic>> secondary = [];
    try {
      secondary = await _fetchSerpResultsOnce(imageUrl, textQuery: null);
    } catch (e) {
      debugPrint('⚠️ Broadening search failed: $e');
      return primary; // Return primary results (even if empty)
    }

    // Merge unique: primary first (keeps original sort bias)
    final seen = <String>{};
    final merged = <Map<String, dynamic>>[];

    for (final m in [...primary, ...secondary]) {
      final key = '${m['link'] ?? ''}|${m['title'] ?? ''}';
      if (seen.add(key)) merged.add(m);
      if (merged.length >= 120) break; // hard safety cap
    }
    return merged;
  }

  Future<List<Map<String, dynamic>>> _fetchSerpResultsOnce(
    String imageUrl, {
    String? textQuery,
  }) async {
    final cacheKey = '$imageUrl|${textQuery ?? ''}';
    if (_serpCache.containsKey(cacheKey)) {
      debugPrint('⚡ Using cached SerpAPI results for: $cacheKey');
      return _serpCache[cacheKey]!;
    }

    final filteredAll = <Map<String, dynamic>>[];

    // 👇 Products-only search (visual_matches disabled to avoid duplicate Lens hits)
    const rails = ['products'];

    for (final rail in rails) {
      String? nextToken;
      int page = 1;

      do {
        final params = <String, String>{
          'engine': 'google_lens',
          'api_key': AppConstants.serpApiKey,
          'url': imageUrl,
          'type': rail, // 👈 lock to products rail (no visual_matches)
          if (textQuery != null && textQuery.isNotEmpty) 'text_query': textQuery,
          if (nextToken != null) 'next_page_token': nextToken!,
        };

        final uri = Uri.https('serpapi.com', '/search', params);
        final start = DateTime.now();
        final response = await _client.get(uri);
        final elapsed = DateTime.now().difference(start).inMilliseconds / 1000.0;

        if (response.statusCode != 200) throw Exception('SerpAPI failed: ${response.body}');
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['error'] != null) throw Exception('SerpAPI error: ${data['error']}');

        final dynamic productResults = data['product_results'];
        final List<dynamic> rawList;
        if (data['visual_matches'] is List<dynamic>) {
          rawList = data['visual_matches'] as List<dynamic>;
        } else if (productResults is List<dynamic>) {
          rawList = productResults;
        } else if (productResults is Map<String, dynamic>) {
          final organic = productResults['organic_results'];
          rawList = organic is List<dynamic> ? organic : const [];
        } else {
          rawList = const [];
        }
        final rawMatches = rawList
            .whereType<Map<String, dynamic>>()
            .toList();

        final pageFiltered = <Map<String, dynamic>>[];
        for (final m in rawMatches) {
          final link = (m['link'] as String?) ?? '';
          final title = (m['title'] as String?) ?? '';
          final source = (m['source'] as String?) ?? '';
          final snippet = (m['snippet'] as String?) ?? '';
          if (_isEcommerceResult(link, source, title, snippet: snippet, match: m) &&
              _isRelevantResult(title)) {
            pageFiltered.add(m);
          }
        }

        filteredAll.addAll(pageFiltered);

        nextToken = (data['serpapi_pagination']?['next_page_token'] as String?);
        debugPrint('🛍️ [$rail] Page $page: +${pageFiltered.length}, '
            'total ${filteredAll.length} (${elapsed.toStringAsFixed(2)}s) next=${nextToken != null}');
        page++;

        if (filteredAll.length >= _maxResultsPerGarment) break;
      } while (nextToken != null);

    }

    _serpCache[cacheKey] = filteredAll;
    return filteredAll;
  }

  /// Guess a helpful text query from a YOLOS label.
  String? _guessTextQuery(String label) {
    final l = (label.isEmpty ? '' : label.toLowerCase());
    if (l.contains('skirt')) {
      return 'silk satin lace midi slip skirt beige';
    }
    if (l.contains('dress')) {
      return 'silk satin lace slip dress midi beige';
    }
    return null; // no hint
  }

  /// === Smart semantic relevance filter ===
  bool _isRelevantResult(String title) {
    final lower = title.toLowerCase();

    // 🚫 banned terms (keep 'shoelace', DO NOT ban 'lace')
    const banned = [
      'texture','pattern','drawing','illustration','clipart','mockup','template',
      'icon','logo','vector','stock photo','hanger','material','silhouette','outline',
      'preset','filter','lightroom','photoshop','digital download','tutorial','guide',
      'lesson','manual','holder','stand','tripod','mount','case','charger','adapter',
      'cable','keyboard','mouse','phone','tablet','shoelace',
    ];
    if (banned.any((term) => lower.contains(term))) return false;

    // ✅ expected garment keywords
    const garmentKeywords = [
      'dress','top','shirt','t-shirt','pants','jeans','skirt','coat',
      'jacket','sweater','hoodie','bag','handbag','backpack','tote',
      'sandal','boot','shoe','sneaker','heel','glasses','sunglasses',
      'hat','cap','scarf','outfit','clothing','apparel','fashion'
    ];
    if (garmentKeywords.any(lower.contains)) return true;

    // Soft positive hints that matter for this garment family
    const styleHints = ['silk','satin','lace','bias','midi','maxi','slip','trim'];
    if (styleHints.any(lower.contains)) return true;

    return false;
  }

  /// === Convert SerpAPI JSON → DetectionResult ===
  List<DetectionResult> _mapToDetectionResults(
    List<Map<String, dynamic>> matches,
    String fallbackImageUrl, {
    String? detectionLabel,
  }) {
    final results = <DetectionResult>[];

    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      final title = (match['title'] as String?) ?? 'Unknown item';
      final source = (match['source'] as String?) ?? 'Unknown';
      final link = (match['link'] as String?) ?? '';
      final snippet = (match['snippet'] as String?) ?? '';
      final thumbnail = (match['thumbnail'] as String?) ?? '';

      // Price extraction
      final priceObj = match['price'];
      final price = (priceObj?['extracted_value'] as num?)?.toDouble() ??
          _extractPrice(snippet) ??
          0.0;

      final brand = _extractBrand(title, source);
      final category = _categorize(title, brand: brand, detectionLabel: detectionLabel);
      final confidence = _estimateConfidence(i, price);
      final tags = _generateTags(title, source);

      results.add(
        DetectionResult(
          id: 'serp_${DateTime.now().millisecondsSinceEpoch}_$i',
          productName: _formatTitle(title),
          brand: brand,
          price: price,
          imageUrl: thumbnail.isNotEmpty ? thumbnail : fallbackImageUrl,
          category: category,
          confidence: confidence,
          description: snippet.isNotEmpty ? snippet : null,
          tags: tags,
          purchaseUrl: link.isNotEmpty ? link : null,
        ),
      );
    }

    // Category consistency with compatibility (e.g., skirts ↔ slip dresses)
    if (results.isNotEmpty) {
      final categoryCounts = <String, int>{};
      for (final r in results) {
        categoryCounts[r.category] = (categoryCounts[r.category] ?? 0) + 1;
      }

      final dominant = categoryCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      final dominantRatio = categoryCounts[dominant]! / results.length;

      bool isCompatible(String dominant, String c) {
        if (dominant == c) return true;
        // Consider dresses <-> bottoms (skirts) compatible for slip/satin cases
        if ((dominant == 'bottoms' && c == 'dresses') || (dominant == 'dresses' && c == 'bottoms')) {
          return true;
        }
        return false;
      }

      if (dominantRatio >= 0.7) { // a touch firmer
        final before = results.length;
        results.removeWhere((r) => !isCompatible(dominant, r.category));
        debugPrint('🧩 Kept dominant "$dominant" (+ compatible), pruned ${before - results.length}');
      }
    }

    return results;
  }

  /// Identify generic collection/listing pages (stricter)
  bool _looksLikeCollection(String title, String url) {
    final l = title.toLowerCase();
    final u = (url).toLowerCase();
    if (RegExp(r'\b(women|men|kids|midi|maxi|skirts?|dresses|clothing)\b').hasMatch(l) && l.contains(' | ')) return true;
    if (RegExp(r'/c/|/category/|/collections?/|/shop/[^/]+/?$|/women/[^/]+/?$|/women/?$|/new-arrivals/?$|/sale/?$').hasMatch(u)) return true;
    if (u.endsWith('/index.html') || u.endsWith('/index')) return true;
    return false;
  }

  /// Prefer PDP-like URLs/titles.
  bool _looksLikePDP(String url, String title) {
    final u = url.toLowerCase();
    final t = title.toLowerCase();
    final pdpUrl = RegExp(r'/product/|/products?/|/p/|/pd/|/sku/|/item/|/buy/|/dp/|/gp/product/|/shop/[^/]*\d');
    final pdpTitle = RegExp(r'\b(sku|style|model|size|midi|maxi|silk|satin|lace)\b');
    return pdpUrl.hasMatch(u) || pdpTitle.hasMatch(t);
  }

  /// === Ecommerce filtering ===
  bool _isEcommerceResult(
    String link,
    String source,
    String title, {
    String? snippet,
    Map<String, dynamic>? match,
  }) {
    final text = '$link $source ${title.toLowerCase()} ${(snippet ?? '').toLowerCase()}';
    final domain = _extractDomain(link).toLowerCase();

    // Fully banned content/non-commerce
    if (_domainMatchesAny(domain, kBannedDomainRoots)) return false;

    // If in trusted roots, allow early (especially in strict mode)
    if (strictMode && _domainMatchesAny(domain, kTrustedDomainRoots)) return true;
    if (!strictMode && _domainMatchesAny(domain, kTrustedDomainRoots)) return true;

    // Generic ecommerce hints
    final hasPrice = RegExp(r'(\$|€|£|¥)\s?\d').hasMatch(text);
    final hasCart = RegExp(r'(add[\s_-]?to[\s_-]?cart|buy\s?now|checkout|in\s?stock)').hasMatch(text);
    final productUrl = RegExp(r'/(product|shop|store|item|buy)[/\-_]').hasMatch(link);
    return hasPrice || hasCart || productUrl;
  }

  /// Fashion-aware score (tier-1 boost, marketplace/aggregator penalty, style boosts)
  double _fashionScore(DetectionResult r) {
    final domain = _extractDomain(r.purchaseUrl ?? '');

    double mult = 1.0;

    // Trust & prestige
    if (_domainMatchesAny(domain, kTier1RetailDomainRoots)) mult *= 1.15;
    if (_domainMatchesAny(domain, kMarketplaceDomainRoots)) mult *= 0.88;
    if (_domainMatchesAny(domain, kAggregatorDomainRoots)) mult *= 0.90;

    // Style keywords
    final t = r.productName.toLowerCase();
    if (t.contains('silk'))  mult *= 1.06;
    if (t.contains('satin')) mult *= 1.06;
    if (t.contains('lace'))  mult *= 1.08;
    if (t.contains('midi'))  mult *= 1.03;
    if (t.contains('slip'))  mult *= 1.04;

    if (r.price > 0) mult *= 1.02;

    final base = r.confidence.clamp(0.0, 1.0);
    return base * mult;
  }

  /// Deduplication + domain caps with PDP preference and aggregator/marketplace limits.
  List<DetectionResult> _deduplicateAndLimitByDomain(List<DetectionResult> results) {
    // Rank by fashion-aware score
    results.sort((a, b) => _fashionScore(b).compareTo(_fashionScore(a)));

    final Map<String, List<DetectionResult>> byDomain = {};
    final Map<String, int> domainCount = {};
    final Set<String> seenUrls = {}; // exact URL dedupe globally

    for (final r in results) {
      final url = (r.purchaseUrl ?? '').trim();
      if (url.isEmpty) continue;
      if (!seenUrls.add(url)) continue; // already have this exact URL

      final domain = _extractDomain(url);
      if (domain.isEmpty) continue;

      final isTier1 = _domainMatchesAny(domain, kTier1RetailDomainRoots);
      final isMarketplace = _domainMatchesAny(domain, kMarketplaceDomainRoots);
      final isAggregator = _domainMatchesAny(domain, kAggregatorDomainRoots);
      final isTrustedRetail = _domainMatchesAny(domain, kTrustedRetailDomainRoots);
      final trusted = isTier1 || isTrustedRetail;

      final cap = (isMarketplace || isAggregator) ? 1 : (isTier1 ? 7 : (trusted ? 5 : _maxPerDomain));

      final list = byDomain.putIfAbsent(domain, () => []);
      if ((domainCount[domain] ?? 0) < cap) {
        // room available: add normally
        list.add(r);
        domainCount[domain] = (domainCount[domain] ?? 0) + 1;
      } else {
        // at cap: if current is PDP and any existing is not PDP, replace the lowest-score non-PDP
        final currIsPdp = _looksLikePDP(r.purchaseUrl ?? '', r.productName);
        if (!currIsPdp) continue;

        int replaceIdx = -1;
        double worstScore = double.infinity;
        for (var i = 0; i < list.length; i++) {
          final existing = list[i];
          final existingIsPdp = _looksLikePDP(existing.purchaseUrl ?? '', existing.productName);
          if (!existingIsPdp) {
            final s = _fashionScore(existing);
            if (s < worstScore) {
              worstScore = s;
              replaceIdx = i;
            }
          }
        }
        if (replaceIdx >= 0) {
          list[replaceIdx] = r; // prefer PDP within the cap
        }
      }
    }

    // Flatten back out (preserve domain-internal order)
    final flattened = <DetectionResult>[];
    byDomain.values.forEach(flattened.addAll);

    debugPrint('🧹 Deduped ${flattened.length} results across ${byDomain.length} domains.');
    return flattened;
  }

  /// === Helpers ===
  String _extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host.replaceAll(RegExp(r'^www\.'), '');
      final parts = host.split('.');
      if (parts.length >= 2) return '${parts[parts.length - 2]}.${parts.last}';
      return host;
    } catch (_) {
      return '';
    }
  }

  bool _domainMatchesAny(String domain, Set<String> roots) {
    final d = domain.toLowerCase();
    return roots.any((root) {
      final r = root.toLowerCase();
      return d == r || d.endsWith('.$r');
    });
  }

  String _normalizeTitle(String title) =>
      title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  String _formatTitle(String title) {
    if (title.isEmpty) return 'Unknown item';

    var clean = title;

    // Remove marketing / store fluff
    clean = clean.replaceAll(RegExp(
      r'(buy\s+now|official\s+store|free\s+shipping|online\s+shop|sale|discount|deal|brand\s+new|shop\s+now)',
      caseSensitive: false,
    ), '');

    // Split on common separators and keep the most informative part
    final parts = clean.split(RegExp(r'[\|\-:–—]+'));
    if (parts.isNotEmpty) {
      final good = parts.firstWhere(
        (p) => RegExp(r'[a-zA-Z]').hasMatch(p.trim()),
        orElse: () => parts.first,
      );
      clean = good.trim();
    }

    // Normalize whitespace
    clean = clean.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Capitalize first letter
    if (clean.isNotEmpty) {
      clean = clean[0].toUpperCase() + clean.substring(1);
    }

    // Limit length
    if (clean.length > 60) {
      clean = '${clean.substring(0, 57)}...';
    }

    return clean;
  }

  double? _extractPrice(String snippet) {
    final match = RegExp(
      r'(\$|£|€|¥|USD|CAD|AUD|Rs\.?|₹)\s?(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2})?)',
      caseSensitive: false,
    ).firstMatch(snippet);
    if (match == null) return null;
    final amount = match.group(2)!.replaceAll(RegExp(r'[,€£$¥₹]'), '');
    return double.tryParse(amount);
  }

  // === Category resolution ===
  // Keeps your explicit rules, then applies a generalized token-vote override.
  String _categorize(String title, {String? brand, String? detectionLabel}) {
    final lower = title.toLowerCase();
    final brandLower = brand?.toLowerCase() ?? '';
    final labelCategory = detectionLabel == null
        ? null
        : _labelCategoryOverrides[detectionLabel.toLowerCase().trim()];

    String? explicitCat;
    String finalizeCategory(String candidate) => _applyCategoryGuards(
      title: title,
      lower: lower,
      candidate: candidate,
      labelCategory: labelCategory,
    );

    // 1️⃣ Accessories (explicit)
    if (lower.contains('sunglass') ||
        lower.contains('eyeglass') ||
        lower.contains('spectacle') ||
        (lower.contains('frame') && lower.contains('lens')) ||
        lower.contains('belt') ||
        lower.contains('waist chain') ||
        lower.contains('necklace') ||
        lower.contains('bracelet') ||
        lower.contains('earring') ||
        lower.contains('ring') ||
        lower.contains('watch') ||
        RegExp(r'\bnecktie\b').hasMatch(lower) ||
        RegExp(r'\btie clip\b').hasMatch(lower) ||
        RegExp(r'\btie bar\b').hasMatch(lower) ||
        lower.contains('scarf') ||
        lower.contains('beanie') ||
        lower.contains('hat') ||
        lower.contains('cap') ||
        lower.contains('hair clip') ||
        lower.contains('hairpin') ||
        lower.contains('headband')) {
      explicitCat = 'accessories';
    }

    // 2️⃣ Bags
    if (explicitCat == null &&
        (lower.contains('bag') ||
            lower.contains('purse') ||
            lower.contains('tote') ||
            lower.contains('backpack') ||
            lower.contains('duffle') ||
            lower.contains('handbag') ||
            lower.contains('satchel') ||
            lower.contains('clutch') ||
            lower.contains('wallet'))) {
      explicitCat = 'bags';
    }

    // 3️⃣ Shoes
    if (explicitCat == null &&
        (lower.contains('shoe') ||
            lower.contains('boot') ||
            lower.contains('heel') ||
            lower.contains('pump') ||
            lower.contains('loafer') ||
            lower.contains('sandal') ||
            lower.contains('sneaker') ||
            lower.contains('trainer') ||
            lower.contains('moccasin') ||
            lower.contains('flip flop'))) {
      explicitCat = 'shoes';
    }

    // 4️⃣ Outerwear
    if (explicitCat == null &&
        (lower.contains('jacket') ||
            lower.contains('coat') ||
            lower.contains('blazer') ||
            lower.contains('parka') ||
            lower.contains('windbreaker') ||
            lower.contains('trench'))) {
      explicitCat = 'outerwear';
    }

    // 5️⃣ Dresses
    if (explicitCat == null &&
        (lower.contains('dress') ||
            lower.contains('jumpsuit') ||
            lower.contains('romper') ||
            lower.contains('gown'))) {
      explicitCat = 'dresses';
    }

    // 6️⃣ Bottoms
    if (explicitCat == null &&
        (lower.contains('pants') ||
            lower.contains('trouser') ||
            lower.contains('jean') ||
            lower.contains('shorts') ||
            lower.contains('skirt') ||
            lower.contains('leggings'))) {
      explicitCat = 'bottoms';
    }

    // 7️⃣ Tops
    if (explicitCat == null &&
        (lower.contains('t-shirt') ||
            lower.contains('tee') ||
            lower.contains('shirt') ||
            lower.contains('blouse') ||
            (lower.contains('top') &&
                !lower.contains('high top') &&
                !lower.contains('low top') &&
                !lower.contains('mid top')) ||
            lower.contains('tank') ||
            lower.contains('hoodie') ||
            lower.contains('sweatshirt') ||
            lower.contains('sweater') ||
            lower.contains('cardigan'))) {
      explicitCat = 'tops';
    }

    // 8️⃣ Headwear
    if (explicitCat == null &&
        (lower.contains('cap') ||
            lower.contains('hat') ||
            lower.contains('beanie') ||
            lower.contains('headband') ||
            lower.contains('beret'))) {
      explicitCat = 'headwear';
    }

    // 9️⃣ Brand-based hints
    if (explicitCat == null) {
      for (final entry in kBrandCategoryHints.entries) {
        if (brandLower.contains(entry.key) || lower.contains(entry.key)) {
          explicitCat = entry.value;
          break;
        }
      }
    }

    // 🔟 Luxury brand fallback
    if (explicitCat == null &&
        RegExp(r'gucci|prada|balenciaga|ysl|saint laurent|fendi|valentino|versace')
            .hasMatch(brandLower)) {
      explicitCat = 'accessories';
    }

    // --- Token-vote across ALL categories (generalized override) ---
    int score(String token) =>
        RegExp('\\b$token\\b').hasMatch(lower) ? 2 : (lower.contains(token) ? 1 : 0);

    final votes = <String, int>{
      'dresses': score('dress') + score('gown') + score('slip dress'),
      'bottoms': score('skirt') + score('pants') + score('trouser') + score('jeans') + score('shorts') + score('slip skirt'),
      'tops':    score('top') + score('shirt') + score('blouse') + score('t-shirt') + score('tee') + score('sweater') + score('cardigan'),
      'outerwear': score('jacket') + score('coat') + score('blazer') + score('trench') + score('parka') + score('windbreaker'),
      'shoes':   score('shoe') + score('sneaker') + score('boot') + score('heel') + score('loafer') + score('sandal') + score('pump'),
      'bags':    score('bag') + score('handbag') + score('tote') + score('backpack') + score('clutch') + score('wallet') + score('crossbody'),
      'accessories': score('belt') + score('scarf') + score('sunglass') + score('glasses') + score('hat') + score('cap') + score('beanie'),
      'headwear': score('cap') + score('hat') + score('beanie') + score('headband') + score('beret'),
    };

    final priority = ['bottoms','dresses','tops','outerwear','shoes','bags','accessories','headwear'];

    String best = 'accessories';
    int bestScore = -1;
    for (final c in priority) {
      final v = votes[c] ?? 0;
      if (v > bestScore) { best = c; bestScore = v; }
    }

    if (explicitCat == null) {
      debugPrint('🧩 Categorized "$title" as $best (vote only)');
      return finalizeCategory(best);
    }

    final explicitScore = votes[explicitCat] ?? 0;

    if (bestScore > explicitScore) {
      debugPrint('🧩 Categorized "$title" as $best (vote override; explicit was $explicitCat)');
      return finalizeCategory(best);
    }

    if (bestScore == explicitScore && best != explicitCat) {
      final pick = (priority.indexOf(best) < priority.indexOf(explicitCat)) ? best : explicitCat;
      debugPrint('🧩 Categorized "$title" as $pick (tie-break; explicit=$explicitCat, vote=$best)');
      return finalizeCategory(pick);
    }

    debugPrint('🧩 Categorized "$title" as $explicitCat (explicit)');
    return finalizeCategory(explicitCat!);
  }

  String _applyCategoryGuards({
    required String title,
    required String lower,
    required String candidate,
    String? labelCategory,
  }) {
    if (candidate == 'all') {
      if (labelCategory != null && _categoryHasKeyword(labelCategory, lower)) {
        debugPrint('Guard align "$title": detector label prefers $labelCategory over $candidate');
        return labelCategory;
      }
      return candidate;
    }

    final candidateValid = _categoryHasKeyword(candidate, lower);
    final labelValid = labelCategory != null && _categoryHasKeyword(labelCategory, lower);

    if (!candidateValid) {
      if (labelValid) {
        debugPrint('Guard override "$title": detector label forced $labelCategory (candidate $candidate missing keywords)');
        return labelCategory!;
      }
      debugPrint('Guard fallback "$title": missing keyword for $candidate, assigning all');
      return 'all';
    }

    if (labelValid && labelCategory != candidate) {
      debugPrint('Guard align "$title": detector label prefers $labelCategory over $candidate');
      return labelCategory!;
    }

    return candidate;
  }

  bool _categoryHasKeyword(String category, String lower) {
    final tokens = _categoryGuardTokens[category];
    if (tokens == null || tokens.isEmpty) return true;
    for (final token in tokens) {
      if (lower.contains(token)) {
        return true;
      }
    }
    return false;
  }

  double _estimateConfidence(int index, double price) {
    var score = 0.55;
    if (index < 5) score += 0.15;
    if (price > 0) score += 0.1;
    return score.clamp(0.0, 0.99);
  }

  List<String> _generateTags(String title, String source) {
    final tags = <String>[];
    final words = title.split(RegExp(r'[^\w]+')).where((w) => w.length > 3).take(5);
    tags.addAll(words.map((w) => w.toLowerCase()));
    if (source.isNotEmpty) tags.add(source.toLowerCase());
    return tags.toSet().toList();
  }

  String _extractBrand(String title, String source) {
    if (source.isNotEmpty) return _titleCase(source);
    final match = RegExp(r"^[A-Za-z0-9'& ]{2,20}").firstMatch(title);
    if (match != null) {
      final candidate = match.group(0)!.trim();
      if (candidate.isNotEmpty && !_stopWords.contains(candidate.toLowerCase())) {
        return _titleCase(candidate);
      }
    }
    return 'Unknown';
  }

  String _titleCase(String value) => value
      .split(RegExp(r'\s+'))
      .where((s) => s.isNotEmpty)
      .map((s) => s[0].toUpperCase() + s.substring(1).toLowerCase())
      .join(' ');

  static const Set<String> _stopWords = {
    'the', 'and', 'with', 'from', 'shop', 'buy', 'store', 'official'
  };

  static const Map<String, List<String>> _categoryGuardTokens = {
    'dresses': ['dress', 'gown', 'jumpsuit', 'romper', 'maxi', 'midi', 'mini'],
    'tops': ['top', 'shirt', 'tee', 't-shirt', 'blouse', 'tank', 'sweater', 'hoodie', 'cardigan', 'crewneck'],
    'bottoms': ['pant', 'pants', 'trouser', 'jean', 'denim', 'short', 'skirt', 'legging', 'culotte', 'jogger'],
    'outerwear': ['jacket', 'coat', 'blazer', 'trench', 'parka', 'vest', 'puffer', 'windbreaker'],
    'shoes': ['shoe', 'sneaker', 'boot', 'heel', 'loafer', 'sandal', 'trainer', 'cleat', 'moccasin', 'slipper', 'oxford', 'derby'],
    'bags': ['bag', 'handbag', 'tote', 'purse', 'crossbody', 'backpack', 'satchel', 'clutch', 'wallet', 'duffel'],
    'accessories': ['scarf', 'belt', 'glasses', 'sunglass', 'earring', 'necklace', 'bracelet', 'ring', 'watch', 'hair clip', 'headband', 'beanie'],
    'headwear': ['hat', 'cap', 'beanie', 'headband', 'beret', 'visor', 'bucket'],
  };

  static const Map<String, String> _labelCategoryOverrides = {
    'dress': 'dresses',
    'jumpsuit': 'dresses',
    'romper': 'dresses',
    'cape': 'outerwear',
    'coat': 'outerwear',
    'jacket': 'outerwear',
    'vest': 'outerwear',
    'cardigan': 'tops',
    'sweater': 'tops',
    'shirt, blouse': 'tops',
    'top, t-shirt, sweatshirt': 'tops',
    'shirt': 'tops',
    'pants': 'bottoms',
    'shorts': 'bottoms',
    'skirt': 'bottoms',
    'shoe': 'shoes',
    'bag, wallet': 'bags',
    'bag': 'bags',
    'glasses': 'accessories',
    'hat': 'headwear',
    'headband, head covering, hair accessory': 'headwear',
    'scarf': 'accessories',
    'belt': 'accessories',
  };

  static const Map<String, List<String>> _categoryKeywords = {
    'dresses': ['dress', 'gown'],
    'tops': ['top', 'shirt', 'blouse', 'tee', 't-shirt', 'sweater'],
    'bottoms': ['jeans', 'pants', 'trouser', 'skirt', 'shorts'],
    'outerwear': ['coat', 'jacket', 'blazer', 'trench'],
    'shoes': ['shoe', 'sneaker', 'boot', 'heel', 'trainer', 'loafer', 'sandal'],
    'bags': ['bag', 'handbag', 'tote', 'backpack', 'clutch', 'crossbody'],
    'accessories': ['hat', 'cap', 'scarf', 'glasses'],
  };
}

class _SerpImageBatch {
  const _SerpImageBatch({required this.originalUrl, required this.crops});
  final String originalUrl;
  final List<_SerpCrop> crops;
}

class _SerpCrop {
  const _SerpCrop({required this.url, required this.score, required this.label});
  final String url;
  final double score;
  final String label;
}
