import 'package:supabase_flutter/supabase_flutter.dart';

/// Service to manage user credits and analyses
///
/// Free users: Get 1 free analysis (can include multiple garments)
/// Paid users: Get 100 credits/month (1 credit = 1 garment search result)
class CreditService {
  final _supabase = Supabase.instance.client;

  /// Initialize a new user with 1 free analysis
  Future<void> initializeNewUser(String userId) async {
    try {
      await _supabase.from('profiles').upsert({
        'id': userId,
        'free_analyses_remaining': 1,
        'paid_credits_remaining': 0,
        'subscription_tier': 'free',
        'updated_at': DateTime.now().toIso8601String(),
      });
      print('[CreditService] Initialized user $userId with 1 free analysis');
    } catch (e) {
      print('[CreditService] Error initializing user credits: $e');
      rethrow;
    }
  }

  /// Check if user can perform an analysis
  /// Returns true if they have free analyses OR paid credits remaining
  Future<bool> canPerformAnalysis() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('profiles')
          .select('free_analyses_remaining, paid_credits_remaining, subscription_tier')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        // User profile doesn't exist yet, initialize it
        await initializeNewUser(userId);
        return true; // They now have 1 free analysis
      }

      final freeAnalyses = response['free_analyses_remaining'] as int? ?? 0;
      final paidCredits = response['paid_credits_remaining'] as int? ?? 0;

      return freeAnalyses > 0 || paidCredits > 0;
    } catch (e) {
      print('[CreditService] Error checking if can perform analysis: $e');
      return false;
    }
  }

  /// Get current user's credit status
  Future<CreditStatus> getCreditStatus() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return CreditStatus(
          subscriptionTier: 'free',
          freeAnalysesRemaining: 0,
          paidCreditsRemaining: 0,
        );
      }

      final response = await _supabase
          .from('profiles')
          .select('free_analyses_remaining, paid_credits_remaining, subscription_tier')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        // New user, return default
        return CreditStatus(
          subscriptionTier: 'free',
          freeAnalysesRemaining: 1,
          paidCreditsRemaining: 0,
        );
      }

      return CreditStatus(
        subscriptionTier: response['subscription_tier'] as String? ?? 'free',
        freeAnalysesRemaining: response['free_analyses_remaining'] as int? ?? 0,
        paidCreditsRemaining: response['paid_credits_remaining'] as int? ?? 0,
      );
    } catch (e) {
      print('[CreditService] Error getting credit status: $e');
      return CreditStatus(
        subscriptionTier: 'free',
        freeAnalysesRemaining: 0,
        paidCreditsRemaining: 0,
      );
    }
  }

  /// Consume credits for an analysis
  /// - For free users: Deducts 1 free analysis (regardless of garment count)
  /// - For paid users: Deducts credits based on number of garments detected
  Future<void> consumeCreditsForAnalysis(int garmentCount) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final status = await getCreditStatus();

      if (status.isFreeUser) {
        // Free user: Consume 1 free analysis
        if (status.freeAnalysesRemaining > 0) {
          await _supabase.from('profiles').update({
            'free_analyses_remaining': status.freeAnalysesRemaining - 1,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', userId);
          print('[CreditService] Consumed 1 free analysis for user $userId (detected $garmentCount garments)');
        } else {
          throw Exception('No free analyses remaining');
        }
      } else {
        // Paid user: Consume credits based on garment count
        if (status.paidCreditsRemaining >= garmentCount) {
          await _supabase.from('profiles').update({
            'paid_credits_remaining': status.paidCreditsRemaining - garmentCount,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', userId);
          print('[CreditService] Consumed $garmentCount credits for user $userId');
        } else {
          throw Exception('Insufficient credits');
        }
      }
    } catch (e) {
      print('[CreditService] Error consuming credits: $e');
      rethrow;
    }
  }

  /// Add paid credits to user (called when they subscribe)
  Future<void> addPaidCredits(String userId, int credits) async {
    try {
      final status = await getCreditStatus();
      await _supabase.from('profiles').update({
        'paid_credits_remaining': status.paidCreditsRemaining + credits,
        'subscription_tier': 'monthly', // or 'yearly'
        'credits_reset_date': _getNextMonthDate().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
      print('[CreditService] Added $credits credits to user $userId');
    } catch (e) {
      print('[CreditService] Error adding paid credits: $e');
      rethrow;
    }
  }

  /// Reset monthly credits (called by cron job or when user opens app)
  Future<void> resetMonthlyCreditsIfNeeded() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('profiles')
          .select('subscription_tier, credits_reset_date')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return;

      final tier = response['subscription_tier'] as String?;
      final resetDateStr = response['credits_reset_date'] as String?;

      // Only reset for paid users
      if (tier == 'monthly' || tier == 'yearly') {
        if (resetDateStr != null) {
          final resetDate = DateTime.parse(resetDateStr);
          final now = DateTime.now();

          // If reset date has passed, give them new credits
          if (now.isAfter(resetDate)) {
            await _supabase.from('profiles').update({
              'paid_credits_remaining': 100,
              'credits_reset_date': _getNextMonthDate().toIso8601String(),
              'updated_at': now.toIso8601String(),
            }).eq('id', userId);
            print('[CreditService] Reset monthly credits for user $userId');
          }
        }
      }
    } catch (e) {
      print('[CreditService] Error resetting monthly credits: $e');
    }
  }

  DateTime _getNextMonthDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1, now.day);
  }
}

/// Model for user's credit status
class CreditStatus {
  final String subscriptionTier; // 'free', 'monthly', 'yearly'
  final int freeAnalysesRemaining;
  final int paidCreditsRemaining;

  CreditStatus({
    required this.subscriptionTier,
    required this.freeAnalysesRemaining,
    required this.paidCreditsRemaining,
  });

  bool get isFreeUser => subscriptionTier == 'free';
  bool get isPaidUser => subscriptionTier == 'monthly' || subscriptionTier == 'yearly';
  bool get hasCredits => freeAnalysesRemaining > 0 || paidCreditsRemaining > 0;

  /// Get user-friendly message about remaining credits
  String get displayMessage {
    if (isFreeUser) {
      return freeAnalysesRemaining > 0
          ? '1 free analysis remaining'
          : 'No analyses remaining';
    } else {
      return '$paidCreditsRemaining credits remaining';
    }
  }
}
