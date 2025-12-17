import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../onboarding/presentation/pages/account_creation_page.dart';
import '../../../onboarding/presentation/pages/welcome_free_analysis_page.dart';
import '../../../auth/domain/providers/auth_provider.dart';
import '../../providers/credit_provider.dart';
import '../../../../shared/widgets/snaplook_circular_icon_button.dart';

enum PaywallPlanType { monthly, yearly }

final selectedPlanProvider = StateProvider<PaywallPlanType>(
  (ref) => PaywallPlanType.yearly,
);
final isPurchasingProvider = StateProvider<bool>((ref) => false);

class PaywallPage extends ConsumerWidget {
  final double maxHeightFactor;
  final bool isFullScreen;

  const PaywallPage({
    super.key,
    this.maxHeightFactor = 1.0,
    this.isFullScreen = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPlan = ref.watch(selectedPlanProvider);
    final isYearlySelected = selectedPlan == PaywallPlanType.yearly;
    final spacing = context.spacing;
    final isPurchasing = ref.watch(isPurchasingProvider);
    final maxSheetHeight = MediaQuery.of(context).size.height * maxHeightFactor;
    final trialEndDate = DateTime.now().add(const Duration(days: 3));
    final trialEndFormatted = DateFormat('MMM d').format(trialEndDate);

    return Container(
      constraints:
          isFullScreen ? null : BoxConstraints(maxHeight: maxSheetHeight),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isFullScreen
            ? BorderRadius.zero
            : const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: isFullScreen ? null : maxSheetHeight,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              if (!isFullScreen)
                Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SnaplookCircularIconButton(
                      icon: Icons.close,
                      iconSize: 20,
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close',
                      semanticLabel: 'Close',
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: isPurchasing
                          ? null
                          : () => _handleRestore(context, ref),
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
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
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
                                  fontSize: 34,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.9,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                isYearlySelected
                                    ? 'Start your 3-day free trial and unlock unlimited matches.'
                                    : 'Unlock unlimited matches, saves, and smart alerts.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 16,
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
                          title: 'Turn photos into matches',
                          subtitle:
                              'Get instant matches from photos, screenshots, or social posts.',
                        ),
                        SizedBox(height: spacing.l),
                        const _FeatureItem(
                          icon: Icons.favorite_rounded,
                          iconColor: AppColors.secondary,
                          title: 'Save the looks you love',
                          subtitle:
                              'Keep styles in one place and come back to them anytime.',
                        ),
                        SizedBox(height: spacing.l),
                        const _FeatureItem(
                          icon: Icons.bolt_rounded,
                          iconColor: Colors.amber,
                          title: 'Shop similar pieces instantly',
                          subtitle:
                              'Discover similar items from trusted retailers in seconds.',
                        ),
                        SizedBox(height: spacing.l),
                        const _FeatureItem(
                          icon: Icons.widgets_rounded,
                          iconColor: Colors.indigo,
                          title: 'Never miss a match',
                          subtitle:
                              'Receive alerts when we find similar pieces you’ll like.',
                        ),
                        SizedBox(height: spacing.xl),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: spacing.l),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
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
                                isYearlySelected
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
                                  title: 'Yearly',
                                  price: '\$59.99',
                                  cadence: '\$4.99/mo after trial',
                                  helper: '3-day free trial',
                                  isSelected: isYearlySelected,
                                  onTap: () => ref
                                      .read(selectedPlanProvider.notifier)
                                      .state = PaywallPlanType.yearly,
                                  isPopular: true,
                                ),
                              ),
                              SizedBox(width: spacing.m),
                              Expanded(
                                child: _PlanOption(
                                  title: 'Monthly',
                                  price: '\$7.99',
                                  cadence: 'Billed monthly',
                                  helper: 'Cancel anytime',
                                  isSelected:
                                      selectedPlan == PaywallPlanType.monthly,
                                  onTap: () => ref
                                      .read(selectedPlanProvider.notifier)
                                      .state = PaywallPlanType.monthly,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Center(
                            child: Text(
                              isYearlySelected
                                  ? 'Nothing due today'
                                  : 'Starts immediately, cancel anytime',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isYearlySelected
                                    ? AppColors.secondary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: spacing.l),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: isPurchasing
                            ? null
                            : () => _handlePurchase(
                                  context,
                                  ref,
                                ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          disabledBackgroundColor: Colors.grey.shade300,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: isPurchasing
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Continue',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.2,
                                ),
                              ),
                      ),
                    ),
                    SizedBox(height: spacing.m),
                    Center(
                      child: Text(
                        isYearlySelected
                            ? '3-day free trial. Then \$59.99/year starting $trialEndFormatted.'
                            : 'Billed \$7.99 today. Cancel anytime.',
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
                    SizedBox(height: spacing.m),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handlePurchase(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      HapticFeedback.mediumImpact();

      final selectedPlan = ref.read(selectedPlanProvider);
      final purchaseController = ref.read(purchaseControllerProvider);

      ref.read(isPurchasingProvider.notifier).state = true;

      final success = await purchaseController.showPaywall(
        // Use a single Superwall placement for both monthly/yearly options.
        placement: 'onboarding_paywall',
      );

      ref.read(isPurchasingProvider.notifier).state = false;

      if (success) {
        HapticFeedback.mediumImpact();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Subscription activated! Enjoy unlimited access.',
                style: TextStyle(fontFamily: 'PlusJakartaSans'),
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );

          final authService = ref.read(authServiceProvider);
          final hasAccount = authService.currentUser != null;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => hasAccount
                  ? const WelcomeFreeAnalysisPage()
                  : const AccountCreationPage(),
            ),
          );
        }
      } else {
        if (context.mounted) {
          _showErrorDialog(
            context,
            'Purchase was not completed. Please try again.',
          );
        }
      }
    } on PlatformException catch (e) {
      ref.read(isPurchasingProvider.notifier).state = false;

      if (context.mounted) {
        _showErrorDialog(
          context,
          e.message ?? 'Purchase failed. Please try again.',
        );
      }
    } catch (e) {
      ref.read(isPurchasingProvider.notifier).state = false;

      if (context.mounted) {
        _showErrorDialog(context, 'An error occurred. Please try again.');
      }
    }
  }

  Future<void> _handleRestore(BuildContext context, WidgetRef ref) async {
    try {
      HapticFeedback.mediumImpact();

      ref.read(isPurchasingProvider.notifier).state = true;

      final purchaseController = ref.read(purchaseControllerProvider);
      final success = await purchaseController.restorePurchases();

      ref.read(isPurchasingProvider.notifier).state = false;

      if (success) {
        HapticFeedback.mediumImpact();

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

          final authService = ref.read(authServiceProvider);
          final hasAccount = authService.currentUser != null;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => hasAccount
                  ? const WelcomeFreeAnalysisPage()
                  : const AccountCreationPage(),
            ),
          );
        }
      } else {
        if (context.mounted) {
          _showErrorDialog(context, 'No purchases found to restore.');
        }
      }
    } catch (e) {
      ref.read(isPurchasingProvider.notifier).state = false;

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
  final String subtitle;

  const _FeatureItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
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
                subtitle,
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

class _PlanOption extends StatelessWidget {
  final String title;
  final String price;
  final String cadence;
  final String? helper;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isPopular;

  const _PlanOption({
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
      onTap: onTap,
      child: AnimatedContainer(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isPopular)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Best value',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.secondary,
                  ),
                ),
              ),
            if (isPopular) const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const Spacer(),
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
                      ? const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: Colors.white,
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              price,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              cadence,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            if (helper != null) ...[
              const SizedBox(height: 6),
              Text(
                helper!,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? AppColors.secondary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
