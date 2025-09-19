import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../home/domain/providers/image_provider.dart';
import '../../../results/presentation/pages/results_page.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../core/constants/app_constants.dart';
import '../providers/detection_provider.dart';

class DetectionPage extends ConsumerStatefulWidget {
  const DetectionPage({super.key});

  @override
  ConsumerState<DetectionPage> createState() => _DetectionPageState();
}

class _DetectionPageState extends ConsumerState<DetectionPage>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

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
    final selectedImage = ref.watch(selectedImageProvider);
    final detectionState = ref.watch(detectionProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
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
        actions: [
          IconButton(
            icon: const Icon(
              Icons.more_vert,
              color: Colors.white,
            ),
            onPressed: () {
              // Show options menu
            },
          ),
        ],
      ),
      body: selectedImage == null
          ? const Center(
              child: Text(
                'No image selected',
                style: TextStyle(color: Colors.white),
              ),
            )
          : AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Stack(
                    children: [
                      // Background Image
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _scaleAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _scaleAnimation.value,
                              child: Image.file(
                                File(selectedImage.path),
                                fit: BoxFit.cover,
                              ),
                            );
                          },
                        ),
                      ),

                      // Detection Overlay
                      if (detectionState.isAnalyzing)
                        _buildDetectionOverlay()
                      else
                        _buildScanControls(),

                      // Bottom Button
                      Positioned(
                        bottom: 50,
                        left: 20,
                        right: 20,
                        child: detectionState.isAnalyzing
                            ? _buildAnalyzingButton()
                            : _buildScanButton(),
                      ),
                    ],
                  ),
                );
              },
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
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
              const SizedBox(height: 20),
              const Text(
                'Analyzing fashion items...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanControls() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
        ),
        child: Center(
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white.withOpacity(0.8),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              children: [
                // Corner indicators
                ...List.generate(4, (index) {
                  return Positioned(
                    top: index < 2 ? 10 : null,
                    bottom: index >= 2 ? 10 : null,
                    left: index % 2 == 0 ? 10 : null,
                    right: index % 2 == 1 ? 10 : null,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        border: Border(
                          top: index < 2
                              ? BorderSide(color: Colors.white, width: 3)
                              : BorderSide.none,
                          bottom: index >= 2
                              ? BorderSide(color: Colors.white, width: 3)
                              : BorderSide.none,
                          left: index % 2 == 0
                              ? BorderSide(color: Colors.white, width: 3)
                              : BorderSide.none,
                          right: index % 2 == 1
                              ? BorderSide(color: Colors.white, width: 3)
                              : BorderSide.none,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
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
          onTap: _startDetection,
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
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
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

  void _startDetection() async {
    print('Starting detection process...');
    final selectedImage = ref.read(selectedImageProvider);
    if (selectedImage == null) return;

    try {
      final results = await ref
          .read(detectionProvider.notifier)
          .analyzeImage(selectedImage);

      if (mounted && results.isNotEmpty) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ResultsPage(results: results),
          ),
        );
      }
    } catch (e) {
      print('DETECTION ERROR: $e');
      print('Error type: ${e.runtimeType}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Detection failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}