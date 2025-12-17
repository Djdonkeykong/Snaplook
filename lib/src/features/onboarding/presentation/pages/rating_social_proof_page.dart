import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:lottie/lottie.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../shared/widgets/snaplook_back_button.dart';
import '../widgets/onboarding_bottom_bar.dart';
import '../widgets/progress_indicator.dart';
import 'notification_permission_page.dart';
import '../../../../shared/services/review_prompt_logs_service.dart';

class RatingSocialProofPage extends StatelessWidget {
  const RatingSocialProofPage({
    super.key,
    this.continueToTrialFlow = false,
  });

  final bool continueToTrialFlow;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final radius = context.radius;
    final currentStep = 12;
    final totalSteps = 14;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const SnaplookBackButton(),
        centerTitle: true,
        title: OnboardingProgressIndicator(
          currentStep: currentStep,
          totalSteps: totalSteps,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.l),
          child: Column(
            children: [
              SizedBox(height: spacing.l),
              const Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How does this feel so far?',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontFamily: 'PlusJakartaSans',
                        letterSpacing: -1.0,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: _EncouragementCard(radius: radius.large),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: OnboardingBottomBar(
        primaryButton: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () async {
              HapticFeedback.mediumImpact();

              // Request in-app review
              final inAppReview = InAppReview.instance;
              final timestamp = DateTime.now().toIso8601String();
              try {
                final available = await inAppReview.isAvailable();
                await ReviewPromptLogsService.addLog(
                  '[$timestamp] requestReview() available=$available (RatingSocialProofPage)',
                );
                if (available) {
                  await inAppReview.requestReview();
                  await ReviewPromptLogsService.addLog(
                    '[$timestamp] requestReview() invoked successfully',
                  );
                } else {
                  await ReviewPromptLogsService.addLog(
                    '[$timestamp] requestReview() skipped (not available)',
                  );
                }
              } catch (e) {
                await ReviewPromptLogsService.addLog(
                  '[$timestamp] requestReview() error: $e',
                );
              }

              if (context.mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => NotificationPermissionPage(
                      continueToTrialFlow: continueToTrialFlow,
                    ),
                  ),
                );
              }
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
              'Continue',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'PlusJakartaSans',
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EncouragementCard extends StatelessWidget {
  const _EncouragementCard({required this.radius});

  final double radius;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: EdgeInsets.all(spacing.l),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 320,
            width: 320,
            child: Transform.scale(
              scale: 1.7, // Increased zoom to fill more of the box
              child: Lottie.asset(
                'assets/animations/twitter.json',
                repeat: true,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const Text(
            "Thanks for giving Snaplook a try!",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.black,
              fontFamily: 'PlusJakartaSans',
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "If you're enjoying the process, we'd love a quick rating. It really helps us.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}
