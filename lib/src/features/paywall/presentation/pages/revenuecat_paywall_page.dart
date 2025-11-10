import 'package:flutter/material.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/credit_provider.dart';

/// Modern RevenueCat Paywall using RevenueCat's Paywall UI
/// This uses RevenueCat's pre-built paywall templates which can be
/// customized in the RevenueCat dashboard without code changes
class RevenueCatPaywallPage extends ConsumerWidget {
  final VoidCallback? onDismiss;
  final VoidCallback? onPurchaseSuccess;

  const RevenueCatPaywallPage({
    super.key,
    this.onDismiss,
    this.onPurchaseSuccess,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PaywallView(
      displayCloseButton: true,
      onRestoreCompleted: (CustomerInfo customerInfo) {
        debugPrint('Restore completed: ${customerInfo.entitlements.active}');

        // Refresh credit balance after restore
        ref.invalidate(creditBalanceProvider);

        if (customerInfo.entitlements.active.isNotEmpty) {
          // User has active subscription, dismiss paywall
          if (onPurchaseSuccess != null) {
            onPurchaseSuccess!();
          } else {
            Navigator.of(context).pop(true);
          }
        }
      },
      onPurchaseCompleted: (CustomerInfo customerInfo, StoreTransaction storeTransaction) {
        debugPrint('Purchase completed: ${storeTransaction.productIdentifier}');
        debugPrint('Active entitlements: ${customerInfo.entitlements.active}');

        // Refresh credit balance after purchase
        ref.invalidate(creditBalanceProvider);

        if (onPurchaseSuccess != null) {
          onPurchaseSuccess!();
        } else {
          Navigator.of(context).pop(true);
        }
      },
      onPurchaseError: (PurchasesError error) {
        debugPrint('Purchase error: ${error.message}');

        // Show error message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Purchase failed: ${error.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      onDismiss: () {
        debugPrint('Paywall dismissed');

        if (onDismiss != null) {
          onDismiss!();
        } else {
          Navigator.of(context).pop(false);
        }
      },
    );
  }
}

/// Show RevenueCat Paywall as a modal
Future<bool?> showRevenueCatPaywall(BuildContext context) async {
  return await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (context) => const RevenueCatPaywallPage(),
      fullscreenDialog: true,
    ),
  );
}
