import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../widgets/onboarding_bottom_bar.dart';
import 'account_creation_page.dart';

class TrialReminderPage extends ConsumerStatefulWidget {
  const TrialReminderPage({super.key});

  @override
  ConsumerState<TrialReminderPage> createState() => _TrialReminderPageState();
}

class _TrialReminderPageState extends ConsumerState<TrialReminderPage> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.asset(
        'assets/videos/bell-new.mp4',
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
      );
      await _controller!.initialize();
      _controller!.setLooping(true);
      _controller!.setVolume(0.0);
      _controller!.play();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('Error initializing bell video: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
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

            // Bell animation
            Center(
              child: SizedBox(
                width: 180,
                height: 180,
                child: _isInitialized && _controller != null
                    ? AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio,
                        child: VideoPlayer(_controller!),
                      )
                    : const SizedBox.shrink(),
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
            // Continue for FREE button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();

                  // Continue to account creation
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
          ],
        ),
        secondaryButton: const Align(
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
      ),
    );
  }
}
