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

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    try {
      final offerings = await RevenueCatService().getOfferings();
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
      }
    }
  }

  Future<void> _handleContinue() async {
    if (_isPurchasing) return;

    final selectedPlan = ref.read(selectedRevenueCatPlanProvider);
    if (selectedPlan == null || _offerings?.current == null) return;

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
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: spacing.l),

              // Title
              const Text(
                'Try Snaplook\nfor free',
                style: TextStyle(
                  fontSize: 34,
                  fontFamily: 'PlusJakartaSans',
                  letterSpacing: -1.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  height: 1.3,
                ),
              ),

              SizedBox(height: spacing.m),

              // Subtitle
              const Text(
                'Unlock unlimited fashion searches and AI-powered outfit recommendations.',
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
              ),

              SizedBox(height: spacing.xl),

              // Plan selection
              if (yearlyPackage != null && monthlyPackage != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: _PlanOption(
                        plan: RevenueCatPaywallPlanType.monthly,
                        title: 'Monthly',
                        price: '\$${monthlyPackage.storeProduct.priceString}/mo',
                        subtitle: '',
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
                        price: yearlyPackage.storeProduct.introductoryPrice != null
                            ? 'Free Trial'
                            : '\$${(yearlyPackage.storeProduct.price / 12).toStringAsFixed(2)}/mo',
                        subtitle: yearlyPackage.storeProduct.introductoryPrice != null
                            ? '3 days, then \$${yearlyPackage.storeProduct.priceString}/year'
                            : null,
                        isSelected: selectedPlan == RevenueCatPaywallPlanType.yearly,
                        onTap: () => ref.read(selectedRevenueCatPlanProvider.notifier).state =
                            RevenueCatPaywallPlanType.yearly,
                        isPopular: true,
                      ),
                    ),
                  ],
                ),
              ],

              SizedBox(height: spacing.xl),

              // Features
              const _FeatureItem(
                icon: Icons.check_circle,
                text: '50 credits per month for fashion searches',
              ),
              SizedBox(height: spacing.m),
              const _FeatureItem(
                icon: Icons.check_circle,
                text: 'AI-powered style recommendations',
              ),
              SizedBox(height: spacing.m),
              const _FeatureItem(
                icon: Icons.check_circle,
                text: 'Unlimited wardrobe organization',
              ),
              SizedBox(height: spacing.m),
              const _FeatureItem(
                icon: Icons.check_circle,
                text: 'Priority customer support',
              ),

              SizedBox(height: spacing.xxl),
            ],
          ),
        ),
      ),
      bottomNavigationBar: OnboardingBottomBar(
        primaryButton: SizedBox(
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
                : const Text(
                    'Start Free Trial',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'PlusJakartaSans',
                      letterSpacing: -0.2,
                    ),
                  ),
          ),
        ),
        secondaryButton: Align(
          alignment: Alignment.center,
          child: Text(
            selectedPlan == RevenueCatPaywallPlanType.monthly
                ? 'Only ${monthlyPackage?.storeProduct.priceString}/month'
                : yearlyPackage?.storeProduct.introductoryPrice != null
                    ? '3 days free, then ${yearlyPackage?.storeProduct.priceString}/year'
                    : 'Billed annually',
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
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isPopular;

  const _PlanOption({
    required this.plan,
    required this.title,
    required this.price,
    this.subtitle,
    required this.isSelected,
    required this.onTap,
    this.isPopular = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFf2003c) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFf2003c) : Colors.grey.shade200,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isPopular && !isSelected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFf2003c),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'POPULAR',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
              ),
            if (isPopular) const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.black,
                fontFamily: 'PlusJakartaSans',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              price,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF6B7280),
                fontFamily: 'PlusJakartaSans',
              ),
            ),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? Colors.white.withOpacity(0.9) : const Color(0xFF9CA3AF),
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureItem({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: const Color(0xFFf2003c),
          size: 24,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              fontFamily: 'PlusJakartaSans',
              fontWeight: FontWeight.w500,
              color: Colors.black,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
