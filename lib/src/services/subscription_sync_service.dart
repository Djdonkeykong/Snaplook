import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'revenue_cat_service.dart';

/// Service for syncing subscription data between RevenueCat and Supabase
///
/// RevenueCat is the source of truth for subscription status.
/// Supabase stores a cached copy for fast queries and offline access.
class SubscriptionSyncService {
  static final SubscriptionSyncService _instance = SubscriptionSyncService._internal();
  factory SubscriptionSyncService() => _instance;
  SubscriptionSyncService._internal();

  final _supabase = Supabase.instance.client;
  final _revenueCat = RevenueCatService();

  /// Sync subscription data from RevenueCat to Supabase
  /// Call this after:
  /// - Successful purchase
  /// - Restore purchases
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

      // Get subscription status from RevenueCat (source of truth)
      final hasActivePremium = await _revenueCat.hasActivePremium();
      final isInTrial = await _revenueCat.isInTrialPeriod();
      final expirationDate = await _revenueCat.getExpirationDate();
      final customerInfo = _revenueCat.currentCustomerInfo;

      // Determine subscription status
      String subscriptionStatus = 'free';
      String? productId;

      if (hasActivePremium) {
        subscriptionStatus = 'active';

        // Get product ID from active entitlements
        final activeEntitlements = customerInfo?.entitlements.active;
        if (activeEntitlements != null && activeEntitlements.isNotEmpty) {
          final premiumEntitlement = activeEntitlements[RevenueCatService.premiumEntitlementId];
          productId = premiumEntitlement?.productIdentifier;
        }
      } else if (expirationDate != null && expirationDate.isBefore(DateTime.now())) {
        subscriptionStatus = 'expired';
      }

      // Update Supabase with subscription data
      // IMPORTANT: Store the Supabase user ID (not RevenueCat's originalAppUserId)
      // This ensures proper linking whether account is created before or after purchase
      await _supabase.from('users').upsert({
        'id': user.id,
        'subscription_status': subscriptionStatus,
        'subscription_expires_at': expirationDate?.toIso8601String(),
        'revenue_cat_user_id': user.id, // Store Supabase user ID for proper account linking
        'subscription_product_id': productId,
        'is_trial': isInTrial,
        'subscription_last_synced_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id');

      debugPrint('[SubscriptionSync] Sync complete - Status: $subscriptionStatus, Trial: $isInTrial, Expires: $expirationDate');
    } catch (e, stackTrace) {
      debugPrint('[SubscriptionSync] Error syncing subscription: $e');
      debugPrint('[SubscriptionSync] Stack trace: $stackTrace');
      // Don't throw - syncing is non-critical, app should continue working
    }
  }

  /// Get cached subscription status from Supabase
  /// This is fast but may be slightly out of date
  /// For critical checks, verify with RevenueCat
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

  /// Check if cached subscription data is stale (older than 1 hour)
  /// If stale, should trigger a sync
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

  /// Link Supabase user to RevenueCat user ID
  /// Call this when user creates account or logs in
  /// Returns true if linking succeeded, false if subscription conflict detected
  Future<bool> linkRevenueCatUser(String userId) async {
    try {
      // Check for existing subscription in Supabase BEFORE linking
      final existingData = await getCachedSubscriptionStatus();
      final hadExistingSubscription = existingData?['subscription_status'] == 'active';

      debugPrint('[SubscriptionSync] Linking user $userId to RevenueCat');
      if (hadExistingSubscription) {
        debugPrint('[SubscriptionSync] User already has active subscription in Supabase');
      }

      // Set user ID in RevenueCat (this also calls syncPurchases internally)
      await _revenueCat.setUserId(userId);

      // Verify entitlements are still active after linking
      final customerInfo = _revenueCat.currentCustomerInfo;
      final hasActivePremium = customerInfo?.entitlements.active
          .containsKey(RevenueCatService.premiumEntitlementId) ?? false;

      if (hadExistingSubscription && !hasActivePremium) {
        debugPrint('[SubscriptionSync] WARNING: Subscription conflict detected - user may have lost access');
        debugPrint('[SubscriptionSync] This can happen when signing into an account that already has a subscription');

        // Sync anyway to update the database
        await syncSubscriptionToSupabase();

        return false; // Indicate conflict detected
      }

      // Sync subscription data to Supabase
      await syncSubscriptionToSupabase();

      debugPrint('[SubscriptionSync] Successfully linked user $userId to RevenueCat');
      return true;
    } catch (e) {
      debugPrint('[SubscriptionSync] Error linking RevenueCat user: $e');
      rethrow;
    }
  }

  /// Unlink RevenueCat user on logout
  Future<void> unlinkRevenueCatUser() async {
    try {
      await _revenueCat.logout();
      debugPrint('[SubscriptionSync] Unlinked RevenueCat user');
    } catch (e) {
      debugPrint('[SubscriptionSync] Error unlinking RevenueCat user: $e');
    }
  }
}
