import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tutorial_image_analysis_page.dart';

enum TikTokTutorialStep {
  step1,
  step2,
  step3,
}

final tiktokTutorialStepProvider = StateProvider<TikTokTutorialStep>((ref) => TikTokTutorialStep.step1);

class TikTokTutorialPage extends ConsumerWidget {
  const TikTokTutorialPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentStep = ref.watch(tiktokTutorialStepProvider);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Define tap areas as fractions of screen size
    Map<String, dynamic> getStepConfig() {
      switch (currentStep) {
        case TikTokTutorialStep.step1:
          return {
            'image': 'assets/images/tiktok_step1.png',
            'tapAreaTop': screenHeight * 0.755,
            'tapAreaLeft': screenWidth * 0.84,
            'tapAreaWidth': screenWidth * 0.18,
            'tapAreaHeight': screenHeight * 0.08,
          };
        case TikTokTutorialStep.step2:
          return {
            'image': 'assets/images/tiktok_step2.png',
            'tapAreaTop': screenHeight * 0.745,
            'tapAreaLeft': screenWidth * 0.79,
            'tapAreaWidth': screenWidth * 0.21,
            'tapAreaHeight': screenHeight * 0.11,
          };
        case TikTokTutorialStep.step3:
          return {
            'image': 'assets/images/tiktok_step3.png',
            'tapAreaTop': screenHeight * 0.75,
            'tapAreaLeft': screenWidth * 0.225,
            'tapAreaWidth': screenWidth * 0.26,
            'tapAreaHeight': screenHeight * 0.12,
          };
      }
    }

    final config = getStepConfig();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background image - always show step 1 image
          Image.asset(
            'assets/images/tiktok_step1.png',
            fit: BoxFit.fill,
            width: screenWidth,
            height: screenHeight,
          ),

          // Dark overlay on background image - appears in step 2 and step 3
          if (currentStep == TikTokTutorialStep.step2 || currentStep == TikTokTutorialStep.step3)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                ),
              ),
            ),

          // Overlay image for step 2 - stays visible in step 3
          if (currentStep == TikTokTutorialStep.step2 || currentStep == TikTokTutorialStep.step3)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: RepaintBoundary(
                child: Image.asset(
                  'assets/images/tiktok_step2.png',
                  fit: BoxFit.fitWidth,
                  gaplessPlayback: true,
                  frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                    // Show immediately without fade
                    return child;
                  },
                ),
              ),
            ),

          // Overlay image for step 3 - appears on top of step 2
          if (currentStep == TikTokTutorialStep.step3)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: RepaintBoundary(
                child: Image.asset(
                  'assets/images/tiktok_step3.png',
                  fit: BoxFit.fitWidth,
                  gaplessPlayback: true,
                  frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                    // Show immediately without fade
                    return child;
                  },
                ),
              ),
            ),

          // Tap detection area - positioned dynamically with visible border
          Positioned(
            top: config['tapAreaTop'],
            left: config['tapAreaLeft'],
            child: GestureDetector(
              onTap: () {
                if (currentStep == TikTokTutorialStep.step1) {
                  ref.read(tiktokTutorialStepProvider.notifier).state = TikTokTutorialStep.step2;
                } else if (currentStep == TikTokTutorialStep.step2) {
                  ref.read(tiktokTutorialStepProvider.notifier).state = TikTokTutorialStep.step3;
                } else {
                  // Navigate to analysis page with TikTok image
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const TutorialImageAnalysisPage(
                        imagePath: 'assets/images/tiktok_tutorial.jpg',
                        scenario: 'TikTok',
                      ),
                      allowSnapshotting: false,
                    ),
                  );
                }
              },
              child: Container(
                width: config['tapAreaWidth'],
                height: config['tapAreaHeight'],
                color: Colors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
