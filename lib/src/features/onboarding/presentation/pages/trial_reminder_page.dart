import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../shared/widgets/snaplook_back_button.dart';
import '../widgets/progress_indicator.dart';
import '../widgets/onboarding_bottom_bar.dart';
import '../../../../../shared/navigation/main_navigation.dart';
import '../../../../services/revenuecat_service.dart';
import '../../../../services/superwall_service.dart';
import '../../../../services/subscription_sync_service.dart';
import '../../../../services/onboarding_state_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TrialReminderPage extends ConsumerStatefulWidget {
  const TrialReminderPage({super.key});

  @override
  ConsumerState<TrialReminderPage> createState() => _TrialReminderPageState();
}

class _TrialReminderPageState extends ConsumerState<TrialReminderPage> {
  bool _isEligibleForTrial = true;
  bool _isCheckingEligibility = true;
  bool _isPresenting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Check trial eligibility
      _checkTrialEligibility();
    });
  }

  Future<void> _checkTrialEligibility() async {
    try {
      final isEligible = await RevenueCatService().isEligibleForTrial();
      if (mounted) {
        setState(() {
          _isEligibleForTrial = isEligible;
          _isCheckingEligibility = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isEligibleForTrial = true;
          _isCheckingEligibility = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: const SnaplookBackButton(enableHaptics: true),
            centerTitle: true,
            title: const OnboardingProgressIndicator(
              currentStep: 17,
              totalSteps: 20,
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  try {
                    await RevenueCatService().restorePurchases();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Purchases restored successfully'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No purchases to restore'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                },
                child: const Text(
                  'Restore',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 14,
                    fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          body: Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: spacing.l),

                // Main heading - conditional based on trial eligibility
                Text(
                  _isEligibleForTrial
                      ? 'We\'ll send you a reminder before your free trial ends'
                      : 'Get notified about new styles and deals',
                  textAlign: TextAlign.start,
                  style: const TextStyle(
                    fontSize: 34,
                    fontFamily: 'PlusJakartaSans',
                    letterSpacing: -1.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    height: 1.3,
                  ),
                ),

                // Spacer to push bell icon to center
                const Spacer(flex: 2),

                // Bell animation
                Center(
                  child: SizedBox(
                    width: 180,
                    height: 180,
                    child: Lottie.asset(
                      'assets/animations/bell.json',
                      fit: BoxFit.contain,
                      repeat: true,
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                SizedBox(height: spacing.l),
              ],
            ),
          ),
      bottomNavigationBar: OnboardingBottomBar(
        primaryButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // No Payment Due Now - only show for new users eligible for trial
            if (_isEligibleForTrial) ...[
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check,
                    color: Colors.green,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'No Payment Due Now',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'PlusJakartaSans',
                      color: Colors.black,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            // Button with conditional text
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () async {
                  HapticFeedback.mediumImpact();

                  setState(() {
                    _isPresenting = true;
                  });

                  try {
                    final userId = Supabase.instance.client.auth.currentUser?.id;
                    final didPurchase = await SuperwallService().presentPaywall(
                      placement: 'onboarding_paywall',
                    );

                    if (!mounted) return;

                    setState(() {
                      _isPresenting = false;
                    });

                    if (didPurchase && userId != null) {
                      // User purchased - sync subscription and navigate to home
                      debugPrint('[TrialReminder] Purchase completed - syncing subscription');

                      try {
                        await Future.delayed(const Duration(milliseconds: 500));
                        await SubscriptionSyncService().syncSubscriptionToSupabase();
                        await OnboardingStateService().markPaymentComplete(userId);
                      } catch (e) {
                        debugPrint('[TrialReminder] Error syncing subscription: $e');
                      }

                      if (mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const MainNavigation(
                              key: ValueKey('fresh-main-nav'),
                            ),
                          ),
                          (route) => false,
                        );
                      }
                    }
                    // If user dismissed without purchasing, stay on this page
                  } catch (e) {
                    debugPrint('[TrialReminder] Error presenting paywall: $e');
                    if (mounted) {
                      setState(() {
                        _isPresenting = false;
                      });
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFf2003c),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: Text(
                  _isEligibleForTrial ? 'Continue for FREE' : 'See plans',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'PlusJakartaSans',
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
        ),
        if (_isPresenting)
          Container(
            color: Colors.black.withOpacity(0.35),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0),
              child: Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: CupertinoActivityIndicator(
                      radius: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
