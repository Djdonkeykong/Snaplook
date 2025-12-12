import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Service to manage RevenueCat SDK configuration and purchases
class RevenueCatService {
  RevenueCatService._internal();
  static final RevenueCatService _instance = RevenueCatService._internal();
  factory RevenueCatService() => _instance;

  bool _configured = false;
  CustomerInfo? _customerInfo;

  /// Initialize RevenueCat with API key
  Future<void> initialize({required String apiKey, String? userId}) async {
    if (_configured) return;

    try {
      // Configure RevenueCat SDK
      await Purchases.configure(
        PurchasesConfiguration(apiKey)
          ..appUserID = userId,
      );

      _configured = true;

      // Get initial customer info
      _customerInfo = await Purchases.getCustomerInfo();

      if (kDebugMode) {
        debugPrint('[RevenueCat] Configured successfully');
        debugPrint('[RevenueCat] User: ${userId ?? 'anonymous'}');
        debugPrint('[RevenueCat] Has active entitlement: ${_customerInfo?.entitlements.active.isNotEmpty}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RevenueCat] Configuration failed: $e');
      }
      rethrow;
    }
  }

  /// Identify a user
  Future<void> identify(String userId) async {
    if (!_configured) {
      if (kDebugMode) {
        debugPrint('[RevenueCat] identify called but not configured - skipping');
      }
      return;
    }

    try {
      await Purchases.logIn(userId);
      _customerInfo = await Purchases.getCustomerInfo();

      if (kDebugMode) {
        debugPrint('[RevenueCat] User identified: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RevenueCat] Error identifying user: $e');
      }
    }
  }

  /// Log out current user
  Future<void> logOut() async {
    if (!_configured) {
      if (kDebugMode) {
        debugPrint('[RevenueCat] logOut called but not configured - skipping');
      }
      return;
    }

    try {
      _customerInfo = await Purchases.logOut();

      if (kDebugMode) {
        debugPrint('[RevenueCat] User logged out');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RevenueCat] Error logging out: $e');
      }
    }
  }

  /// Get available offerings
  Future<Offerings?> getOfferings() async {
    if (!_configured) {
      if (kDebugMode) {
        debugPrint('[RevenueCat] getOfferings called but not configured');
      }
      return null;
    }

    try {
      final offerings = await Purchases.getOfferings();

      if (kDebugMode) {
        debugPrint('[RevenueCat] Fetched offerings: ${offerings.current?.identifier}');
      }

      return offerings;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RevenueCat] Error fetching offerings: $e');
      }
      return null;
    }
  }

  /// Purchase a package
  Future<bool> purchasePackage(Package package) async {
    if (!_configured) {
      if (kDebugMode) {
        debugPrint('[RevenueCat] purchasePackage called but not configured');
      }
      return false;
    }

    try {
      if (kDebugMode) {
        debugPrint('[RevenueCat] Purchasing package: ${package.identifier}');
      }

      final purchaseResult = await Purchases.purchasePackage(package);
      _customerInfo = purchaseResult.customerInfo;

      final hasActiveEntitlement = _customerInfo?.entitlements.active.isNotEmpty ?? false;

      if (kDebugMode) {
        debugPrint('[RevenueCat] Purchase completed - Has active entitlement: $hasActiveEntitlement');
      }

      return hasActiveEntitlement;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RevenueCat] Purchase error: $e');
      }
      return false;
    }
  }

  /// Restore purchases
  Future<bool> restorePurchases() async {
    if (!_configured) {
      if (kDebugMode) {
        debugPrint('[RevenueCat] restorePurchases called but not configured');
      }
      return false;
    }

    try {
      if (kDebugMode) {
        debugPrint('[RevenueCat] Restoring purchases...');
      }

      _customerInfo = await Purchases.restorePurchases();
      final hasActiveEntitlement = _customerInfo?.entitlements.active.isNotEmpty ?? false;

      if (kDebugMode) {
        debugPrint('[RevenueCat] Restore completed - Has active entitlement: $hasActiveEntitlement');
      }

      return hasActiveEntitlement;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RevenueCat] Restore error: $e');
      }
      return false;
    }
  }

  /// Check if user has active subscription
  Future<bool> hasActiveSubscription() async {
    if (!_configured) return false;

    try {
      final customerInfo = await Purchases.getCustomerInfo();
      _customerInfo = customerInfo;

      return customerInfo.entitlements.active.containsKey('premium');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RevenueCat] Error checking subscription: $e');
      }
      return false;
    }
  }

  /// Get current customer info
  CustomerInfo? get currentCustomerInfo => _customerInfo;

  /// Check if configured
  bool get isConfigured => _configured;
}
