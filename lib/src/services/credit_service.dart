import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/paywall/models/credit_balance.dart';
import '../features/paywall/models/subscription_plan.dart';
import 'superwall_service.dart';

/// Service for managing user credits
class CreditService {
  static final CreditService _instance = CreditService._internal();
  factory CreditService() => _instance;
  CreditService._internal();

  final SuperwallService _superwallService = SuperwallService();

  static const String _creditBalanceKey = 'credit_balance';
  static const String _lastRefillDateKey = 'last_refill_date';
  static const String _freeTrialUsedKey = 'free_trial_used';

  CreditBalance? _cachedBalance;

  /// Get current credit balance
  Future<CreditBalance> getCreditBalance() async {
    if (_cachedBalance != null) {
      return _cachedBalance!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if user has used free trial
      final hasUsedFreeTrial = prefs.getBool(_freeTrialUsedKey) ?? false;

      // Get subscription status from Superwall
      final subscriptionStatus = _superwallService.getSubscriptionSnapshot();

      // If user has never used free trial and has no subscription, give 1 free credit
      if (!hasUsedFreeTrial && !subscriptionStatus.isActive) {
        _cachedBalance = CreditBalance.initial();
        await _saveCreditBalance(_cachedBalance!);
        return _cachedBalance!;
      }

      // Load saved credit balance
      final savedBalance = prefs.getString(_creditBalanceKey);
      if (savedBalance != null) {
        final jsonData = jsonDecode(savedBalance) as Map<String, dynamic>;
        _cachedBalance = CreditBalance.fromJson(jsonData);

        // Update subscription status
        _cachedBalance = _cachedBalance!.copyWith(
          hasActiveSubscription: subscriptionStatus.isActive,
          subscriptionPlanId: subscriptionStatus.productIdentifier,
        );

        // Check if credits need to be refilled
        if (subscriptionStatus.isActive) {
          _cachedBalance = await _checkAndRefillCredits(_cachedBalance!);
        }

        await _saveCreditBalance(_cachedBalance!);
        return _cachedBalance!;
      }

      // No saved balance - create appropriate initial state
      if (subscriptionStatus.isActive) {
        // User has subscription - give full credits
        final plan = SubscriptionPlan.getPlanByProductId(
              subscriptionStatus.productIdentifier ?? SubscriptionPlan.yearly.productId) ??
            SubscriptionPlan.yearly;
        final credits = plan?.creditsPerMonth ?? 100;

        _cachedBalance = CreditBalance(
          availableCredits: credits,
          totalCredits: credits,
          hasActiveSubscription: true,
          hasUsedFreeTrial: true,
          nextRefillDate: _calculateNextRefillDate(),
          subscriptionPlanId: subscriptionStatus.productIdentifier,
        );
      } else {
        // No subscription and no saved data
        _cachedBalance = hasUsedFreeTrial
            ? CreditBalance.empty()
            : CreditBalance.initial();
      }

      await _saveCreditBalance(_cachedBalance!);
      return _cachedBalance!;
    } catch (e) {
      debugPrint('Error getting credit balance: $e');
      return CreditBalance.initial();
    }
  }

  /// Consume one credit for an action
  Future<CreditBalance> consumeCredit() async {
    try {
      final balance = await getCreditBalance();

      if (!balance.canPerformAction) {
        throw Exception('No credits available');
      }

      // Mark free trial as used if this is the first credit consumption
      if (balance.isInFreeTrial) {
        await _markFreeTrialAsUsed();
      }

      _cachedBalance = balance.consumeCredit();
      await _saveCreditBalance(_cachedBalance!);

      debugPrint('Credit consumed. Remaining: ${_cachedBalance!.availableCredits}');
      return _cachedBalance!;
    } catch (e) {
      debugPrint('Error consuming credit: $e');
      rethrow;
    }
  }

  /// Refill credits (called when subscription is renewed monthly)
  Future<CreditBalance> refillCredits() async {
    try {
      final subscriptionStatus = _superwallService.getSubscriptionSnapshot();

      if (!subscriptionStatus.isActive) {
        throw Exception('No active subscription');
      }

      final plan = SubscriptionPlan.getPlanByProductId(
            subscriptionStatus.productIdentifier ?? SubscriptionPlan.yearly.productId) ??
          SubscriptionPlan.yearly;

      if (plan == null) {
        throw Exception('Unknown subscription plan');
      }

      _cachedBalance = (await getCreditBalance()).refillCredits(plan.creditsPerMonth);
      _cachedBalance = _cachedBalance!.copyWith(
        nextRefillDate: _calculateNextRefillDate(),
      );

      await _saveCreditBalance(_cachedBalance!);
      await _saveLastRefillDate(DateTime.now());

      debugPrint('Credits refilled. New balance: ${_cachedBalance!.availableCredits}');
      return _cachedBalance!;
    } catch (e) {
      debugPrint('Error refilling credits: $e');
      rethrow;
    }
  }

  /// Check if credits need to be refilled (monthly check)
  Future<CreditBalance> _checkAndRefillCredits(CreditBalance currentBalance) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastRefillDateString = prefs.getString(_lastRefillDateKey);

      if (lastRefillDateString == null) {
        // First time - refill now
        return await refillCredits();
      }

      final lastRefillDate = DateTime.parse(lastRefillDateString);
      final now = DateTime.now();

      // Check if a month has passed since last refill
      final monthsSinceRefill = _monthsBetween(lastRefillDate, now);

      if (monthsSinceRefill >= 1) {
        debugPrint('Monthly refill due. Last refill: $lastRefillDate');
        return await refillCredits();
      }

      return currentBalance;
    } catch (e) {
      debugPrint('Error checking refill: $e');
      return currentBalance;
    }
  }

  /// Calculate months between two dates
  int _monthsBetween(DateTime from, DateTime to) {
    return (to.year - from.year) * 12 + to.month - from.month;
  }

  /// Calculate next refill date (1 month from now)
  DateTime _calculateNextRefillDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1, now.day);
  }

  /// Save credit balance to local storage
  Future<void> _saveCreditBalance(CreditBalance balance) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(balance.toJson());
      await prefs.setString(_creditBalanceKey, jsonString);
      debugPrint('Credit balance saved: $balance');
    } catch (e) {
      debugPrint('Error saving credit balance: $e');
    }
  }

  /// Save last refill date
  Future<void> _saveLastRefillDate(DateTime date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastRefillDateKey, date.toIso8601String());
    } catch (e) {
      debugPrint('Error saving refill date: $e');
    }
  }

  /// Mark free trial as used
  Future<void> _markFreeTrialAsUsed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_freeTrialUsedKey, true);
      debugPrint('Free trial marked as used');
    } catch (e) {
      debugPrint('Error marking free trial as used: $e');
    }
  }

  /// Sync credits with subscription status (call after purchase/restore)
  Future<CreditBalance> syncWithSubscription() async {
    try {
      final subscriptionStatus = _superwallService.getSubscriptionSnapshot();

      if (subscriptionStatus.isActive) {
        // User has active subscription - refill credits
        return await refillCredits();
      } else {
        // No active subscription - use current balance
        _cachedBalance = null; // Clear cache to force reload
        return await getCreditBalance();
      }
    } catch (e) {
      debugPrint('Error syncing with subscription: $e');
      rethrow;
    }
  }

  /// Reset credit balance (for testing/debugging)
  Future<void> resetCredits() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_creditBalanceKey);
      await prefs.remove(_lastRefillDateKey);
      await prefs.remove(_freeTrialUsedKey);
      _cachedBalance = null;
      debugPrint('Credits reset');
    } catch (e) {
      debugPrint('Error resetting credits: $e');
    }
  }

  /// Clear cached balance (force reload on next access)
  void clearCache() {
    _cachedBalance = null;
  }
}
