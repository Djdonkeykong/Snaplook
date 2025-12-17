import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../shared/widgets/snaplook_back_button.dart';
import '../widgets/progress_indicator.dart';
import '../../../auth/domain/providers/auth_provider.dart';
import '../../../../services/onboarding_state_service.dart';
import '../../../../services/revenuecat_service.dart';
import '../../../../services/subscription_sync_service.dart';
import 'account_creation_page.dart';
import 'welcome_free_analysis_page.dart';

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

  String _formatPriceFloor(double value) {
    final cents = (value * 100).floor();
    return (cents / 100).toStringAsFixed(2);
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

    final hasAccount = ref.read(authServiceProvider).currentUser != null;
    debugPrint(
        '[RevenueCatPaywall] Navigating after purchase: $didPurchase, hasAccount: $hasAccount');

    final nextPage =
        hasAccount ? const WelcomeFreeAnalysisPage() : const AccountCreationPage();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => nextPage),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedPlan = ref.watch(selectedRevenueCatPlanProvider);
    final selectedPlanValue = selectedPlan ?? RevenueCatPaywallPlanType.yearly;
    final spacing = context.spacing;
    final viewPadding = MediaQuery.of(context).padding;

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
    final double? yearlyMonthlyEquivalentValue =
        yearlyPackage != null ? yearlyPackage.storeProduct.price / 12 : null;
    final yearlyMonthlyEquivalent = yearlyMonthlyEquivalentValue != null
        ? _formatPriceFloor(yearlyMonthlyEquivalentValue)
        : null;
    final hasPlans = yearlyPackage != null && monthlyPackage != null;
    final bottomScrollPadding =
        (hasPlans ? 360.0 : spacing.l * 2) + viewPadding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const SnaplookBackButton(),
        centerTitle: true,
        title: const OnboardingProgressIndicator(
          currentStep: 14,
          totalSteps: 14,
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
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              spacing.l * 1.5,
              0,
              spacing.l * 1.5,
              bottomScrollPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: spacing.m),
                const _HeroMark(),
                SizedBox(height: spacing.l),
                Center(
                  child: Column(
                    children: [
                      Text(
                        _isEligibleForTrial
                            ? 'Start your 3-day FREE trial to continue'
                            : 'Access all of Snaplook',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.7,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: spacing.xl + spacing.s),
                if (_isEligibleForTrial && selectedPlan == RevenueCatPaywallPlanType.yearly)
                  _TrialTimeline(trialEndFormatted: trialEndFormatted)
                else ...[
                  _FeatureItem(
                    iconBgColor: AppColors.tertiary.withOpacity(0.12),
                    icon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.tertiary,
                      size: 16,
                    ),
                    title: 'Turn photos into matches',
                    description:
                        'Get instant matches from photos, screenshots, or social posts.',
                  ),
                  SizedBox(height: spacing.l),
                  _FeatureItem(
                    iconBgColor: const Color(0xFFf2003c).withOpacity(0.1),
                    icon: const Icon(
                      Icons.favorite_rounded,
                      color: Color(0xFFf2003c),
                      size: 16,
                    ),
                    title: 'Save the looks you love',
                    description:
                        'Keep styles in one place and come back to them anytime.',
                  ),
                  SizedBox(height: spacing.l),
                  _FeatureItem(
                    iconBgColor: const Color(0xFFFFF1E0),
                    icon: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: SvgPicture.asset(
                        'assets/icons/meteocons--lightning-bolt.svg',
                        width: 48,
                        height: 48,
                      ),
                    ),
                    title: 'Shop similar pieces instantly',
                    description:
                        'Discover similar items from trusted retailers in seconds.',
                  ),
                  SizedBox(height: spacing.l),
                  _FeatureItem(
                    iconBgColor: const Color(0xFFEFF2FF),
                    icon: SvgPicture.asset(
                      'assets/icons/lets-icons--bell-pin.svg',
                      width: 16,
                      height: 16,
                    ),
                    title: 'Never miss a match',
                    description:
                        "Receive alerts when we find similar pieces you'll like.",
                  ),
                  SizedBox(height: spacing.l * 2),
                ],
              ],
            ),
          ),
          if (hasPlans)
            Positioned(
              left: spacing.l,
              right: spacing.l,
              bottom: spacing.l + viewPadding.bottom,
              child: _PlanSelectionCard(
                yearlyPackage: yearlyPackage!,
                monthlyPackage: monthlyPackage!,
                yearlyMonthlyEquivalent: yearlyMonthlyEquivalent,
                yearlyMonthlyEquivalentValue: yearlyMonthlyEquivalentValue!,
                selectedPlan: selectedPlanValue,
                isEligibleForTrial: _isEligibleForTrial,
                isPurchasing: _isPurchasing,
                trialEndFormatted: trialEndFormatted,
                onSelectPlan: (plan) => ref
                    .read(selectedRevenueCatPlanProvider.notifier)
                    .state = plan,
                onContinue: _handleContinue,
              ),
            ),
        ],
      ),
    );
  }
}

class _PlanOption extends StatelessWidget {
  final RevenueCatPaywallPlanType plan;
  final String title;
  final String price;
  final String? cadence;
  final String? helper;
  final bool isSelected;
  final VoidCallback onTap;
  final String? badgeLabel;

  const _PlanOption({
    required this.plan,
    required this.title,
    required this.price,
    this.cadence,
    this.helper,
    required this.isSelected,
    required this.onTap,
    this.badgeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final Color borderColor =
        isSelected ? AppColors.secondary : AppColors.outline;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding:
                EdgeInsets.fromLTRB(12, badgeLabel != null ? 22 : 12, 12, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: borderColor,
                width: 2.0,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          fontFamily: 'PlusJakartaSans',
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? AppColors.secondary : Colors.white,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.secondary
                              : AppColors.outline,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 18,
                            )
                          : null,
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    if (cadence != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        cadence!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          fontFamily: 'PlusJakartaSans',
                        ),
                      ),
                    ],
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
              ],
            ),
          ),
          if (badgeLabel != null)
            Positioned(
              top: -12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badgeLabel!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
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

class _HeroMark extends StatelessWidget {
  const _HeroMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _FeatureItem extends StatelessWidget {
  final Widget icon;
  final Color iconBgColor;
  final String title;
  final String description;

  const _FeatureItem({
    required this.icon,
    required this.iconBgColor,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: iconBgColor,
            shape: BoxShape.circle,
          ),
          child: icon,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanSelectionCard extends StatelessWidget {
  final Package yearlyPackage;
  final Package monthlyPackage;
  final String? yearlyMonthlyEquivalent;
  final double yearlyMonthlyEquivalentValue;
  final RevenueCatPaywallPlanType selectedPlan;
  final bool isEligibleForTrial;
  final bool isPurchasing;
  final String trialEndFormatted;
  final ValueChanged<RevenueCatPaywallPlanType> onSelectPlan;
  final VoidCallback onContinue;

  const _PlanSelectionCard({
    required this.yearlyPackage,
    required this.monthlyPackage,
    required this.yearlyMonthlyEquivalent,
    required this.yearlyMonthlyEquivalentValue,
    required this.selectedPlan,
    required this.isEligibleForTrial,
    required this.isPurchasing,
    required this.trialEndFormatted,
    required this.onSelectPlan,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final double monthlyPriceValue = monthlyPackage.storeProduct.price;
    final int? yearlySavingsPercent = monthlyPriceValue > 0
        ? ((1 - (yearlyMonthlyEquivalentValue / monthlyPriceValue)) * 100)
            .round()
            .clamp(0, 100)
        : null;
    final String? badgeLabel = isEligibleForTrial
        ? '3-day FREE'
        : (yearlySavingsPercent != null ? 'Save $yearlySavingsPercent%' : null);
    final String footnote = selectedPlan == RevenueCatPaywallPlanType.monthly
        ? 'Billed ${monthlyPackage.storeProduct.priceString} today.'
        : isEligibleForTrial
            ? '3-day free trial, then ${yearlyPackage.storeProduct.priceString} per year'
            : 'Just ${yearlyPackage.storeProduct.priceString} per year'
                '${yearlyMonthlyEquivalent != null ? ' (\$$yearlyMonthlyEquivalent/mo)' : ''}';
    const double planOptionHeight = 120;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
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
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: planOptionHeight,
                  child: _PlanOption(
                    plan: RevenueCatPaywallPlanType.monthly,
                    title: 'Monthly',
                    price: monthlyPackage.storeProduct.priceString,
                    isSelected:
                        selectedPlan == RevenueCatPaywallPlanType.monthly,
                    onTap: () =>
                        onSelectPlan(RevenueCatPaywallPlanType.monthly),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: planOptionHeight,
                  child: _PlanOption(
                    plan: RevenueCatPaywallPlanType.yearly,
                    title: 'Yearly',
                    price: yearlyPackage.storeProduct.priceString,
                    cadence: yearlyMonthlyEquivalent != null
                        ? '\$$yearlyMonthlyEquivalent/mo'
                        : 'Billed annually',
                    isSelected:
                        selectedPlan == RevenueCatPaywallPlanType.yearly,
                    onTap: () => onSelectPlan(RevenueCatPaywallPlanType.yearly),
                    badgeLabel: badgeLabel,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isEligibleForTrial && selectedPlan == RevenueCatPaywallPlanType.yearly) ...[
                  const Icon(
                    Icons.check_rounded,
                    color: AppColors.textPrimary,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  isEligibleForTrial && selectedPlan == RevenueCatPaywallPlanType.yearly
                      ? 'No payment due now'
                      : 'Starts immediately, cancel anytime',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: isPurchasing ? null : onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: isPurchasing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      isEligibleForTrial && selectedPlan == RevenueCatPaywallPlanType.yearly
                          ? 'Continue for free'
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
            footnote,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrialTimeline extends StatelessWidget {
  final String trialEndFormatted;

  const _TrialTimeline({required this.trialEndFormatted});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          _TimelineItem(
            iconAsset: 'assets/icons/uil--unlock-alt.svg',
            iconColor: Colors.white,
            iconBgColor: const Color(0xFFf2003c),
            iconSize: 20,
            iconVerticalOffset: -1,
            title: 'Today',
            description:
                "Unlock all the app's features like AI fashion analysis and more.",
            isLast: false,
          ),
          _TimelineItem(
            iconAsset: 'assets/icons/mdi--bell-ring-outline.svg',
            iconColor: Colors.white,
            iconBgColor: const Color(0xFFf2003c),
            iconSize: 18,
            title: 'In 2 Days',
            description: "We'll send you a reminder that your trial is ending soon.",
            isLast: false,
          ),
          _TimelineItem(
            iconAsset: 'assets/icons/mdi--crown-outline.svg',
            iconColor: Colors.white,
            iconBgColor: AppColors.textPrimary,
            iconSize: 21,
            iconVerticalOffset: -1,
            title: 'In 3 Days',
            description:
                "You'll be charged on $trialEndFormatted unless you cancel anytime before.",
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final String iconAsset;
  final Color iconColor;
  final Color iconBgColor;
  final double iconSize;
  final double iconVerticalOffset;
  final bool flipHorizontally;
  final String title;
  final String description;
  final bool isLast;

  const _TimelineItem({
    required this.iconAsset,
    required this.iconColor,
    required this.iconBgColor,
    this.iconSize = 18,
    this.iconVerticalOffset = 0,
    this.flipHorizontally = false,
    required this.title,
    required this.description,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Transform.translate(
                    offset: Offset(0, iconVerticalOffset),
                    child: Transform.flip(
                      flipX: flipHorizontally,
                      child: SvgPicture.asset(
                        iconAsset,
                        width: iconSize,
                        height: iconSize,
                        color: iconColor,
                      ),
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 4,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD1DC),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
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
