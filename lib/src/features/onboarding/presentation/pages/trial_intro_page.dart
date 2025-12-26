import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../shared/widgets/snaplook_back_button.dart';
import '../../../../../src/shared/services/video_preloader.dart';
import '../widgets/progress_indicator.dart';
import '../widgets/onboarding_bottom_bar.dart';
import 'trial_reminder_page.dart';
import 'paywall_presentation_page.dart';
import '../../../../services/revenuecat_service.dart';
import '../../../../services/onboarding_state_service.dart';

class TrialIntroPage extends ConsumerStatefulWidget {
  const TrialIntroPage({super.key});

  @override
  ConsumerState<TrialIntroPage> createState() => _TrialIntroPageState();
}

class _TrialIntroPageState extends ConsumerState<TrialIntroPage>
    with WidgetsBindingObserver {
  VideoPlayerController? get _controller =>
      VideoPreloader.instance.trialVideoController;
  bool _isEligibleForTrial = true;
  bool _isCheckingEligibility = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Update checkpoint for authenticated users
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        try {
          await OnboardingStateService().updateCheckpoint(
            userId,
            OnboardingCheckpoint.trial,
          );
        } catch (e) {
          debugPrint('[TrialIntro] Error updating checkpoint: $e');
        }
      }

      // Check trial eligibility first
      await _checkTrialEligibility();

      await VideoPreloader.instance.preloadTrialVideo();
      // Preload bell video for next page
      VideoPreloader.instance.preloadBellVideo();
      if (mounted) {
        setState(() {});
        // Ensure video plays when returning to this page
        VideoPreloader.instance.playTrialVideo();
      }
    });
  }

  Future<void> _checkTrialEligibility() async {
    try {
      final isEligible = await RevenueCatService().isEligibleForTrial().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint(
              '[TrialIntro] Trial eligibility check timed out - defaulting to eligible');
          return true;
        },
      );
      if (mounted) {
        setState(() {
          _isEligibleForTrial = isEligible;
          _isCheckingEligibility = false;
        });

        // If not eligible, skip directly to paywall
        if (!isEligible && mounted) {
          final userId = Supabase.instance.client.auth.currentUser?.id;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => PaywallPresentationPage(
                userId: userId,
                placement: 'onboarding_paywall',
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[TrialIntro] Error checking trial eligibility: $e');
      if (mounted) {
        setState(() {
          _isEligibleForTrial = true; // Default to showing trial on error
          _isCheckingEligibility = false;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    VideoPreloader.instance.pauseTrialVideo();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Resume video when app comes back to foreground
      VideoPreloader.instance.playTrialVideo();
    } else if (state == AppLifecycleState.paused) {
      // Pause video when app goes to background
      VideoPreloader.instance.pauseTrialVideo();
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
        leading: const SnaplookBackButton(enableHaptics: true),
        centerTitle: true,
        title: const OnboardingProgressIndicator(
          currentStep: 7,
          totalSteps: 10,
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
              'We want you to\ntry Snaplook for free',
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

            SizedBox(height: spacing.xl),

            // Video player with slight seek to avoid initial flash
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  widthFactor: 0.92,
                  child: _controller != null &&
                          VideoPreloader.instance.isTrialVideoInitialized
                      ? Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Center(
                              child: AspectRatio(
                                aspectRatio: _controller!.value.aspectRatio,
                                child: VideoPlayer(_controller!),
                              ),
                            ),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: OnboardingBottomBar(
        primaryButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // No Payment Due Now
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
            // Try For $0.00 button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const TrialReminderPage(),
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
                  'Try for \$0.00',
                  style: TextStyle(
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
        secondaryButton: const Align(
          alignment: Alignment.center,
          child: Text(
            'Just \$41.99 per year (\$3.49/mo)',
            textAlign: TextAlign.center,
            style: TextStyle(
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
