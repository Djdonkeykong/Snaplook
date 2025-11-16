import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../features/paywall/models/subscription_status.dart';

/// Service for managing RevenueCat purchases and subscriptions
class RevenueCatService {
  static final RevenueCatService _instance = RevenueCatService._internal();
  factory RevenueCatService() => _instance;
  RevenueCatService._internal();

  bool _isConfigured = false;
  CustomerInfo? _currentCustomerInfo;

  // RevenueCat API keys
  // Get them from: https://app.revenuecat.com/settings/api-keys
  static const String _appleApiKey = 'appl_uohzNateNMeOXeZppfARhFngkQr';
  static const String _googleApiKey = 'appl_uohzNateNMeOXeZppfARhFngkQr'; // Update with Android key when available

  // Entitlement identifier (must match your RevenueCat dashboard)
  static const String premiumEntitlementId = 'premium';

  /// Initialize RevenueCat SDK
  Future<void> initialize({String? userId, String? apiKeyOverride}) async {
    if (_isConfigured) {
      debugPrint('RevenueCat already configured');
      return;
    }

    try {
      final fallbackKey = Platform.isIOS ? _appleApiKey : _googleApiKey;
      final apiKey =
          (apiKeyOverride != null && apiKeyOverride.isNotEmpty) ? apiKeyOverride : fallbackKey;

      if (apiKey.startsWith('YOUR_')) {
        throw Exception(
          'RevenueCat API key not configured. '
          'Please update the API keys in revenue_cat_service.dart',
        );
      }

      final configuration = PurchasesConfiguration(apiKey);

      if (userId != null) {
        configuration.appUserID = userId;
      }

      // Enable debug logs in debug mode
      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      }

      await Purchases.configure(configuration);
      _isConfigured = true;

      // Get initial customer info
      _currentCustomerInfo = await Purchases.getCustomerInfo();

      debugPrint('RevenueCat initialized successfully');
      debugPrint('User ID: ${_currentCustomerInfo?.originalAppUserId}');
      debugPrint('Active subscriptions: ${_currentCustomerInfo?.entitlements.active}');
    } on PlatformException catch (e) {
      debugPrint('RevenueCat initialization failed: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('RevenueCat initialization error: $e');
      rethrow;
    }
  }

  /// Get current subscription status
  Future<SubscriptionStatus> getSubscriptionStatus() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      _currentCustomerInfo = customerInfo;
      return SubscriptionStatus.fromCustomerInfo(customerInfo);
    } catch (e) {
      debugPrint('Error getting subscription status: $e');
      return SubscriptionStatus.initial();
    }
  }

  /// Get available offerings from RevenueCat
  Future<Offerings?> getOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      if (offerings.current == null) {
        debugPrint('No offerings available');
        return null;
      }
      return offerings;
    } catch (e) {
      debugPrint('Error getting offerings: $e');
      return null;
    }
  }

  /// Purchase a subscription package
  Future<CustomerInfo?> purchasePackage(Package package) async {
    try {
      final customerInfo = await Purchases.purchasePackage(package);
      _currentCustomerInfo = customerInfo;

      // Check if purchase was successful
      if (customerInfo.entitlements.active.containsKey(premiumEntitlementId)) {
        debugPrint('Purchase successful!');
        return customerInfo;
      } else {
        debugPrint('Purchase completed but entitlement not active');
        return null;
      }
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('User cancelled purchase');
      } else if (errorCode == PurchasesErrorCode.purchaseNotAllowedError) {
        debugPrint('User not allowed to purchase');
      } else if (errorCode == PurchasesErrorCode.paymentPendingError) {
        debugPrint('Payment pending');
      } else {
        debugPrint('Purchase error: ${e.message}');
      }
      rethrow;
    } catch (e) {
      debugPrint('Purchase error: $e');
      rethrow;
    }
  }

  /// Purchase a subscription by product ID (alternative method)
  Future<CustomerInfo?> purchaseProduct(String productId) async {
    try {
      final offerings = await getOfferings();
      if (offerings == null || offerings.current == null) {
        throw Exception('No offerings available');
      }

      // Find the package with the matching product ID
      Package? targetPackage;
      for (final package in offerings.current!.availablePackages) {
        if (package.storeProduct.identifier == productId) {
          targetPackage = package;
          break;
        }
      }

      if (targetPackage == null) {
        throw Exception('Product not found: $productId');
      }

      return await purchasePackage(targetPackage);
    } catch (e) {
      debugPrint('Error purchasing product: $e');
      rethrow;
    }
  }

  /// Restore previous purchases
  Future<CustomerInfo?> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      _currentCustomerInfo = customerInfo;

      if (customerInfo.entitlements.active.containsKey(premiumEntitlementId)) {
        debugPrint('Purchases restored successfully');
        return customerInfo;
      } else {
        debugPrint('No active purchases to restore');
        return null;
      }
    } on PlatformException catch (e) {
      debugPrint('Restore purchases error: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Restore purchases error: $e');
      rethrow;
    }
  }

  /// Check if user has active premium subscription
  Future<bool> hasActivePremium() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.active.containsKey(premiumEntitlementId);
    } catch (e) {
      debugPrint('Error checking premium status: $e');
      return false;
    }
  }

  /// Get current customer info
  CustomerInfo? get currentCustomerInfo => _currentCustomerInfo;

  /// Check if user is in trial period
  Future<bool> isInTrialPeriod() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final entitlement = customerInfo.entitlements.active[premiumEntitlementId];
      return entitlement?.periodType == PeriodType.trial;
    } catch (e) {
      debugPrint('Error checking trial status: $e');
      return false;
    }
  }

  /// Get subscription expiration date
  Future<DateTime?> getExpirationDate() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final entitlement = customerInfo.entitlements.active[premiumEntitlementId];
      final expirationDateString = entitlement?.expirationDate;
      return expirationDateString != null ? DateTime.tryParse(expirationDateString) : null;
    } catch (e) {
      debugPrint('Error getting expiration date: $e');
      return null;
    }
  }

  /// Set user ID (for identifying users across devices)
  Future<void> setUserId(String userId) async {
    try {
      await Purchases.logIn(userId);
      _currentCustomerInfo = await Purchases.getCustomerInfo();
      debugPrint('User ID set: $userId');
    } catch (e) {
      debugPrint('Error setting user ID: $e');
      rethrow;
    }
  }

  /// Log out current user
  Future<void> logout() async {
    try {
      final customerInfo = await Purchases.logOut();
      _currentCustomerInfo = customerInfo;
      debugPrint('User logged out');
    } catch (e) {
      debugPrint('Error logging out: $e');
      rethrow;
    }
  }

  /// Check for promotional offers (iOS only)
  Future<bool> hasPromotionalOffer(String productId) async {
    if (!Platform.isIOS) return false;

    try {
      final offerings = await getOfferings();
      if (offerings == null || offerings.current == null) return false;

      for (final package in offerings.current!.availablePackages) {
        if (package.storeProduct.identifier == productId) {
          // Check if package has promotional offer
          return package.storeProduct.discounts?.isNotEmpty ?? false;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error checking promotional offer: $e');
      return false;
    }
  }

  /// Show management UI (opens store subscription management)
  /// Note: This uses platform-specific URLs since RevenueCat removed showManagementUI
  Future<void> showManagementUI() async {
    // RevenueCat removed showManagementUI method in newer versions
    // Users should be directed to platform-specific subscription management:
    // iOS: Settings > Apple ID > Subscriptions
    // Android: Play Store > Menu > Subscriptions
    debugPrint('Note: Direct management UI not available. Users should manage subscriptions via platform settings.');
  }
}
