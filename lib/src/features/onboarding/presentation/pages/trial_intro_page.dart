import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../src/shared/services/video_preloader.dart';
import '../widgets/progress_indicator.dart';
import 'trial_reminder_page.dart';

class TrialIntroPage extends ConsumerStatefulWidget {
  const TrialIntroPage({super.key});

  @override
  ConsumerState<TrialIntroPage> createState() => _TrialIntroPageState();
}

class _TrialIntroPageState extends ConsumerState<TrialIntroPage> with WidgetsBindingObserver {
  VideoPlayerController? get _controller => VideoPreloader.instance.trialVideoController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await VideoPreloader.instance.preloadTrialVideo();
      if (mounted) {
        setState(() {});
      }
    });
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
              'We want you to\ntry Snaplook for free.',
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

            // Video player
            Expanded(
              child: Center(
                child: _controller != null && VideoPreloader.instance.isTrialVideoInitialized
                    ? Container(
                        width: double.infinity,
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
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
              ),
            ),

            SizedBox(height: spacing.xl),

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

            // Try For $0.00 button
            Container(
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

            SizedBox(height: spacing.m),

            // Pricing text
            const Align(
              alignment: Alignment.center,
              child: Text(
                'Just \$59.99 per year (\$4.99/mo)',
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

            SizedBox(height: spacing.xxl),
          ],
        ),
      ),
    );
  }
}
