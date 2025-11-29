import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tutorial_image_analysis_page.dart';

const bool _kShowTouchTargets = true;

// Step 1 (share button) placements
const double _step1BottomFraction = 0.9;
const double _step1LeftFraction = 0.9;
const double _step1WidthFraction = 0.1;
const double _step1HeightFraction = 0.05;

// Step 2 (tapShare) placements
const double _tapShareBottomFraction = 0.06;
const double _tapShareLeftFraction = 0;
const double _tapShareWidthFraction = 1;
const double _tapShareHeightFraction = 0.05;

// Step 3 (tapMore) placements - scroll right and tap More
const double _tapMoreBottomFraction = 0.185;
const double _tapMoreLeftFraction = 0.77;
const double _tapMoreWidthFraction = 0.22;
const double _tapMoreHeightFraction = 0.12;

// Step 4 (tapEdit) placements
const double _tapEditBottomFraction = 0.84;
const double _tapEditRightFraction = 0.015;
const double _tapEditWidthFraction = 0.14;
const double _tapEditHeightFraction = 0.065;

// Step 5 (tapSnaplookShortcut) placements
const double _tapSnaplookShortcutBottomFraction = 0.475;
const double _tapSnaplookShortcutLeftFraction = 0.06;
const double _tapSnaplookShortcutWidthFraction = 0.13;
const double _tapSnaplookShortcutHeightFraction = 0.07;

// Step 6 (tapDone) placements - top positioning
const double _tapDoneTopPadding = 40.0;
const double _tapDoneRightFraction = 0.02;
const double _tapDoneWidthFraction = 0.165;
const double _tapDoneHeightFraction = 0.065;

// Step 7 (final selection) placements
const double _finalSelectBottomFraction = 0.17;
const double _finalSelectLeftFraction = 0.44;
const double _finalSelectWidthFraction = 0.26;
const double _finalSelectHeightFraction = 0.13;

enum ImdbTutorialStep {
  step1,
  tapShare,
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
      case ImdbTutorialStep.tapShare:
        return "Now tap the Share button to see additional sharing options.";
      case ImdbTutorialStep.tapMore:
        return "This is a one-time setup to add Snaplook as a shortcut. Scroll to the right and tap 'More'.";
      case ImdbTutorialStep.tapEdit:
        return "Tap 'Edit'.";
      case ImdbTutorialStep.tapSnaplookShortcut:
        return "Find Snaplook and tap the '+' button to add it.";
      case ImdbTutorialStep.tapDone:
        return "Tap 'Done'.";
      case ImdbTutorialStep.step2:
        return "Now tap Snaplook to share the image with our app.";
    }
  }

  bool _isOneTimeSetupStep(ImdbTutorialStep step) {
    return step == ImdbTutorialStep.tapMore ||
           step == ImdbTutorialStep.tapEdit ||
           step == ImdbTutorialStep.tapSnaplookShortcut ||
           step == ImdbTutorialStep.tapDone;
  }

  void _onInstructionComplete() {
    ref.read(imdbTutorialPhaseProvider.notifier).state = ImdbTutorialPhase.waitingForAction;
  }

  void _onActionComplete(ImdbTutorialStep nextStep) {
    ref.read(imdbTutorialStepProvider.notifier).state = nextStep;
    ref.read(imdbTutorialPhaseProvider.notifier).state = ImdbTutorialPhase.showingInstruction;

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        ref.read(imdbHasUserTappedProvider.notifier).state = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = ref.watch(imdbTutorialStepProvider);
    final currentPhase = ref.watch(imdbTutorialPhaseProvider);
    final hasUserTapped = ref.watch(imdbHasUserTappedProvider);
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
              'assets/images/imdb-1.png',
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),

          // Dark overlay when popup appears
          if (hasUserTapped && (currentStep == ImdbTutorialStep.tapShare ||
              currentStep == ImdbTutorialStep.tapMore ||
              currentStep == ImdbTutorialStep.tapEdit ||
              currentStep == ImdbTutorialStep.tapSnaplookShortcut ||
              currentStep == ImdbTutorialStep.tapDone ||
              currentStep == ImdbTutorialStep.step2))
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
              ),
            ),

          // Step 2 overlay - after tapping share button (shows Share sheet)
          if (hasUserTapped && currentStep == ImdbTutorialStep.tapShare)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Image.asset(
                'assets/images/imdb-step-2.png',
                fit: BoxFit.fitWidth,
                gaplessPlayback: true,
              ),
            ),

          // Step 3 overlay - after tapping Share (shows More button)
          if (hasUserTapped && currentStep == ImdbTutorialStep.tapMore)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Image.asset(
                'assets/images/imdb-step-3.png',
                fit: BoxFit.fitWidth,
                gaplessPlayback: true,
              ),
            ),

          // Step 4 overlay - after tapping More
          if (hasUserTapped && currentStep == ImdbTutorialStep.tapEdit)
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

          // Step 5 overlay - after tapping Edit
          if (hasUserTapped && currentStep == ImdbTutorialStep.tapSnaplookShortcut)
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

          // Step 6 overlay - after tapping Snaplook shortcut
          if (hasUserTapped && currentStep == ImdbTutorialStep.tapDone)
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

          // Step 7 overlay - after tapping Done (final step)
          if (hasUserTapped && currentStep == ImdbTutorialStep.step2)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Image.asset(
                'assets/images/imdb-step-last.png',
                fit: BoxFit.fitWidth,
                gaplessPlayback: true,
              ),
            ),

          // Tap area for step1 - share button
          if (currentPhase == ImdbTutorialPhase.waitingForAction && currentStep == ImdbTutorialStep.step1)
            Positioned(
              bottom: screenHeight * _step1BottomFraction,
              left: screenWidth * _step1LeftFraction,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _onActionComplete(ImdbTutorialStep.tapShare);
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

          // Tap area for tapShare - Share button
          if (hasUserTapped && currentPhase == ImdbTutorialPhase.waitingForAction && currentStep == ImdbTutorialStep.tapShare)
            Positioned(
              bottom: screenHeight * _tapShareBottomFraction,
              left: screenWidth * _tapShareLeftFraction,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _onActionComplete(ImdbTutorialStep.tapMore);
                },
                child: Container(
                  width: screenWidth * _tapShareWidthFraction,
                  height: screenHeight * _tapShareHeightFraction,
                  decoration: BoxDecoration(
                    color: _kShowTouchTargets ? Colors.red.withValues(alpha: 0.25) : Colors.transparent,
                    border: _kShowTouchTargets ? Border.all(color: Colors.redAccent) : null,
                  ),
                ),
              ),
            ),

          // Tap area for tapMore - More button (scroll right)
          if (hasUserTapped && currentPhase == ImdbTutorialPhase.waitingForAction && currentStep == ImdbTutorialStep.tapMore)
            Positioned(
              bottom: screenHeight * _tapMoreBottomFraction,
              left: screenWidth * _tapMoreLeftFraction,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _onActionComplete(ImdbTutorialStep.tapEdit);
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
          if (hasUserTapped && currentPhase == ImdbTutorialPhase.waitingForAction && currentStep == ImdbTutorialStep.tapEdit)
            Positioned(
              bottom: screenHeight * _tapEditBottomFraction,
              right: screenWidth * _tapEditRightFraction,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _onActionComplete(ImdbTutorialStep.tapSnaplookShortcut);
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
          if (hasUserTapped && currentPhase == ImdbTutorialPhase.waitingForAction && currentStep == ImdbTutorialStep.tapSnaplookShortcut)
            Positioned(
              bottom: screenHeight * _tapSnaplookShortcutBottomFraction,
              left: screenWidth * _tapSnaplookShortcutLeftFraction,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _onActionComplete(ImdbTutorialStep.tapDone);
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
          if (hasUserTapped && currentPhase == ImdbTutorialPhase.waitingForAction && currentStep == ImdbTutorialStep.tapDone)
            Positioned(
              top: MediaQuery.of(context).padding.top + _tapDoneTopPadding,
              right: screenWidth * _tapDoneRightFraction,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _onActionComplete(ImdbTutorialStep.step2);
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
          if (hasUserTapped && currentPhase == ImdbTutorialPhase.waitingForAction && currentStep == ImdbTutorialStep.step2)
            Positioned(
              bottom: screenHeight * _finalSelectBottomFraction,
              left: screenWidth * _finalSelectLeftFraction,
              child: GestureDetector(
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  await precacheImage(
                    const AssetImage('assets/images/imdb-analysis.jpg'),
                    context,
                  );
                  if (!mounted) return;
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => TutorialImageAnalysisPage(
                        returnToOnboarding: widget.returnToOnboarding,
                        imagePath: 'assets/images/imdb-analysis.jpg',
                        scenario: 'IMDb',
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
          if (currentPhase == ImdbTutorialPhase.showingInstruction)
            _InstructionOverlay(
              text: _getInstructionText(currentStep),
              onComplete: _onInstructionComplete,
            ),

          // One-time setup indicator
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
