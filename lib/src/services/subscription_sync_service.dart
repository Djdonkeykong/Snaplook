import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'revenuecat_service.dart';
import 'superwall_service.dart';

class UserAccessState {
  const UserAccessState({
    required this.subscriptionStatus,
    required this.isTrial,
    required this.paidCreditsRemaining,
    this.subscriptionProductId,
    this.subscriptionExpiresAt,
    this.subscriptionLastSyncedAt,
  });

  final String subscriptionStatus;
  final bool isTrial;
  final int paidCreditsRemaining;
  final String? subscriptionProductId;
  final DateTime? subscriptionExpiresAt;
  final DateTime? subscriptionLastSyncedAt;

  bool get hasActiveSubscription => subscriptionStatus == 'active' || isTrial;
  bool get hasCredits => paidCreditsRemaining > 0;
  bool get hasAccess => hasActiveSubscription || hasCredits;

  factory UserAccessState.fromRow(Map<String, dynamic>? row) {
    final subscriptionStatus = row?['subscription_status'] as String? ?? 'free';
    final isTrial = row?['is_trial'] == true;
    final creditsRaw = row?['paid_credits_remaining'];
    final paidCreditsRemaining =
        creditsRaw is int ? creditsRaw : (creditsRaw as num?)?.toInt() ?? 0;
    final expiresAtRaw = row?['subscription_expires_at'] as String?;
    final lastSyncedRaw = row?['subscription_last_synced_at'] as String?;

    return UserAccessState(
      subscriptionStatus: subscriptionStatus,
      isTrial: isTrial,
      paidCreditsRemaining: paidCreditsRemaining,
      subscriptionProductId: row?['subscription_product_id'] as String?,
      subscriptionExpiresAt:
          expiresAtRaw != null ? DateTime.tryParse(expiresAtRaw) : null,
      subscriptionLastSyncedAt:
          lastSyncedRaw != null ? DateTime.tryParse(lastSyncedRaw) : null,
    );
  }
}

/// Service for syncing RevenueCat purchase data into Supabase.
/// This now handles both subscriptions and one-time credit packs.
class SubscriptionSyncService {
  SubscriptionSyncService._internal();

  static final SubscriptionSyncService _instance =
      SubscriptionSyncService._internal();

  factory SubscriptionSyncService() => _instance;

  final _supabase = Supabase.instance.client;
  final _superwall = SuperwallService();
  final _revenueCat = RevenueCatService();

  static const MethodChannel _authChannel = MethodChannel('snaplook/auth');

  static const Set<String> _creditPackProductIds = {
    'com.snaplook.credits20',
    'com.snaplook.credits50',
    'com.snaplook.credits100',
  };

  static const String _userAccessSelect =
      'subscription_status, subscription_expires_at, is_trial, '
      'subscription_last_synced_at, paid_credits_remaining, '
      'subscription_product_id';

  bool _isCreditPackProduct(String? productId) {
    final normalized = productId?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty) return false;

    return _creditPackProductIds.contains(normalized) ||
        _creditPackProductIds.any((id) => normalized.startsWith('$id:'));
  }

  Map<String, dynamic>? _extractRpcRow(dynamic response) {
    if (response is List && response.isNotEmpty && response.first is Map) {
      return Map<String, dynamic>.from(response.first as Map);
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    return null;
  }

  Future<int> _syncCreditPurchasesToSupabase({
    required String userId,
    required CustomerInfo customerInfo,
  }) async {
    final transactions = customerInfo.nonSubscriptionTransactions;
    if (transactions.isEmpty) {
      debugPrint('[SubscriptionSync] No non-subscription transactions to sync');
      return 0;
    }

    var grantedCredits = 0;

    for (final transaction in transactions) {
      final productId = transaction.productIdentifier;
      final transactionId = transaction.transactionIdentifier;

      if (!_isCreditPackProduct(productId)) {
        continue;
      }

      if (transactionId.trim().isEmpty) {
        debugPrint(
          '[SubscriptionSync] Skipping credit transaction with empty transaction id for product=$productId',
        );
        continue;
      }

      try {
        final response = await _supabase.rpc('apply_credit_purchase', params: {
          'p_user_id': userId,
          'p_product_id': productId,
          'p_transaction_id': transactionId,
          'p_source': 'client_sync',
        });

        final row = _extractRpcRow(response);
        final success = row?['success'] == true;
        final creditsAdded = (row?['credits_added'] as num?)?.toInt() ?? 0;
        final remaining =
            (row?['paid_credits_remaining'] as num?)?.toInt() ?? 0;
        final message = row?['message']?.toString() ?? 'unknown';

        if (success && creditsAdded > 0) {
          grantedCredits += creditsAdded;
        }

        debugPrint(
          '[SubscriptionSync] Credit sync tx=$transactionId product=$productId '
          'success=$success added=$creditsAdded remaining=$remaining message=$message',
        );
      } catch (e) {
        debugPrint(
          '[SubscriptionSync] Failed to sync credit tx=$transactionId product=$productId: $e',
        );
      }
    }

    return grantedCredits;
  }

  Future<UserAccessState?> getUserAccessState({String? userId}) async {
    try {
      final resolvedUserId = userId ?? _supabase.auth.currentUser?.id;
      if (resolvedUserId == null) return null;

      final response = await _supabase
          .from('users')
          .select(_userAccessSelect)
          .eq('id', resolvedUserId)
          .maybeSingle();

      if (response == null) return null;
      return UserAccessState.fromRow(response);
    } catch (e) {
      debugPrint('[SubscriptionSync] Error getting access state: $e');
      return null;
    }
  }

  /// Sync RevenueCat data into Supabase and return the current access state.
  /// Call this after:
  /// - successful paywall flow
  /// - user login
  /// - app startup (if authenticated)
  Future<UserAccessState?> syncSubscriptionToSupabase({
    CustomerInfo? customerInfo,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        debugPrint('[SubscriptionSync] No authenticated user - skipping sync');
        return null;
      }

      debugPrint(
        '[SubscriptionSync] Starting RevenueCat sync for user ${user.id}',
      );

      CustomerInfo? resolvedCustomerInfo = customerInfo;
      try {
        resolvedCustomerInfo ??= await Purchases.getCustomerInfo();
        debugPrint(
          '[SubscriptionSync] Fetched fresh customer info from RevenueCat',
        );
      } catch (e) {
        debugPrint(
          '[SubscriptionSync] Error fetching RevenueCat customer info: $e',
        );
        final accessState = await getUserAccessState(userId: user.id);
        await _syncShareExtensionAuthSnapshot(
          userId: user.id,
          accessState: accessState,
        );
        return accessState;
      }

      final creditsGranted = await _syncCreditPurchasesToSupabase(
        userId: user.id,
        customerInfo: resolvedCustomerInfo,
      );

      final activeEntitlements = resolvedCustomerInfo.entitlements.active.values;
      final entitlement =
          activeEntitlements.isNotEmpty ? activeEntitlements.first : null;
      final hasActiveRevenueCat = entitlement != null;
      final isTrial = entitlement?.periodType == PeriodType.trial ||
          entitlement?.periodType == PeriodType.intro;
      final expirationDateIso = entitlement?.expirationDate != null
          ? DateTime.tryParse(entitlement!.expirationDate!)?.toIso8601String()
          : null;
      final productId = entitlement?.productIdentifier;
      final revenueCatUserId = resolvedCustomerInfo.originalAppUserId;

      debugPrint('[SubscriptionSync] RevenueCat data:');
      debugPrint('  - originalAppUserId: $revenueCatUserId');
      debugPrint('  - hasActiveSubscription: $hasActiveRevenueCat');
      debugPrint('  - isTrial: $isTrial');
      debugPrint('  - productId: $productId');
      debugPrint('  - expiresAt: $expirationDateIso');
      debugPrint('  - grantedCreditsFromTransactions: $creditsGranted');

      final currentAccess = await getUserAccessState(userId: user.id);
      final hasCredits = currentAccess?.hasCredits ?? false;
      final currentStatus = currentAccess?.subscriptionStatus ?? 'free';

      if (hasActiveRevenueCat) {
        await _supabase.from('users').upsert({
          'id': user.id,
          'revenue_cat_user_id': revenueCatUserId,
          'subscription_status': 'active',
          'subscription_expires_at': expirationDateIso,
          'subscription_product_id': productId,
          'is_trial': isTrial,
          'subscription_last_synced_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'id');

        debugPrint(
          '[SubscriptionSync] Sync complete - Status: active, Trial: $isTrial, Expires: $expirationDateIso',
        );
      } else if (hasCredits &&
          (currentStatus == 'active' || currentStatus == 'expired')) {
        // The user bought credits but no longer has an active subscription.
        // Preserve the last known subscription metadata while still updating
        // the sync timestamp.
        await _supabase.from('users').update({
          'subscription_last_synced_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', user.id);

        debugPrint(
          '[SubscriptionSync] User has credits - preserving existing subscription data. Status: $currentStatus',
        );
      } else {
        var subscriptionStatus = 'free';
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
      }

      await _superwall.syncSubscriptionStatus();

      final accessState = await getUserAccessState(userId: user.id);
      await _syncShareExtensionAuthSnapshot(
        userId: user.id,
        accessState: accessState,
      );
      return accessState;
    } catch (e, stackTrace) {
      debugPrint('[SubscriptionSync] Error syncing subscription: $e');
      debugPrint('[SubscriptionSync] Stack trace: $stackTrace');
      return null;
    }
  }

  Future<void> _syncShareExtensionAuthSnapshot({
    required String userId,
    UserAccessState? accessState,
  }) async {
    try {
      final resolvedAccessState =
          accessState ?? await getUserAccessState(userId: userId);
      final hasActiveSubscription =
          resolvedAccessState?.hasActiveSubscription ?? false;
      final availableCredits = resolvedAccessState?.paidCreditsRemaining ?? 0;
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
        '[SubscriptionSync] Failed to sync share extension auth snapshot: $e',
      );
    }
  }

  /// Get cached subscription status from Supabase.
  /// This is fast but may be slightly out of date.
  Future<Map<String, dynamic>?> getCachedSubscriptionStatus() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      return await _supabase
          .from('users')
          .select(
            'subscription_status, subscription_expires_at, is_trial, '
            'subscription_last_synced_at, paid_credits_remaining',
          )
          .eq('id', user.id)
          .single();
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
      return true;
    }
  }

  /// Identify user with RevenueCat and Superwall.
  /// This links any anonymous purchases to the identified user.
  Future<UserAccessState?> identify(String userId) async {
    debugPrint('[SubscriptionSync] Identifying user $userId with RevenueCat');

    await _revenueCat.identify(userId);
    await _superwall.identify(userId);

    return syncSubscriptionToSupabase();
  }

  /// Identify user with Superwall (deprecated - use identify() instead).
  @deprecated
  Future<UserAccessState?> identifyWithSuperwall(String userId) async {
    return identify(userId);
  }

  /// Reset RevenueCat and Superwall identity on logout.
  Future<void> resetOnLogout() async {
    await _revenueCat.logOut();
    await _superwall.reset();
  }
}
