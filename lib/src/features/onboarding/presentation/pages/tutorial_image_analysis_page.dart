import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_confetti/flutter_confetti.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/snaplook_ai_icon.dart';
import '../../../../services/analytics_service.dart';
import '../../../detection/presentation/widgets/detection_progress_overlay.dart';
import '../../../detection/domain/models/detection_result.dart';
import '../../../results/presentation/widgets/results_bottom_sheet.dart';
import '../../domain/services/tutorial_service.dart';
import '../widgets/onboarding_phone_frame.dart';
import 'discovery_source_page.dart';

class TutorialImageAnalysisPage extends ConsumerStatefulWidget {
  final String? imagePath;
  final String scenario;
  final bool returnToOnboarding;

  const TutorialImageAnalysisPage({
    super.key,
    this.imagePath,
    this.scenario = 'Instagram',
    this.returnToOnboarding = true,
  });

  @override
  ConsumerState<TutorialImageAnalysisPage> createState() =>
      _TutorialImageAnalysisPageState();
}

class _TutorialImageAnalysisPageState
    extends ConsumerState<TutorialImageAnalysisPage> {
  // Instruction state
  bool _showInstruction = true;

  // Analysis state
  bool _isAnalyzing = false;
  double _currentProgress = 0.0;
  final double _targetProgress = 1.0;
  DateTime? _progressStartTime;
  static const Duration _progressDuration = Duration(milliseconds: 2500);
  Timer? _progressTimer;

  // Results sheet state
  static const double _resultsMinExtent = 0.4;
  static const double _resultsInitialExtent = 0.6;
  static const double _resultsMaxExtent = 0.85;
  double _currentResultsExtent = _resultsInitialExtent;
  bool _isResultsSheetVisible = false;
  List<DetectionResult> _results = [];
  bool _showCongratulations = false;
  final TutorialService _tutorialService = TutorialService();

  @override
  void initState() {
    super.initState();
    AnalyticsService().trackScreenView('onboarding_tutorial_analysis');
  }

  @override
  void dispose() {
    _stopProgressTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool showShareAction = _isResultsSheetVisible && _results.isNotEmpty;

    return OnboardingPhoneFrame(
      backgroundColor: Colors.black,
      aspectRatio: kOnboardingPhoneAspectRatio,
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        extendBody: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          actions: _isResultsSheetVisible
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
                        if (widget.returnToOnboarding) {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => const DiscoverySourcePage(),
                            ),
                          );
                        } else {
                          Navigator.of(context)
                              .popUntil((route) => route.isFirst);
                        }
                      },
                      icon: const Icon(Icons.check,
                          color: Colors.black, size: 18),
                    ),
                  ),
                ]
              : null,
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: _buildTutorialImage(),
            ),
            if (_isAnalyzing)
              DetectionProgressOverlay(
                statusText: 'Analyzing...',
                progress: _currentProgress,
                overlayOpacity: 0.65,
              ),
            if (!_isAnalyzing && !_isResultsSheetVisible)
              Positioned(
                bottom: 80,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    Center(child: _buildScanButton()),
                  ],
                ),
              ),
            if (_isResultsSheetVisible && _results.isNotEmpty) ...[
              if (!_showCongratulations)
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
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                top: 0,
                child: NotificationListener<DraggableScrollableNotification>(
                  onNotification: (notification) {
                    final extent = notification.extent;
                    setState(() => _currentResultsExtent = extent);
                    return false;
                  },
                  child: DraggableScrollableSheet(
                    key: const ValueKey('tutorial_results_sheet'),
                    initialChildSize: _resultsInitialExtent,
                    minChildSize: _resultsMinExtent,
                    maxChildSize: _resultsMaxExtent,
                    snap: false,
                    expand: false,
                    builder: (context, scrollController) {
                      return ResultsBottomSheetContent(
                        results: _results,
                        scrollController: scrollController,
                        onProductTap: _openProduct,
                        showFavoriteButton: false,
                        analyzedImage: widget.imagePath,
                      );
                    },
                  ),
                ),
              ),
            ],
            if (_showCongratulations) _buildCongratulationsOverlay(),

            // Instruction overlay (shows on page load)
            if (_showInstruction)
              _InstructionOverlay(
                text: 'Ready to find matches? Tap the search icon below',
                onComplete: () {
                  if (mounted) {
                    setState(() => _showInstruction = false);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  double get _resultsOverlayOpacity {
    if (!_isResultsSheetVisible) return 0;
    final range = _resultsMaxExtent - _resultsMinExtent;
    if (range <= 0) return 0.7;
    final normalized =
        ((_currentResultsExtent - _resultsMinExtent) / range).clamp(0.0, 1.0);
    return 0.15 + (0.55 * normalized);
  }

  bool get _isNetworkImage {
    final path = widget.imagePath;
    if (path == null) return false;
    final uri = Uri.tryParse(path);
    if (uri == null) return false;
    return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  String get _resolvedImagePath =>
      widget.imagePath ?? 'assets/images/tutorial_analysis_image_2.jpg';

  Widget _buildNetworkPlaceholder() {
    return Container(
      color: Colors.black,
    );
  }

  Widget _buildNetworkError() {
    return Container(
      color: Colors.black,
      child: const Icon(
        Icons.broken_image_outlined,
        color: Colors.white54,
        size: 42,
      ),
    );
  }

  Widget _buildTutorialImage() {
    final alignment = widget.scenario == 'X'
        ? const Alignment(0.4, 0.0) // Nudge right for X tutorial
        : Alignment.center;

    if (_isNetworkImage) {
      return CachedNetworkImage(
        imageUrl: _resolvedImagePath,
        fit: BoxFit.cover,
        alignment: alignment,
        width: double.infinity,
        height: double.infinity,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholderFadeInDuration: Duration.zero,
        placeholder: (_, __) => _buildNetworkPlaceholder(),
        errorWidget: (_, __, ___) => _buildNetworkError(),
      );
    }

    return Image.asset(
      _resolvedImagePath,
      fit: BoxFit.cover,
      alignment: alignment,
      gaplessPlayback: true,
    );
  }

  Widget _buildCongratulationsOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.65),
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
    );
  }

  Future<void> _openProduct(DetectionResult result) async {
    final url = result.purchaseUrl;
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
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
            color: Colors.black.withOpacity(0.3),
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

  void _startAnalysis() async {
    if (_isAnalyzing) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _isAnalyzing = true;
    });
    _progressStartTime = DateTime.now();
    _currentProgress = 0.0;
    _startSmoothProgressTimer();

    // Load tutorial products
    try {
      final results =
          await _tutorialService.getTutorialProducts(scenario: widget.scenario);

      await Future.delayed(const Duration(milliseconds: 2500));

      if (!mounted) return;

      _completeProgress();
      _stopProgressTimer();

      setState(() {
        _results = results;
        _isAnalyzing = false;
        _isResultsSheetVisible = true;
        _currentResultsExtent = _resultsInitialExtent;
        _showCongratulations = true;
      });

      // Launch confetti
      HapticFeedback.mediumImpact();
      _launchConfetti();

      // Hide congratulations overlay after 4 seconds
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() {
            _showCongratulations = false;
          });
        }
      });
    } catch (e) {
      print('Error loading tutorial products: $e');
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  void _launchConfetti() {
    // Launch multiple confetti bursts for better effect
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

    // Additional bursts from left and right
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

  void _startSmoothProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted || !_isAnalyzing) {
        timer.cancel();
        return;
      }

      if (_progressStartTime == null) {
        _completeProgress();
        timer.cancel();
        return;
      }

      final elapsed = DateTime.now().difference(_progressStartTime!);
      final normalized =
          (elapsed.inMilliseconds / _progressDuration.inMilliseconds)
              .clamp(0.0, 1.0);

      if (normalized >= 1.0) {
        _completeProgress();
        timer.cancel();
        return;
      }

      if ((normalized - _currentProgress).abs() > 0.0001) {
        setState(() {
          _currentProgress = normalized;
        });
      }
    });
  }

  void _stopProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  void _completeProgress() {
    if (!mounted) return;
    setState(() {
      _currentProgress = _targetProgress;
      _progressStartTime = null;
    });
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

  void _completeWithFade(
      {Duration fadeDuration = const Duration(milliseconds: 800)}) {
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
          color: Colors.black.withOpacity(0.70),
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
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
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
