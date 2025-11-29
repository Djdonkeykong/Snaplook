import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tutorial_image_analysis_page.dart';

const bool _kShowTouchTargets = false;

// Step 1 (share button) placements
const double _step1BottomFraction = 0.01;
const double _step1LeftFraction = 0.33;
const double _step1WidthFraction = 0.26;
const double _step1HeightFraction = 0.12;

// Step 2 (tapMore) placements
const double _tapMoreBottomFraction = 0.16;
const double _tapMoreLeftFraction = 0.72;
const double _tapMoreWidthFraction = 0.3;
const double _tapMoreHeightFraction = 0.15;

// Step 3 (tapEdit) placements
const double _tapEditBottomFraction = 0.82;
const double _tapEditRightFraction = 0.0;
const double _tapEditWidthFraction = 0.2;
const double _tapEditHeightFraction = 0.12;

// Step 4 (tapSnaplookShortcut) placements
const double _tapSnaplookShortcutBottomFraction = 0.47;
const double _tapSnaplookShortcutLeftFraction = 0.035;
const double _tapSnaplookShortcutWidthFraction = 0.18;
const double _tapSnaplookShortcutHeightFraction = 0.08;

// Step 5 (tapDone) placements - top positioning
const double _tapDoneTopFraction = 0;
const double _tapDoneRightFraction = 0;
const double _tapDoneWidthFraction = 0.2;
const double _tapDoneHeightFraction = 0.13;

// Step 6 (final selection) placements
const double _finalSelectBottomFraction = 0.17;
const double _finalSelectLeftFraction = 0.45;
const double _finalSelectWidthFraction = 0.25;
const double _finalSelectHeightFraction = 0.13;

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

  bool _isOneTimeSetupStep(FacebookTutorialStep step) {
    return step == FacebookTutorialStep.tapMore ||
           step == FacebookTutorialStep.tapEdit ||
           step == FacebookTutorialStep.tapSnaplookShortcut ||
           step == FacebookTutorialStep.tapDone;
  }

  void _onInstructionComplete() {
    ref.read(facebookTutorialPhaseProvider.notifier).state = FacebookTutorialPhase.waitingForAction;
  }

  void _onActionComplete(FacebookTutorialStep nextStep) {
    ref.read(facebookTutorialStepProvider.notifier).state = nextStep;
    ref.read(facebookTutorialPhaseProvider.notifier).state = FacebookTutorialPhase.showingInstruction;

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        ref.read(facebookHasUserTappedProvider.notifier).state = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = ref.watch(facebookTutorialStepProvider);
    final currentPhase = ref.watch(facebookTutorialPhaseProvider);
    final hasUserTapped = ref.watch(facebookHasUserTappedProvider);
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Base screenshot (ALWAYS visible)
          Positioned.fill(
            child: Image.asset(
              'assets/images/facebook-1.png',
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),

          // Dark overlay when popup appears
          if (hasUserTapped && (currentStep == FacebookTutorialStep.tapMore ||
              currentStep == FacebookTutorialStep.tapEdit ||
              currentStep == FacebookTutorialStep.tapSnaplookShortcut ||
              currentStep == FacebookTutorialStep.tapDone ||
              currentStep == FacebookTutorialStep.step2))
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
              ),
            ),

          // Step 2 overlay - after tapping share button
          if (hasUserTapped && currentStep == FacebookTutorialStep.tapMore)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Image.asset(
                'assets/images/tap-more.png',
                fit: BoxFit.fitWidth,
                gaplessPlayback: true,
              ),
            ),

          // Step 3 overlay - after tapping More
          if (hasUserTapped && currentStep == FacebookTutorialStep.tapEdit)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Image.asset(
                'assets/images/tap-edit.png',
                fit: BoxFit.fitWidth,
                gaplessPlayback: true,
              ),
            ),

          // Step 4 overlay - after tapping Edit
          if (hasUserTapped && currentStep == FacebookTutorialStep.tapSnaplookShortcut)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Image.asset(
                'assets/images/tap-snaplook.png',
                fit: BoxFit.fitWidth,
                gaplessPlayback: true,
              ),
            ),

          // Step 5 overlay - after tapping Snaplook shortcut
          if (hasUserTapped && currentStep == FacebookTutorialStep.tapDone)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Image.asset(
                'assets/images/tap-done.png',
                fit: BoxFit.fitWidth,
                gaplessPlayback: true,
              ),
            ),

          // Final step overlay - after tapping Done
          if (hasUserTapped && currentStep == FacebookTutorialStep.step2)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Image.asset(
                'assets/images/tap-snaplook-last.png',
                fit: BoxFit.fitWidth,
                gaplessPlayback: true,
              ),
            ),

          // Tap area for step1 - share button
          if (currentPhase == FacebookTutorialPhase.waitingForAction && currentStep == FacebookTutorialStep.step1)
            Positioned(
              bottom: screenHeight * _step1BottomFraction,
              left: screenWidth * _step1LeftFraction,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _onActionComplete(FacebookTutorialStep.tapMore);
                },
                child: Container(
                  width: screenWidth * _step1WidthFraction,
                  height: screenHeight * _step1HeightFraction,
                  decoration: BoxDecoration(
                    color: _kShowTouchTargets ? Colors.red.withValues(alpha: 0.25) : Colors.transparent,
                    border: _kShowTouchTargets ? Border.all(color: Colors.redAccent) : null,
                  ),
                ),
              ),
            ),

          // Tap area for tapMore - More button
          if (hasUserTapped && currentPhase == FacebookTutorialPhase.waitingForAction && currentStep == FacebookTutorialStep.tapMore)
            Positioned(
              bottom: screenHeight * _tapMoreBottomFraction,
              left: screenWidth * _tapMoreLeftFraction,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _onActionComplete(FacebookTutorialStep.tapEdit);
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

          // Tap area for tapEdit - Edit button
          if (hasUserTapped && currentPhase == FacebookTutorialPhase.waitingForAction && currentStep == FacebookTutorialStep.tapEdit)
            Positioned(
              bottom: screenHeight * _tapEditBottomFraction,
              right: screenWidth * _tapEditRightFraction,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _onActionComplete(FacebookTutorialStep.tapSnaplookShortcut);
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

          // Tap area for tapSnaplookShortcut - Snaplook icon
          if (hasUserTapped && currentPhase == FacebookTutorialPhase.waitingForAction && currentStep == FacebookTutorialStep.tapSnaplookShortcut)
            Positioned(
              bottom: screenHeight * _tapSnaplookShortcutBottomFraction,
              left: screenWidth * _tapSnaplookShortcutLeftFraction,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _onActionComplete(FacebookTutorialStep.tapDone);
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

          // Tap area for tapDone - Done button
          if (hasUserTapped && currentPhase == FacebookTutorialPhase.waitingForAction && currentStep == FacebookTutorialStep.tapDone)
            Positioned(
              top: MediaQuery.of(context).padding.top + screenHeight * _tapDoneTopFraction,
              right: screenWidth * _tapDoneRightFraction,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _onActionComplete(FacebookTutorialStep.step2);
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

          // Tap area for step2 - final Snaplook selection
          if (hasUserTapped && currentPhase == FacebookTutorialPhase.waitingForAction && currentStep == FacebookTutorialStep.step2)
            Positioned(
              bottom: screenHeight * _finalSelectBottomFraction,
              left: screenWidth * _finalSelectLeftFraction,
              child: GestureDetector(
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  await precacheImage(
                    const AssetImage('assets/images/facebook-analysis.png'),
                    context,
                  );
                  if (!mounted) return;
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => TutorialImageAnalysisPage(
                        returnToOnboarding: widget.returnToOnboarding,
                        imagePath: 'assets/images/facebook-analysis.png',
                        scenario: 'Facebook',
                      ),
                    ),
                  );
                },
                child: Container(
                  width: screenWidth * _finalSelectWidthFraction,
                  height: screenHeight * _finalSelectHeightFraction,
                  decoration: BoxDecoration(
                    color: _kShowTouchTargets ? Colors.red.withValues(alpha: 0.25) : Colors.transparent,
                    border: _kShowTouchTargets ? Border.all(color: Colors.redAccent) : null,
                  ),
                ),
              ),
            ),

          // Instruction overlay
          if (currentPhase == FacebookTutorialPhase.showingInstruction)
            _InstructionOverlay(
              text: _getInstructionText(currentStep),
              onComplete: _onInstructionComplete,
            ),

          // One-time setup indicator
          if (_isOneTimeSetupStep(currentStep))
            Positioned(
              top: currentStep == FacebookTutorialStep.tapMore ? MediaQuery.of(context).padding.top + 20 : null,
              bottom: currentStep == FacebookTutorialStep.tapMore ? null : 60.0,
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
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontFamily: 'PlusJakartaSans',
            letterSpacing: -0.3,
          ),
        ),
      ),
    );
  }
}
