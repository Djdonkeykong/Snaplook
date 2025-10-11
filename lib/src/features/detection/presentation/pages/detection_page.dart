import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../../home/domain/providers/image_provider.dart';
import '../../../results/presentation/pages/results_page.dart';
import '../../../../../core/constants/app_constants.dart';
import '../providers/detection_provider.dart';

class DetectionPage extends ConsumerStatefulWidget {
  final String? imageUrl;

  const DetectionPage({super.key, this.imageUrl});

  @override
  ConsumerState<DetectionPage> createState() => _DetectionPageState();
}

class _DetectionPageState extends ConsumerState<DetectionPage>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  PageController _pageController = PageController();

  // Crop selection state
  bool _isCropMode = false;
  Rect? _cropRect;

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
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imagesState = ref.watch(selectedImagesProvider);
    final selectedImage = imagesState.currentImage;
    final detectionState = ref.watch(detectionProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
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
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.black, size: 20),
          ),
        ),
        actions: [
          if (!ref.watch(detectionProvider).isAnalyzing)
            Container(
              margin: const EdgeInsets.all(8),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _isCropMode
                    ? const Color(0xFFf2003c)
                    : Colors.white.withOpacity(0.9),
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
                  setState(() {
                    _isCropMode = !_isCropMode;
                    if (_isCropMode && _cropRect == null) {
                      // Initialize crop rect to center of screen
                      final screenSize = MediaQuery.of(context).size;
                      final cropSize = screenSize.width * 0.7;
                      final left = (screenSize.width - cropSize) / 2;
                      final top = (screenSize.height - cropSize) / 2;
                      _cropRect = Rect.fromLTWH(left, top, cropSize, cropSize);
                    }
                  });
                },
                icon: Icon(
                  _isCropMode ? Icons.fullscreen_exit : Icons.crop_free,
                  color: _isCropMode ? Colors.white : Colors.black,
                  size: 20,
                ),
              ),
            ),
        ],
      ),
      body: selectedImage == null && widget.imageUrl == null
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
                      // Background Images - Full Screen with PageView
                      Positioned.fill(
                        child: widget.imageUrl != null
                            // Network image from scan button - no scale animation
                            ? SizedBox.expand(
                                child: Image.network(
                                  widget.imageUrl!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                              )
                            // Local images from camera/gallery - with scale animation
                            : AnimatedBuilder(
                                animation: _scaleAnimation,
                                builder: (context, child) {
                                  return Transform.scale(
                                    scale: _scaleAnimation.value,
                                    child: imagesState.hasMultipleImages
                                        ? PageView.builder(
                                            controller: _pageController,
                                            onPageChanged: (index) {
                                              ref.read(selectedImagesProvider.notifier).setCurrentIndex(index);
                                            },
                                            itemCount: imagesState.totalImages,
                                            itemBuilder: (context, index) {
                                              return Image.file(
                                                File(imagesState.images[index].path),
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                height: double.infinity,
                                              );
                                            },
                                          )
                                        : Image.file(
                                            File(selectedImage!.path),
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: double.infinity,
                                          ),
                                  );
                                },
                              ),
                      ),

                      // Detection Overlay
                      if (detectionState.isAnalyzing)
                        _buildDetectionOverlay(),

                      // Image dots indicator for multiple images
                      if (imagesState.hasMultipleImages)
                        Positioned(
                          bottom: 40, // Below the search icon with more spacing
                          left: 0,
                          right: 0,
                          child: _buildDotsIndicator(imagesState),
                        ),

                      // Crop Mode Overlay
                      if (_isCropMode && !detectionState.isAnalyzing)
                        _buildCropOverlay(),


                      // Bottom Controls
                      Positioned(
                        bottom: 80,
                        left: 0,
                        right: 0,
                        child: Column(
                          children: [
                            const SizedBox(height: 16),
                            // Main scan button
                            Center(
                              child: detectionState.isAnalyzing
                                  ? _buildAnalyzingButton()
                                  : _buildScanButton(),
                            ),
                          ],
                        ),
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


  Widget _buildScanButton() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFFf2003c),
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
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDotsIndicator(SelectedImagesState imagesState) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            imagesState.totalImages,
            (index) => Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index == imagesState.currentIndex
                    ? Colors.white
                    : Colors.white.withOpacity(0.4),
              ),
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





  Widget _buildCropOverlay() {
    if (_cropRect == null) return const SizedBox.shrink();

    return Stack(
      children: [
        // Dark overlay with transparent crop area
        Positioned.fill(
          child: CustomPaint(
            painter: _CropOverlayPainter(_cropRect!),
          ),
        ),
        // Crop box with rounded corners and corner brackets
        Positioned(
          left: _cropRect!.left,
          top: _cropRect!.top,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _cropRect = Rect.fromLTWH(
                  (_cropRect!.left + details.delta.dx).clamp(0, MediaQuery.of(context).size.width - _cropRect!.width),
                  (_cropRect!.top + details.delta.dy).clamp(0, MediaQuery.of(context).size.height - _cropRect!.height),
                  _cropRect!.width,
                  _cropRect!.height,
                );
              });
            },
            child: Container(
              width: _cropRect!.width,
              height: _cropRect!.height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                children: [
                  _buildCornerBracket(Alignment.topLeft),
                  _buildCornerBracket(Alignment.topRight),
                  _buildCornerBracket(Alignment.bottomLeft),
                  _buildCornerBracket(Alignment.bottomRight),
                  // Invisible resize handles
                  ..._buildResizeHandles(),
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
                  onPressed: _performCrop,
                  icon: const Icon(Icons.check, color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCornerBracket(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 30,
        height: 30,
        child: CustomPaint(
          painter: _CornerBracketPainter(alignment),
        ),
      ),
    );
  }

  List<Widget> _buildResizeHandles() {
    const handleSize = 40.0;

    return [
      // Top-left
      Positioned(
        left: 0,
        top: 0,
        child: GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              final newLeft = (_cropRect!.left + details.delta.dx).clamp(0.0, _cropRect!.right - 100);
              final newTop = (_cropRect!.top + details.delta.dy).clamp(0.0, _cropRect!.bottom - 100);
              _cropRect = Rect.fromLTRB(newLeft, newTop, _cropRect!.right, _cropRect!.bottom);
            });
          },
          child: Container(
            width: handleSize,
            height: handleSize,
            color: Colors.transparent,
          ),
        ),
      ),
      // Top-right
      Positioned(
        right: 0,
        top: 0,
        child: GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              final newRight = (_cropRect!.right + details.delta.dx).clamp(_cropRect!.left + 100, MediaQuery.of(context).size.width);
              final newTop = (_cropRect!.top + details.delta.dy).clamp(0.0, _cropRect!.bottom - 100);
              _cropRect = Rect.fromLTRB(_cropRect!.left, newTop, newRight, _cropRect!.bottom);
            });
          },
          child: Container(
            width: handleSize,
            height: handleSize,
            color: Colors.transparent,
          ),
        ),
      ),
      // Bottom-left
      Positioned(
        left: 0,
        bottom: 0,
        child: GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              final newLeft = (_cropRect!.left + details.delta.dx).clamp(0.0, _cropRect!.right - 100);
              final newBottom = (_cropRect!.bottom + details.delta.dy).clamp(_cropRect!.top + 100, MediaQuery.of(context).size.height);
              _cropRect = Rect.fromLTRB(newLeft, _cropRect!.top, _cropRect!.right, newBottom);
            });
          },
          child: Container(
            width: handleSize,
            height: handleSize,
            color: Colors.transparent,
          ),
        ),
      ),
      // Bottom-right
      Positioned(
        right: 0,
        bottom: 0,
        child: GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              final newRight = (_cropRect!.right + details.delta.dx).clamp(_cropRect!.left + 100, MediaQuery.of(context).size.width);
              final newBottom = (_cropRect!.bottom + details.delta.dy).clamp(_cropRect!.top + 100, MediaQuery.of(context).size.height);
              _cropRect = Rect.fromLTRB(_cropRect!.left, _cropRect!.top, newRight, newBottom);
            });
          },
          child: Container(
            width: handleSize,
            height: handleSize,
            color: Colors.transparent,
          ),
        ),
      ),
    ];
  }

  void _performCrop() async {
    try {
      // Exit crop mode
      setState(() {
        _isCropMode = false;
      });

      // For now, just proceed with the original image since we're focusing on the UI
      // The crop rect information is available in _cropRect if needed for actual cropping
      XFile imageToAnalyze;

      if (widget.imageUrl != null) {
        // Network image - download and create XFile
        final response = await http.get(Uri.parse(widget.imageUrl!));
        if (response.statusCode == 200) {
          final tempDir = Directory.systemTemp;
          final fileName = 'scan_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final file = File('${tempDir.path}/$fileName');
          await file.writeAsBytes(response.bodyBytes);
          imageToAnalyze = XFile(file.path);
        } else {
          throw Exception('Failed to download image');
        }
      } else {
        // Local image
        final imagesState = ref.read(selectedImagesProvider);
        final selectedImage = imagesState.currentImage;
        if (selectedImage == null) return;
        imageToAnalyze = selectedImage;
      }

      final results = await ref
          .read(detectionProvider.notifier)
          .analyzeImage(imageToAnalyze);

      if (mounted && results.isNotEmpty) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ResultsPage(
              results: results,
              originalImageUrl: widget.imageUrl,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error performing crop: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analysis failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }



  void _startDetection() async {
    print('Starting detection process...');

    try {
      XFile imageToAnalyze;

      if (widget.imageUrl != null) {
        // Network image from scan button - download and create XFile
        print('Downloading network image: ${widget.imageUrl}');
        final response = await http.get(Uri.parse(widget.imageUrl!));
        if (response.statusCode == 200) {
          final tempDir = Directory.systemTemp;
          final fileName = 'scan_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final file = File('${tempDir.path}/$fileName');
          await file.writeAsBytes(response.bodyBytes);
          imageToAnalyze = XFile(file.path);
        } else {
          throw Exception('Failed to download image');
        }
      } else {
        // Local image from camera/gallery - use existing logic
        final imagesState = ref.read(selectedImagesProvider);
        final selectedImage = imagesState.currentImage;
        if (selectedImage == null) return;
        imageToAnalyze = selectedImage;
      }

      final results = await ref
          .read(detectionProvider.notifier)
          .analyzeImage(imageToAnalyze);

      if (mounted && results.isNotEmpty) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ResultsPage(
              results: results,
              originalImageUrl: widget.imageUrl, // Pass network image URL
            ),
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

class _CropOverlayPainter extends CustomPainter {
  final Rect cropRect;

  _CropOverlayPainter(this.cropRect);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final paint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(cropRect, const Radius.circular(20)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CropOverlayPainter oldDelegate) {
    return oldDelegate.cropRect != cropRect;
  }
}

class _CornerBracketPainter extends CustomPainter {
  final Alignment alignment;

  _CornerBracketPainter(this.alignment);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final bracketLength = 20.0;
    final cornerRadius = 8.0;
    final path = Path();

    if (alignment == Alignment.topLeft) {
      path.moveTo(bracketLength, 0);
      path.lineTo(cornerRadius, 0);
      path.arcToPoint(
        Offset(0, cornerRadius),
        radius: Radius.circular(cornerRadius),
        clockwise: false,
      );
      path.lineTo(0, bracketLength);
    } else if (alignment == Alignment.topRight) {
      path.moveTo(size.width - bracketLength, 0);
      path.lineTo(size.width - cornerRadius, 0);
      path.arcToPoint(
        Offset(size.width, cornerRadius),
        radius: Radius.circular(cornerRadius),
        clockwise: true,
      );
      path.lineTo(size.width, bracketLength);
    } else if (alignment == Alignment.bottomLeft) {
      path.moveTo(0, size.height - bracketLength);
      path.lineTo(0, size.height - cornerRadius);
      path.arcToPoint(
        Offset(cornerRadius, size.height),
        radius: Radius.circular(cornerRadius),
        clockwise: false,
      );
      path.lineTo(bracketLength, size.height);
    } else if (alignment == Alignment.bottomRight) {
      path.moveTo(size.width, size.height - bracketLength);
      path.lineTo(size.width, size.height - cornerRadius);
      path.arcToPoint(
        Offset(size.width - cornerRadius, size.height),
        radius: Radius.circular(cornerRadius),
        clockwise: true,
      );
      path.lineTo(size.width - bracketLength, size.height);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CornerBracketPainter oldDelegate) {
    return oldDelegate.alignment != alignment;
  }
}