import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/theme/snaplook_ai_icon.dart';
import 'tutorial_results_page.dart';

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
                if (!_isAnalyzing)
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

                // "Tap here" indicator (only when not analyzing)
                if (!_isAnalyzing)
                  Positioned(
                    bottom: 168, // Position above the scan button - moved up 18px from 150 (12+6)
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFf2003c),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Text(
                              'Tap to analyze',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),

                          // Arrow pointing down to the scan button
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            child: const Icon(
                              Icons.keyboard_arrow_down,
                              color: Color(0xFFf2003c),
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                    ),
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

  Widget _buildDetectionOverlay() {
    return Positioned.fill(
      child: Stack(
        children: [
          // Smooth up-and-down scanning beam
          const _ScanningBeam(),
          // "Analyzing..." text at bottom with red accent
          Positioned(
            bottom: 140,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFf2003c),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFf2003c).withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Analyzing...',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
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

  void _startAnalysis() {
    setState(() {
      _isAnalyzing = true;
    });

    // Navigate to results after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => TutorialResultsPage(
              imagePath: widget.imagePath,
              scenario: widget.scenario,
            ),
          ),
        );
      }
    });
  }
}

// Custom scanning beam that animates up and down smoothly
class _ScanningBeam extends StatefulWidget {
  const _ScanningBeam();

  @override
  State<_ScanningBeam> createState() => _ScanningBeamState();
}

class _ScanningBeamState extends State<_ScanningBeam>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double? _previousValue;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.linear, // Linear for continuous smooth motion
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final currentValue = _animation.value;
        final isMovingDown = _previousValue == null ? true : currentValue > _previousValue!;
        _previousValue = currentValue;

        return CustomPaint(
          painter: _ScanningBeamPainter(currentValue, isMovingDown),
          child: Container(),
        );
      },
    );
  }
}

class _ScanningBeamPainter extends CustomPainter {
  final double progress;
  final bool isMovingDown;

  _ScanningBeamPainter(this.progress, this.isMovingDown);

  @override
  void paint(Canvas canvas, Size size) {
    final beamHeight = 200.0;
    final overshoot = 20.0; // Amount to extend beyond screen edges
    // Position beam so bright edge goes from -overshoot to size.height + overshoot
    // Bright edge is at 85% when moving down, 15% when moving up
    final beamY = (size.height + overshoot * 2) * progress - overshoot - beamHeight * (isMovingDown ? 0.85 : 0.15);

    // Gradient direction changes based on movement (subtle opacities)
    final colors = isMovingDown
        ? [
            Colors.transparent,
            const Color(0xFFf2003c).withOpacity(0.01),
            const Color(0xFFf2003c).withOpacity(0.03),
            const Color(0xFFf2003c).withOpacity(0.08),
            const Color(0xFFf2003c).withOpacity(0.15),
            const Color(0xFFf2003c).withOpacity(0.3),
            const Color(0xFFf2003c).withOpacity(0.4), // Bright at bottom when moving down
            Colors.transparent,
          ]
        : [
            Colors.transparent,
            const Color(0xFFf2003c).withOpacity(0.4), // Bright at top when moving up
            const Color(0xFFf2003c).withOpacity(0.3),
            const Color(0xFFf2003c).withOpacity(0.15),
            const Color(0xFFf2003c).withOpacity(0.08),
            const Color(0xFFf2003c).withOpacity(0.03),
            const Color(0xFFf2003c).withOpacity(0.01),
            Colors.transparent,
          ];

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
        stops: const [0.0, 0.15, 0.25, 0.4, 0.6, 0.75, 0.85, 1.0],
      ).createShader(Rect.fromLTWH(0, beamY, size.width, beamHeight));

    canvas.drawRect(
      Rect.fromLTWH(0, beamY, size.width, beamHeight),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ScanningBeamPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isMovingDown != isMovingDown;
  }
}