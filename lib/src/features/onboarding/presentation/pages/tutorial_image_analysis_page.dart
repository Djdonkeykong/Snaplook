import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_confetti/flutter_confetti.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/theme/snaplook_ai_icon.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../detection/domain/models/detection_result.dart';
import '../../../results/presentation/widgets/results_bottom_sheet.dart';
import '../../domain/services/tutorial_service.dart';
import 'trial_intro_page.dart';

class TutorialImageAnalysisPage extends ConsumerStatefulWidget {
  final String? imagePath;
  final String scenario;

  const TutorialImageAnalysisPage({
    super.key,
    this.imagePath,
    this.scenario = 'Instagram',
  });

  @override
  ConsumerState<TutorialImageAnalysisPage> createState() => _TutorialImageAnalysisPageState();
}

class _TutorialImageAnalysisPageState extends ConsumerState<TutorialImageAnalysisPage>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  // Analysis state
  bool _isAnalyzing = false;
  bool _showInstruction = true;
  double _currentProgress = 0.0;
  Timer? _progressTimer;

  // Results sheet state
  static const double _minSheetExtent = 0.4;
  static const double _initialSheetExtent = 0.6;
  static const double _maxSheetExtent = 0.85;

  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  bool _isResultsSheetVisible = false;
  bool _showCongratulations = false;
  double _currentSheetExtent = _initialSheetExtent;
  List<DetectionResult> _tutorialResults = [];
  bool _isLoading = true;
  final TutorialService _tutorialService = TutorialService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: AppConstants.mediumAnimation,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _progressTimer?.cancel();
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: _isAnalyzing || _showInstruction
            ? null
            : _isResultsSheetVisible
                ? [
                    Container(
                      margin: const EdgeInsets.all(8),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => const TrialIntroPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.check, color: Colors.black, size: 20),
                      ),
                    ),
                  ]
                : null,
      ),
      body: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Stack(
              children: [
                // Background Image - Full Screen
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _scaleAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Image.asset(
                          widget.imagePath ?? 'assets/images/tutorial_analysis_image_2.jpg',
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      );
                    },
                  ),
                ),

                // Black overlay covering everything (only when not analyzing)
                if (!_isAnalyzing)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.4),
                    ),
                  ),

                // Detection Overlay during analysis
                if (_isAnalyzing)
                  _buildDetectionOverlay(),

                // Bottom Controls
                if (!_isAnalyzing && !_isResultsSheetVisible)
                  Positioned(
                    bottom: 80,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        // Main scan button with tap detection
                        Center(
                          child: _buildScanButton(),
                        ),
                      ],
                    ),
                  ),

                // Results sheet overlay
                if (_isResultsSheetVisible) ...[
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      ignoring: true,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        color: Colors.black.withOpacity(_resultsOverlayOpacity),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height,
                      child: NotificationListener<DraggableScrollableNotification>(
                        onNotification: (notification) {
                          if (!mounted) return false;
                          final extent = notification.extent
                              .clamp(_minSheetExtent, _maxSheetExtent)
                              .toDouble();
                          setState(() => _currentSheetExtent = extent);
                          return false;
                        },
                        child: DraggableScrollableSheet(
                          controller: _sheetController,
                          initialChildSize: _initialSheetExtent,
                          minChildSize: _minSheetExtent,
                          maxChildSize: _maxSheetExtent,
                          snap: false,
                          expand: false,
                          builder: (context, scrollController) {
                            return ResultsBottomSheetContent(
                              results: _tutorialResults,
                              scrollController: scrollController,
                              onProductTap: _openProduct,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],

                // Congratulations overlay
                if (_showCongratulations)
                  _buildCongratulationsOverlay(),

                // Instruction overlay (shows on page load)
                if (_showInstruction)
                  _InstructionOverlay(
                    text: "Now tap the scan button to find similar items.",
                    onComplete: () {
                      setState(() {
                        _showInstruction = false;
                      });
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildScanButton() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(40),
          onTap: _startAnalysis,
          child: Center(
            child: Transform.translate(
              offset: const Offset(0, -1),
              child: const Icon(
                SnaplookAiIcon.aiSearchIcon,
                size: 32,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetectionOverlay() {
    final spacing = context.spacing;
    final screenWidth = MediaQuery.of(context).size.width;
    final double clampedProgressWidth =
        ((screenWidth * 0.45).clamp(160.0, 240.0)).toDouble();

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.65),
        padding: EdgeInsets.symmetric(horizontal: spacing.l),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CupertinoActivityIndicator(
                radius: 18,
                color: Colors.white,
              ),
              SizedBox(height: spacing.l * 1.1),
              const Text(
                'Analyzing...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'PlusJakartaSans',
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
              SizedBox(height: spacing.l),
              SizedBox(
                width: clampedProgressWidth,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: _currentProgress.clamp(0.0, 1.0),
                    minHeight: 5,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                    backgroundColor: Colors.white24,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startAnalysis() {
    setState(() {
      _isAnalyzing = true;
      _currentProgress = 0.0;
    });

    // Load tutorial products
    _loadTutorialProducts();

    // Simple linear progress from 0 to 100% over 2 seconds
    const totalDuration = 2000; // 2 seconds in milliseconds
    const updateInterval = 30; // Update every 30ms
    const totalSteps = totalDuration / updateInterval;
    const incrementPerStep = 1.0 / totalSteps;

    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: updateInterval), (timer) {
      if (!mounted || !_isAnalyzing) {
        timer.cancel();
        return;
      }

      setState(() {
        _currentProgress = (_currentProgress + incrementPerStep).clamp(0.0, 1.0);
      });

      // Stop timer and show results sheet when complete
      if (_currentProgress >= 1.0) {
        timer.cancel();
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            setState(() {
              _isAnalyzing = false;
              _showCongratulations = true;
              _isResultsSheetVisible = true;
            });
            HapticFeedback.mediumImpact();
            _launchConfetti();
            // Hide congratulations after 2.5 seconds
            Future.delayed(const Duration(milliseconds: 2500), () {
              if (mounted) {
                setState(() {
                  _showCongratulations = false;
                });
              }
            });
          }
        });
      }
    });
  }

  Future<void> _loadTutorialProducts() async {
    try {
      final results = await _tutorialService.getTutorialProducts(scenario: widget.scenario);
      if (mounted) {
        setState(() {
          _tutorialResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading tutorial products: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openProduct(DetectionResult result) async {
    // Do nothing in tutorial mode
  }

  double get _resultsOverlayOpacity {
    if (!_isResultsSheetVisible) return 0;
    final range = _maxSheetExtent - _minSheetExtent;
    if (range <= 0) return 0.7;
    final normalized = ((_currentSheetExtent - _minSheetExtent) / range)
        .clamp(0.0, 1.0);
    return 0.15 + (0.55 * normalized);
  }

  void _launchConfetti() {
    Confetti.launch(
      context,
      options: const ConfettiOptions(
        particleCount: 100,
        spread: 70,
        y: 0.6,
        colors: [
          Color(0xFFf2003c),
          Colors.yellow,
          Colors.blue,
          Colors.green,
          Colors.purple,
          Colors.orange,
        ],
      ),
    );

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        Confetti.launch(
          context,
          options: const ConfettiOptions(
            particleCount: 50,
            spread: 55,
            angle: 60,
            x: 0.1,
            y: 0.7,
            colors: [
              Color(0xFFf2003c),
              Colors.yellow,
              Colors.blue,
              Colors.green,
            ],
          ),
        );
      }
    });

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        Confetti.launch(
          context,
          options: const ConfettiOptions(
            particleCount: 50,
            spread: 55,
            angle: 120,
            x: 0.9,
            y: 0.7,
            colors: [
              Color(0xFFf2003c),
              Colors.yellow,
              Colors.blue,
              Colors.green,
            ],
          ),
        );
      }
    });
  }

  Widget _buildCongratulationsOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: Colors.black.withOpacity(0.8),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Congratulations!',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${widget.scenario} insights unlocked.',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white70,
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
              ],
            ),
          ),
        ),
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
