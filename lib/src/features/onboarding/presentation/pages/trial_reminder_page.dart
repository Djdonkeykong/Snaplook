import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../paywall/presentation/pages/paywall_page.dart';

class TrialReminderPage extends ConsumerWidget {
  const TrialReminderPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            SizedBox(height: spacing.l),

            // Main heading
            const Text(
              'We\'ll send you a reminder before your free trial ends',
              textAlign: TextAlign.start,
              style: TextStyle(
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

            // Bell icon with notification badge
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.notifications,
                      size: 60,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFFf2003c),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          '1',
                          style: TextStyle(
                            fontSize: 20,
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
            ),

            const Spacer(flex: 2),

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
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'PlusJakartaSans',
                    color: Colors.black,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),

            SizedBox(height: spacing.m),

            // Continue for FREE button
            Container(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const PaywallPage(),
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
                  'Continue for FREE',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'PlusJakartaSans',
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),

            SizedBox(height: spacing.m),

            // Pricing text
            const Align(
              alignment: Alignment.center,
              child: Text(
                'Just \$59.99 per year (\$4.99/mo)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.2,
                ),
              ),
            ),

            SizedBox(height: spacing.xxl),
          ],
        ),
      ),
    );
  }
}
