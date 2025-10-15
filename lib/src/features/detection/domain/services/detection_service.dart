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

  static const int _maxGarments = 4;
  static const int _maxResultsPerGarment = 10;
  static const int _maxPerDomain = 3;

  static final Map<String, List<Map<String, dynamic>>> _serpCache = {};

  /// Main entrypoint — detect garments, upload crops, and fetch SerpAPI matches.
  Future<List<DetectionResult>> analyzeImage(XFile image) async {
    try {
      debugPrint('🧠 Starting garment detection pipeline (strict=$strictMode)...');
      final batch = await _runLocalDetector(image);

      final urls = <String>{};
      if (batch.originalUrl.isNotEmpty) urls.add(batch.originalUrl);
      for (final crop in batch.crops.take(_maxGarments)) {
        if (crop.url.isNotEmpty) urls.add(crop.url);
      }

      if (urls.isEmpty) throw Exception('No usable image crops produced.');

      debugPrint('🔍 Querying SerpAPI for ${urls.length} image URLs (parallel)...');

      final futures = urls.map((url) async {
        final matches = await _fetchSerpResults(url);
        final seen = <String>{};
        final uniqueMatches = matches.where((m) {
          final link = (m['link'] as String?) ?? '';
          final title = (m['title'] as String?) ?? '';
          final key = '$link|$title';
          if (seen.contains(key)) return false;
          seen.add(key);
          return true;
        }).take(_maxResultsPerGarment).toList();
        return _mapToDetectionResults(uniqueMatches, url);
      }).toList();

      final allResults = (await Future.wait(futures)).expand((x) => x).toList();
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

  /// Step 2 — Search via SerpAPI (Google Lens)
  Future<List<Map<String, dynamic>>> _fetchSerpResults(String imageUrl) async {
    if (_serpCache.containsKey(imageUrl)) {
      debugPrint('⚡ Using cached SerpAPI results for: $imageUrl');
      return _serpCache[imageUrl]!;
    }

    final uri = Uri.https('serpapi.com', '/search', {
      'engine': 'google_lens',
      'api_key': AppConstants.serpApiKey,
      'url': imageUrl,
    });

    final start = DateTime.now();
    final response = await _client.get(uri);
    final elapsed = DateTime.now().difference(start).inMilliseconds / 1000.0;

    if (response.statusCode != 200) throw Exception('SerpAPI failed: ${response.body}');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['error'] != null) throw Exception('SerpAPI error: ${data['error']}');

    final rawMatches = data['visual_matches'] as List<dynamic>? ?? [];

    final filtered = <Map<String, dynamic>>[];
    for (final match in rawMatches) {
      final m = match as Map<String, dynamic>;
      final link = (m['link'] as String?) ?? '';
      final title = (m['title'] as String?) ?? '';
      final source = (m['source'] as String?) ?? '';
      final snippet = (m['snippet'] as String?) ?? '';

      if (!_isEcommerceResult(link, source, title, snippet: snippet, match: m)) continue;
      if (!_isRelevantResult(title)) continue; // ✅ semantic filter

      filtered.add(m);
    }

    debugPrint('🛍️ ${filtered.length} semantically relevant results (${elapsed.toStringAsFixed(2)}s)');
    _serpCache[imageUrl] = filtered;
    return filtered;
  }

  /// === Smart semantic relevance filter ===
  bool _isRelevantResult(String title) {
    final lower = title.toLowerCase();

    // 🚫 banned terms
    const banned = [
      'texture', 'pattern', 'drawing', 'illustration', 'clipart', 'mockup', 'template',
      'icon', 'logo', 'vector', 'stock photo', 'fabric', 'shoelace', 'lace',
      'hanger', 'material', 'cloth', 'silhouette', 'outline', 'art', 'design',
    ];
    if (banned.any((term) => lower.contains(term))) return false;

    // ✅ expected garment keywords
    const garmentKeywords = [
      'dress', 'top', 'shirt', 't-shirt', 'pants', 'jeans', 'skirt', 'coat',
      'jacket', 'sweater', 'hoodie', 'bag', 'handbag', 'backpack', 'tote',
      'sandal', 'boot', 'shoe', 'sneaker', 'heel', 'glasses', 'sunglasses',
      'hat', 'cap', 'scarf', 'outfit', 'clothing', 'apparel', 'fashion'
    ];
    if (garmentKeywords.any((k) => lower.contains(k))) return true;

    return false;
  }

  /// === Convert SerpAPI JSON → DetectionResult ===
  List<DetectionResult> _mapToDetectionResults(List<Map<String, dynamic>> matches, String fallbackImageUrl) {
    final results = <DetectionResult>[];
    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      final title = (match['title'] as String?) ?? 'Unknown item';
      final source = (match['source'] as String?) ?? 'Unknown';
      final link = (match['link'] as String?) ?? '';
      final snippet = (match['snippet'] as String?) ?? '';
      final thumbnail = (match['thumbnail'] as String?) ?? '';

      // ✅ Updated price extraction logic
      final priceObj = match['price'];
      final price = (priceObj?['extracted_value'] as num?)?.toDouble()
          ?? _extractPrice(snippet)
          ?? 0.0;
      final currency = (priceObj?['currency'] as String?) ?? '\$';

      final brand = _extractBrand(title, source);
      final category = _categorize(title);
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
          // Optionally, extend DetectionResult to include currency if desired
        ),
      );
    }
    return results;
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

    for (final bad in kBannedDomains) {
      if (domain.contains(bad) || source.toLowerCase().contains(bad)) return false;
    }

    if (strictMode && kTrustedDomains.any((good) => domain.contains(good))) return true;
    if (!strictMode && kTrustedDomains.any((d) => domain.contains(d))) return true;

    final hasPrice = RegExp(r'(\$|€|£|¥)\s?\d').hasMatch(text);
    final hasCart = RegExp(r'(add[\s_-]?to[\s_-]?cart|buy\s?now|checkout|in\s?stock)').hasMatch(text);
    final productUrl = RegExp(r'/(product|shop|store|item|buy)[/\-_]').hasMatch(link);
    return hasPrice || hasCart || productUrl;
  }

  /// === Deduplication ===
  List<DetectionResult> _deduplicateAndLimitByDomain(List<DetectionResult> results) {
    final Map<String, DetectionResult> deduped = {};
    final Map<String, int> domainCount = {};

    results.sort((a, b) {
      final ascore = a.confidence + (a.price > 0 ? 0.1 : 0);
      final bscore = b.confidence + (b.price > 0 ? 0.1 : 0);
      return bscore.compareTo(ascore);
    });

    for (final r in results) {
      final domain = _extractDomain(r.purchaseUrl ?? '');
      if (domain.isEmpty) continue;
      if (domainCount[domain] != null && domainCount[domain]! >= _maxPerDomain) continue;
      final key = '${_normalizeTitle(r.productName)}|$domain|${r.imageUrl}';
      if (!deduped.containsKey(key)) {
        deduped[key] = r;
        domainCount[domain] = (domainCount[domain] ?? 0) + 1;
      }
    }

    debugPrint('🧹 Deduped ${deduped.length} results across ${domainCount.length} domains.');
    return deduped.values.toList();
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
      // Pick the first part that looks like a real product name (has letters)
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

  String _categorize(String title, {String? brand}) {
    final lower = title.toLowerCase();
    final brandLower = brand?.toLowerCase() ?? '';

    // 1️⃣ Brand-based hints
    for (final entry in kBrandCategoryHints.entries) {
      if (brandLower.contains(entry.key) || lower.contains(entry.key)) {
        debugPrint('🧩 Categorized "$title" as ${entry.value} (brand hint)');
        return entry.value;
      }
    }

    // 2️⃣ Contextual overrides
    for (final entry in kCategoryOverrides.entries) {
      if (lower.contains(entry.key)) {
        debugPrint('🧩 Categorized "$title" as ${entry.value} (override)');
        return entry.value;
      }
    }

    // 3️⃣ Meta-context: "X | Shoes | Y" style titles
    if (lower.contains('| shoes |') ||
        lower.contains(' boots ') ||
        lower.contains('booties') ||
        lower.contains('heels ') ||
        lower.contains('sneaker')) {
      debugPrint('🧩 Categorized "$title" as shoes (context)');
      return 'shoes';
    }
    if (lower.contains('| bags |') || lower.contains(' handbag ') || lower.contains(' purse ')) {
      debugPrint('🧩 Categorized "$title" as bags (context)');
      return 'bags';
    }
    if (lower.contains('| accessories |') || lower.contains(' jewelry ')) {
      debugPrint('🧩 Categorized "$title" as accessories (context)');
      return 'accessories';
    }

    // 4️⃣ Keyword-based fallback (with word boundaries)
    for (final entry in kCategoryKeywords.entries) {
      for (final keyword in entry.value) {
        final pattern = RegExp(r'\b' + RegExp.escape(keyword) + r'\b');
        if (pattern.hasMatch(lower)) {
          debugPrint('🧩 Categorized "$title" as ${entry.key}');
          return entry.key;
        }
      }
    }

    // 5️⃣ Fallback: if brand is a fashion house (like Gucci, Prada, etc.)
    if (RegExp(r'gucci|prada|balenciaga|ysl|saint laurent|fendi|valentino|versace')
        .hasMatch(brandLower)) {
      debugPrint('🧩 Categorized "$title" as accessories (luxury fallback)');
      return 'accessories';
    }

    debugPrint('❔ No match for "$title", defaulted to accessories');
    return 'accessories';
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
