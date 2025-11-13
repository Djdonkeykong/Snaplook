import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../models/credit_balance.dart';
import '../models/subscription_status.dart';
import '../../../services/credit_service.dart';
import '../../../services/revenue_cat_service.dart';
import '../../../services/subscription_sync_service.dart';

/// Provider for credit service
final creditServiceProvider = Provider<CreditService>((ref) {
  return CreditService();
});

/// Provider for RevenueCat service
final revenueCatServiceProvider = Provider<RevenueCatService>((ref) {
  return RevenueCatService();
});

/// Provider for credit balance
final creditBalanceProvider = StateNotifierProvider<CreditBalanceNotifier, AsyncValue<CreditBalance>>((ref) {
  return CreditBalanceNotifier(ref.read(creditServiceProvider));
});

/// Provider for subscription status
final subscriptionStatusProvider = StateNotifierProvider<SubscriptionStatusNotifier, AsyncValue<SubscriptionStatus>>((ref) {
  return SubscriptionStatusNotifier(ref.read(revenueCatServiceProvider));
});

/// Notifier for managing credit balance state
class CreditBalanceNotifier extends StateNotifier<AsyncValue<CreditBalance>> {
  final CreditService _creditService;

  CreditBalanceNotifier(this._creditService) : super(const AsyncValue.loading()) {
    loadBalance();
  }

  /// Load credit balance
  Future<void> loadBalance() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return await _creditService.getCreditBalance();
    });
  }

  /// Consume one credit
  Future<bool> consumeCredit() async {
    try {
      final newBalance = await _creditService.consumeCredit();
      state = AsyncValue.data(newBalance);
      return true;
    } catch (e) {
      // Don't update state if consumption fails
      return false;
    }
  }

  /// Refill credits (monthly refill)
  Future<void> refillCredits() async {
    try {
      final newBalance = await _creditService.refillCredits();
      state = AsyncValue.data(newBalance);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  /// Sync with subscription after purchase/restore
  Future<void> syncWithSubscription() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return await _creditService.syncWithSubscription();
    });
  }

  /// Reset credits (for testing)
  Future<void> reset() async {
    await _creditService.resetCredits();
    await loadBalance();
  }

  /// Refresh balance
  Future<void> refresh() async {
    _creditService.clearCache();
    await loadBalance();
  }
}

/// Notifier for managing subscription status state
class SubscriptionStatusNotifier extends StateNotifier<AsyncValue<SubscriptionStatus>> {
  final RevenueCatService _revenueCatService;

  SubscriptionStatusNotifier(this._revenueCatService) : super(const AsyncValue.loading()) {
    loadStatus();
  }

  /// Load subscription status
  Future<void> loadStatus() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return await _revenueCatService.getSubscriptionStatus();
    });
  }

  /// Refresh subscription status
  Future<void> refresh() async {
    await loadStatus();
  }
}

/// Provider for checking if user can perform action
final canPerformActionProvider = Provider<bool>((ref) {
  final creditBalance = ref.watch(creditBalanceProvider);
  return creditBalance.maybeWhen(
    data: (balance) => balance.canPerformAction,
    orElse: () => false,
  );
});

/// Provider for checking if paywall should be shown
final shouldShowPaywallProvider = Provider<bool>((ref) {
  final creditBalance = ref.watch(creditBalanceProvider);
  return creditBalance.maybeWhen(
    data: (balance) => balance.needsPaywall,
    orElse: () => false,
  );
});

/// Provider for checking if user has active subscription
final hasActiveSubscriptionProvider = Provider<bool>((ref) {
  final subscriptionStatus = ref.watch(subscriptionStatusProvider);
  return subscriptionStatus.maybeWhen(
    data: (status) => status.isActive,
    orElse: () => false,
  );
});

/// Provider for checking if user is in trial period
final isInTrialPeriodProvider = Provider<bool>((ref) {
  final subscriptionStatus = ref.watch(subscriptionStatusProvider);
  return subscriptionStatus.maybeWhen(
    data: (status) => status.isInTrialPeriod,
    orElse: () => false,
  );
});

/// Purchase controller for handling purchase operations
final purchaseControllerProvider = Provider<PurchaseController>((ref) {
  return PurchaseController(
    ref.read(revenueCatServiceProvider),
    ref.read(creditBalanceProvider.notifier),
    ref.read(subscriptionStatusProvider.notifier),
  );
});

/// Controller for purchase operations
class PurchaseController {
  final RevenueCatService _revenueCatService;
  final CreditBalanceNotifier _creditNotifier;
  final SubscriptionStatusNotifier _subscriptionNotifier;
  final _subscriptionSyncService = SubscriptionSyncService();

  PurchaseController(
    this._revenueCatService,
    this._creditNotifier,
    this._subscriptionNotifier,
  );

  /// Purchase a package
  Future<bool> purchasePackage(Package package) async {
    try {
      final customerInfo = await _revenueCatService.purchasePackage(package);
      if (customerInfo != null) {
        // Purchase successful - sync credit balance and subscription status
        await _creditNotifier.syncWithSubscription();
        await _subscriptionNotifier.refresh();

        // Sync subscription data to Supabase
        await _subscriptionSyncService.syncSubscriptionToSupabase();

        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Restore purchases
  Future<bool> restorePurchases() async {
    try {
      final customerInfo = await _revenueCatService.restorePurchases();
      if (customerInfo != null) {
        // Restore successful - sync credit balance and subscription status
        await _creditNotifier.syncWithSubscription();
        await _subscriptionNotifier.refresh();

        // Sync subscription data to Supabase
        await _subscriptionSyncService.syncSubscriptionToSupabase();

        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get available offerings
  Future<Offerings?> getOfferings() async {
    return await _revenueCatService.getOfferings();
  }

  /// Show management UI
  Future<void> showManagementUI() async {
    await _revenueCatService.showManagementUI();
  }
}
