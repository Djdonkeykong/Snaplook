import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tutorial_analysis_page.dart';

enum PinterestTutorialStep {
  step1,
  step2,
  step3,
}

final pinterestTutorialStepProvider = StateProvider<PinterestTutorialStep>((ref) => PinterestTutorialStep.step1);

class PinterestTutorialPage extends ConsumerWidget {
  const PinterestTutorialPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentStep = ref.watch(pinterestTutorialStepProvider);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Define tap areas and text positions as fractions of screen size
    Map<String, dynamic> getStepConfig() {
      switch (currentStep) {
        case PinterestTutorialStep.step1:
          return {
            'image': 'assets/images/pinterest_step1.png',
            'tapAreaTop': screenHeight * 0.87, // Further down
            'tapAreaLeft': screenWidth * 0.25, // Further to the left
            'tapAreaWidth': screenWidth * 0.20,
            'tapAreaHeight': screenHeight * 0.08,
            'textTop': screenHeight * 0.785, // Further down
            'textLeft': screenWidth * 0.24, // Further to the left
            'instruction': 'Tap here',
            'arrowDirection': 'down',
          };
        case PinterestTutorialStep.step2:
          return {
            'image': 'assets/images/pinterest_step2.png',
            'tapAreaTop': screenHeight * 0.85, // Bottom popup area
            'tapAreaLeft': screenWidth * 0.5,
            'tapAreaWidth': screenWidth * 0.25,
            'tapAreaHeight': screenHeight * 0.12,
            'textTop': screenHeight * 0.76,
            'textLeft': screenWidth * 0.50,
            'instruction': 'Tap here',
            'arrowDirection': 'down',
          };
        case PinterestTutorialStep.step3:
          return {
            'image': 'assets/images/pinterest_step3.png',
            'tapAreaTop': screenHeight * 0.70, // Bottom share button
            'tapAreaLeft': screenWidth * 0.0,
            'tapAreaWidth': screenWidth * 0.25,
            'tapAreaHeight': screenHeight * 0.12,
            'textTop': screenHeight * 0.61,
            'textLeft': screenWidth * 0.01,
            'instruction': 'Tap here',
            'arrowDirection': 'down',
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
            'assets/images/pinterest_step1.png',
            fit: BoxFit.fill,
            width: screenWidth,
            height: screenHeight,
          ),

          // Dark overlay on background image - light in step 2, darker in step 3
          if (currentStep == PinterestTutorialStep.step2)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                ),
              ),
            ),
          if (currentStep == PinterestTutorialStep.step3)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                ),
              ),
            ),

          // Overlay image for step 2 - stays visible in step 3
          if (currentStep == PinterestTutorialStep.step2 || currentStep == PinterestTutorialStep.step3)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: RepaintBoundary(
                child: Image.asset(
                  'assets/images/pinterest_step2.png',
                  fit: BoxFit.fitWidth,
                  gaplessPlayback: true,
                  frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                    // Show immediately without fade
                    return child;
                  },
                ),
              ),
            ),

          // Dark overlay on step 2 image when step 3 is showing
          if (currentStep == PinterestTutorialStep.step3)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                ),
              ),
            ),

          // Overlay image for step 3 - appears on top of step 2
          if (currentStep == PinterestTutorialStep.step3)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: RepaintBoundary(
                child: Image.asset(
                  'assets/images/pinterest_step3.png',
                  fit: BoxFit.fitWidth,
                  gaplessPlayback: true,
                  frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                    // Show immediately without fade
                    return child;
                  },
                ),
              ),
            ),

          // Tap detection area - positioned dynamically
          Positioned(
            top: config['tapAreaTop'],
            left: config['tapAreaLeft'],
            child: GestureDetector(
              onTap: () {
                if (currentStep == PinterestTutorialStep.step1) {
                  ref.read(pinterestTutorialStepProvider.notifier).state = PinterestTutorialStep.step2;
                } else if (currentStep == PinterestTutorialStep.step2) {
                  ref.read(pinterestTutorialStepProvider.notifier).state = PinterestTutorialStep.step3;
                } else {
                  // Navigate to analysis page with Pinterest image
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const TutorialAnalysisPage(
                        imagePath: 'assets/images/pinterest_tutorial.jpg',
                        scenario: 'Pinterest',
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

          // "Tap here" indicator - positioned dynamically above tap area
          Positioned(
            top: config['textTop'],
            left: config['textLeft'],
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFf2003c),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      config['instruction'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'PlusJakartaSans',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                // Arrow pointing down to tap area
                if (config['arrowDirection'] == 'down')
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Color(0xFFf2003c),
                      size: 28,
                    ),
                  ),
              ],
            ),
          ),

        ],
      ),
    );
  }
}
