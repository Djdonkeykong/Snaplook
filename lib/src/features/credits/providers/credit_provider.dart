import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/credit_service.dart';

/// Provider for CreditService instance
final creditServiceProvider = Provider<CreditService>((ref) {
  return CreditService();
});

/// Provider to check if user can perform an analysis
final canPerformAnalysisProvider = FutureProvider<bool>((ref) async {
  final creditService = ref.watch(creditServiceProvider);
  return await creditService.canPerformAnalysis();
});

/// Provider for user's credit status
final creditStatusProvider = StreamProvider<CreditStatus>((ref) async* {
  final creditService = ref.watch(creditServiceProvider);

  // Initial load
  yield await creditService.getCreditStatus();

  // Refresh every time this provider is invalidated
  // (e.g., after consuming credits or subscribing)
  while (true) {
    await Future.delayed(const Duration(seconds: 1));
    yield await creditService.getCreditStatus();
    break; // Only run once per invalidation
  }
});

/// Provider to get user-friendly credit display message
final creditDisplayMessageProvider = Provider<String>((ref) {
  final creditStatusAsync = ref.watch(creditStatusProvider);

  return creditStatusAsync.when(
    data: (status) => status.displayMessage,
    loading: () => 'Loading...',
    error: (_, __) => 'Unknown',
  );
});

/// Provider to check if user has any credits/analyses remaining
final hasCreditsProvider = Provider<bool>((ref) {
  final creditStatusAsync = ref.watch(creditStatusProvider);

  return creditStatusAsync.when(
    data: (status) => status.hasCredits,
    loading: () => false,
    error: (_, __) => false,
  );
});
