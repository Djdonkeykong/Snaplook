import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tutorial_analysis_page.dart';

enum TutorialStep {
  viewPost,
  tapShare,
  selectSnaplook,
  confirmShare,
}

final tutorialStepProvider = StateProvider<TutorialStep>((ref) => TutorialStep.viewPost);

class InstagramTutorialPage extends ConsumerWidget {
  const InstagramTutorialPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentStep = ref.watch(tutorialStepProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full-screen Instagram screenshot - different image based on step
          Positioned.fill(
            child: GestureDetector(
              onTap: currentStep == TutorialStep.viewPost ? () {
                ref.read(tutorialStepProvider.notifier).state = TutorialStep.tapShare;
              } : null,
              child: Image.asset(
                'assets/images/instagram_step1_updated.png', // Same image for all steps
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Share button tap area for step 2 - user must tap the share button specifically
          if (currentStep == TutorialStep.tapShare)
            Positioned(
              bottom: 218, // Position over the share button
              right: -15,   // Position over the share button
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // "Tap here" indicator - visual only, not tappable
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFf2003c),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Text(
                      'Tap here',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  // Arrow pointing right to the share button
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    child: const Icon(
                      Icons.keyboard_arrow_right,
                      color: Color(0xFFf2003c),
                      size: 24,
                    ),
                  ),

                  // Actual tap detection area covering the share button
                  GestureDetector(
                    onTap: () {
                      ref.read(tutorialStepProvider.notifier).state = TutorialStep.selectSnaplook;
                    },
                    child: Container(
                      width: 60,
                      height: 60,
                      color: Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),

          // Tutorial Overlay Instructions - only show for viewPost step
          if (currentStep == TutorialStep.viewPost)
            _TutorialOverlay(
              currentStep: currentStep,
              onNext: () {
                ref.read(tutorialStepProvider.notifier).state = TutorialStep.tapShare;
              },
            ),

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
              bottom: 186, // Default position - adjust as needed
              right: 142,  // Default position - adjust as needed
              child: GestureDetector(
                onTap: () {
                  print("Step 4 tap detected! Moving to analysis page");
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const TutorialAnalysisPage(),
                    ),
                  );
                },
                child: Container(
                  width: 80,
                  height: 80,
                  color: Colors.transparent,
                ),
              ),
            ),

          // "Tap here" indicator for step 4 (confirmShare)
          if (currentStep == TutorialStep.confirmShare)
            Positioned(
              bottom: 270, // Position above the tap detection area
              right: 134,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFf2003c),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Tap here',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    // Arrow pointing down to the tap area
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      child: Transform.rotate(
                        angle: 0.0, // Rotation angle in radians
                        child: const Icon(
                          Icons.keyboard_arrow_down,
                          color: Color(0xFFf2003c),
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Tap detection area for the "Share to" button in the popup
          if (currentStep == TutorialStep.selectSnaplook)
            Positioned(
              bottom: 90, // Position over the green "Share to" button
              left: 10,  // Position over the green "Share to" button
              child: GestureDetector(
                onTap: () {
                  print("Tap detected! Moving to confirmShare step");
                  ref.read(tutorialStepProvider.notifier).state = TutorialStep.confirmShare;
                },
                child: Container(
                  width: 80,
                  height: 80,
                  color: Colors.transparent,
                ),
              ),
            ),

          // "Tap here" indicator on top of the popup
          if (currentStep == TutorialStep.selectSnaplook)
            Positioned(
              bottom: 164, // Adjust position to be over the popup
              left: 20,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFf2003c),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Tap here',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    // Arrow pointing down to the popup
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      child: Transform.rotate(
                        angle: 0.5, // Rotation angle in radians
                        child: const Icon(
                          Icons.keyboard_arrow_down,
                          color: Color(0xFFf2003c),
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TutorialOverlay extends StatelessWidget {
  final TutorialStep currentStep;
  final VoidCallback onNext;

  const _TutorialOverlay({
    required this.currentStep,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    String instruction;
    double top;
    double left;

    switch (currentStep) {
      case TutorialStep.viewPost:
        instruction = "Tap anywhere to continue";
        top = 150;
        left = 20;
        break;
      case TutorialStep.tapShare:
        instruction = "Tap the share button";
        top = MediaQuery.of(context).size.height - 300;
        left = 250;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Stack(
      children: [
        if (currentStep == TutorialStep.viewPost)
          Positioned.fill(
            child: GestureDetector(
              onTap: onNext,
              child: Container(
                color: Colors.black.withValues(alpha: 0.3),
              ),
            ),
          ),
        Positioned(
          top: top,
          left: left,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFf2003c),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              instruction,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
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