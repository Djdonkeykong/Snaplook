import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tutorial_image_analysis_page.dart';

const bool _kShowTouchTargets = false;

enum YouTubeTutorialStep {
  step1,
  tapMore,
  tapEdit,
  tapSnaplookShortcut,
  tapDone,
  tapDoneLast,
  step2,
}

enum YouTubeTutorialPhase {
  showingInstruction,
  waitingForAction,
}

final youtubeTutorialStepProvider = StateProvider<YouTubeTutorialStep>((ref) => YouTubeTutorialStep.step1);
final youtubeTutorialPhaseProvider = StateProvider<YouTubeTutorialPhase>((ref) => YouTubeTutorialPhase.showingInstruction);
final youtubeHasUserTappedProvider = StateProvider<bool>((ref) => false);

class YouTubeTutorialPage extends ConsumerStatefulWidget {
  final bool returnToOnboarding;

  const YouTubeTutorialPage({
    super.key,
    this.returnToOnboarding = true,
  });

  @override
  ConsumerState<YouTubeTutorialPage> createState() => _YouTubeTutorialPageState();
}

class _YouTubeTutorialPageState extends ConsumerState<YouTubeTutorialPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(youtubeTutorialStepProvider.notifier).state = YouTubeTutorialStep.step1;
      ref.read(youtubeTutorialPhaseProvider.notifier).state = YouTubeTutorialPhase.showingInstruction;
      ref.read(youtubeHasUserTappedProvider.notifier).state = false;
    });
  }

  String _getInstructionText(YouTubeTutorialStep step) {
    switch (step) {
      case YouTubeTutorialStep.step1:
        return "When you find a clothing item you love on YouTube, tap the share button.";
      case YouTubeTutorialStep.tapMore:
        return "Now tap the More button to see additional sharing options.";
      case YouTubeTutorialStep.tapEdit:
        return "Tap Edit Actions to customize your sharing menu.";
      case YouTubeTutorialStep.tapSnaplookShortcut:
        return "Find and tap the Snaplook icon to add it to your shortcuts.";
      case YouTubeTutorialStep.tapDone:
        return "Tap Done to save your changes.";
      case YouTubeTutorialStep.tapDoneLast:
        return "Tap 'Done' again to finish the setup.";
      case YouTubeTutorialStep.step2:
        return "Now select Snaplook from the share menu to find similar items.";
    }
  }

  void _handleTap() {
    final currentStep = ref.read(youtubeTutorialStepProvider);
    final currentPhase = ref.read(youtubeTutorialPhaseProvider);

    if (currentPhase == YouTubeTutorialPhase.showingInstruction) {
      ref.read(youtubeTutorialPhaseProvider.notifier).state = YouTubeTutorialPhase.waitingForAction;
      ref.read(youtubeHasUserTappedProvider.notifier).state = true;
    } else {
      _advanceToNextStep(currentStep);
    }
  }

  void _advanceToNextStep(YouTubeTutorialStep currentStep) {
    YouTubeTutorialStep? nextStep;

    switch (currentStep) {
      case YouTubeTutorialStep.step1:
        nextStep = YouTubeTutorialStep.tapMore;
        break;
      case YouTubeTutorialStep.tapMore:
        nextStep = YouTubeTutorialStep.tapEdit;
        break;
      case YouTubeTutorialStep.tapEdit:
        nextStep = YouTubeTutorialStep.tapSnaplookShortcut;
        break;
      case YouTubeTutorialStep.tapSnaplookShortcut:
        nextStep = YouTubeTutorialStep.tapDone;
        break;
      case YouTubeTutorialStep.tapDone:
        nextStep = YouTubeTutorialStep.tapDoneLast;
        break;
      case YouTubeTutorialStep.tapDoneLast:
        nextStep = YouTubeTutorialStep.step2;
        break;
      case YouTubeTutorialStep.step2:
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
      ref.read(youtubeTutorialStepProvider.notifier).state = nextStep;
      ref.read(youtubeTutorialPhaseProvider.notifier).state = YouTubeTutorialPhase.showingInstruction;
      ref.read(youtubeHasUserTappedProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = ref.watch(youtubeTutorialStepProvider);
    final currentPhase = ref.watch(youtubeTutorialPhaseProvider);
    final hasUserTapped = ref.watch(youtubeHasUserTappedProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Base screenshot
          Positioned.fill(
            child: Image.asset(
              'assets/images/youtube-1.png',
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),

          // Instruction overlay
          if (currentPhase == YouTubeTutorialPhase.showingInstruction)
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
                        if (currentStep == YouTubeTutorialStep.tapMore ||
                            currentStep == YouTubeTutorialStep.tapEdit ||
                            currentStep == YouTubeTutorialStep.tapSnaplookShortcut ||
                            currentStep == YouTubeTutorialStep.tapDone)
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
                        if (currentStep == YouTubeTutorialStep.tapMore ||
                            currentStep == YouTubeTutorialStep.tapEdit ||
                            currentStep == YouTubeTutorialStep.tapSnaplookShortcut ||
                            currentStep == YouTubeTutorialStep.tapDone)
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
