import 'package:equatable/equatable.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Represents the user's subscription status from RevenueCat
class SubscriptionStatus extends Equatable {
  final bool isActive;
  final bool isInTrialPeriod;
  final String? productIdentifier;
  final DateTime? expirationDate;
  final DateTime? purchaseDate;
  final EntitlementInfo? entitlementInfo;

  const SubscriptionStatus({
    required this.isActive,
    this.isInTrialPeriod = false,
    this.productIdentifier,
    this.expirationDate,
    this.purchaseDate,
    this.entitlementInfo,
  });

  /// Create from RevenueCat CustomerInfo
  factory SubscriptionStatus.fromCustomerInfo(CustomerInfo customerInfo) {
    // Check if user has premium entitlement
    final entitlement = customerInfo.entitlements.active['premium'];
    final isActive = entitlement != null;

    return SubscriptionStatus(
      isActive: isActive,
      isInTrialPeriod: entitlement?.periodType == PeriodType.trial,
      productIdentifier: entitlement?.productIdentifier,
      expirationDate: entitlement?.expirationDate,
      purchaseDate: entitlement?.latestPurchaseDate,
      entitlementInfo: entitlement,
    );
  }

  /// Initial state (no subscription)
  factory SubscriptionStatus.initial() {
    return const SubscriptionStatus(
      isActive: false,
      isInTrialPeriod: false,
    );
  }

  /// Check if subscription is expired
  bool get isExpired {
    if (expirationDate == null) return false;
    return DateTime.now().isAfter(expirationDate!);
  }

  /// Get days remaining in trial
  int? get daysRemainingInTrial {
    if (!isInTrialPeriod || expirationDate == null) return null;
    final daysRemaining = expirationDate!.difference(DateTime.now()).inDays;
    return daysRemaining > 0 ? daysRemaining : 0;
  }

  /// Get days until expiration
  int? get daysUntilExpiration {
    if (expirationDate == null) return null;
    final daysRemaining = expirationDate!.difference(DateTime.now()).inDays;
    return daysRemaining > 0 ? daysRemaining : 0;
  }

  /// Check if user should see renewal reminder
  bool get shouldShowRenewalReminder {
    final daysRemaining = daysUntilExpiration;
    if (daysRemaining == null) return false;
    return daysRemaining <= 3 && daysRemaining > 0;
  }

  @override
  List<Object?> get props => [
        isActive,
        isInTrialPeriod,
        productIdentifier,
        expirationDate,
        purchaseDate,
      ];

  @override
  String toString() {
    return 'SubscriptionStatus(isActive: $isActive, isInTrialPeriod: $isInTrialPeriod, productIdentifier: $productIdentifier, expirationDate: $expirationDate)';
  }
}
