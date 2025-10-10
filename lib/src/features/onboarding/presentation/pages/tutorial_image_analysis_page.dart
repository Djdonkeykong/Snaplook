import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/constants/app_constants.dart';
import 'tutorial_results_page.dart';

class TutorialImageAnalysisPage extends ConsumerStatefulWidget {
  const TutorialImageAnalysisPage({super.key});

  @override
  ConsumerState<TutorialImageAnalysisPage> createState() => _TutorialImageAnalysisPageState();
}

class _TutorialImageAnalysisPageState extends ConsumerState<TutorialImageAnalysisPage>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  // Crop selection state
  bool _isCropMode = false;
  Rect _cropRect = const Rect.fromLTWH(50, 50, 200, 200);

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
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
                          'assets/images/tutorial_analysis_image_2.jpg',
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      );
                    },
                  ),
                ),

                // Black overlay covering everything (only when not analyzing)
                if (!_isCropMode && !_isAnalyzing)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.4),
                    ),
                  ),

                // Detection Overlay during analysis
                if (_isAnalyzing)
                  _buildDetectionOverlay(),

                // Crop Mode Overlay
                if (_isCropMode)
                  _buildCropOverlay(),

                // Bottom Controls
                Positioned(
                  bottom: 80,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      // Main scan button with tap detection
                      Center(
                        child: _isAnalyzing ? _buildAnalyzingButton() : _buildScanButton(),
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
          child: const Center(
            child: Icon(
              Icons.search,
              size: 32,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyzingButton() {
    return Container(
      width: 200,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.black,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Analyzing...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetectionOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              shape: BoxShape.circle,
            ),
            child: const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
          ),
        ),
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
            builder: (context) => const TutorialResultsPage(),
          ),
        );
      }
    });
  }

  Widget _buildCropOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.2),
        child: Stack(
          children: [
            // Crop selection rectangle
            CustomPaint(
              painter: CropOverlayPainter(_cropRect),
              size: Size.infinite,
            ),

            // Draggable crop area
            Positioned(
              left: _cropRect.left,
              top: _cropRect.top,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _cropRect = Rect.fromLTWH(
                      (_cropRect.left + details.delta.dx).clamp(0, MediaQuery.of(context).size.width - _cropRect.width),
                      (_cropRect.top + details.delta.dy).clamp(0, MediaQuery.of(context).size.height - _cropRect.height),
                      _cropRect.width,
                      _cropRect.height,
                    );
                  });
                },
                child: Container(
                  width: _cropRect.width,
                  height: _cropRect.height,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFf2003c), width: 2),
                  ),
                  child: Stack(
                    children: [
                      // Corner handles
                      ..._buildCornerHandles(),
                    ],
                  ),
                ),
              ),
            ),

            // Action buttons
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Cancel button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: IconButton(
                      onPressed: () {
                        setState(() {
                          _isCropMode = false;
                        });
                      },
                      icon: const Icon(Icons.close, color: Colors.white, size: 24),
                    ),
                  ),

                  // Crop & Analyze button
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFf2003c),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: IconButton(
                      onPressed: () {
                        // Navigate to results page
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => const TutorialResultsPage(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.check, color: Colors.white, size: 24),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCornerHandles() {
    const handleSize = 20.0;
    const handleColor = Color(0xFFf2003c);

    return [
      // Top-left
      Positioned(
        left: -handleSize / 2,
        top: -handleSize / 2,
        child: Container(
          width: handleSize,
          height: handleSize,
          decoration: const BoxDecoration(
            color: handleColor,
            shape: BoxShape.circle,
          ),
        ),
      ),
      // Top-right
      Positioned(
        right: -handleSize / 2,
        top: -handleSize / 2,
        child: Container(
          width: handleSize,
          height: handleSize,
          decoration: const BoxDecoration(
            color: handleColor,
            shape: BoxShape.circle,
          ),
        ),
      ),
      // Bottom-left
      Positioned(
        left: -handleSize / 2,
        bottom: -handleSize / 2,
        child: Container(
          width: handleSize,
          height: handleSize,
          decoration: const BoxDecoration(
            color: handleColor,
            shape: BoxShape.circle,
          ),
        ),
      ),
      // Bottom-right
      Positioned(
        right: -handleSize / 2,
        bottom: -handleSize / 2,
        child: Container(
          width: handleSize,
          height: handleSize,
          decoration: const BoxDecoration(
            color: handleColor,
            shape: BoxShape.circle,
          ),
        ),
      ),
    ];
  }
}

class CropOverlayPainter extends CustomPainter {
  final Rect cropRect;

  CropOverlayPainter(this.cropRect);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    // Draw darkened overlay everywhere except crop area
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Create path with hole for crop area
    final path = Path()
      ..addRect(fullRect)
      ..addRect(cropRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CropOverlayPainter oldDelegate) {
    return oldDelegate.cropRect != cropRect;
  }
}