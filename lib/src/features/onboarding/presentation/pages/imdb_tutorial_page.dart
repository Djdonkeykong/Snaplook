import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tutorial_image_analysis_page.dart';

const bool _kShowTouchTargets = false;

enum ImdbTutorialStep {
  step1,
  tapMore,
  tapEdit,
  tapSnaplookShortcut,
  tapDone,
  step2,
}

enum ImdbTutorialPhase {
  showingInstruction,
  waitingForAction,
}

final imdbTutorialStepProvider = StateProvider<ImdbTutorialStep>((ref) => ImdbTutorialStep.step1);
final imdbTutorialPhaseProvider = StateProvider<ImdbTutorialPhase>((ref) => ImdbTutorialPhase.showingInstruction);
final imdbHasUserTappedProvider = StateProvider<bool>((ref) => false);

class ImdbTutorialPage extends ConsumerStatefulWidget {
  final bool returnToOnboarding;

  const ImdbTutorialPage({
    super.key,
    this.returnToOnboarding = true,
  });

  @override
  ConsumerState<ImdbTutorialPage> createState() => _ImdbTutorialPageState();
}

class _ImdbTutorialPageState extends ConsumerState<ImdbTutorialPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(imdbTutorialStepProvider.notifier).state = ImdbTutorialStep.step1;
      ref.read(imdbTutorialPhaseProvider.notifier).state = ImdbTutorialPhase.showingInstruction;
      ref.read(imdbHasUserTappedProvider.notifier).state = false;
    });
  }

  String _getInstructionText(ImdbTutorialStep step) {
    switch (step) {
      case ImdbTutorialStep.step1:
        return "When you find a clothing item you love on IMDb, tap the share button.";
      case ImdbTutorialStep.tapMore:
        return "Now tap the More button to see additional sharing options.";
      case ImdbTutorialStep.tapEdit:
        return "Tap Edit Actions to customize your sharing menu.";
      case ImdbTutorialStep.tapSnaplookShortcut:
        return "Find and tap the Snaplook icon to add it to your shortcuts.";
      case ImdbTutorialStep.tapDone:
        return "Tap Done to save your changes.";
      case ImdbTutorialStep.step2:
        return "Now select Snaplook from the share menu to find similar items.";
    }
  }

  void _handleTap() {
    final currentStep = ref.read(imdbTutorialStepProvider);
    final currentPhase = ref.read(imdbTutorialPhaseProvider);

    if (currentPhase == ImdbTutorialPhase.showingInstruction) {
      ref.read(imdbTutorialPhaseProvider.notifier).state = ImdbTutorialPhase.waitingForAction;
      ref.read(imdbHasUserTappedProvider.notifier).state = true;
    } else {
      _advanceToNextStep(currentStep);
    }
  }

  void _advanceToNextStep(ImdbTutorialStep currentStep) {
    ImdbTutorialStep? nextStep;

    switch (currentStep) {
      case ImdbTutorialStep.step1:
        nextStep = ImdbTutorialStep.tapMore;
        break;
      case ImdbTutorialStep.tapMore:
        nextStep = ImdbTutorialStep.tapEdit;
        break;
      case ImdbTutorialStep.tapEdit:
        nextStep = ImdbTutorialStep.tapSnaplookShortcut;
        break;
      case ImdbTutorialStep.tapSnaplookShortcut:
        nextStep = ImdbTutorialStep.tapDone;
        break;
      case ImdbTutorialStep.tapDone:
        nextStep = ImdbTutorialStep.step2;
        break;
      case ImdbTutorialStep.step2:
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
      ref.read(imdbTutorialStepProvider.notifier).state = nextStep;
      ref.read(imdbTutorialPhaseProvider.notifier).state = ImdbTutorialPhase.showingInstruction;
      ref.read(imdbHasUserTappedProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = ref.watch(imdbTutorialStepProvider);
    final currentPhase = ref.watch(imdbTutorialPhaseProvider);
    final hasUserTapped = ref.watch(imdbHasUserTappedProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Base screenshot
          Positioned.fill(
            child: Image.asset(
              'assets/images/imdb-1.png',
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),

          // Instruction overlay
          if (currentPhase == ImdbTutorialPhase.showingInstruction)
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
                        if (currentStep == ImdbTutorialStep.tapMore ||
                            currentStep == ImdbTutorialStep.tapEdit ||
                            currentStep == ImdbTutorialStep.tapSnaplookShortcut ||
                            currentStep == ImdbTutorialStep.tapDone)
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
                        if (currentStep == ImdbTutorialStep.tapMore ||
                            currentStep == ImdbTutorialStep.tapEdit ||
                            currentStep == ImdbTutorialStep.tapSnaplookShortcut ||
                            currentStep == ImdbTutorialStep.tapDone)
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
