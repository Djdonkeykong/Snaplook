import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart' as sw;
import 'package:purchases_flutter/purchases_flutter.dart';
import 'rc_purchase_controller.dart';

/// Thin wrapper around Superwall to manage configuration, identity, and paywall presentation.
class SuperwallService {
  SuperwallService._internal();
  static final SuperwallService _instance = SuperwallService._internal();
  factory SuperwallService() => _instance;

  static const String defaultPlacement = 'onboarding_paywall';

  sw.SubscriptionStatus _latestStatus = sw.SubscriptionStatus.unknown;
  StreamSubscription<sw.SubscriptionStatus>? _statusSub;
  bool _configured = false;

  /// Configure Superwall with the provided API key and optional user.
  Future<void> initialize({required String apiKey, String? userId}) async {
    if (_configured) {
      if (kDebugMode) {
        debugPrint('[Superwall] Already configured, skipping...');
      }
      return;
    }

    if (kDebugMode) {
      debugPrint('[Superwall] Creating RevenueCat purchase controller...');
    }

    try {
      // Create RevenueCat purchase controller
      final purchaseController = RCPurchaseController();

      if (kDebugMode) {
        debugPrint('[Superwall] Configuring Superwall with API key: ${apiKey.substring(0, 5)}...');
      }

      // Configure Superwall with RevenueCat purchase controller
      sw.Superwall.configure(
        apiKey,
        purchaseController: purchaseController,
      );
      _configured = true;

      if (kDebugMode) {
        debugPrint('[Superwall] Configured with RevenueCat purchase controller');
      }

      _statusSub = sw.Superwall.shared.subscriptionStatus.listen((status) {
        _latestStatus = status;
        if (kDebugMode) {
          debugPrint('[Superwall] Subscription status changed: ${status.runtimeType}');
        }
      });

      if (userId != null && userId.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('[Superwall] Identifying user: $userId');
        }
        await identify(userId);
      }

      if (kDebugMode) {
        debugPrint('[Superwall] Initialization complete; user=${userId ?? 'anon'}');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[Superwall] ERROR during initialization: $e');
        debugPrint('[Superwall] Stack trace: $stackTrace');
      }
      rethrow;
    }
  }

  /// Identify the current user and sync subscription status from RevenueCat.
  Future<void> identify(String userId) async {
    if (!_configured) {
      if (kDebugMode) {
        debugPrint('[Superwall] identify called but not configured - skipping');
      }
      return;
    }
    await sw.Superwall.shared.identify(userId);

    // Sync subscription status from RevenueCat to Superwall
    await _syncSubscriptionStatus();
  }

  /// Sync RevenueCat subscription status to Superwall
  /// This ensures Superwall knows about active subscriptions and trial eligibility
  Future<void> _syncSubscriptionStatus() async {
    if (!_configured) return;

    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final hasActiveEntitlement = customerInfo.entitlements.active.isNotEmpty;

      if (hasActiveEntitlement) {
        // User has active subscription - tell Superwall
        // Convert RevenueCat entitlements to Superwall entitlements
        final entitlements = customerInfo.entitlements.active.keys.map((id) {
          return sw.Entitlement(id: id);
        }).toSet();

        await sw.Superwall.shared.setSubscriptionStatus(
          sw.SubscriptionStatusActive(entitlements: entitlements),
        );

        if (kDebugMode) {
          debugPrint('[Superwall] Synced subscription status: active with ${entitlements.length} entitlements');
        }
      } else {
        // User has no active subscription
        await sw.Superwall.shared.setSubscriptionStatus(sw.SubscriptionStatusInactive());

        if (kDebugMode) {
          debugPrint('[Superwall] Synced subscription status: inactive');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Superwall] Error syncing subscription status: $e');
      }
    }
  }

  /// Sync subscription status from RevenueCat to Superwall
  /// Call this after purchases or when subscription status changes
  Future<void> syncSubscriptionStatus() async {
    await _syncSubscriptionStatus();
  }

  /// Reset the current user/session.
  Future<void> reset() async {
    if (!_configured) {
      if (kDebugMode) {
        debugPrint('[Superwall] reset called but not configured - skipping');
      }
      return;
    }
    await sw.Superwall.shared.reset();
    _latestStatus = sw.SubscriptionStatus.unknown;
  }

  /// Present a paywall and return true if user purchased, false otherwise.
  Future<bool> presentPaywall({
    String placement = defaultPlacement,
  }) async {
    if (kDebugMode) {
      debugPrint('[Superwall] presentPaywall called with placement: $placement');
      debugPrint('[Superwall] _configured = $_configured');
    }

    if (!_configured) {
      if (kDebugMode) {
        debugPrint('[Superwall] ERROR - presentPaywall called but not configured - skipping');
      }
      return false;
    }

    try {
      if (kDebugMode) {
        debugPrint('[Superwall] Creating PaywallPresentationHandler...');
      }
      final completer = Completer<bool>();
      final handler = sw.PaywallPresentationHandler();

      handler.onPresent((paywallInfo) {
        if (kDebugMode) {
          debugPrint('[Superwall] Paywall presented: ${paywallInfo.experiment?.id ?? "no_experiment"}');
        }
      });

      handler.onDismiss((paywallInfo, result) {
        if (kDebugMode) {
          debugPrint('[Superwall] Paywall dismissed');
        }

        // Handle different paywall results using type checking
        if (result is sw.PurchasedPaywallResult) {
          final productId = result.productId;
          if (kDebugMode) {
            debugPrint('[Superwall] Purchase completed: $productId');
          }
          completer.complete(true);
        } else if (result is sw.RestoredPaywallResult) {
          if (kDebugMode) {
            debugPrint('[Superwall] Purchases restored');
          }
          completer.complete(true);
        } else if (result is sw.DeclinedPaywallResult) {
          if (kDebugMode) {
            debugPrint('[Superwall] User declined paywall');
          }
          completer.complete(false);
        }
      });

      handler.onSkip((paywallInfo) {
        // User already has entitlements, paywall was skipped
        if (kDebugMode) {
          debugPrint('[Superwall] Paywall skipped - user already subscribed');
        }
        completer.complete(true);
      });

      handler.onError((error) {
        if (kDebugMode) {
          debugPrint('[Superwall] Paywall error: $error');
        }
        completer.complete(false);
      });

      // Register the placement with the handler
      if (kDebugMode) {
        debugPrint('[Superwall] Registering placement: $placement');
      }
      await sw.Superwall.shared.registerPlacement(placement, handler: handler);
      if (kDebugMode) {
        debugPrint('[Superwall] Placement registered successfully, waiting for user action...');
      }

      // Wait for the result
      return await completer.future;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[Superwall] presentPaywall error: $e');
        debugPrint('[Superwall] Stack trace: $stackTrace');
      }
      return false;
    }
  }

  /// Current cached subscription status.
  SubscriptionStatusSnapshot getSubscriptionSnapshot() {
    if (!_configured) {
      if (kDebugMode) {
        debugPrint('[Superwall] getSubscriptionSnapshot called but not configured - returning inactive');
      }
      return SubscriptionStatusSnapshot.initial();
    }
    return SubscriptionStatusSnapshot.fromSuperwall(_latestStatus);
  }

  /// Dispose listeners (rarely needed in app lifecycle).
  void dispose() {
    _statusSub?.cancel();
    _statusSub = null;
  }
}

/// Lightweight status DTO the app can use without importing Superwall enums everywhere.
class SubscriptionStatusSnapshot {
  final bool isActive;
  final bool isInTrialPeriod;
  final String? productIdentifier;
  final DateTime? expirationDate;

  const SubscriptionStatusSnapshot({
    required this.isActive,
    this.isInTrialPeriod = false,
    this.productIdentifier,
    this.expirationDate,
  });

  factory SubscriptionStatusSnapshot.fromSuperwall(sw.SubscriptionStatus status) {
    return SubscriptionStatusSnapshot(
      isActive: status is sw.SubscriptionStatusActive,
      isInTrialPeriod: false,
    );
  }

  factory SubscriptionStatusSnapshot.initial() {
    return const SubscriptionStatusSnapshot(isActive: false);
  }
}
