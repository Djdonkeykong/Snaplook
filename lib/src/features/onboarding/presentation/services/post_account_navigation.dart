import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../shared/navigation/main_navigation.dart';
import '../../../../auth/domain/providers/auth_provider.dart';
import '../../../../services/fraud_prevention_service.dart';
import '../../../../services/onboarding_state_service.dart';
import '../../../../services/revenuecat_service.dart';
import '../../../../services/subscription_sync_service.dart';
import '../../../../services/superwall_service.dart';
import '../../domain/providers/gender_provider.dart';
import '../../domain/providers/onboarding_preferences_provider.dart';
import '../pages/trial_intro_page.dart';

class PostAccountNavigation {
  static Future<void> route({
    required BuildContext context,
    required WidgetRef ref,
  }) async {
    final authService = ref.read(authServiceProvider);
    final userId = authService.currentUser?.id;

    if (userId == null || !context.mounted) {
      debugPrint('[PostAccountNavigation] No user ID after auth');
      return;
    }

    debugPrint('[PostAccountNavigation] Routing authenticated user $userId');

    try {
      unawaited(OnboardingStateService().updateCheckpoint(
        userId,
        OnboardingCheckpoint.saveProgress,
      ));
    } catch (e) {
      debugPrint('[PostAccountNavigation] Error updating checkpoint: $e');
    }

    try {
      await SubscriptionSyncService().identify(userId);
      await FraudPreventionService.updateUserDeviceFingerprint(userId);

      final email = authService.currentUser?.email;
      if (email != null) {
        await FraudPreventionService.calculateFraudScore(
          userId,
          email: email,
        );
      }
    } catch (e) {
      debugPrint('[PostAccountNavigation] Error syncing auth data: $e');
    }

    await _persistOnboardingSelections(ref: ref, userId: userId);
    if (!context.mounted) return;
    await _navigateBasedOnSubscriptionStatus(
      context: context,
      ref: ref,
      userId: userId,
    );
  }

  static Future<void> _persistOnboardingSelections({
    required WidgetRef ref,
    required String userId,
  }) async {
    try {
      final selectedGender = ref.read(selectedGenderProvider);
      final notificationGranted =
          ref.read(notificationPermissionGrantedProvider);
      final styleDirection = ref.read(styleDirectionProvider);
      final whatYouWant = ref.read(whatYouWantProvider);
      final budget = ref.read(budgetProvider);
      final discoverySource = ref.read(selectedDiscoverySourceProvider);

      String? preferredGenderFilter;
      if (selectedGender != null) {
        switch (selectedGender) {
          case Gender.male:
            preferredGenderFilter = 'men';
            break;
          case Gender.female:
            preferredGenderFilter = 'women';
            break;
          case Gender.other:
            preferredGenderFilter = 'all';
            break;
        }
      }

      final discoverySourceString = discoverySource?.name;

      await OnboardingStateService().saveUserPreferences(
        userId: userId,
        preferredGenderFilter: preferredGenderFilter,
        notificationEnabled: notificationGranted,
        styleDirection: styleDirection.isNotEmpty ? styleDirection : null,
        whatYouWant: whatYouWant.isNotEmpty ? whatYouWant : null,
        budget: budget,
        discoverySource: discoverySourceString,
      );

      debugPrint(
          '[PostAccountNavigation] Onboarding selections persisted successfully');
    } catch (e) {
      debugPrint(
          '[PostAccountNavigation] Error persisting onboarding selections: $e');
    }
  }

  static Future<void> _navigateBasedOnSubscriptionStatus({
    required BuildContext context,
    required WidgetRef ref,
    required String userId,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      final userResponse = await supabase
          .from('users')
          .select('onboarding_state, paid_credits_remaining')
          .eq('id', userId)
          .maybeSingle();

      final hasCompletedOnboarding = userResponse != null &&
          userResponse['onboarding_state'] == 'completed';
      final paidCreditsRaw = userResponse?['paid_credits_remaining'];
      final paidCredits = paidCreditsRaw is int
          ? paidCreditsRaw
          : (paidCreditsRaw as num?)?.toInt() ?? 0;
      final hasCredits = paidCredits > 0;

      if (hasCompletedOnboarding) {
        CustomerInfo? customerInfo;
        int retryCount = 0;
        const maxRetries = 3;

        while (retryCount < maxRetries) {
          try {
            customerInfo = RevenueCatService().currentCustomerInfo ??
                await Purchases.getCustomerInfo()
                    .timeout(const Duration(seconds: 10));
            break;
          } catch (e) {
            retryCount++;
            debugPrint(
                '[PostAccountNavigation] Error fetching customer info (attempt $retryCount/$maxRetries): $e');

            if (retryCount >= maxRetries) {
              break;
            }

            await Future.delayed(Duration(seconds: retryCount));
          }
        }

        final activeEntitlements = customerInfo?.entitlements.active.values;
        final hasActiveSubscription =
            activeEntitlements != null && activeEntitlements.isNotEmpty;

        if (hasActiveSubscription || hasCredits) {
          if (hasActiveSubscription) {
            try {
              await SubscriptionSyncService()
                  .syncSubscriptionToSupabase()
                  .timeout(const Duration(seconds: 10));
            } catch (e) {
              debugPrint(
                  '[PostAccountNavigation] Error syncing subscription: $e');
            }
          }

          if (!context.mounted) return;
          _resetMainNavigationState(ref);
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const MainNavigation(
                key: ValueKey('fresh-main-nav'),
              ),
            ),
            (route) => false,
          );
          return;
        }

        if (!context.mounted) return;
        final didPurchase = await SuperwallService().presentPaywall(
          placement: 'onboarding_paywall',
        );

        if (!context.mounted || !didPurchase) return;

        try {
          await Future.delayed(const Duration(milliseconds: 500));
          await SubscriptionSyncService().syncSubscriptionToSupabase();
          await OnboardingStateService().markPaymentComplete(userId);
        } catch (e) {
          debugPrint('[PostAccountNavigation] Error syncing purchase: $e');
        }

        if (!context.mounted) return;
        _resetMainNavigationState(ref);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const MainNavigation(
              key: ValueKey('fresh-main-nav'),
            ),
          ),
          (route) => false,
        );
        return;
      }

      if (!context.mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const TrialIntroPage()),
      );
    } catch (e, stackTrace) {
      debugPrint('[PostAccountNavigation] Error checking status: $e');
      debugPrint('[PostAccountNavigation] Stack trace: $stackTrace');

      if (!context.mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const TrialIntroPage()),
      );
    }
  }

  static void _resetMainNavigationState(WidgetRef ref) {
    ref.read(selectedIndexProvider.notifier).state = 0;
    ref.invalidate(selectedIndexProvider);
    ref.invalidate(scrollToTopTriggerProvider);
    ref.invalidate(isAtHomeRootProvider);
  }
}
