import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tutorial_image_analysis_page.dart';

const bool _kShowTouchTargets = false;

// Step 1 tap area placements
const double _step1TapAreaTopFraction = 0.87;
const double _step1TapAreaLeftFraction = 0.25;
const double _step1TapAreaWidthFraction = 0.20;
const double _step1TapAreaHeightFraction = 0.08;

// Step 2 tap area placements
const double _step2TapAreaTopFraction = 0.85;
const double _step2TapAreaLeftFraction = 0.5;
const double _step2TapAreaWidthFraction = 0.25;
const double _step2TapAreaHeightFraction = 0.12;

// Step 3 (tapMore) - centered bottom tap area
const double _tapMoreBottomFraction = 0.19;
const double _tapMoreLeftFraction = 0.77;
const double _tapMoreWidthFraction = 0.22;
const double _tapMoreHeightFraction = 0.1;

// Step 4 (tapEdit) - centered bottom tap area
const double _tapEditBottomFraction = 0.84;
const double _tapEditLeftFraction = 0.825;
const double _tapEditWidthFraction = 0.17;
const double _tapEditHeightFraction = 0.08;

// Step 5 (tapSnaplookShortcut) - centered tap area
const double _tapSnaplookShortcutBottomFraction = 0.48;
const double _tapSnaplookShortcutLeftFraction = 0.068;
const double _tapSnaplookShortcutWidthFraction = 0.12;
const double _tapSnaplookShortcutHeightFraction = 0.06;

// Step 6 (tapDone) - top right
const double _tapDoneTopFraction = 0.09;
const double _tapDoneRightFraction = 0.03;
const double _tapDoneWidthFraction = 0.15;
const double _tapDoneHeightFraction = 0.07;

// Step 3 tap area placements
const double _step3TapAreaTopFraction = 0.70;
const double _step3TapAreaLeftFraction = 0.45;
const double _step3TapAreaWidthFraction = 0.25;
const double _step3TapAreaHeightFraction = 0.12;

enum PinterestTutorialStep {
  step1,
  step2,
  tapMore,
  tapEdit,
  tapSnaplookShortcut,
  tapDone,
  step3,
}

enum TutorialPhase {
  showingInstruction,
  waitingForAction,
}

final pinterestTutorialStepProvider = StateProvider<PinterestTutorialStep>((ref) => PinterestTutorialStep.step1);
final pinterestTutorialPhaseProvider = StateProvider<TutorialPhase>((ref) => TutorialPhase.showingInstruction);
final pinterestHasUserTappedProvider = StateProvider<bool>((ref) => false);

class PinterestTutorialPage extends ConsumerStatefulWidget {
  final bool returnToOnboarding;

  const PinterestTutorialPage({
    super.key,
    this.returnToOnboarding = true,
  });

  @override
  ConsumerState<PinterestTutorialPage> createState() => _PinterestTutorialPageState();
}

class _PinterestTutorialPageState extends ConsumerState<PinterestTutorialPage> {
  @override
  void initState() {
    super.initState();
    // Reset to initial state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pinterestTutorialStepProvider.notifier).state = PinterestTutorialStep.step1;
      ref.read(pinterestTutorialPhaseProvider.notifier).state = TutorialPhase.showingInstruction;
      ref.read(pinterestHasUserTappedProvider.notifier).state = false;
    });
  }

  String _getInstructionText(PinterestTutorialStep step) {
    switch (step) {
      case PinterestTutorialStep.step1:
        return "When you find a clothing item you love on Pinterest, tap the share button.";
      case PinterestTutorialStep.step2:
        return "Now tap \"More apps\" to open the sharing options.";
      case PinterestTutorialStep.tapMore:
        return "This is a one-time setup to add Snaplook as a shortcut. Scroll to the right and tap 'More'.";
      case PinterestTutorialStep.tapEdit:
        return "Tap 'Edit'.";
      case PinterestTutorialStep.tapSnaplookShortcut:
        return "Find Snaplook and tap the '+' button to add it.";
      case PinterestTutorialStep.tapDone:
        return "Tap 'Done'.";
      case PinterestTutorialStep.step3:
        return "Finally, tap on Snaplook to share the image with our app.";
    }
  }

  bool _isOneTimeSetupStep(PinterestTutorialStep step) {
    return step == PinterestTutorialStep.tapMore ||
           step == PinterestTutorialStep.tapEdit ||
           step == PinterestTutorialStep.tapSnaplookShortcut ||
           step == PinterestTutorialStep.tapDone;
  }

  void _onInstructionComplete() {
    ref.read(pinterestTutorialPhaseProvider.notifier).state = TutorialPhase.waitingForAction;
    // Don't reset hasUserTapped here - we want to keep popups visible
  }

  void _onActionComplete(PinterestTutorialStep nextStep) {
    // Show instruction overlay first
    ref.read(pinterestTutorialStepProvider.notifier).state = nextStep;
    ref.read(pinterestTutorialPhaseProvider.notifier).state = TutorialPhase.showingInstruction;

    // Then show popup image after a brief delay (150ms) so overlay appears first
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        ref.read(pinterestHasUserTappedProvider.notifier).state = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = ref.watch(pinterestTutorialStepProvider);
    final currentPhase = ref.watch(pinterestTutorialPhaseProvider);
    final hasUserTapped = ref.watch(pinterestHasUserTappedProvider);
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full-screen Pinterest screenshot (step 1 - ALWAYS visible)
          Positioned.fill(
            child: Image.asset(
              'assets/images/pinterest_step1.png',
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),

          // Dark overlay when popup appears
          if (hasUserTapped && (currentStep == PinterestTutorialStep.step2 ||
              currentStep == PinterestTutorialStep.tapMore ||
              currentStep == PinterestTutorialStep.tapEdit ||
              currentStep == PinterestTutorialStep.tapSnaplookShortcut ||
              currentStep == PinterestTutorialStep.tapDone ||
              currentStep == PinterestTutorialStep.step3))
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.3),
              ),
            ),

          // Popup overlay for step 2 (after tapping share button)
          if (hasUserTapped && currentStep == PinterestTutorialStep.step2)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Image.asset(
                'assets/images/pinterest_step2.png',
                fit: BoxFit.fitWidth,
                gaplessPlayback: true,
              ),
            ),

          // Tap More overlay
          if (hasUserTapped && currentStep == PinterestTutorialStep.tapMore)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Image.asset(
                'assets/images/tap_more.png',
                fit: BoxFit.fitWidth,
                gaplessPlayback: true,
              ),
            ),

          // Tap Edit overlay
          if (hasUserTapped && currentStep == PinterestTutorialStep.tapEdit)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Image.asset(
                'assets/images/tap_edit.png',
                fit: BoxFit.fitWidth,
                gaplessPlayback: true,
              ),
            ),

          // Tap Snaplook Shortcut overlay
          if (hasUserTapped && currentStep == PinterestTutorialStep.tapSnaplookShortcut)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Image.asset(
                'assets/images/tap_snaplook.png',
                fit: BoxFit.fitWidth,
                gaplessPlayback: true,
              ),
            ),

          // Tap Done overlay
          if (hasUserTapped && currentStep == PinterestTutorialStep.tapDone)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Image.asset(
                'assets/images/tap_done.png',
                fit: BoxFit.fitWidth,
                gaplessPlayback: true,
              ),
            ),

          // Popup overlay for step 3 (final confirmation)
          if (hasUserTapped && currentStep == PinterestTutorialStep.step3)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Image.asset(
                'assets/images/tap_snaplook_last.png',
                fit: BoxFit.fitWidth,
                gaplessPlayback: true,
              ),
            ),

          // Step 1 tap area (tap share button)
          if (currentPhase == TutorialPhase.waitingForAction && currentStep == PinterestTutorialStep.step1)
            Positioned(
              top: screenHeight * _step1TapAreaTopFraction,
              left: screenWidth * _step1TapAreaLeftFraction,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _onActionComplete(PinterestTutorialStep.step2);
                },
                child: Container(
                  width: screenWidth * _step1TapAreaWidthFraction,
                  height: screenHeight * _step1TapAreaHeightFraction,
                  decoration: BoxDecoration(
                    color: _kShowTouchTargets ? Colors.red.withValues(alpha: 0.25) : Colors.transparent,
                    border: _kShowTouchTargets ? Border.all(color: Colors.redAccent) : null,
                  ),
                ),
              ),
            ),

          // Step 2 tap area (tap Share option) - only active when popup is visible
          if (hasUserTapped && currentPhase == TutorialPhase.waitingForAction && currentStep == PinterestTutorialStep.step2)
            Positioned(
              top: screenHeight * _step2TapAreaTopFraction,
              left: screenWidth * _step2TapAreaLeftFraction,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _onActionComplete(PinterestTutorialStep.tapMore);
                },
                child: Container(
                  width: screenWidth * _step2TapAreaWidthFraction,
                  height: screenHeight * _step2TapAreaHeightFraction,
                  decoration: BoxDecoration(
                    color: _kShowTouchTargets ? Colors.red.withValues(alpha: 0.25) : Colors.transparent,
                    border: _kShowTouchTargets ? Border.all(color: Colors.redAccent) : null,
                  ),
                ),
              ),
            ),

          // Tap More area
          if (hasUserTapped && currentPhase == TutorialPhase.waitingForAction && currentStep == PinterestTutorialStep.tapMore)
            Positioned(
              bottom: screenHeight * _tapMoreBottomFraction,
              left: screenWidth * _tapMoreLeftFraction,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _onActionComplete(PinterestTutorialStep.tapEdit);
                },
                child: Container(
                  width: screenWidth * _tapMoreWidthFraction,
                  height: screenHeight * _tapMoreHeightFraction,
                  decoration: BoxDecoration(
                    color: _kShowTouchTargets ? Colors.red.withValues(alpha: 0.25) : Colors.transparent,
                    border: _kShowTouchTargets ? Border.all(color: Colors.redAccent) : null,
                  ),
                ),
              ),
            ),

          // Tap Edit area
          if (hasUserTapped && currentPhase == TutorialPhase.waitingForAction && currentStep == PinterestTutorialStep.tapEdit)
            Positioned(
              bottom: screenHeight * _tapEditBottomFraction,
              left: screenWidth * _tapEditLeftFraction,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _onActionComplete(PinterestTutorialStep.tapSnaplookShortcut);
                },
                child: Container(
                  width: screenWidth * _tapEditWidthFraction,
                  height: screenHeight * _tapEditHeightFraction,
                  decoration: BoxDecoration(
                    color: _kShowTouchTargets ? Colors.red.withValues(alpha: 0.25) : Colors.transparent,
                    border: _kShowTouchTargets ? Border.all(color: Colors.redAccent) : null,
                  ),
                ),
              ),
            ),

          // Tap Snaplook Shortcut area
          if (hasUserTapped && currentPhase == TutorialPhase.waitingForAction && currentStep == PinterestTutorialStep.tapSnaplookShortcut)
            Positioned(
              bottom: screenHeight * _tapSnaplookShortcutBottomFraction,
              left: screenWidth * _tapSnaplookShortcutLeftFraction,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _onActionComplete(PinterestTutorialStep.tapDone);
                },
                child: Container(
                  width: screenWidth * _tapSnaplookShortcutWidthFraction,
                  height: screenHeight * _tapSnaplookShortcutHeightFraction,
                  decoration: BoxDecoration(
                    color: _kShowTouchTargets ? Colors.red.withValues(alpha: 0.25) : Colors.transparent,
                    border: _kShowTouchTargets ? Border.all(color: Colors.redAccent) : null,
                  ),
                ),
              ),
            ),

          // Tap Done area
          if (hasUserTapped && currentPhase == TutorialPhase.waitingForAction && currentStep == PinterestTutorialStep.tapDone)
            Positioned(
              top: screenHeight * _tapDoneTopFraction,
              right: screenWidth * _tapDoneRightFraction,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _onActionComplete(PinterestTutorialStep.step3);
                },
                child: Container(
                  width: screenWidth * _tapDoneWidthFraction,
                  height: screenHeight * _tapDoneHeightFraction,
                  decoration: BoxDecoration(
                    color: _kShowTouchTargets ? Colors.red.withValues(alpha: 0.25) : Colors.transparent,
                    border: _kShowTouchTargets ? Border.all(color: Colors.redAccent) : null,
                  ),
                ),
              ),
            ),

          // Step 3 tap area (tap Snaplook) - only active when popup is visible
          if (hasUserTapped && currentPhase == TutorialPhase.waitingForAction && currentStep == PinterestTutorialStep.step3)
            Positioned(
              top: screenHeight * _step3TapAreaTopFraction,
              left: screenWidth * _step3TapAreaLeftFraction,
              child: GestureDetector(
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  // Precache the image before navigating
                  await precacheImage(
                    const AssetImage('assets/images/pinterest_tutorial.jpg'),
                    context,
                  );
                  if (!mounted) return;
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => TutorialImageAnalysisPage(
                        imagePath: 'assets/images/pinterest_tutorial.jpg',
                        scenario: 'Pinterest',
                        returnToOnboarding: widget.returnToOnboarding,
                      ),
                      allowSnapshotting: false,
                    ),
                  );
                },
                child: Container(
                  width: screenWidth * _step3TapAreaWidthFraction,
                  height: screenHeight * _step3TapAreaHeightFraction,
                  decoration: BoxDecoration(
                    color: _kShowTouchTargets ? Colors.red.withValues(alpha: 0.25) : Colors.transparent,
                    border: _kShowTouchTargets ? Border.all(color: Colors.redAccent) : null,
                  ),
                ),
              ),
            ),

          // Instruction overlay (shows during instruction phase)
          if (currentPhase == TutorialPhase.showingInstruction)
            _InstructionOverlay(
              text: _getInstructionText(currentStep),
              onComplete: _onInstructionComplete,
            ),

          // One-time setup indicator (shows during all 4 setup steps, stays above overlay)
          if (_isOneTimeSetupStep(currentStep))
            Positioned(
              bottom: 60.0,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: const Color(0xFFf2003c),
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'One-time setup',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          color: const Color(0xFFf2003c),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Animated instruction overlay with streaming text effect
class _InstructionOverlay extends StatefulWidget {
  final String text;
  final VoidCallback onComplete;

  const _InstructionOverlay({
    required this.text,
    required this.onComplete,
  });

  @override
  State<_InstructionOverlay> createState() => _InstructionOverlayState();
}

class _InstructionOverlayState extends State<_InstructionOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  final _streamController = StreamController<String>();
  final List<String> _words = [];
  late final List<String> _tokens;
  late final Timer _timer;
  int _currentIndex = 0;
  bool _hasCompleted = false;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _fadeController.forward();

    // Split text into words
    _tokens = widget.text.split(RegExp(r'\s+'));

    // Stream words one by one
    _timer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (_currentIndex >= _tokens.length) {
        timer.cancel();
        _streamController.close();
        _onStreamingComplete();
        return;
      }
      _streamController.add(_tokens[_currentIndex++]);
    });

    // Listen to stream and update words list
    _streamController.stream.listen((word) {
      if (mounted) {
        setState(() => _words.add(word));
      }
    });
  }

  void _onStreamingComplete() {
    // Wait 2 seconds after streaming completes for reading
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (!mounted || _hasCompleted) return;
      _completeWithFade();
    });
  }

  void _handleTapToDismiss() {
    _completeWithFade(fadeDuration: const Duration(milliseconds: 200));
  }

  void _completeWithFade({Duration fadeDuration = const Duration(milliseconds: 800)}) {
    if (_hasCompleted) return;
    _hasCompleted = true;

    if (_timer.isActive) {
      _timer.cancel();
    }
    if (!_streamController.isClosed) {
      _streamController.close();
    }

    _fadeController
        .animateTo(
      0.0,
      duration: fadeDuration,
      curve: Curves.easeOut,
    )
        .then((_) {
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    if (!_streamController.isClosed) {
      _streamController.close();
    }
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTapToDismiss,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          color: Colors.black.withValues(alpha: 0.70),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Wrap(
                alignment: WrapAlignment.center,
                children: List.generate(_words.length, (index) {
                  return _FadeInWord(
                    key: ValueKey('word_$index'),
                    word: _words[index],
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Widget that fades in each word individually
class _FadeInWord extends StatefulWidget {
  final String word;

  const _FadeInWord({
    super.key,
    required this.word,
  });

  @override
  State<_FadeInWord> createState() => _FadeInWordState();
}

class _FadeInWordState extends State<_FadeInWord>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..forward();
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Padding(
        padding: const EdgeInsets.only(right: 5.0),
        child: Text(
          widget.word,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
