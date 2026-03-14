import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'credit_service.dart';
import 'superwall_service.dart';
import 'revenuecat_service.dart';

/// Service for syncing subscription data between RevenueCat and Supabase.
class SubscriptionSyncService {
  static final SubscriptionSyncService _instance =
      SubscriptionSyncService._internal();
  factory SubscriptionSyncService() => _instance;
  SubscriptionSyncService._internal();

  final _supabase = Supabase.instance.client;
  final _superwall = SuperwallService();
  final _revenueCat = RevenueCatService();
  static const MethodChannel _authChannel = MethodChannel('snaplook/auth');
  static const Map<String, int> _creditPackProducts = {
    'com.snaplook.credits20': 20,
    'com.snaplook.credits50': 50,
    'com.snaplook.credits100': 100,
  };

  /// Sync subscription data from RevenueCat to Supabase.
  /// Call this after:
  /// - Successful paywall flow
  /// - User login
  /// - App startup (if authenticated)
  Future<void> syncSubscriptionToSupabase({
    bool attemptRestoreOnNoEntitlement = false,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        debugPrint('[SubscriptionSync] No authenticated user - skipping sync');
        return;
      }

      debugPrint(
          '[SubscriptionSync] Starting RevenueCat sync for user ${user.id}');

      // Get FRESH RevenueCat customer info (don't use cache after purchase)
      CustomerInfo? customerInfo;
      try {
        customerInfo = await Purchases.getCustomerInfo();
        debugPrint(
            '[SubscriptionSync] Fetched fresh customer info from RevenueCat');
      } catch (e) {
        debugPrint(
            '[SubscriptionSync] Error fetching RevenueCat customer info: $e');
        await _syncShareExtensionAuthSnapshot(userId: user.id);
        return;
      }

      if (customerInfo == null) {
        debugPrint(
            '[SubscriptionSync] Customer info was null after fetch - skipping sync');
        await _syncShareExtensionAuthSnapshot(userId: user.id);
        return;
      }

      // Parse RevenueCat subscription data
      var activeEntitlements = customerInfo.entitlements.active.values;
      var entitlement =
          (activeEntitlements.isNotEmpty) ? activeEntitlements.first : null;
      var hasActiveRevenueCat =
          entitlement != null || customerInfo.activeSubscriptions.isNotEmpty;

      if (!hasActiveRevenueCat && attemptRestoreOnNoEntitlement) {
        debugPrint(
            '[SubscriptionSync] No active entitlement from getCustomerInfo - attempting restore');
        try {
          final restoredInfo =
              await Purchases.restorePurchases().timeout(const Duration(seconds: 12));
          customerInfo = restoredInfo;
          activeEntitlements = customerInfo.entitlements.active.values;
          entitlement =
              (activeEntitlements.isNotEmpty) ? activeEntitlements.first : null;
          hasActiveRevenueCat =
              entitlement != null || customerInfo.activeSubscriptions.isNotEmpty;
          debugPrint(
              '[SubscriptionSync] Restore completed. hasActive=$hasActiveRevenueCat activeSubscriptions=${customerInfo.activeSubscriptions}');
        } catch (restoreError) {
          debugPrint(
              '[SubscriptionSync] Restore-on-no-entitlement failed: $restoreError');
        }
      }

      final isTrialFromEntitlement = entitlement?.periodType == PeriodType.trial ||
          entitlement?.periodType == PeriodType.intro;
      final expirationDateIso = entitlement?.expirationDate != null
          ? DateTime.tryParse(entitlement!.expirationDate!)?.toIso8601String()
          : (customerInfo.latestExpirationDate != null
              ? DateTime.tryParse(customerInfo.latestExpirationDate!)
                  ?.toIso8601String()
              : null);
      final productId = entitlement?.productIdentifier ??
          (customerInfo.activeSubscriptions.isNotEmpty
              ? customerInfo.activeSubscriptions.first
              : null);
      final revenueCatUserId = customerInfo.originalAppUserId;

      debugPrint('[SubscriptionSync] RevenueCat data:');
      debugPrint('  - originalAppUserId: $revenueCatUserId');
      debugPrint('  - hasActiveSubscription: $hasActiveRevenueCat');
      debugPrint('  - isTrialFromEntitlement: $isTrialFromEntitlement');
      debugPrint('  - productId: $productId');
      debugPrint('  - expiresAt: $expirationDateIso');
      debugPrint('  - activeSubscriptions: ${customerInfo.activeSubscriptions}');

      await _syncCreditPackPurchases(
        userId: user.id,
        revenueCatUserId: revenueCatUserId,
        customerInfo: customerInfo,
      );

      // Check if user has credits (users with credits should not have their status overwritten to 'free')
      final userResponse = await _supabase
          .from('users')
          .select(
              'paid_credits_remaining, subscription_status, subscription_expires_at, subscription_product_id, is_trial')
          .eq('id', user.id)
          .maybeSingle();

      final hasCredits = (userResponse?['paid_credits_remaining'] ?? 0) > 0;
      final currentStatus = userResponse?['subscription_status'] ?? 'free';
      final currentIsTrial = userResponse?['is_trial'] == true;
      final isTrial = entitlement == null ? currentIsTrial : isTrialFromEntitlement;

      // Determine what to sync
      if (hasActiveRevenueCat) {
        // RevenueCat says active - sync all data from RevenueCat
        const subscriptionStatus = 'active';

        await _supabase.from('users').upsert({
          'id': user.id,
          'revenue_cat_user_id': revenueCatUserId,
          'subscription_status': subscriptionStatus,
          'subscription_expires_at': expirationDateIso,
          'subscription_product_id': productId,
          'is_trial': isTrial,
          'subscription_last_synced_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'id');

        debugPrint(
            '[SubscriptionSync] Sync complete - Status: $subscriptionStatus, Trial: $isTrial, Expires: $expirationDateIso');

        // Also sync status to Superwall so it knows about the subscription
        await _superwall.syncSubscriptionStatus();
      } else if (currentStatus == 'active' ||
          currentStatus == 'expired' ||
          currentIsTrial) {
        // RevenueCat can briefly report no active entitlement immediately
        // after auth or purchase transitions. Preserve known non-free state
        // instead of downgrading the user to free.
        await _supabase.from('users').update({
          'subscription_last_synced_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', user.id);

        debugPrint(
            '[SubscriptionSync] Preserving existing subscription state. Status: $currentStatus, isTrial: $currentIsTrial, hasCredits: $hasCredits');

        // Sync status to Superwall
        await _superwall.syncSubscriptionStatus();
      } else {
        // No RevenueCat subscription and no credits - set to free or expired
        String subscriptionStatus = 'free';
        if (expirationDateIso != null) {
          final expirationDate = DateTime.parse(expirationDateIso);
          if (expirationDate.isBefore(DateTime.now())) {
            subscriptionStatus = 'expired';
          }
        }

        await _supabase.from('users').upsert({
          'id': user.id,
          'revenue_cat_user_id': revenueCatUserId,
          'subscription_status': subscriptionStatus,
          'subscription_expires_at': expirationDateIso,
          'subscription_product_id': productId,
          'is_trial': isTrial,
          'subscription_last_synced_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'id');

        // Sync status to Superwall
        await _superwall.syncSubscriptionStatus();
      }

      CreditService().clearCache();
      await _syncShareExtensionAuthSnapshot(userId: user.id);
    } catch (e, stackTrace) {
      debugPrint('[SubscriptionSync] Error syncing subscription: $e');
      debugPrint('[SubscriptionSync] Stack trace: $stackTrace');
    }
  }

  int? _creditsForProduct(String productId) {
    final normalized = productId.toLowerCase();
    for (final entry in _creditPackProducts.entries) {
      final sku = entry.key.toLowerCase();
      if (normalized == sku || normalized.startsWith('$sku:')) {
        return entry.value;
      }
    }
    return null;
  }

  Future<void> _syncCreditPackPurchases({
    required String userId,
    required String revenueCatUserId,
    required CustomerInfo customerInfo,
  }) async {
    final transactions = customerInfo.nonSubscriptionTransactions;
    if (transactions.isEmpty) return;

    for (final transaction in transactions) {
      final productId = transaction.productIdentifier;
      final credits = _creditsForProduct(productId);
      if (credits == null) continue;

      final purchaseDateIso =
          DateTime.tryParse(transaction.purchaseDate)?.toIso8601String() ??
              DateTime.now().toIso8601String();
      final fallbackTransactionId =
          '$revenueCatUserId:$productId:${transaction.purchaseDate}';
      final transactionId = transaction.transactionIdentifier.isNotEmpty
          ? transaction.transactionIdentifier
          : fallbackTransactionId;

      try {
        final response = await _supabase.rpc(
          'apply_credit_purchase',
          params: {
            'p_user_id': userId,
            'p_product_id': productId,
            'p_transaction_id': transactionId,
            'p_purchased_at': purchaseDateIso,
            'p_source': 'client_sync',
          },
        );
        debugPrint(
          '[SubscriptionSync] Synced credit pack purchase: '
          'product=$productId credits=$credits tx=$transactionId response=$response',
        );
      } catch (e) {
        debugPrint(
          '[SubscriptionSync] Failed syncing credit pack purchase '
          '(product=$productId tx=$transactionId): $e',
        );
      }
    }
  }

  Future<void> _syncShareExtensionAuthSnapshot({required String userId}) async {
    try {
      final userResponse = await _supabase
          .from('users')
          .select('subscription_status, is_trial, paid_credits_remaining')
          .eq('id', userId)
          .maybeSingle();

      final subscriptionStatus = userResponse?['subscription_status'] ?? 'free';
      final isTrial = userResponse?['is_trial'] == true;
      final hasActiveSubscription = subscriptionStatus == 'active' || isTrial;
      final creditsRaw = userResponse?['paid_credits_remaining'];
      final availableCredits =
          creditsRaw is int ? creditsRaw : (creditsRaw as num?)?.toInt() ?? 0;
      final accessToken = _supabase.auth.currentSession?.accessToken;

      await _authChannel.invokeMethod('setAuthFlag', {
        'isAuthenticated': true,
        'userId': userId,
        'hasActiveSubscription': hasActiveSubscription,
        'availableCredits': availableCredits,
        'accessToken': accessToken,
      });

      debugPrint(
        '[SubscriptionSync] Synced share extension auth snapshot: '
        'subscription=$hasActiveSubscription, credits=$availableCredits',
      );
    } catch (e) {
      debugPrint(
          '[SubscriptionSync] Failed to sync share extension auth snapshot: $e');
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
          .select(
              'subscription_status, subscription_expires_at, is_trial, subscription_last_synced_at')
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

  /// Identify user with RevenueCat and Superwall.
  /// This links any anonymous purchases to the identified user.
  Future<void> identify(String userId) async {
    debugPrint('[SubscriptionSync] Identifying user $userId with RevenueCat');

    // Identify with RevenueCat - this merges anonymous purchases with the user account
    await _revenueCat.identify(userId);

    // Also identify with Superwall (for backwards compatibility)
    await _superwall.identify(userId);

    // Sync subscription data to Supabase
    await syncSubscriptionToSupabase(
      attemptRestoreOnNoEntitlement: true,
    );
  }

  /// Identify user with Superwall (deprecated - use identify() instead).
  @deprecated
  Future<void> identifyWithSuperwall(String userId) async {
    await identify(userId);
  }

  /// Reset RevenueCat and Superwall identity on logout.
  Future<void> resetOnLogout() async {
    await _revenueCat.logOut();
    await _superwall.reset();
  }
}
