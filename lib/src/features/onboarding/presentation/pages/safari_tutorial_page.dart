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

          // Indicator + arrow
          Positioned(
            top: size.height * config.indicatorTopFraction,
            left: size.width * config.indicatorLeftFraction,
            child: _SafariIndicator(
              instruction: config.instruction,
              arrowDirection: config.arrowDirection,
            ),
          ),
        ],
      ),
    );
  }
}

class _SafariIndicator extends StatelessWidget {
  const _SafariIndicator({
    required this.instruction,
    required this.arrowDirection,
  });

  final String instruction;
  final _SafariArrowDirection arrowDirection;

  @override
  Widget build(BuildContext context) {
    final label = Container(
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
      child: Text(
        instruction,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          fontFamily: 'PlusJakartaSans',
        ),
      ),
    );

    final arrow = _buildArrow();

    if (arrowDirection == _SafariArrowDirection.right) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          label,
          const SizedBox(width: 8),
          arrow,
        ],
      );
    }

    if (arrowDirection == _SafariArrowDirection.up) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          arrow,
          const SizedBox(height: 8),
          label,
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        label,
        const SizedBox(height: 8),
        arrow,
      ],
    );
  }

  Widget _buildArrow() {
    switch (arrowDirection) {
      case _SafariArrowDirection.right:
        return const Icon(
          Icons.keyboard_arrow_right,
          color: Color(0xFFf2003c),
          size: 32,
        );
      case _SafariArrowDirection.up:
        return Transform.rotate(
          angle: 3.14159,
          child: const Icon(
            Icons.keyboard_arrow_down,
            color: Color(0xFFf2003c),
            size: 32,
          ),
        );
      case _SafariArrowDirection.down:
      default:
        return const Icon(
          Icons.keyboard_arrow_down,
          color: Color(0xFFf2003c),
          size: 32,
        );
    }
  }
}

class _SafariStepConfig {
  const _SafariStepConfig({
    required this.imagePath,
    required this.tapTopFraction,
    required this.tapLeftFraction,
    required this.tapWidthFraction,
    required this.tapHeightFraction,
    required this.indicatorTopFraction,
    required this.indicatorLeftFraction,
    required this.instruction,
    required this.arrowDirection,
  });

  final String imagePath;
  final double tapTopFraction;
  final double tapLeftFraction;
  final double tapWidthFraction;
  final double tapHeightFraction;
  final double indicatorTopFraction;
  final double indicatorLeftFraction;
  final String instruction;
  final _SafariArrowDirection arrowDirection;
}

enum _SafariArrowDirection { right, down, up }

_SafariStepConfig _getConfig(SafariTutorialStep step) {
  switch (step) {
    case SafariTutorialStep.step1:
      return const _SafariStepConfig(
        imagePath: 'assets/images/safari_step1.png',
        tapTopFraction: 0.1,
        tapLeftFraction: 0.0,
        tapWidthFraction: 1,
        tapHeightFraction: 0.55,
        indicatorTopFraction: 0.66,
        indicatorLeftFraction: 0.34,
        instruction: 'Hold here',
        arrowDirection: _SafariArrowDirection.up,
      );
    case SafariTutorialStep.step2:
      return const _SafariStepConfig(
        imagePath: 'assets/images/safari_step2.png',
        tapTopFraction: 0.645,
        tapLeftFraction: 0.2,
        tapWidthFraction: 0.61,
        tapHeightFraction: 0.07,
        indicatorTopFraction: 0.54,
        indicatorLeftFraction: 0.38,
        instruction: 'Tap here',
        arrowDirection: _SafariArrowDirection.down,
      );
    case SafariTutorialStep.step3:
    default:
      return const _SafariStepConfig(
        imagePath: 'assets/images/safari_step3.png',
        tapTopFraction: 0.7,
        tapLeftFraction: 0.22,
        tapWidthFraction: 0.25,
        tapHeightFraction: 0.1,
        indicatorTopFraction: 0.6,
        indicatorLeftFraction: 0.23,
        instruction: 'Tap here',
        arrowDirection: _SafariArrowDirection.down,
      );
  }
}
