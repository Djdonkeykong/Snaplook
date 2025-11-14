import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tutorial_image_analysis_page.dart';

const bool _kShowTouchTargets = false;

// Step 1 tap area placements
const double _step1TapAreaTopFraction = 0.9;
const double _step1TapAreaLeftFraction = 0.03;
const double _step1TapAreaWidthFraction = 0.20;
const double _step1TapAreaHeightFraction = 0.08;

// Step 2 tap area placements
const double _step2TapAreaTopFraction = 0.73;
const double _step2TapAreaLeftFraction = 0.22;
const double _step2TapAreaWidthFraction = 0.25;
const double _step2TapAreaHeightFraction = 0.12;

enum PhotosTutorialStep {
  step1,
  step2,
}

enum TutorialPhase {
  showingInstruction,
  waitingForAction,
}

final photosTutorialStepProvider = StateProvider<PhotosTutorialStep>((ref) => PhotosTutorialStep.step1);
final photosTutorialPhaseProvider = StateProvider<TutorialPhase>((ref) => TutorialPhase.showingInstruction);
final photosHasUserTappedProvider = StateProvider<bool>((ref) => false);

class PhotosTutorialPage extends ConsumerStatefulWidget {
  final bool returnToOnboarding;

  const PhotosTutorialPage({
    super.key,
    this.returnToOnboarding = true,
  });

  @override
  ConsumerState<PhotosTutorialPage> createState() => _PhotosTutorialPageState();
}

class _PhotosTutorialPageState extends ConsumerState<PhotosTutorialPage> {
  @override
  void initState() {
    super.initState();
    // Reset to initial state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(photosTutorialStepProvider.notifier).state = PhotosTutorialStep.step1;
      ref.read(photosTutorialPhaseProvider.notifier).state = TutorialPhase.showingInstruction;
      ref.read(photosHasUserTappedProvider.notifier).state = false;
    });
  }

  String _getInstructionText(PhotosTutorialStep step) {
    switch (step) {
      case PhotosTutorialStep.step1:
        return "When you find a clothing item you love in your Photos, tap the share icon.";
      case PhotosTutorialStep.step2:
        return "Now tap on Snaplook to share the image with our app.";
    }
  }

  void _onInstructionComplete() {
    ref.read(photosTutorialPhaseProvider.notifier).state = TutorialPhase.waitingForAction;
    // Don't reset hasUserTapped here - we want to keep popups visible
  }

  void _onActionComplete(PhotosTutorialStep nextStep) {
    // Set flag to show popup immediately after tap
    ref.read(photosHasUserTappedProvider.notifier).state = true;

    // Wait briefly to show the popup, then show next instruction
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        ref.read(photosTutorialStepProvider.notifier).state = nextStep;
        ref.read(photosTutorialPhaseProvider.notifier).state = TutorialPhase.showingInstruction;
        // Keep hasUserTapped true so popup stays visible during instruction
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = ref.watch(photosTutorialStepProvider);
    final currentPhase = ref.watch(photosTutorialPhaseProvider);
    final hasUserTapped = ref.watch(photosHasUserTappedProvider);
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full-screen Photos screenshot (step 1 - ALWAYS visible)
          Positioned.fill(
            child: Image.asset(
              'assets/images/photos_step1.png',
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),

          // Dark overlay when popup appears
          if (hasUserTapped && currentStep == PhotosTutorialStep.step2)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.3),
              ),
            ),

          // Popup overlay for step 2 (after tapping photo)
          if (hasUserTapped && currentStep == PhotosTutorialStep.step2)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Image.asset(
                'assets/images/photos_step2.png',
                fit: BoxFit.fitWidth,
                gaplessPlayback: true,
              ),
            ),

          // Step 1 tap area (tap on photo)
          if (currentPhase == TutorialPhase.waitingForAction && currentStep == PhotosTutorialStep.step1)
            Positioned(
              top: screenHeight * _step1TapAreaTopFraction,
              left: screenWidth * _step1TapAreaLeftFraction,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _onActionComplete(PhotosTutorialStep.step2);
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

          // Step 2 tap area (tap share button) - only active when popup is visible
          if (hasUserTapped && currentPhase == TutorialPhase.waitingForAction && currentStep == PhotosTutorialStep.step2)
            Positioned(
              top: screenHeight * _step2TapAreaTopFraction,
              left: screenWidth * _step2TapAreaLeftFraction,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => TutorialImageAnalysisPage(
                        imagePath: 'assets/images/photos_tutorial.jpg',
                        scenario: 'Photos',
                        returnToOnboarding: widget.returnToOnboarding,
                      ),
                      allowSnapshotting: false,
                    ),
                  );
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
