import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tutorial_analysis_page.dart';

const bool _kShowTouchTargets = false;

// Step 2 (tapShare) placements
const double _shareIndicatorBottomFraction = 0.23;
const double _shareIndicatorLeftFraction = 0.53;
const double _shareTapAreaBottomFraction = 0.21;
const double _shareTapAreaLeftFraction = 0.85;
const double _shareTapAreaWidthFraction = 0.15;
const double _shareTapAreaHeightFraction = 0.08;

// Step 3 (selectSnaplook) placements
const double _selectTapAreaBottomFraction = 0.084;
const double _selectTapAreaLeftFraction = 0.012077294685990338;
const double _selectTapAreaWidthFraction = 0.2;
const double _selectTapAreaHeightFraction = 0.1;
const double _selectIndicatorBottomFraction = 0.19;
const double _selectIndicatorLeftFraction = 0.01;

// Step 4 (confirmShare) placements
const double _confirmTapAreaBottomFraction = 0.17;
const double _confirmTapAreaRightFraction = 0.315;
const double _confirmTapAreaWidthFraction = 0.23;
const double _confirmTapAreaHeightFraction = 0.125;
const double _confirmIndicatorBottomFraction = 0.315;
const double _confirmIndicatorRightFraction = 0.315;

enum TutorialStep {
  tapShare,
  selectSnaplook,
  confirmShare,
}

final tutorialStepProvider = StateProvider<TutorialStep>((ref) => TutorialStep.tapShare);

class InstagramTutorialPage extends ConsumerWidget {
  const InstagramTutorialPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentStep = ref.watch(tutorialStepProvider);
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full-screen Instagram screenshot
          Positioned.fill(
            child: Image.asset(
              'assets/images/instagram_step1_updated.png', // Same image for all steps
              fit: BoxFit.cover,
            ),
          ),

          // Share button tap area for step 2 - user must tap the share button specifically
          if (currentStep == TutorialStep.tapShare) ...[
            Positioned(
              bottom: screenHeight * _shareTapAreaBottomFraction,
              left: screenWidth * _shareTapAreaLeftFraction,
              child: GestureDetector(
                onTap: () {
                  ref.read(tutorialStepProvider.notifier).state = TutorialStep.selectSnaplook;
                },
                child: Container(
                  width: screenWidth * _shareTapAreaWidthFraction,
                  height: screenHeight * _shareTapAreaHeightFraction,
                  decoration: BoxDecoration(
                    color: _kShowTouchTargets ? Colors.red.withOpacity(0.25) : Colors.transparent,
                    border: _kShowTouchTargets ? Border.all(color: Colors.redAccent) : null,
                  ),
                ),
              ),
            ),
          ],

          // Dark overlay when popup appears
          if (currentStep == TutorialStep.selectSnaplook || currentStep == TutorialStep.confirmShare)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
              ),
            ),

          // Share popup overlay for step 3 (selectSnaplook)
          if (currentStep == TutorialStep.selectSnaplook)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Image.asset(
                'assets/images/instagram_popup.png',
                fit: BoxFit.fitWidth,
              ),
            ),

          // Step 4 popup overlay (confirmShare) - different popup
          if (currentStep == TutorialStep.confirmShare)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Image.asset(
                'assets/images/instagram_step3_popup.png', // Use the correct step3 popup
                fit: BoxFit.fitWidth,
              ),
            ),

          // Tap detection area for step 4 (confirmShare)
          if (currentStep == TutorialStep.confirmShare)
            Positioned(
              bottom: screenHeight * _confirmTapAreaBottomFraction,
              right: screenWidth * _confirmTapAreaRightFraction,
              child: GestureDetector(
                onTap: () {
                  print("Step 4 tap detected! Moving to analysis page");
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const TutorialAnalysisPage(
                        scenario: 'Instagram',
                      ),
                      allowSnapshotting: false,
                    ),
                  );
                },
                child: Container(
                  width: screenWidth * _confirmTapAreaWidthFraction,
                  height: screenHeight * _confirmTapAreaHeightFraction,
                  decoration: BoxDecoration(
                    color: _kShowTouchTargets ? Colors.red.withOpacity(0.25) : Colors.transparent,
                    border: _kShowTouchTargets ? Border.all(color: Colors.redAccent) : null,
                  ),
                ),
              ),
            ),


          // Tap detection area for the "Share to" button in the popup
          if (currentStep == TutorialStep.selectSnaplook)
            Positioned(
              bottom: screenHeight * _selectTapAreaBottomFraction,
              left: screenWidth * _selectTapAreaLeftFraction,
              child: GestureDetector(
                onTap: () {
                  print("Tap detected! Moving to confirmShare step");
                  ref.read(tutorialStepProvider.notifier).state = TutorialStep.confirmShare;
                },
                child: Container(
                  width: screenWidth * _selectTapAreaWidthFraction,
                  height: screenHeight * _selectTapAreaHeightFraction,
                  decoration: BoxDecoration(
                    color: _kShowTouchTargets ? Colors.red.withOpacity(0.25) : Colors.transparent,
                    border: _kShowTouchTargets ? Border.all(color: Colors.redAccent) : null,
                  ),
                ),
              ),
            ),

        ],
      ),
    );
  }
}

class _ShareSheet extends StatelessWidget {
  final VoidCallback onSnaplookTap;

  const _ShareSheet({required this.onSnaplookTap});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 300,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Share',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 20),

            // Share options
            Expanded(
              child: GridView.count(
                crossAxisCount: 4,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _ShareOption(
                    icon: Icons.message,
                    label: 'Messages',
                    onTap: () {},
                  ),
                  _ShareOption(
                    icon: Icons.copy,
                    label: 'Copy Link',
                    onTap: () {},
                  ),

                  // Snaplook option - highlighted and pulsing
                  GestureDetector(
                    onTap: onSnaplookTap,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.yellow, width: 3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const _ShareOption(
                        icon: Icons.style,
                        label: 'Snaplook',
                        isHighlighted: true,
                      ),
                    ),
                  ),

                  _ShareOption(
                    icon: Icons.facebook,
                    label: 'Facebook',
                    onTap: () {},
                  ),
                ],
              ),
            ),

            // Instruction
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.yellow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Tap Snaplook to analyze this fashion outfit!',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isHighlighted;

  const _ShareOption({
    required this.icon,
    required this.label,
    this.onTap,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isHighlighted ? Colors.orange : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isHighlighted ? Colors.white : Colors.grey.shade600,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isHighlighted ? Colors.orange : Colors.grey.shade600,
              fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
