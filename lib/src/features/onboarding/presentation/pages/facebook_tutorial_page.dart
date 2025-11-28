import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tutorial_image_analysis_page.dart';

const bool _kShowTouchTargets = false;

enum FacebookTutorialStep {
  step1,
  tapMore,
  tapEdit,
  tapSnaplookShortcut,
  tapDone,
  step2,
}

enum FacebookTutorialPhase {
  showingInstruction,
  waitingForAction,
}

final facebookTutorialStepProvider = StateProvider<FacebookTutorialStep>((ref) => FacebookTutorialStep.step1);
final facebookTutorialPhaseProvider = StateProvider<FacebookTutorialPhase>((ref) => FacebookTutorialPhase.showingInstruction);
final facebookHasUserTappedProvider = StateProvider<bool>((ref) => false);

class FacebookTutorialPage extends ConsumerStatefulWidget {
  final bool returnToOnboarding;

  const FacebookTutorialPage({
    super.key,
    this.returnToOnboarding = true,
  });

  @override
  ConsumerState<FacebookTutorialPage> createState() => _FacebookTutorialPageState();
}

class _FacebookTutorialPageState extends ConsumerState<FacebookTutorialPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(facebookTutorialStepProvider.notifier).state = FacebookTutorialStep.step1;
      ref.read(facebookTutorialPhaseProvider.notifier).state = FacebookTutorialPhase.showingInstruction;
      ref.read(facebookHasUserTappedProvider.notifier).state = false;
    });
  }

  String _getInstructionText(FacebookTutorialStep step) {
    switch (step) {
      case FacebookTutorialStep.step1:
        return "When you find a clothing item you love on Facebook, tap the share button.";
      case FacebookTutorialStep.tapMore:
        return "Now tap the More button to see additional sharing options.";
      case FacebookTutorialStep.tapEdit:
        return "Tap Edit Actions to customize your sharing menu.";
      case FacebookTutorialStep.tapSnaplookShortcut:
        return "Find and tap the Snaplook icon to add it to your shortcuts.";
      case FacebookTutorialStep.tapDone:
        return "Tap Done to save your changes.";
      case FacebookTutorialStep.step2:
        return "Now select Snaplook from the share menu to find similar items.";
    }
  }

  void _handleTap() {
    final currentStep = ref.read(facebookTutorialStepProvider);
    final currentPhase = ref.read(facebookTutorialPhaseProvider);

    if (currentPhase == FacebookTutorialPhase.showingInstruction) {
      ref.read(facebookTutorialPhaseProvider.notifier).state = FacebookTutorialPhase.waitingForAction;
      ref.read(facebookHasUserTappedProvider.notifier).state = true;
    } else {
      _advanceToNextStep(currentStep);
    }
  }

  void _advanceToNextStep(FacebookTutorialStep currentStep) {
    FacebookTutorialStep? nextStep;

    switch (currentStep) {
      case FacebookTutorialStep.step1:
        nextStep = FacebookTutorialStep.tapMore;
        break;
      case FacebookTutorialStep.tapMore:
        nextStep = FacebookTutorialStep.tapEdit;
        break;
      case FacebookTutorialStep.tapEdit:
        nextStep = FacebookTutorialStep.tapSnaplookShortcut;
        break;
      case FacebookTutorialStep.tapSnaplookShortcut:
        nextStep = FacebookTutorialStep.tapDone;
        break;
      case FacebookTutorialStep.tapDone:
        nextStep = FacebookTutorialStep.step2;
        break;
      case FacebookTutorialStep.step2:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => TutorialImageAnalysisPage(
              returnToOnboarding: widget.returnToOnboarding,
            ),
          ),
        );
        return;
    }

    if (nextStep != null) {
      ref.read(facebookTutorialStepProvider.notifier).state = nextStep;
      ref.read(facebookTutorialPhaseProvider.notifier).state = FacebookTutorialPhase.showingInstruction;
      ref.read(facebookHasUserTappedProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = ref.watch(facebookTutorialStepProvider);
    final currentPhase = ref.watch(facebookTutorialPhaseProvider);
    final hasUserTapped = ref.watch(facebookHasUserTappedProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Base screenshot
          Positioned.fill(
            child: Image.asset(
              'assets/images/facebook-1.png',
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),

          // Instruction overlay
          if (currentPhase == FacebookTutorialPhase.showingInstruction)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: _handleTap,
                child: Container(
                  color: Colors.black.withOpacity(0.85),
                  padding: const EdgeInsets.all(32),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (currentStep == FacebookTutorialStep.tapMore ||
                            currentStep == FacebookTutorialStep.tapEdit ||
                            currentStep == FacebookTutorialStep.tapSnaplookShortcut ||
                            currentStep == FacebookTutorialStep.tapDone)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFf2003c).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFf2003c).withOpacity(0.4),
                                width: 1,
                              ),
                            ),
                            child: const Text(
                              'One-time setup',
                              style: TextStyle(
                                color: Color(0xFFf2003c),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'PlusJakartaSans',
                              ),
                            ),
                          ),
                        if (currentStep == FacebookTutorialStep.tapMore ||
                            currentStep == FacebookTutorialStep.tapEdit ||
                            currentStep == FacebookTutorialStep.tapSnaplookShortcut ||
                            currentStep == FacebookTutorialStep.tapDone)
                          const SizedBox(height: 16),
                        Text(
                          _getInstructionText(currentStep),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            height: 1.4,
                            fontFamily: 'PlusJakartaSans',
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Tap anywhere to continue',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 14,
                            fontFamily: 'PlusJakartaSans',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
