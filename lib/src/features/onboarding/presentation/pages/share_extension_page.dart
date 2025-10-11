import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../widgets/progress_indicator.dart';
import 'add_first_style_page.dart';
import 'trial_intro_page.dart';
import '../../../../../src/shared/services/video_preloader.dart';

class ShareExtensionPage extends ConsumerWidget {
  const ShareExtensionPage({super.key});

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
        centerTitle: true,
        title: const OnboardingProgressIndicator(
          currentStep: 4,
          totalSteps: 6,
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            SizedBox(height: spacing.l),

            // Title
            const Text(
              'Analyze fashion from\nany app',
              style: TextStyle(
                fontSize: 38,
                fontFamily: 'PlusJakartaSans',
                letterSpacing: -1.0,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                height: 1.3,
              ),
            ),

            SizedBox(height: spacing.xl),

            // Video Demo - Optimal size
            Container(
              height: 480, // Increased from 380 to 480 for bigger size
              width: double.infinity,
              margin: EdgeInsets.symmetric(horizontal: spacing.l),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: Colors.white, // White background to replace video's black background
                  child: const _PreloadedVideoPlayer(),
                ),
              ),
            ),

            SizedBox(height: spacing.xl),

            // Try it now Button
            Container(
              width: double.infinity,
              height: 56,
              margin: EdgeInsets.only(bottom: spacing.m),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AddFirstStylePage(),
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
                  'Try it now',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'PlusJakartaSans',
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),

            // Skip Button
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const TrialIntroPage(),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                margin: EdgeInsets.only(bottom: spacing.xxl),
                child: const Center(
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isHighlighted;

  const _ShareOption(
    this.icon,
    this.label, {
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isHighlighted ? const Color(0xFFFF521B).withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 20,
            color: isHighlighted ? const Color(0xFFFF521B) : Colors.grey.shade600,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isHighlighted ? const Color(0xFFFF521B) : Colors.grey.shade600,
              fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreloadedVideoPlayer extends StatefulWidget {
  const _PreloadedVideoPlayer();

  @override
  State<_PreloadedVideoPlayer> createState() => _PreloadedVideoPlayerState();
}

class _PreloadedVideoPlayerState extends State<_PreloadedVideoPlayer> {
  VideoPlayerController? get _controller => VideoPreloader.instance.shareVideoController;

  @override
  void initState() {
    super.initState();
    // Resume video when entering this page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      VideoPreloader.instance.playShareVideo();
    });
  }

  @override
  void dispose() {
    // Pause video to reduce buffer usage when leaving page
    VideoPreloader.instance.pauseShareVideo();
    super.dispose();
  }

  @override
  void deactivate() {
    // Also pause when page becomes inactive
    VideoPreloader.instance.pauseShareVideo();
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !VideoPreloader.instance.isInitialized) {
      // If for some reason the video isn't preloaded, show a minimal placeholder
      return Container(
        color: Colors.white,
        child: const Center(
          child: Icon(
            Icons.play_circle_outline,
            size: 48,
            color: Colors.grey,
          ),
        ),
      );
    }

    return Container(
      color: Colors.white,
      child: Stack(
        children: [
          Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            ),
          ),
          // White stripe to cover black bar at top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 2,
              color: Colors.white,
            ),
          ),
          // White stripe to cover black bar at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 2,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}