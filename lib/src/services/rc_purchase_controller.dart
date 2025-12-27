import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart' as sw;

/// RevenueCat purchase controller for Superwall
/// This allows Superwall to use RevenueCat for purchases and access trial eligibility
class RCPurchaseController extends sw.PurchaseController {
  @override
  Future<sw.PurchaseResult> purchaseFromAppStore(String productId) async {
    try {
      if (kDebugMode) {
        debugPrint('[RCPurchaseController] Purchasing iOS product: $productId');
      }

      // Find the RevenueCat package that matches this product
      final offerings = await Purchases.getOfferings();
      final currentOffering = offerings.current;

      if (currentOffering == null) {
        if (kDebugMode) {
          debugPrint('[RCPurchaseController] No current offering found');
        }
        return sw.PurchaseResult.failed('No offerings available');
      }

      // Find the package with this product identifier
      Package? matchingPackage;
      for (final package in currentOffering.availablePackages) {
        if (kDebugMode) {
          debugPrint('[RCPurchaseController] Checking package: ${package.identifier} with product: ${package.storeProduct.identifier}');
        }
        if (package.storeProduct.identifier == productId) {
          matchingPackage = package;
          if (kDebugMode) {
            debugPrint('[RCPurchaseController] ✓ Found matching package: ${package.identifier}');
          }
          break;
        }
      }

      if (matchingPackage == null) {
        if (kDebugMode) {
          debugPrint('[RCPurchaseController] No matching package found for $productId');
        }
        return sw.PurchaseResult.failed('Product not found in offerings');
      }

      if (kDebugMode) {
        debugPrint('[RCPurchaseController] Purchasing package: ${matchingPackage.identifier}');
        debugPrint('[RCPurchaseController] Product ID: ${matchingPackage.storeProduct.identifier}');
      }

      // Purchase through RevenueCat
      final customerInfo = await Purchases.purchasePackage(matchingPackage);

      if (kDebugMode) {
        debugPrint('[RCPurchaseController] Purchase completed');
        debugPrint('[RCPurchaseController] All purchased product IDs: ${customerInfo.allPurchasedProductIdentifiers}');
      }

      if (kDebugMode) {
        debugPrint('[RCPurchaseController] Purchase successful');
        debugPrint('[RCPurchaseController] Active entitlements: ${customerInfo.entitlements.active.keys}');
      }

      return sw.PurchaseResult.purchased;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[RCPurchaseController] Purchase error: ${e.message}');
      }

      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        return sw.PurchaseResult.cancelled;
      }

      return sw.PurchaseResult.failed(e.message ?? 'Purchase failed');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RCPurchaseController] Purchase error: $e');
      }

      // Check if user cancelled
      if (e.toString().contains('purchaseCancelledError') ||
          e.toString().contains('cancelled')) {
        return sw.PurchaseResult.cancelled;
      }

      return sw.PurchaseResult.failed(e.toString());
    }
  }

  @override
  Future<sw.PurchaseResult> purchaseFromGooglePlay(
    String productId,
    String? basePlanId,
    String? offerId,
  ) async {
    try {
      if (kDebugMode) {
        debugPrint('[RCPurchaseController] Purchasing Android product: $productId');
        debugPrint('[RCPurchaseController]   basePlanId: $basePlanId');
        debugPrint('[RCPurchaseController]   offerId: $offerId');
      }

      // Find the RevenueCat package that matches this product
      final offerings = await Purchases.getOfferings();
      final currentOffering = offerings.current;

      if (currentOffering == null) {
        if (kDebugMode) {
          debugPrint('[RCPurchaseController] No current offering found');
        }
        return sw.PurchaseResult.failed('No offerings available');
      }

      // Find the package with this product identifier
      // For Google Play, the identifier format is "productId:basePlanId" in RevenueCat
      String searchIdentifier = productId;
      if (basePlanId != null && basePlanId.isNotEmpty) {
        searchIdentifier = '$productId:$basePlanId';
      }

      Package? matchingPackage;
      for (final package in currentOffering.availablePackages) {
        if (package.storeProduct.identifier == searchIdentifier ||
            package.storeProduct.identifier == productId) {
          matchingPackage = package;
          break;
        }
      }

      if (matchingPackage == null) {
        if (kDebugMode) {
          debugPrint('[RCPurchaseController] No matching package found for $searchIdentifier');
        }
        return sw.PurchaseResult.failed('Product not found in offerings');
      }

      // Purchase through RevenueCat
      final customerInfo = await Purchases.purchasePackage(matchingPackage);

      if (kDebugMode) {
        debugPrint('[RCPurchaseController] Purchase successful');
        debugPrint('[RCPurchaseController] Active entitlements: ${customerInfo.entitlements.active.keys}');
      }

      return sw.PurchaseResult.purchased;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[RCPurchaseController] Purchase error: ${e.message}');
      }

      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        return sw.PurchaseResult.cancelled;
      }

      return sw.PurchaseResult.failed(e.message ?? 'Purchase failed');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RCPurchaseController] Purchase error: $e');
      }

      // Check if user cancelled
      if (e.toString().contains('purchaseCancelledError') ||
          e.toString().contains('cancelled')) {
        return sw.PurchaseResult.cancelled;
      }

      return sw.PurchaseResult.failed(e.toString());
    }
  }

  @override
  Future<sw.RestorationResult> restorePurchases() async {
    try {
      if (kDebugMode) {
        debugPrint('[RCPurchaseController] Restoring purchases...');
      }

      final customerInfo = await Purchases.restorePurchases();

      if (kDebugMode) {
        debugPrint('[RCPurchaseController] Restore complete');
        debugPrint('[RCPurchaseController] Active entitlements: ${customerInfo.entitlements.active.keys}');
      }

      return sw.RestorationResult.restored;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RCPurchaseController] Restore error: $e');
      }

      return sw.RestorationResult.failed(e.toString());
    }
  }
}
