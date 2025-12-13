import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../shared/widgets/snaplook_back_button.dart';
import '../widgets/progress_indicator.dart';
import '../widgets/onboarding_bottom_bar.dart';
import 'account_creation_page.dart';
import 'welcome_free_analysis_page.dart';
import '../../../auth/domain/providers/auth_provider.dart';
import '../../../../services/onboarding_state_service.dart';
import '../../../../services/revenuecat_service.dart';
import '../../../../services/subscription_sync_service.dart';

enum RevenueCatPaywallPlanType { monthly, yearly }

final selectedRevenueCatPlanProvider =
    StateProvider<RevenueCatPaywallPlanType?>((ref) => RevenueCatPaywallPlanType.yearly);

class RevenueCatPaywallPage extends ConsumerStatefulWidget {
  const RevenueCatPaywallPage({super.key});

  @override
  ConsumerState<RevenueCatPaywallPage> createState() => _RevenueCatPaywallPageState();
}

class _RevenueCatPaywallPageState extends ConsumerState<RevenueCatPaywallPage> {
  Offerings? _offerings;
  bool _isLoading = true;
  bool _isPurchasing = false;
  bool _isEligibleForTrial = true;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
    _checkTrialEligibility();
  }

  Future<void> _checkTrialEligibility() async {
    try {
      final isEligible = await RevenueCatService().isEligibleForTrial();
      if (mounted) {
        setState(() {
          _isEligibleForTrial = isEligible;
        });
      }
    } catch (e) {
      debugPrint('[RevenueCatPaywall] Error checking trial eligibility: $e');
      if (mounted) {
        setState(() {
          _isEligibleForTrial = true;
        });
      }
    }
  }

  Future<void> _loadOfferings() async {
    try {
      final offerings = await RevenueCatService()
          .getOfferings()
          .timeout(const Duration(seconds: 10));
      if (mounted) {
        setState(() {
          _offerings = offerings;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[RevenueCatPaywall] Error loading offerings: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Show error message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unable to load subscription plans. You can skip for now.'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _handleContinue() async {
    if (_isPurchasing) return;

    // If offerings failed to load, just navigate to next step
    if (_offerings?.current == null) {
      _navigateNext(false);
      return;
    }

    final selectedPlan = ref.read(selectedRevenueCatPlanProvider);
    if (selectedPlan == null) return;

    setState(() {
      _isPurchasing = true;
    });

    HapticFeedback.mediumImpact();

    try {
      debugPrint('[RevenueCatPaywall] Starting purchase...');

      // Get the selected package
      Package? package;
      if (selectedPlan == RevenueCatPaywallPlanType.yearly) {
        package = _offerings!.current!.annual;
      } else {
        package = _offerings!.current!.monthly;
      }

      if (package == null) {
        debugPrint('[RevenueCatPaywall] Package not found for selected plan');
        _navigateNext(false);
        return;
      }

      // Purchase the package
      final didPurchase = await RevenueCatService().purchasePackage(package);

      if (!mounted) return;

      debugPrint('[RevenueCatPaywall] Purchase result: $didPurchase');

      // Check if user is authenticated
      final authService = ref.read(authServiceProvider);
      final isAuthenticated = authService.currentUser != null;

      // If user purchased and has account, sync subscription to Supabase
      if (didPurchase && isAuthenticated) {
        try {
          debugPrint('[RevenueCatPaywall] Syncing subscription to Supabase...');
          await SubscriptionSyncService().syncSubscriptionToSupabase();
          await OnboardingStateService().markPaymentComplete(authService.currentUser!.id);
          debugPrint('[RevenueCatPaywall] Subscription synced successfully');
        } catch (e) {
          debugPrint('[RevenueCatPaywall] Error syncing subscription: $e');
        }
      }

      _navigateNext(didPurchase);
    } catch (e) {
      debugPrint('[RevenueCatPaywall] Error during purchase: $e');
      _navigateNext(false);
    } finally {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
        });
      }
    }
  }

  void _navigateNext(bool didPurchase) {
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

  @override
  Widget build(BuildContext context) {
    final selectedPlan = ref.watch(selectedRevenueCatPlanProvider);
    final spacing = context.spacing;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFf2003c)),
          ),
        ),
      );
    }

    final currentOffering = _offerings?.current;
    final yearlyPackage = currentOffering?.annual;
    final monthlyPackage = currentOffering?.monthly;

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
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: spacing.l),

              // Title
              Text(
                _isEligibleForTrial
                    ? 'Start your 3-day FREE trial to continue'
                    : 'Unlock everything Snaplook offers.',
                style: const TextStyle(
                  fontSize: 28,
                  fontFamily: 'PlusJakartaSans',
                  letterSpacing: -0.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  height: 1.2,
                ),
              ),

              SizedBox(height: spacing.xl),

              // Timeline for trial-eligible users OR Benefits for non-trial users
              if (_isEligibleForTrial) ...[
                _TimelineItem(
                  icon: Icons.lock_open_rounded,
                  iconColor: const Color(0xFFf2003c),
                  title: 'Today',
                  description:
                      'Unlock all the app\'s features like AI fashion analysis and more.',
                ),
                SizedBox(height: spacing.m),
                _TimelineItem(
                  icon: Icons.notifications_rounded,
                  iconColor: const Color(0xFFf2003c),
                  title: 'In 2 Days',
                  description: 'We\'ll send you a reminder that your trial is ending soon.',
                ),
                SizedBox(height: spacing.m),
                _TimelineItem(
                  icon: Icons.event_rounded,
                  iconColor: Colors.black,
                  title: 'In 3 Days',
                  description:
                      'You\'ll be charged on ${DateTime.now().add(const Duration(days: 3)).month}/${DateTime.now().add(const Duration(days: 3)).day}/${DateTime.now().add(const Duration(days: 3)).year} unless you cancel anytime before.',
                ),
              ] else ...[
                _BenefitItem(
                  icon: Icons.check_circle,
                  title: 'AI-powered matches',
                  description:
                      'Share an image to instantly find similar products from thousands of retailers.',
                ),
                SizedBox(height: spacing.m),
                _BenefitItem(
                  icon: Icons.check_circle,
                  title: 'Save favorite finds',
                  description:
                      'Bookmark the products you love so you can jump back in when it\'s time to buy.',
                ),
                SizedBox(height: spacing.m),
                _BenefitItem(
                  icon: Icons.check_circle,
                  title: '100 credits included',
                  description:
                      'Every subscription unlocks 100 credits (up to 100 searches) so you can keep scanning outfits all month.',
                ),
              ],

              SizedBox(height: spacing.xl),

              // Plan selection
              if (yearlyPackage != null && monthlyPackage != null) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: _PlanOption(
                          plan: RevenueCatPaywallPlanType.monthly,
                          title: 'Monthly',
                          price: '${monthlyPackage.storeProduct.priceString}/mo',
                          isSelected: selectedPlan == RevenueCatPaywallPlanType.monthly,
                          onTap: () => ref.read(selectedRevenueCatPlanProvider.notifier).state =
                              RevenueCatPaywallPlanType.monthly,
                        ),
                      ),
                      SizedBox(width: spacing.m),
                      Expanded(
                        child: _PlanOption(
                          plan: RevenueCatPaywallPlanType.yearly,
                          title: 'Yearly',
                          price: '\$${((yearlyPackage.storeProduct.price / 12) * 100).floor() / 100}/mo',
                          isSelected: selectedPlan == RevenueCatPaywallPlanType.yearly,
                          onTap: () => ref.read(selectedRevenueCatPlanProvider.notifier).state =
                              RevenueCatPaywallPlanType.yearly,
                          badge: _isEligibleForTrial ? '3-Days FREE' : 'Most Popular',
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Show error state when products can't be loaded
                Container(
                  padding: EdgeInsets.all(spacing.l),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Color(0xFFEF4444),
                        size: 48,
                      ),
                      SizedBox(height: spacing.m),
                      const Text(
                        'Unable to load plans',
                        style: TextStyle(
                          fontSize: 18,
                          fontFamily: 'PlusJakartaSans',
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                      SizedBox(height: spacing.s),
                      const Text(
                        'Subscription plans are currently unavailable. You can continue and subscribe later from your profile.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'PlusJakartaSans',
                          color: Color(0xFF6B7280),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              SizedBox(height: spacing.xxl),
            ],
          ),
        ),
      ),
      bottomNavigationBar: OnboardingBottomBar(
        primaryButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isEligibleForTrial) ...[
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'No payment due now',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'PlusJakartaSans',
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ] else ...[
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'No commitment - cancel anytime',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'PlusJakartaSans',
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isPurchasing ? null : _handleContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFf2003c),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: _isPurchasing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        _offerings?.current == null
                            ? 'Skip for Now'
                            : _isEligibleForTrial
                                ? 'Start my 3-day FREE'
                                : 'Start my journey',
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
        secondaryButton: Align(
          alignment: Alignment.center,
          child: Text(
            _offerings?.current == null
                ? ''
                : selectedPlan == RevenueCatPaywallPlanType.monthly
                    ? 'Only ${monthlyPackage?.storeProduct.priceString}/month'
                    : _isEligibleForTrial
                        ? '3-days free, then ${yearlyPackage?.storeProduct.priceString} per year'
                        : 'Just ${yearlyPackage?.storeProduct.priceString} per year (\$${((yearlyPackage!.storeProduct.price / 12) * 100).floor() / 100}/mo)',
            textAlign: TextAlign.center,
            style: const TextStyle(
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
}

class _PlanOption extends StatelessWidget {
  final RevenueCatPaywallPlanType plan;
  final String title;
  final String price;
  final bool isSelected;
  final VoidCallback onTap;
  final String? badge;

  const _PlanOption({
    required this.plan,
    required this.title,
    required this.price,
    required this.isSelected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? Colors.black : const Color(0xFFE5E7EB),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          fontFamily: 'PlusJakartaSans',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        price,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                          fontFamily: 'PlusJakartaSans',
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFFf2003c),
                    size: 24,
                  ),
              ],
            ),
          ),
          if (badge != null)
            Positioned(
              top: -10,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFf2003c),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'PlusJakartaSans',
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

class _TimelineItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  const _TimelineItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor == const Color(0xFFf2003c)
                ? const Color(0xFFf2003c).withOpacity(0.1)
                : Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BenefitItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _BenefitItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Color(0xFFf2003c),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
