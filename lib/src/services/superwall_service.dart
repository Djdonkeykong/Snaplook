import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart' as sw;
import 'package:purchases_flutter/purchases_flutter.dart';
import 'rc_purchase_controller.dart';
import 'debug_log_service.dart';

/// Thin wrapper around Superwall to manage configuration, identity, and paywall presentation.
class SuperwallService {
  SuperwallService._internal();
  static final SuperwallService _instance = SuperwallService._internal();
  factory SuperwallService() => _instance;

  static const String defaultPlacement = 'onboarding_paywall';

  sw.SubscriptionStatus _latestStatus = sw.SubscriptionStatus.unknown;
  StreamSubscription<sw.SubscriptionStatus>? _statusSub;
  bool _configured = false;
  final _debugLog = DebugLogService();

  void _log(String message, {LogLevel level = LogLevel.info}) {
    _debugLog.log(message, level: level, tag: 'Superwall');
    if (kDebugMode) {
      debugPrint('[Superwall] $message');
    }
  }

  /// Configure Superwall with the provided API key and optional user.
  Future<void> initialize({required String apiKey, String? userId}) async {
    if (_configured) {
      _log('Already configured, skipping...');
      return;
    }

    _log('Creating RevenueCat purchase controller...');

    try {
      // Create RevenueCat purchase controller
      final purchaseController = RCPurchaseController();

      _log('Configuring Superwall with API key: ${apiKey.substring(0, 5)}...');

      // Configure Superwall with RevenueCat purchase controller
      sw.Superwall.configure(
        apiKey,
        purchaseController: purchaseController,
      );
      _configured = true;

      _log('Configured with RevenueCat purchase controller');

      _statusSub = sw.Superwall.shared.subscriptionStatus.listen((status) {
        _latestStatus = status;
        _log('Subscription status changed: ${status.runtimeType}');
      });

      if (userId != null && userId.isNotEmpty) {
        _log('Identifying user: $userId');
        await identify(userId);
      }

      _log('Initialization complete; user=${userId ?? 'anon'}');
    } catch (e, stackTrace) {
      _log('ERROR during initialization: $e\nStack trace: $stackTrace', level: LogLevel.error);
      rethrow;
    }
  }

  /// Identify the current user and sync subscription status from RevenueCat.
  Future<void> identify(String userId) async {
    if (!_configured) {
      _log('identify called but not configured - skipping', level: LogLevel.warning);
      return;
    }
    _log('Identifying user: $userId');
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

        _log('Synced subscription status: active with ${entitlements.length} entitlements');
      } else {
        // User has no active subscription
        await sw.Superwall.shared.setSubscriptionStatus(sw.SubscriptionStatusInactive());

        _log('Synced subscription status: inactive');
      }
    } catch (e) {
      _log('Error syncing subscription status: $e', level: LogLevel.error);
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
      _log('reset called but not configured - skipping', level: LogLevel.warning);
      return;
    }
    _log('Resetting Superwall identity');
    await sw.Superwall.shared.reset();
    _latestStatus = sw.SubscriptionStatus.unknown;
  }

  /// Present a paywall and return true if user purchased, false otherwise.
  Future<bool> presentPaywall({
    String placement = defaultPlacement,
  }) async {
    _log('presentPaywall called with placement: $placement');
    _log('_configured = $_configured');

    if (!_configured) {
      _log('ERROR - presentPaywall called but not configured - skipping', level: LogLevel.error);
      return false;
    }

    try {
      _log('Creating PaywallPresentationHandler...');
      final completer = Completer<bool>();
      final handler = sw.PaywallPresentationHandler();

      handler.onPresent((paywallInfo) {
        _log('Paywall presented: ${paywallInfo.experiment?.id ?? "no_experiment"}');
      });

      handler.onDismiss((paywallInfo, result) {
        _log('Paywall dismissed');

        // Handle different paywall results using type checking
        if (result is sw.PurchasedPaywallResult) {
          final productId = result.productId;
          _log('Purchase completed: $productId');
          completer.complete(true);
        } else if (result is sw.RestoredPaywallResult) {
          _log('Purchases restored');
          completer.complete(true);
        } else if (result is sw.DeclinedPaywallResult) {
          _log('User declined paywall');
          completer.complete(false);
        }
      });

      handler.onSkip((paywallInfo) {
        // User already has entitlements, paywall was skipped
        _log('Paywall skipped - user already subscribed');
        completer.complete(true);
      });

      handler.onError((error) {
        _log('Paywall error: $error', level: LogLevel.error);
        completer.complete(false);
      });

      // Register the placement with the handler
      _log('Registering placement: $placement');
      await sw.Superwall.shared.registerPlacement(placement, handler: handler);
      _log('Placement registered successfully, waiting for user action...');

      // Wait for the result
      return await completer.future;
    } catch (e, stackTrace) {
      _log('presentPaywall error: $e\nStack trace: $stackTrace', level: LogLevel.error);
      return false;
    }
  }

  /// Current cached subscription status.
  SubscriptionStatusSnapshot getSubscriptionSnapshot() {
    if (!_configured) {
      _log('getSubscriptionSnapshot called but not configured - returning inactive', level: LogLevel.warning);
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
