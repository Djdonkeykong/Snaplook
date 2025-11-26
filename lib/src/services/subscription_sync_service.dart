import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'superwall_service.dart';

/// Service for syncing subscription data between Superwall and Supabase.
class SubscriptionSyncService {
  static final SubscriptionSyncService _instance = SubscriptionSyncService._internal();
  factory SubscriptionSyncService() => _instance;
  SubscriptionSyncService._internal();

  final _supabase = Supabase.instance.client;
  final _superwall = SuperwallService();

  /// Sync subscription data from Superwall to Supabase.
  /// Call this after:
  /// - Successful paywall flow
  /// - User login
  /// - App startup (if authenticated)
  Future<void> syncSubscriptionToSupabase() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        debugPrint('[SubscriptionSync] No authenticated user - skipping sync');
        return;
      }

      debugPrint('[SubscriptionSync] Starting sync for user ${user.id}');

      final status = _superwall.getSubscriptionSnapshot();

      // Determine subscription status
      String subscriptionStatus = status.isActive ? 'active' : 'free';
      final expirationDate = status.expirationDate;
      final productId = status.productIdentifier;

      if (!status.isActive && expirationDate != null && expirationDate.isBefore(DateTime.now())) {
        subscriptionStatus = 'expired';
      }

      await _supabase.from('users').upsert({
        'id': user.id,
        'subscription_status': subscriptionStatus,
        'subscription_expires_at': expirationDate?.toIso8601String(),
        'billing_user_id': user.id,
        'subscription_product_id': productId,
        'subscription_provider': 'superwall',
        'is_trial': status.isInTrialPeriod,
        'subscription_last_synced_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id');

      debugPrint('[SubscriptionSync] Sync complete - Status: $subscriptionStatus, Trial: ${status.isInTrialPeriod}, Expires: $expirationDate');
    } catch (e, stackTrace) {
      debugPrint('[SubscriptionSync] Error syncing subscription: $e');
      debugPrint('[SubscriptionSync] Stack trace: $stackTrace');
    }
  }

  /// Get cached subscription status from Supabase
  /// This is fast but may be slightly out of date.
  Future<Map<String, dynamic>?> getCachedSubscriptionStatus() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final response = await _supabase
          .from('users')
          .select('subscription_status, subscription_expires_at, is_trial, subscription_last_synced_at')
          .eq('id', user.id)
          .single();

      return response;
    } catch (e) {
      debugPrint('[SubscriptionSync] Error getting cached status: $e');
      return null;
    }
  }

  /// Check if cached subscription data is stale (older than 1 hour).
  Future<bool> isCacheStale() async {
    try {
      final cached = await getCachedSubscriptionStatus();
      if (cached == null) return true;

      final lastSynced = cached['subscription_last_synced_at'] as String?;
      if (lastSynced == null) return true;

      final lastSyncedDate = DateTime.parse(lastSynced);
      final hoursSinceSync = DateTime.now().difference(lastSyncedDate).inHours;

      return hoursSinceSync > 1;
    } catch (e) {
      debugPrint('[SubscriptionSync] Error checking cache staleness: $e');
      return true; // If error, assume stale
    }
  }

  /// Identify user with Superwall.
  Future<void> identifyWithSuperwall(String userId) async {
    await _superwall.identify(userId);
    await syncSubscriptionToSupabase();
  }

  /// Reset Superwall identity on logout.
  Future<void> resetOnLogout() async {
    await _superwall.reset();
  }
}
