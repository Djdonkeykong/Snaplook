import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../onboarding/presentation/pages/account_creation_page.dart';
import '../../providers/credit_provider.dart';

enum PaywallPlanType { monthly, yearly }

final selectedPlanProvider = StateProvider<PaywallPlanType>(
  (ref) => PaywallPlanType.yearly,
);
final offeringsProvider = FutureProvider<Offerings?>((ref) async {
  final purchaseController = ref.read(purchaseControllerProvider);
  return await purchaseController.getOfferings();
});
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
    final spacing = context.spacing;
    final offerings = ref.watch(offeringsProvider);
    final isPurchasing = ref.watch(isPurchasingProvider);
    final maxSheetHeight =
        MediaQuery.of(context).size.height * maxHeightFactor;
    final trialEndDate = DateTime.now().add(const Duration(days: 3));
    final trialEndFormatted = DateFormat('d MMM y').format(trialEndDate);
    final billingSubtitle =
        'You\'ll be charged on $trialEndFormatted unless\nyou cancel anytime before.';

    return Container(
      constraints: isFullScreen ? null : BoxConstraints(maxHeight: maxSheetHeight),
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
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(minHeight: 36, minWidth: 36),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.black,
                        size: 20,
                      ),
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
                    SizedBox(height: spacing.m),
                    Text(
                      selectedPlan == PaywallPlanType.monthly
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
                      SizedBox(height: spacing.xxl),
                      if (selectedPlan == PaywallPlanType.monthly)
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _FeatureItem(
                              icon: Icons.check,
                              title: 'AI-powered matches',
                              subtitle:
                                  'Tap into a massive catalog of brands — every image you upload is analyzed to surface the closest lookalikes across thousands of retailers.',
                            ),
                            SizedBox(height: spacing.xl),
                            const _FeatureItem(
                              icon: Icons.bookmark_added,
                              title: 'Save favorite finds',
                              subtitle:
                                  'Bookmark the products you love so you can jump back in when it’s time to buy.',
                            ),
                            SizedBox(height: spacing.xl),
                            _FeatureItem(
                              icon: Icons.bolt,
                              title: '50 credits included',
                              subtitle:
                                  'Every subscription unlocks 50 credits (up to 50 searches) so you can keep scanning and saving outfits all month.',
                            ),
                            SizedBox(height: spacing.xl),
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
                    Row(
                      children: [
                        Expanded(
                          child: _PlanOption(
                            plan: PaywallPlanType.monthly,
                            title: 'Monthly',
                            price: '\$7.99/mo',
                            subtitle: '',
                            isSelected: selectedPlan == PaywallPlanType.monthly,
                            onTap: () => ref
                                .read(selectedPlanProvider.notifier)
                                .state = PaywallPlanType.monthly,
                          ),
                        ),
                        SizedBox(width: spacing.m),
                        Expanded(
                          child: _PlanOption(
                            plan: PaywallPlanType.yearly,
                            title: 'Yearly',
                            price: '\$4.99/mo',
                            subtitle: null,
                            isSelected: selectedPlan == PaywallPlanType.yearly,
                            onTap: () => ref
                                .read(selectedPlanProvider.notifier)
                                .state = PaywallPlanType.yearly,
                            isPopular: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check, color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          selectedPlan == PaywallPlanType.yearly
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
                    SizedBox(height: spacing.m),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: isPurchasing
                            ? null
                            : () => _handlePurchase(
                                context,
                                ref,
                                offerings.value,
                              ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFf2003c),
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
                            : Text(
                                selectedPlan == PaywallPlanType.yearly
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
                    SizedBox(height: spacing.m),
                    Center(
                      child: Text(
                        selectedPlan == PaywallPlanType.yearly
                            ? '3 days free, then \$59.99 per year (\$4.99/mo)'
                            : 'Just \$7.99 per month',
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
    Offerings? offerings,
  ) async {
    try {
      HapticFeedback.mediumImpact();

      if (offerings == null || offerings.current == null) {
        _showErrorDialog(
          context,
          'No subscription plans available. Please try again later.',
        );
        return;
      }

      final selectedPlan = ref.read(selectedPlanProvider);
      final purchaseController = ref.read(purchaseControllerProvider);

      Package? targetPackage;
      final currentOffering = offerings.current!;

      if (selectedPlan == PaywallPlanType.yearly) {
        targetPackage =
            currentOffering.annual ??
            currentOffering.availablePackages.firstWhere(
              (p) => p.packageType == PackageType.annual,
              orElse: () => currentOffering.availablePackages.first,
            );
      } else {
        targetPackage =
            currentOffering.monthly ??
            currentOffering.availablePackages.firstWhere(
              (p) => p.packageType == PackageType.monthly,
              orElse: () => currentOffering.availablePackages.first,
            );
      }

      ref.read(isPurchasingProvider.notifier).state = true;

      final success = await purchaseController.purchasePackage(targetPackage);

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

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const AccountCreationPage(),
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

      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        if (context.mounted) {
          _showErrorDialog(
            context,
            e.message ?? 'Purchase failed. Please try again.',
          );
        }
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

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const AccountCreationPage(),
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
        const Icon(Icons.check, color: Color(0xFF23B6A8), size: 28),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                  letterSpacing: -0.5,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14,
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
    const double circleDiameter = 46;
    const double lineWidth = 6;

    final circle = Container(
      width: circleDiameter,
      height: circleDiameter,
      decoration: BoxDecoration(
        color: circleColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: circleColor.withOpacity(0.15),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(icon, size: 24, color: Colors.white),
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

    const double connectorGap = 36;
    final double topSegmentHeight = isFirst ? 0 : connectorGap;
    final double bottomSegmentHeight = isLast ? 92 : connectorGap;

    final lineSegments = SizedBox(
      width: 60,
      height: topSegmentHeight + circleDiameter + bottomSegmentHeight,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned.fill(
            child: Column(
              children: [
                if (!isFirst)
                  Container(width: lineWidth, height: topSegmentHeight, color: lineColor),
                Container(width: lineWidth, height: circleDiameter, color: lineColor),
                if (!isLast)
                  Container(width: lineWidth, height: bottomSegmentHeight, color: lineColor)
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
            left: (60 - circleDiameter) / 2,
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
          const SizedBox(width: 16),
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
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14,
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
  final PaywallPlanType plan;
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
