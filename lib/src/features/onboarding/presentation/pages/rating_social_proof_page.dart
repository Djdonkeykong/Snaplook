import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:lottie/lottie.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../services/analytics_service.dart';
import '../../../../shared/widgets/snaplook_back_button.dart';
import '../widgets/onboarding_bottom_bar.dart';
import '../widgets/progress_indicator.dart';
import 'notification_permission_page.dart';
import '../../../../shared/services/review_prompt_logs_service.dart';

class RatingSocialProofPage extends StatefulWidget {
  const RatingSocialProofPage({
    super.key,
    this.continueToTrialFlow = false,
  });

  final bool continueToTrialFlow;

  @override
  State<RatingSocialProofPage> createState() => _RatingSocialProofPageState();
}

class _RatingSocialProofPageState extends State<RatingSocialProofPage> {
  bool _canContinue = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService().trackOnboardingScreen('onboarding_rating_social_proof');
    _requestReview();
    _startTimer();
  }

  Future<void> _requestReview() async {
    // Request in-app review on load
    final inAppReview = InAppReview.instance;
    final timestamp = DateTime.now().toIso8601String();
    try {
      final available = await inAppReview.isAvailable();
      await ReviewPromptLogsService.addLog(
        '[$timestamp] requestReview() available=$available (RatingSocialProofPage - on load)',
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
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _canContinue = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final radius = context.radius;
    final currentStep = 6;
    final totalSteps = 7;
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
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How does this feel so far?',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
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
            onPressed: _canContinue
                ? () {
                    HapticFeedback.mediumImpact();

                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => NotificationPermissionPage(
                          continueToTrialFlow: widget.continueToTrialFlow,
                        ),
                      ),
                    );
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _canContinue
                  ? AppColors.secondary
                  : colorScheme.outlineVariant,
              foregroundColor:
                  _canContinue ? Colors.white : colorScheme.onSurfaceVariant,
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
    final colorScheme = Theme.of(context).colorScheme;

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
          Text(
            "Thanks for giving Snaplook a try!",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
              fontFamily: 'PlusJakartaSans',
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "If you're enjoying the process, we'd love a quick rating - it really helps us",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant,
              height: 1.25,
              fontFamily: 'PlusJakartaSans',
            ),
          ),
        ],
      ),
    );
  }
}
