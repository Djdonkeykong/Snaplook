import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../services/analytics_service.dart';
import '../../../../shared/widgets/snaplook_back_button.dart';
import '../widgets/onboarding_bottom_bar.dart';
import '../widgets/progress_indicator.dart';
import 'rating_social_proof_page.dart';

class ProfileReadyPage extends StatefulWidget {
  const ProfileReadyPage({
    super.key,
    this.continueToTrialFlow = true,
  });

  final bool continueToTrialFlow;

  @override
  State<ProfileReadyPage> createState() => _ProfileReadyPageState();
}

class _ProfileReadyPageState extends State<ProfileReadyPage> {
  @override
  void initState() {
    super.initState();
    AnalyticsService().trackOnboardingScreen('onboarding_profile_ready');
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: SnaplookBackButton(
          enableHaptics: true,
          backgroundColor: colorScheme.surface,
          iconColor: colorScheme.onSurface,
        ),
        centerTitle: true,
        title: const OnboardingProgressIndicator(
          currentStep: 11,
          totalSteps: 14,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: spacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: spacing.l),
              Text(
                'Your style, tuned to you',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                  fontFamily: 'PlusJakartaSans',
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),
              SizedBox(height: spacing.m),
              Text(
                'Snaplook has aligned your preferences into a clear style direction',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurfaceVariant,
                  fontFamily: 'PlusJakartaSans',
                  height: 1.5,
                ),
              ),
              SizedBox(height: spacing.l),
              Align(
                alignment: Alignment.center,
                child: Lottie.asset(
                  'assets/animations/arrow2.json',
                  height: 440,
                  repeat: false,
                ),
              ),
              SizedBox(height: spacing.xl),
            ],
          ),
        ),
      ),
      bottomNavigationBar: OnboardingBottomBar(
        primaryButton: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const RatingSocialProofPage(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              splashFactory: InkSparkle.splashFactory,
            ),
            child: const Text(
              "Let's get started",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                fontFamily: 'PlusJakartaSans',
                letterSpacing: -0.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
