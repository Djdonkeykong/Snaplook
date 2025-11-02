import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tutorial_analysis_page.dart';

enum PhotosTutorialStep {
  step1,
  step2,
}

final photosTutorialStepProvider = StateProvider<PhotosTutorialStep>((ref) => PhotosTutorialStep.step1);

class PhotosTutorialPage extends ConsumerWidget {
  const PhotosTutorialPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentStep = ref.watch(photosTutorialStepProvider);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Define tap areas and text positions as fractions of screen size
    Map<String, dynamic> getStepConfig() {
      switch (currentStep) {
        case PhotosTutorialStep.step1:
          return {
            'image': 'assets/images/photos_step1.png',
            'tapAreaTop': screenHeight * 0.9,
            'tapAreaLeft': screenWidth * 0.03,
            'tapAreaWidth': screenWidth * 0.20,
            'tapAreaHeight': screenHeight * 0.08,
            'textTop': screenHeight * 0.81,
            'textLeft': screenWidth * 0.01,
            'instruction': 'Tap here',
            'arrowDirection': 'down',
          };
        case PhotosTutorialStep.step2:
          return {
            'image': 'assets/images/photos_step2.png',
            'tapAreaTop': screenHeight * 0.73,
            'tapAreaLeft': screenWidth * 0.22,
            'tapAreaWidth': screenWidth * 0.25,
            'tapAreaHeight': screenHeight * 0.12,
            'textTop': screenHeight * 0.64,
            'textLeft': screenWidth * 0.23,
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
            'assets/images/photos_step1.png',
            fit: BoxFit.fill,
            width: screenWidth,
            height: screenHeight,
          ),

          // Dark overlay on background image - appears in step 2
          if (currentStep == PhotosTutorialStep.step2)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                ),
              ),
            ),

          // Overlay image for step 2
          if (currentStep == PhotosTutorialStep.step2)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: RepaintBoundary(
                child: Image.asset(
                  'assets/images/photos_step2.png',
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
                if (currentStep == PhotosTutorialStep.step1) {
                  ref.read(photosTutorialStepProvider.notifier).state = PhotosTutorialStep.step2;
                } else {
                  // Navigate to analysis page with Photos image
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const TutorialAnalysisPage(
                        imagePath: 'assets/images/photos_tutorial.jpg',
                        scenario: 'Photos',
                      ),
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
