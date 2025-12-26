import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/onboarding/presentation/pages/welcome_free_analysis_page.dart';
import '../../shared/navigation/main_navigation.dart';
import 'superwall_service.dart';
import 'subscription_sync_service.dart';
import 'onboarding_state_service.dart';

/// Helper to present Superwall paywall and handle post-purchase navigation
class PaywallHelper {
  /// Present Superwall paywall and navigate appropriately
  /// Returns true if user subscribed successfully
  static Future<bool> presentPaywall({
    required BuildContext context,
    required String? userId,
    String placement = 'onboarding_paywall',
  }) async {
    try {
      debugPrint('[PaywallHelper] Presenting Superwall paywall...');

      // Present Superwall paywall
      final didPurchase = await SuperwallService().presentPaywall(
        placement: placement,
      );

      if (!context.mounted) return didPurchase;

      debugPrint('[PaywallHelper] Purchase result: $didPurchase');

      // If user purchased and has account, sync subscription to Supabase
      if (didPurchase && userId != null) {
        try {
          debugPrint('[PaywallHelper] Syncing subscription to Supabase...');
          await SubscriptionSyncService().syncSubscriptionToSupabase();
          await OnboardingStateService().markPaymentComplete(userId);
          debugPrint('[PaywallHelper] Subscription synced successfully');
        } catch (e) {
          debugPrint('[PaywallHelper] Error syncing subscription: $e');
        }
      }

      return didPurchase;
    } catch (e) {
      debugPrint('[PaywallHelper] Error during paywall presentation: $e');
      return false;
    }
  }

  /// Present paywall and navigate to next screen based on onboarding state
  /// Only navigates forward if user completed purchase
  static Future<void> presentPaywallAndNavigate({
    required BuildContext context,
    required String? userId,
    String placement = 'onboarding_paywall',
  }) async {
    if (!context.mounted) return;

    try {
      // Present paywall
      final didPurchase = await presentPaywall(
        context: context,
        userId: userId,
        placement: placement,
      );

      if (!context.mounted) return;

      // Only navigate forward if user purchased
      if (!didPurchase) {
        debugPrint('[PaywallHelper] User dismissed paywall without purchasing - staying on current page');
        return;
      }

      if (userId == null) {
        // Should never happen since auth is required before paywall
        debugPrint('[PaywallHelper] WARNING: No user found after paywall');
        return;
      }

      // Check if user has completed onboarding before
      final supabase = Supabase.instance.client;
      final userResponse = await supabase
          .from('users')
          .select('onboarding_state')
          .eq('id', userId)
          .maybeSingle();

      final hasCompletedOnboarding =
          userResponse?['onboarding_state'] == 'completed';

      debugPrint(
          '[PaywallHelper] User purchased - navigating: hasCompletedOnboarding=$hasCompletedOnboarding');

      final nextPage = hasCompletedOnboarding
          ? const MainNavigation()
          : const WelcomeFreeAnalysisPage();

      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => nextPage),
        );
      }
    } catch (e) {
      debugPrint('[PaywallHelper] Error in navigation flow: $e');
      // Don't navigate on error - let user stay where they are
    }
  }
}
