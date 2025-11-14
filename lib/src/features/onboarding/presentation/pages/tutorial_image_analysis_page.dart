import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/theme/snaplook_ai_icon.dart';
import '../../../detection/presentation/widgets/detection_progress_overlay.dart';
import 'tutorial_results_page.dart';

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
  ConsumerState<TutorialImageAnalysisPage> createState() => _TutorialImageAnalysisPageState();
}

class _TutorialImageAnalysisPageState extends ConsumerState<TutorialImageAnalysisPage> {
  // Analysis state
  bool _isAnalyzing = false;
  double _currentProgress = 0.0;
  final double _targetProgress = 1.0;
  DateTime? _progressStartTime;
  static const Duration _progressDuration = Duration(milliseconds: 2500);
  Timer? _progressTimer;

  @override
  void dispose() {
    _stopProgressTimer();
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
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              widget.imagePath ?? 'assets/images/tutorial_analysis_image_2.jpg',
              fit: BoxFit.cover,
            ),
          ),
          if (!_isAnalyzing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.35),
              ),
            ),
          if (_isAnalyzing)
            DetectionProgressOverlay(
              statusText: 'Analyzing...',
              progress: _currentProgress,
              overlayOpacity: 0.65,
            ),
          if (!_isAnalyzing)
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
        ],
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

  void _startAnalysis() {
    if (_isAnalyzing) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _isAnalyzing = true;
    });
    _progressStartTime = DateTime.now();
    _currentProgress = 0.0;
    _startSmoothProgressTimer();

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      _completeProgress();
      _stopProgressTimer();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => TutorialResultsPage(
            imagePath: widget.imagePath,
            scenario: widget.scenario,
            returnToOnboarding: widget.returnToOnboarding,
          ),
        ),
      );
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
