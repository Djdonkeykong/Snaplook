import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tutorial_analysis_page.dart';

enum SafariTutorialStep {
  step1,
  step2,
  step3,
}

final safariTutorialStepProvider =
    StateProvider<SafariTutorialStep>((ref) => SafariTutorialStep.step1);

class SafariTutorialPage extends ConsumerWidget {
  const SafariTutorialPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentStep = ref.watch(safariTutorialStepProvider);
    final size = MediaQuery.of(context).size;
    final config = _getConfig(currentStep);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              config.imagePath,
              fit: BoxFit.cover,
              width: size.width,
              height: size.height,
            ),
          ),

          // Tap detection area
          Positioned(
            top: size.height * config.tapTopFraction,
            left: size.width * config.tapLeftFraction,
            child: GestureDetector(
              onTap: currentStep != SafariTutorialStep.step1 ? () {
                final notifier = ref.read(safariTutorialStepProvider.notifier);
                if (currentStep == SafariTutorialStep.step2) {
                  notifier.state = SafariTutorialStep.step3;
                } else {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const TutorialAnalysisPage(
                        imagePath: 'assets/images/safari_tutorial.webp',
                        scenario: 'Safari',
                      ),
                      allowSnapshotting: false,
                    ),
                  );
                }
              } : null,
              onLongPress: currentStep == SafariTutorialStep.step1 ? () {
                final notifier = ref.read(safariTutorialStepProvider.notifier);
                notifier.state = SafariTutorialStep.step2;
              } : null,
              child: Container(
                width: size.width * config.tapWidthFraction,
                height: size.height * config.tapHeightFraction,
                color: Colors.transparent,
              ),
            ),
          ),

        ],
      ),
    );
  }
}

class _SafariStepConfig {
  const _SafariStepConfig({
    required this.imagePath,
    required this.tapTopFraction,
    required this.tapLeftFraction,
    required this.tapWidthFraction,
    required this.tapHeightFraction,
  });

  final String imagePath;
  final double tapTopFraction;
  final double tapLeftFraction;
  final double tapWidthFraction;
  final double tapHeightFraction;
}

_SafariStepConfig _getConfig(SafariTutorialStep step) {
  switch (step) {
    case SafariTutorialStep.step1:
      return const _SafariStepConfig(
        imagePath: 'assets/images/safari_step1.png',
        tapTopFraction: 0.1,
        tapLeftFraction: 0.0,
        tapWidthFraction: 1,
        tapHeightFraction: 0.55,
      );
    case SafariTutorialStep.step2:
      return const _SafariStepConfig(
        imagePath: 'assets/images/safari_step2.png',
        tapTopFraction: 0.645,
        tapLeftFraction: 0.2,
        tapWidthFraction: 0.61,
        tapHeightFraction: 0.07,
      );
    case SafariTutorialStep.step3:
    default:
      return const _SafariStepConfig(
        imagePath: 'assets/images/safari_step3.png',
        tapTopFraction: 0.7,
        tapLeftFraction: 0.22,
        tapWidthFraction: 0.25,
        tapHeightFraction: 0.1,
      );
  }
}
