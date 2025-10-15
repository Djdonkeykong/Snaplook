import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/models/detection_result.dart';
import '../../domain/services/detection_service.dart';

class DetectionState {
  final bool isAnalyzing;
  final String? error;
  final List<DetectionResult> results;
  final String selectedCategory;

  const DetectionState({
    this.isAnalyzing = false,
    this.error,
    this.results = const [],
    this.selectedCategory = 'all',
  });

  DetectionState copyWith({
    bool? isAnalyzing,
    String? error,
    List<DetectionResult>? results,
    String? selectedCategory,
  }) {
    return DetectionState(
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      error: error,
      results: results ?? this.results,
      selectedCategory: selectedCategory ?? this.selectedCategory,
    );
  }
}

class DetectionNotifier extends StateNotifier<DetectionState> {
  final DetectionService _detectionService;

  DetectionNotifier(this._detectionService) : super(const DetectionState());

  // === Core image analysis ===
  Future<List<DetectionResult>> analyzeImage(XFile image) async {
    print('DetectionProvider: Starting image analysis');
    state = state.copyWith(isAnalyzing: true, error: null);

    try {
      print('DetectionProvider: Calling detection service...');
      final results = await _detectionService.analyzeImage(image);
      print('DetectionProvider: Analysis completed, ${results.length} results');

      state = state.copyWith(
        isAnalyzing: false,
        results: results,
      );
      return results;
    } catch (e) {
      print('DetectionProvider: Analysis failed - $e');
      state = state.copyWith(
        isAnalyzing: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  // === Category selection ===
  void setSelectedCategory(String category) {
    state = state.copyWith(selectedCategory: category.toLowerCase());
  }

  // === Clear ===
  void clearResults() {
    state = const DetectionState();
  }

  // === Derived getters ===

  /// Dynamically computes all available categories from current results.
  /// Always includes "all", sorted in consistent visual order.
  List<String> get availableCategories {
    const preferredOrder = [
      'all',
      'dresses',
      'tops',
      'bottoms',
      'outerwear',
      'shoes',
      'bags',
      'accessories',
      'headwear',
    ];

    final found = state.results.map((r) => r.category.toLowerCase()).toSet();
    final filtered = preferredOrder.where((c) => c == 'all' || found.contains(c)).toList();
    return filtered;
  }

  /// Returns results filtered by selected category.
  List<DetectionResult> get filteredResults {
    if (state.selectedCategory == 'all') return state.results;
    return state.results
        .where((r) => r.category.toLowerCase() == state.selectedCategory)
        .toList();
  }
}

final detectionServiceProvider = Provider<DetectionService>((ref) {
  return DetectionService();
});

final detectionProvider = StateNotifierProvider<DetectionNotifier, DetectionState>((ref) {
  return DetectionNotifier(ref.watch(detectionServiceProvider));
});
