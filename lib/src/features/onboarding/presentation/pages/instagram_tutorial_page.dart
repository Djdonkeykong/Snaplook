import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tutorial_image_analysis_page.dart';

const bool _kShowTouchTargets = false;

// Step 2 (tapShare) placements
const double _shareTapAreaBottomFraction = 0.21;
const double _shareTapAreaLeftFraction = 0.85;
const double _shareTapAreaWidthFraction = 0.15;
const double _shareTapAreaHeightFraction = 0.08;

// Step 3 (selectSnaplook) placements
const double _selectTapAreaBottomFraction = 0.084;
const double _selectTapAreaLeftFraction = 0.012077294685990338;
const double _selectTapAreaWidthFraction = 0.2;
const double _selectTapAreaHeightFraction = 0.1;

// Step 4 (confirmShare) placements
const double _confirmTapAreaBottomFraction = 0.17;
const double _confirmTapAreaRightFraction = 0.315;
const double _confirmTapAreaWidthFraction = 0.23;
const double _confirmTapAreaHeightFraction = 0.125;

enum TutorialStep {
  tapShare,
  selectSnaplook,
  confirmShare,
}

enum TutorialPhase {
  showingInstruction,
  waitingForAction,
}

final tutorialStepProvider = StateProvider<TutorialStep>((ref) => TutorialStep.tapShare);
final tutorialPhaseProvider = StateProvider<TutorialPhase>((ref) => TutorialPhase.showingInstruction);
final hasUserTappedProvider = StateProvider<bool>((ref) => false);

class InstagramTutorialPage extends ConsumerStatefulWidget {
  final bool returnToOnboarding;

  const InstagramTutorialPage({
    super.key,
    this.returnToOnboarding = true,
  });

  @override
  ConsumerState<InstagramTutorialPage> createState() => _InstagramTutorialPageState();
}

class _InstagramTutorialPageState extends ConsumerState<InstagramTutorialPage> {
  @override
  void initState() {
    super.initState();
    // Reset to initial state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tutorialStepProvider.notifier).state = TutorialStep.tapShare;
      ref.read(tutorialPhaseProvider.notifier).state = TutorialPhase.showingInstruction;
      ref.read(hasUserTappedProvider.notifier).state = false;
    });
  }

  String _getInstructionText(TutorialStep step) {
    switch (step) {
      case TutorialStep.tapShare:
        return "When you find a clothing item you love on Instagram, tap the share button at the bottom.";
      case TutorialStep.selectSnaplook:
        return "Now tap \"Share to\" to open the sharing options.";
      case TutorialStep.confirmShare:
        return "Tap Snaplook to share the image with our app.";
    }
  }

  void _onInstructionComplete() {
    ref.read(tutorialPhaseProvider.notifier).state = TutorialPhase.waitingForAction;
    // Don't reset hasUserTapped here - we want to keep popups visible
  }

  void _onActionComplete(TutorialStep nextStep) {
    // Show instruction overlay first
    ref.read(tutorialStepProvider.notifier).state = nextStep;
    ref.read(tutorialPhaseProvider.notifier).state = TutorialPhase.showingInstruction;

    // Then show popup image after a brief delay (150ms) so overlay appears first
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        ref.read(hasUserTappedProvider.notifier).state = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = ref.watch(tutorialStepProvider);
    final currentPhase = ref.watch(tutorialPhaseProvider);
    final hasUserTapped = ref.watch(hasUserTappedProvider);
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full-screen Instagram screenshot (ALWAYS visible)
          Positioned.fill(
            child: Image.asset(
              'assets/images/instagram_step1_updated.png',
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),

          // Dark overlay when popup appears
          if (hasUserTapped && (currentStep == TutorialStep.selectSnaplook || currentStep == TutorialStep.confirmShare))
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
              ),
            ),

          // Share popup overlay for step 2 (after tapping share button)
          if (hasUserTapped && currentStep == TutorialStep.selectSnaplook)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Image.asset(
                'assets/images/instagram_popup.png',
                fit: BoxFit.fitWidth,
                gaplessPlayback: true,
              ),
            ),

          // Step 3 popup overlay (after tapping Snaplook)
          if (hasUserTapped && currentStep == TutorialStep.confirmShare)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Image.asset(
                'assets/images/instagram_step3_popup.png',
                fit: BoxFit.fitWidth,
                gaplessPlayback: true,
              ),
            ),

          // Share button tap area (tapShare step)
          if (currentPhase == TutorialPhase.waitingForAction && currentStep == TutorialStep.tapShare)
            Positioned(
              bottom: screenHeight * _shareTapAreaBottomFraction,
              left: screenWidth * _shareTapAreaLeftFraction,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _onActionComplete(TutorialStep.selectSnaplook);
                },
                child: Container(
                  width: screenWidth * _shareTapAreaWidthFraction,
                  height: screenHeight * _shareTapAreaHeightFraction,
                  decoration: BoxDecoration(
                    color: _kShowTouchTargets ? Colors.red.withValues(alpha: 0.25) : Colors.transparent,
                    border: _kShowTouchTargets ? Border.all(color: Colors.redAccent) : null,
                  ),
                ),
              ),
            ),

          // Snaplook selection tap area (selectSnaplook step) - only active when popup is visible
          if (hasUserTapped && currentPhase == TutorialPhase.waitingForAction && currentStep == TutorialStep.selectSnaplook)
            Positioned(
              bottom: screenHeight * _selectTapAreaBottomFraction,
              left: screenWidth * _selectTapAreaLeftFraction,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _onActionComplete(TutorialStep.confirmShare);
                },
                child: Container(
                  width: screenWidth * _selectTapAreaWidthFraction,
                  height: screenHeight * _selectTapAreaHeightFraction,
                  decoration: BoxDecoration(
                    color: _kShowTouchTargets ? Colors.red.withValues(alpha: 0.25) : Colors.transparent,
                    border: _kShowTouchTargets ? Border.all(color: Colors.redAccent) : null,
                  ),
                ),
              ),
            ),

          // Confirm share tap area (confirmShare step) - only active when popup is visible
          if (hasUserTapped && currentPhase == TutorialPhase.waitingForAction && currentStep == TutorialStep.confirmShare)
            Positioned(
              bottom: screenHeight * _confirmTapAreaBottomFraction,
              right: screenWidth * _confirmTapAreaRightFraction,
              child: GestureDetector(
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  // Precache the image before navigating
                  await precacheImage(
                    const AssetImage('assets/images/tutorial_analysis_image_2.jpg'),
                    context,
                  );
                  if (!mounted) return;
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => TutorialImageAnalysisPage(
                        scenario: 'Instagram',
                        returnToOnboarding: widget.returnToOnboarding,
                      ),
                      allowSnapshotting: false,
                    ),
                  );
                },
                child: Container(
                  width: screenWidth * _confirmTapAreaWidthFraction,
                  height: screenHeight * _confirmTapAreaHeightFraction,
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
      if (mounted) {
        _fadeController.reverse().then((_) {
          if (mounted) {
            widget.onComplete();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _streamController.close();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
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
