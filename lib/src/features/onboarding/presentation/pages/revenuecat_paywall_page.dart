import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../shared/widgets/snaplook_back_button.dart';
import '../widgets/progress_indicator.dart';
import 'account_creation_page.dart';
import 'welcome_free_analysis_page.dart';
import '../../../auth/domain/providers/auth_provider.dart';
import '../../../../services/onboarding_state_service.dart';
import '../../../../services/revenuecat_service.dart';
import '../../../../services/subscription_sync_service.dart';

enum RevenueCatPaywallPlanType { monthly, yearly }

final selectedRevenueCatPlanProvider =
    StateProvider<RevenueCatPaywallPlanType?>(
        (ref) => RevenueCatPaywallPlanType.yearly);

class RevenueCatPaywallPage extends ConsumerStatefulWidget {
  const RevenueCatPaywallPage({super.key});

  @override
  ConsumerState<RevenueCatPaywallPage> createState() =>
      _RevenueCatPaywallPageState();
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
              content: Text(
                  'Unable to load subscription plans. You can skip for now.'),
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
          await OnboardingStateService()
              .markPaymentComplete(authService.currentUser!.id);
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
        builder: (context) => hasAccount
            ? const WelcomeFreeAnalysisPage()
            : const AccountCreationPage(),
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
    final trialEndDate = DateTime.now().add(const Duration(days: 3));
    final trialEndFormatted =
        '${trialEndDate.month}/${trialEndDate.day}/${trialEndDate.year}';
    final yearlyMonthlyEquivalent = yearlyPackage != null
        ? (yearlyPackage.storeProduct.price / 12).toStringAsFixed(2)
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const SnaplookBackButton(),
        centerTitle: true,
        title: const OnboardingProgressIndicator(
          currentStep: 18,
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
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: spacing.l),
              const _HeroMark(),
              SizedBox(height: spacing.l),
              Center(
                child: Column(
                  children: [
                    const Text(
                      'Access all of Snaplook',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.7,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _isEligibleForTrial
                          ? 'Start your 3-day free trial and unlock unlimited matches.'
                          : 'Unlock unlimited matches, saves, and smart alerts.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: spacing.xl),
              const _FeatureItem(
                icon: Icons.search_rounded,
                iconColor: AppColors.tertiary,
                title: 'Unlimited visual searches',
                description: 'Instant matches from every photo you drop in.',
              ),
              SizedBox(height: spacing.l),
              const _FeatureItem(
                icon: Icons.favorite_rounded,
                iconColor: AppColors.secondary,
                title: 'Save & curate looks',
                description:
                    'Keep the styles you love in one place to revisit anytime.',
              ),
              SizedBox(height: spacing.l),
              const _FeatureItem(
                icon: Icons.bolt_rounded,
                iconColor: Colors.amber,
                title: 'AI-powered brand matches',
                description:
                    'See similar pieces across top retailers in seconds.',
              ),
              SizedBox(height: spacing.l),
              const _FeatureItem(
                icon: Icons.widgets_rounded,
                iconColor: Colors.indigo,
                title: 'Widgets & smart alerts',
                description:
                    'Lock-screen shortcuts and drop reminders for fast access.',
              ),
              SizedBox(height: spacing.xl),
              if (yearlyPackage != null && monthlyPackage != null)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 28,
                        offset: Offset(0, 18),
                      ),
                    ],
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.star_rounded,
                                    size: 16, color: AppColors.secondary),
                                SizedBox(width: 6),
                                Text(
                                  'Save 20%',
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: AppColors.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Text(
                            selectedPlan == RevenueCatPaywallPlanType.yearly
                                ? 'Best value'
                                : 'Choose a plan',
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _PlanOption(
                              plan: RevenueCatPaywallPlanType.yearly,
                              title: 'Yearly',
                              price: yearlyPackage.storeProduct.priceString,
                              cadence: yearlyMonthlyEquivalent != null
                                  ? '\$$yearlyMonthlyEquivalent/mo after trial'
                                  : 'Billed annually',
                              helper: _isEligibleForTrial
                                  ? '3-day free trial'
                                  : 'Best value',
                              isSelected: selectedPlan ==
                                  RevenueCatPaywallPlanType.yearly,
                              onTap: () => ref
                                  .read(selectedRevenueCatPlanProvider.notifier)
                                  .state = RevenueCatPaywallPlanType.yearly,
                              isPopular: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _PlanOption(
                              plan: RevenueCatPaywallPlanType.monthly,
                              title: 'Monthly',
                              price: monthlyPackage.storeProduct.priceString,
                              cadence: 'Billed monthly',
                              helper: 'Cancel anytime',
                              isSelected: selectedPlan ==
                                  RevenueCatPaywallPlanType.monthly,
                              onTap: () => ref
                                  .read(selectedRevenueCatPlanProvider.notifier)
                                  .state = RevenueCatPaywallPlanType.monthly,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: Text(
                          _isEligibleForTrial
                              ? 'Nothing due today'
                              : 'Starts immediately, cancel anytime',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _isEligibleForTrial
                                ? AppColors.secondary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isPurchasing ? null : _handleContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
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
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : Text(
                                  _offerings?.current == null
                                      ? 'Skip for Now'
                                      : _isEligibleForTrial
                                          ? 'Continue'
                                          : 'Subscribe now',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'PlusJakartaSans',
                                    letterSpacing: -0.2,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _offerings?.current == null
                            ? ''
                            : selectedPlan == RevenueCatPaywallPlanType.monthly
                                ? 'Billed ${monthlyPackage.storeProduct.priceString} today.'
                                : _isEligibleForTrial
                                    ? '3-day free trial, then ${yearlyPackage.storeProduct.priceString}/year starting $trialEndFormatted.'
                                    : 'Just ${yearlyPackage.storeProduct.priceString} per year'
                                        '${yearlyMonthlyEquivalent != null ? ' (\$$yearlyMonthlyEquivalent/mo)' : ''}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(height: spacing.l * 2),
            ],
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
  final String cadence;
  final String? helper;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isPopular;

  const _PlanOption({
    required this.plan,
    required this.title,
    required this.price,
    required this.cadence,
    this.helper,
    required this.isSelected,
    required this.onTap,
    this.isPopular = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color borderColor =
        isSelected ? AppColors.secondary : AppColors.outline;
    final Color backgroundColor =
        isSelected ? AppColors.secondary.withOpacity(0.06) : Colors.white;

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
              color: backgroundColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: borderColor,
                width: isSelected ? 1.6 : 1.1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.secondary.withOpacity(0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 8),
                      ),
                    ],
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
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          fontFamily: 'PlusJakartaSans',
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        price,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          fontFamily: 'PlusJakartaSans',
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cadence,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          fontFamily: 'PlusJakartaSans',
                        ),
                      ),
                      if (helper != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          helper!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? AppColors.secondary
                                : AppColors.textSecondary,
                            fontFamily: 'PlusJakartaSans',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? AppColors.secondary : Colors.white,
                    border: Border.all(
                      color:
                          isSelected ? AppColors.secondary : AppColors.outline,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : null,
                ),
              ],
            ),
          ),
          if (isPopular)
            Positioned(
              top: -10,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Best value',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary,
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

class _HeroMark extends StatelessWidget {
  const _HeroMark();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.secondary.withOpacity(0.16),
                  AppColors.secondaryLight.withOpacity(0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary.withOpacity(0.18),
                  blurRadius: 32,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
          ),
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 48,
              color: AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  const _FeatureItem({
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
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
