import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/models/detection_result.dart';
import '../../domain/services/detection_service.dart';

class DetectionState {
  final bool isAnalyzing;
  final String? error;
  final List<DetectionResult> results;

  const DetectionState({
    this.isAnalyzing = false,
    this.error,
    this.results = const [],
  });

  DetectionState copyWith({
    bool? isAnalyzing,
    String? error,
    List<DetectionResult>? results,
  }) {
    return DetectionState(
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      error: error,
      results: results ?? this.results,
    );
  }
}

class DetectionNotifier extends StateNotifier<DetectionState> {
  final DetectionService _detectionService;

  DetectionNotifier(this._detectionService) : super(const DetectionState());

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

  void clearResults() {
    state = const DetectionState();
  }
}

final detectionServiceProvider = Provider<DetectionService>((ref) {
  return DetectionService();
});

final detectionProvider = StateNotifierProvider<DetectionNotifier, DetectionState>((ref) {
  return DetectionNotifier(ref.watch(detectionServiceProvider));
});