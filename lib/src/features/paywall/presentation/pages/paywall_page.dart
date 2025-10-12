import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../onboarding/presentation/pages/account_creation_page.dart';
import '../../../../../shared/navigation/main_navigation.dart';

enum SubscriptionPlan { monthly, yearly }

final selectedPlanProvider = StateProvider<SubscriptionPlan>((ref) => SubscriptionPlan.yearly);

class PaywallPage extends ConsumerWidget {
  const PaywallPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPlan = ref.watch(selectedPlanProvider);
    final spacing = context.spacing;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_back,
              color: Colors.black,
              size: 20,
            ),
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: spacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: spacing.m),

            // Main heading
            Text(
              selectedPlan == SubscriptionPlan.monthly
                ? 'Unlock Snaplook to discover\nyour perfect style.'
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

            SizedBox(height: spacing.xl),

            // Dynamic content based on selected plan
            selectedPlan == SubscriptionPlan.monthly
              ? Column(
                  children: [
                    _FeatureItem(
                      icon: Icons.check,
                      title: 'AI fashion analysis',
                      subtitle: 'Discover similar styles with just a photo',
                    ),
                    SizedBox(height: spacing.l),
                    _FeatureItem(
                      icon: Icons.check,
                      title: 'Unlimited style matching',
                      subtitle: 'Find your perfect look from any image\nyou share',
                    ),
                    SizedBox(height: spacing.l),
                    _FeatureItem(
                      icon: Icons.check,
                      title: 'Personalized recommendations',
                      subtitle: 'Get curated fashion suggestions\nbased on your preferences',
                    ),
                  ],
                )
              : Column(
                  children: [
                    _TimelineItem(
                      icon: Icons.lock_open,
                      iconColor: AppColors.secondary,
                      title: 'Today',
                      subtitle: 'Unlock all the app\'s features like AI\nfashion analysis and more.',
                      isFirst: true,
                    ),
                    _TimelineItem(
                      icon: Icons.notifications_outlined,
                      iconColor: AppColors.secondary,
                      title: 'In 2 Days - Reminder',
                      subtitle: 'We\'ll send you a reminder that your trial\nis ending soon.',
                    ),
                    _TimelineItem(
                      icon: Icons.account_balance_wallet_outlined,
                      iconColor: AppColors.secondary,
                      title: 'In 3 Days - Billing Starts',
                      subtitle: 'You\'ll be charged on 30 Sep 2025 unless\nyou cancel anytime before.',
                      isLast: true,
                    ),
                  ],
                ),

            // Add spacer to push everything below to a fixed position
            const Spacer(),

            // Fixed bottom section with specific heights to prevent movement
            SizedBox(
              height: 120, // Fixed height container for subscription plans
              child: Column(
                children: [
                  // Subscription plans
                  Row(
                    children: [
                      // Monthly plan
                      Expanded(
                        child: _PlanOption(
                          plan: SubscriptionPlan.monthly,
                          title: 'Monthly',
                          price: 'NOK 129,00/mo',
                          subtitle: '', // Empty subtitle to match yearly plan height
                          isSelected: selectedPlan == SubscriptionPlan.monthly,
                          onTap: () => ref.read(selectedPlanProvider.notifier).state = SubscriptionPlan.monthly,
                        ),
                      ),
                      SizedBox(width: spacing.m),
                      // Yearly plan
                      Expanded(
                        child: _PlanOption(
                          plan: SubscriptionPlan.yearly,
                          title: 'Yearly',
                          price: 'NOK 33,25/mo',
                          subtitle: '3 DAYS FREE',
                          isSelected: selectedPlan == SubscriptionPlan.yearly,
                          onTap: () => ref.read(selectedPlanProvider.notifier).state = SubscriptionPlan.yearly,
                          isPopular: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: spacing.l),

            // No Payment Due Now
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check,
                  color: Colors.green,
                  size: 16,
                ),
                const SizedBox(width: 8),
                const Text(
                  'No Payment Due Now',
                  style: TextStyle(
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

            // Start trial button
            Container(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  // Start trial and navigate to account creation
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AccountCreationPage(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFf2003c),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: const Text(
                  'Start My 3-Day Free Trial',
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

            // Bottom pricing text
            const Text(
              '3 days free, then NOK 399,00 per year (NOK 33,25/mo)',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.2,
              ),
            ),

            SizedBox(height: spacing.xxl),
          ],
        ),
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
        Icon(
          icon,
          color: Colors.green,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
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
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isFirst;
  final bool isLast;

  const _TimelineItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        children: [
          // Timeline line and icon
          Column(
            children: [
              // Top line (hidden for first item)
              if (!isFirst)
                Container(
                  width: 2,
                  height: 20,
                  color: iconColor,
                ),
              // Icon container
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              // Bottom line (hidden for last item)
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: iconColor,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
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
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.3,
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
  final SubscriptionPlan plan;
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
      onTap: onTap,
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? Colors.black : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.black : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: isSelected ? Colors.white : Colors.black,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  price,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: isSelected ? Colors.white : Colors.black,
                    letterSpacing: -0.3,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      color: isSelected ? Colors.white.withOpacity(0.8) : Colors.black,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // 3 Days Free badge
          if (isPopular)
            Positioned(
              top: -6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '3 DAYS FREE',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.black : Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
