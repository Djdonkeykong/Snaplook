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

  static const String _userAccessSelect =
      'subscription_status, subscription_expires_at, is_trial, '
      'subscription_last_synced_at, paid_credits_remaining, '
      'subscription_product_id';

  static Duration purchaseGrantTimeout({
    required String placement,
    required bool didPurchase,
  }) {
    if (didPurchase) {
      return const Duration(seconds: 10);
    }

    if (placement == SuperwallService.defaultPlacement) {
      return const Duration(seconds: 15);
    }

    return const Duration(seconds: 6);
  }

  Future<void> _persistUserSyncFields(
    String userId,
    Map<String, dynamic> fields,
  ) async {
    final payload = <String, dynamic>{
      ...fields,
      'updated_at': DateTime.now().toIso8601String(),
    };

    final updatedRow = await _supabase
        .from('users')
        .update(payload)
        .eq('id', userId)
        .select('id')
        .maybeSingle();

    if (updatedRow != null) {
      return;
    }

    await _supabase.from('users').upsert({
      'id': userId,
      ...payload,
    }, onConflict: 'id');
  }

  bool _hasMeaningfulPurchaseChange(
    UserAccessState? before,
    UserAccessState? after,
  ) {
    if (after == null) return false;
    if (before == null) return after.hasAccess;

    return (!before.hasActiveSubscription && after.hasActiveSubscription) ||
        after.paidCreditsRemaining > before.paidCreditsRemaining ||
        ((before.subscriptionProductId ?? '') !=
                (after.subscriptionProductId ?? '') &&
            after.subscriptionProductId != null);
  }

  bool gainedAccess(
    UserAccessState? before,
    UserAccessState? after,
  ) {
    final hadAccessBefore = before?.hasAccess ?? false;
    final hasAccessAfter = after?.hasAccess ?? false;
    return !hadAccessBefore && hasAccessAfter;
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

  Future<UserAccessState?> refreshAccessState({required String userId}) async {
    return await syncSubscriptionToSupabase() ??
        await getUserAccessState(userId: userId);
  }

  /// Sync RevenueCat subscription metadata into Supabase and return the
  /// current access state. Credit packs are granted by the RevenueCat webhook
  /// so we don't blindly replay all historical consumable transactions here.
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

      final activeEntitlements =
          resolvedCustomerInfo.entitlements.active.values;
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

      final currentAccess = await getUserAccessState(userId: user.id);
      final hasCredits = currentAccess?.hasCredits ?? false;
      final currentStatus = currentAccess?.subscriptionStatus ?? 'free';

      if (hasActiveRevenueCat) {
        await _persistUserSyncFields(user.id, {
          'revenue_cat_user_id': revenueCatUserId,
          'subscription_status': 'active',
          'subscription_expires_at': expirationDateIso,
          'subscription_product_id': productId,
          'is_trial': isTrial,
          'subscription_last_synced_at': DateTime.now().toIso8601String(),
        });

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

        await _persistUserSyncFields(user.id, {
          'revenue_cat_user_id': revenueCatUserId,
          'subscription_status': subscriptionStatus,
          'subscription_expires_at': expirationDateIso,
          'subscription_product_id': productId,
          'is_trial': isTrial,
          'subscription_last_synced_at': DateTime.now().toIso8601String(),
        });
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

  /// Poll Supabase for the result of a purchase that may still be propagating
  /// through the RevenueCat webhook or RC customer-info refresh.
  Future<UserAccessState?> waitForPurchaseGrant({
    required String userId,
    UserAccessState? previousAccessState,
    Duration timeout = const Duration(seconds: 10),
    Duration pollInterval = const Duration(seconds: 1),
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (true) {
      UserAccessState? latestAccessState;
      try {
        latestAccessState = await syncSubscriptionToSupabase() ??
            await getUserAccessState(userId: userId);
      } catch (e) {
        debugPrint(
            '[SubscriptionSync] Error while waiting for purchase grant: $e');
      }

      if (_hasMeaningfulPurchaseChange(
          previousAccessState, latestAccessState)) {
        debugPrint(
          '[SubscriptionSync] Purchase grant detected for user=$userId '
          'credits=${latestAccessState?.paidCreditsRemaining} '
          'subscription=${latestAccessState?.subscriptionStatus}',
        );
        return latestAccessState;
      }

      if (DateTime.now().isAfter(deadline)) {
        debugPrint(
          '[SubscriptionSync] Timed out waiting for purchase grant for user=$userId',
        );
        return null;
      }

      await Future.delayed(pollInterval);
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
