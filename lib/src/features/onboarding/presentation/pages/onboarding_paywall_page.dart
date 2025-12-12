import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../shared/widgets/snaplook_back_button.dart';
import '../../../paywall/providers/credit_provider.dart';
import '../widgets/progress_indicator.dart';
import '../widgets/onboarding_bottom_bar.dart';
import 'account_creation_page.dart';
import 'welcome_free_analysis_page.dart';
import '../../../auth/domain/providers/auth_provider.dart';
import '../../../../services/fraud_prevention_service.dart';
import '../../../../services/onboarding_state_service.dart';
import '../../../../services/subscription_sync_service.dart';
import '../../../../services/superwall_service.dart';

enum OnboardingPaywallPlanType { monthly, yearly }

final selectedOnboardingPlanProvider = StateProvider<OnboardingPaywallPlanType>(
  (ref) => OnboardingPaywallPlanType.yearly,
);
final isOnboardingPurchasingProvider = StateProvider<bool>((ref) => false);
final isTrialEligibleProvider = StateProvider<bool>((ref) => true);

class OnboardingPaywallPage extends ConsumerStatefulWidget {
  const OnboardingPaywallPage({super.key});

  @override
  ConsumerState<OnboardingPaywallPage> createState() =>
      _OnboardingPaywallPageState();
}

class _OnboardingPaywallPageState extends ConsumerState<OnboardingPaywallPage> {
  @override
  void initState() {
    super.initState();
    _checkTrialEligibility();
  }

  Future<void> _checkTrialEligibility() async {
    try {
      debugPrint('[OnboardingPaywall] Checking trial eligibility...');
      final isEligible = await FraudPreventionService.isDeviceEligibleForTrial();

      if (mounted) {
        ref.read(isTrialEligibleProvider.notifier).state = isEligible;
        debugPrint('[OnboardingPaywall] Trial eligible: $isEligible');

        if (!isEligible) {
          // Auto-switch to monthly plan if trial not available
          ref.read(selectedOnboardingPlanProvider.notifier).state =
              OnboardingPaywallPlanType.monthly;
          debugPrint('[OnboardingPaywall] Trial not available - switched to monthly plan');
        }
      }
    } catch (e) {
      debugPrint('[OnboardingPaywall] Error checking trial eligibility: $e');
      // Default to eligible on error
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedPlan = ref.watch(selectedOnboardingPlanProvider);
    final spacing = context.spacing;
    final isPurchasing = ref.watch(isOnboardingPurchasingProvider);
    final trialEndDate = DateTime.now().add(const Duration(days: 3));
    final trialEndFormatted = DateFormat('d MMM y').format(trialEndDate);
    final billingSubtitle =
        'You\'ll be charged on $trialEndFormatted unless\nyou cancel anytime before.';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const SnaplookBackButton(),
        centerTitle: true,
        title: const OnboardingProgressIndicator(
          currentStep: 9,
          totalSteps: 10,
        ),
        actions: [
          TextButton(
            onPressed: isPurchasing ? null : () => _handleRestore(context, ref),
            style: TextButton.styleFrom(
              foregroundColor: Colors.black87,
              textStyle: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            child: const Text('Restore'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Fixed title at top
            Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.l),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: spacing.m),
                    Text(
                      selectedPlan == OnboardingPaywallPlanType.monthly
                          ? 'Unlock everything Snaplook offers.'
                          : 'Start your 3-day FREE\ntrial to continue.',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        letterSpacing: -1.0,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 34),
                  ],
                ),
              ),
            ),
            // Scrollable content area
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: spacing.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (selectedPlan == OnboardingPaywallPlanType.monthly)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _FeatureItem(
                            icon: Icons.check,
                            title: 'AI-powered matches',
                            subtitle:
                                'Tap into a massive catalog of brands — every image you upload is analyzed to surface the closest lookalikes across thousands of retailers.',
                          ),
                          const SizedBox(height: 26),
                          const _FeatureItem(
                            icon: Icons.bookmark_added,
                            title: 'Save favorite finds',
                            subtitle:
                                'Bookmark the products you love so you can jump back in when it\'s time to buy.',
                          ),
                          const SizedBox(height: 26),
                          _FeatureItem(
                            icon: Icons.bolt,
                            title: '50 credits included',
                            subtitle:
                                'Every subscription unlocks 50 credits (up to 50 searches) so you can keep scanning and saving outfits all month.',
                          ),
                        ],
                      )
                    else
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _TimelineItem(
                            icon: Icons.lock,
                            circleColor: Color(0xFFF2003C),
                            title: 'Today',
                            subtitle:
                                'Unlock all the app\'s features like AI\nfashion analysis and more.',
                            isFirst: true,
                          ),
                          const _TimelineItem(
                            icon: Icons.notifications_active,
                            circleColor: Color(0xFFF2003C),
                            title: 'In 2 Days - Reminder',
                            subtitle:
                                'We\'ll send you a reminder that your trial\nis ending soon.',
                          ),
                          _TimelineItem(
                            icon: Icons.star,
                            circleColor: const Color(0xFF2ED3B7),
                            title: 'In 3 Days - Billing Starts',
                            subtitle: billingSubtitle,
                            isLast: true,
                          ),
                        ],
                      ),
                    const SizedBox(height: 17),
                  ],
                ),
              ),
            ),

            // Fixed plan selection cards at bottom
            Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.l),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _PlanOption(
                          plan: OnboardingPaywallPlanType.monthly,
                          title: 'Monthly',
                          price: '\$7.99/mo',
                          subtitle: '',
                          isSelected:
                              selectedPlan == OnboardingPaywallPlanType.monthly,
                          onTap: () => ref
                              .read(selectedOnboardingPlanProvider.notifier)
                              .state = OnboardingPaywallPlanType.monthly,
                        ),
                      ),
                      SizedBox(width: spacing.m),
                      Expanded(
                        child: _PlanOption(
                          plan: OnboardingPaywallPlanType.yearly,
                          title: 'Yearly',
                          price: '\$4.99/mo',
                          subtitle: null,
                          isSelected:
                              selectedPlan == OnboardingPaywallPlanType.yearly,
                          onTap: () => ref
                              .read(selectedOnboardingPlanProvider.notifier)
                              .state = OnboardingPaywallPlanType.yearly,
                          isPopular: true,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: spacing.l),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: OnboardingBottomBar(
        primaryButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // No Payment Due Now
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check, color: Colors.green, size: 16),
                const SizedBox(width: 8),
                Text(
                  selectedPlan == OnboardingPaywallPlanType.yearly
                      ? 'No Payment Due Now'
                      : 'No Commitment - Cancel Anytime',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Subscribe button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => _handleContinue(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFf2003c),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: Text(
                  selectedPlan == OnboardingPaywallPlanType.yearly
                      ? 'Start My 3-Day Free Trial'
                      : 'Subscribe Now',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          ],
        ),
        secondaryButton: const Align(
          alignment: Alignment.center,
          child: Text(
            '3 days free, then \$59.99 per year (\$4.99/mo)',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 14,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  void _handleContinue(BuildContext context) async {
    HapticFeedback.mediumImpact();

    // Present Superwall paywall after screenshot page
    debugPrint('[OnboardingPaywall] Presenting Superwall paywall...');

    try {
      final superwallService = SuperwallService();
      final didPurchase = await superwallService.presentPaywall(
        placement: 'onboarding_paywall',
        timeout: const Duration(seconds: 60),
      );

      if (!mounted) return;

      debugPrint('[OnboardingPaywall] Paywall result - purchased: $didPurchase');

      final authService = ref.read(authServiceProvider);
      final hasAccount = authService.currentUser != null;

      // If user purchased and has account, sync subscription to Supabase
      if (didPurchase && hasAccount) {
        try {
          debugPrint('[OnboardingPaywall] Syncing subscription to Supabase...');
          await SubscriptionSyncService().syncSubscriptionToSupabase();
          await OnboardingStateService().markPaymentComplete(authService.currentUser!.id);
          debugPrint('[OnboardingPaywall] Subscription synced successfully');
        } catch (e) {
          debugPrint('[OnboardingPaywall] Error syncing subscription: $e');
          // Non-critical - continue
        }
      }

      // Navigate to next step regardless of purchase result
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                hasAccount ? const WelcomeFreeAnalysisPage() : const AccountCreationPage(),
          ),
        );
      }
    } catch (e) {
      debugPrint('[OnboardingPaywall] Error presenting paywall: $e');

      // On error, navigate to next step anyway
      if (!mounted) return;

      final authService = ref.read(authServiceProvider);
      final hasAccount = authService.currentUser != null;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) =>
              hasAccount ? const WelcomeFreeAnalysisPage() : const AccountCreationPage(),
        ),
      );
    }
  }

  Future<void> _handleRestore(BuildContext context, WidgetRef ref) async {
    try {
      HapticFeedback.mediumImpact();

      ref.read(isOnboardingPurchasingProvider.notifier).state = true;

      final purchaseController = ref.read(purchaseControllerProvider);
      final success = await purchaseController.restorePurchases();

      ref.read(isOnboardingPurchasingProvider.notifier).state = false;

      if (success) {
        HapticFeedback.mediumImpact();

        final authService = ref.read(authServiceProvider);
        final hasAccount = authService.currentUser != null;

        // Sync restored subscription to Supabase
        if (hasAccount) {
          final user = authService.currentUser;
          if (user != null) {
            try {
              await SubscriptionSyncService().syncSubscriptionToSupabase();
              await OnboardingStateService().markPaymentComplete(user.id);
              debugPrint('[OnboardingPaywall] Subscription restored and synced for user ${user.id}');
            } catch (e) {
              debugPrint('[OnboardingPaywall] Error syncing restored subscription: $e');
            }
          }
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Purchases restored successfully!',
                style: TextStyle(fontFamily: 'PlusJakartaSans'),
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) =>
                  hasAccount ? const WelcomeFreeAnalysisPage() : const AccountCreationPage(),
            ),
          );
        }
      } else {
        if (context.mounted) {
          _showErrorDialog(context, 'No purchases found to restore.');
        }
      }
    } catch (e) {
      ref.read(isOnboardingPurchasingProvider.notifier).state = false;

      if (context.mounted) {
        _showErrorDialog(
          context,
          'Failed to restore purchases. Please try again.',
        );
      }
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Error',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'PlusJakartaSans'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'OK',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                color: Color(0xFFf2003c),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check, color: Color(0xFF23B6A8), size: 26),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                  letterSpacing: -0.4,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    color: Color(0xFF6C7280),
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final IconData icon;
  final Color circleColor;
  final String title;
  final String subtitle;
  final bool isFirst;
  final bool isLast;
  final Color lineColor;

  const _TimelineItem({
    required this.icon,
    required this.circleColor,
    required this.title,
    required this.subtitle,
    this.isFirst = false,
    this.isLast = false,
    this.lineColor = const Color(0xFFE3E5ED),
  });

  @override
  Widget build(BuildContext context) {
    const double circleDiameter = 42;
    const double lineWidth = 5;

    final circle = Container(
      width: circleDiameter,
      height: circleDiameter,
      decoration: BoxDecoration(
        color: circleColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: circleColor.withOpacity(0.15),
            blurRadius: 10,
            spreadRadius: 0.8,
          ),
        ],
      ),
      child: Icon(icon, size: 22, color: Colors.white),
    );

    final fadeDecoration = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor,
          lineColor.withOpacity(0.0),
        ],
      ),
    );

    const double connectorGap = 30;
    final double topSegmentHeight = isFirst ? 0 : connectorGap;
    final double bottomSegmentHeight = isLast ? 78 : connectorGap;

    final lineSegments = SizedBox(
      width: 50,
      height: topSegmentHeight + circleDiameter + bottomSegmentHeight,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned.fill(
            child: Column(
              children: [
                if (!isFirst)
                  Container(
                      width: lineWidth,
                      height: topSegmentHeight,
                      color: lineColor),
                Container(
                    width: lineWidth, height: circleDiameter, color: lineColor),
                if (!isLast)
                  Container(
                      width: lineWidth,
                      height: bottomSegmentHeight,
                      color: lineColor)
                else
                  Container(
                    width: lineWidth,
                    height: bottomSegmentHeight,
                    decoration: fadeDecoration,
                  ),
              ],
            ),
          ),
          Positioned(
            top: topSegmentHeight,
            left: (50 - circleDiameter) / 2,
            child: circle,
          ),
        ],
      ),
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          lineSegments,
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: topSegmentHeight, bottom: 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      color: Color(0xFF6C7280),
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.2,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanOption extends StatelessWidget {
  final OnboardingPaywallPlanType plan;
  final String title;
  final String price;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isPopular;
  final double height;

  const _PlanOption({
    required this.plan,
    required this.title,
    required this.price,
    this.subtitle,
    required this.isSelected,
    required this.onTap,
    this.isPopular = false,
    this.height = 106,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            height: height,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.black : Colors.grey.shade300,
                width: isSelected ? 2.4 : 1.2,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        price,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? Colors.black : Colors.white,
                    border: Border.all(
                      color: isSelected ? Colors.black : Colors.grey.shade400,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 18, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ),
          if (isPopular)
            Positioned(
              top: -12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Text(
                    '3 DAYS FREE',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
