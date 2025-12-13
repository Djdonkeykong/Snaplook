import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../shared/widgets/snaplook_back_button.dart';
import '../widgets/progress_indicator.dart';
import '../widgets/onboarding_bottom_bar.dart';
import 'revenuecat_paywall_page.dart';
import '../../../../services/revenuecat_service.dart';

class TrialReminderPage extends ConsumerStatefulWidget {
  const TrialReminderPage({super.key});

  @override
  ConsumerState<TrialReminderPage> createState() => _TrialReminderPageState();
}

class _TrialReminderPageState extends ConsumerState<TrialReminderPage> {
  bool _isEligibleForTrial = true;
  bool _isCheckingEligibility = true;

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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const SnaplookBackButton(),
        centerTitle: true,
        title: const OnboardingProgressIndicator(
          currentStep: 8,
          totalSteps: 10,
        ),
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
                  ? 'We\'ll send you a reminder before your free trial ends.'
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
                onPressed: () {
                  HapticFeedback.mediumImpact();

                  // Navigate to RevenueCat paywall
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const RevenueCatPaywallPage(),
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
                child: Text(
                  _isEligibleForTrial ? 'Continue for FREE' : 'See Plans',
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
            _isEligibleForTrial
                ? 'Just \$41.99 per year (\$3.49/mo)'
                : 'Choose your perfect plan',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
              fontFamily: 'PlusJakartaSans',
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
