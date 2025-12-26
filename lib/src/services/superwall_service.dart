import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart' as sw;

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
    if (_configured) return;

    sw.Superwall.configure(apiKey);
    _configured = true;

    _statusSub = sw.Superwall.shared.subscriptionStatus.listen((status) {
      _latestStatus = status;
    });

    if (userId != null && userId.isNotEmpty) {
      await identify(userId);
    }

    if (kDebugMode) {
      debugPrint('[Superwall] configured; user=${userId ?? 'anon'}');
    }
  }

  /// Identify the current user.
  Future<void> identify(String userId) async {
    if (!_configured) {
      if (kDebugMode) {
        debugPrint('[Superwall] identify called but not configured - skipping');
      }
      return;
    }
    await sw.Superwall.shared.identify(userId);
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
    if (!_configured) {
      if (kDebugMode) {
        debugPrint('[Superwall] presentPaywall called but not configured - skipping');
      }
      return false;
    }

    try {
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
      await sw.Superwall.shared.registerPlacement(placement, handler: handler);

      // Wait for the result
      return await completer.future;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Superwall] presentPaywall error: $e');
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
