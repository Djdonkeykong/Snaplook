import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import '../../../home/domain/providers/image_provider.dart';
import '../../../results/presentation/pages/results_page.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/theme/snaplook_ai_icon.dart';
import '../providers/detection_provider.dart';

class DetectionPage extends ConsumerStatefulWidget {
  final String? imageUrl;

  const DetectionPage({super.key, this.imageUrl});

  @override
  ConsumerState<DetectionPage> createState() => _DetectionPageState();
}

class _DetectionPageState extends ConsumerState<DetectionPage> {
  final PageController _pageController = PageController();
  final GlobalKey _imageKey = GlobalKey();

  // Crop selection state
  bool _isCropMode = false;
  Rect? _cropRect;
  Uint8List? _croppedImageBytes;

  @override
  void initState() {
    super.initState();
    print("[DETECTION PAGE] initState called");
    print("[DETECTION PAGE] imageUrl: ${widget.imageUrl}");
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imagesState = ref.watch(selectedImagesProvider);
    final selectedImage = imagesState.currentImage;
    final detectionState = ref.watch(detectionProvider);

    print("[DETECTION PAGE] build called");
    print("[DETECTION PAGE] selectedImage: ${selectedImage?.path ?? 'null'}");
    print("[DETECTION PAGE] widget.imageUrl: ${widget.imageUrl ?? 'null'}");
    print(
        "[DETECTION PAGE] hasMultipleImages: ${imagesState.hasMultipleImages}");
    print("[DETECTION PAGE] totalImages: ${imagesState.totalImages}");

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
                    if (!_isCropMode) {
                      // Entering crop mode - initialize crop rect if needed
                      if (_cropRect == null) {
                        final screenSize = MediaQuery.of(context).size;
                        final cropSize = screenSize.width * 0.7;
                        final left = (screenSize.width - cropSize) / 2;
                        final top = (screenSize.height - cropSize) / 2;
                        _cropRect = Rect.fromLTWH(left, top, cropSize, cropSize);
                      }
                    } else {
                      // Exiting crop mode - clear cropped bytes
                      _croppedImageBytes = null;
                    }
                    _isCropMode = !_isCropMode;
                  });
                },
                icon: Icon(
                  _isCropMode ? Icons.close : Icons.crop_free,
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
          : Stack(
              children: [
                Positioned.fill(
                  child: widget.imageUrl != null
                      ? SizedBox.expand(
                          child: Image.network(
                            widget.imageUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        )
                      : imagesState.hasMultipleImages
                          ? PageView.builder(
                              controller: _pageController,
                              onPageChanged: (index) {
                                ref
                                    .read(selectedImagesProvider.notifier)
                                    .setCurrentIndex(index);
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
                ),
                if (detectionState.isAnalyzing) _buildDetectionOverlay(),
                if (imagesState.hasMultipleImages)
                  Positioned(
                    bottom: 40,
                    left: 0,
                    right: 0,
                    child: _buildDotsIndicator(imagesState),
                  ),
                if (_isCropMode) _buildCropOverlay(),
                Positioned(
                  bottom: 80,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
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
  }

  Widget _buildDetectionOverlay() {
    return Positioned.fill(
      child: Stack(
        children: [
          // Smooth up-and-down scanning beam (clipped to crop area if active)
          if (_isCropMode && _cropRect != null)
            Positioned(
              left: _cropRect!.left,
              top: _cropRect!.top,
              width: _cropRect!.width,
              height: _cropRect!.height,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _ScanningBeam(),
              ),
            )
          else
            _ScanningBeam(),
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
          onTap: () async {
            HapticFeedback.mediumImpact();
            _startDetection();
          },
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
    // Return empty widget - the overlay now handles the "Analyzing" text
    return const SizedBox.shrink();
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
                  (_cropRect!.left + details.delta.dx).clamp(
                      0, MediaQuery.of(context).size.width - _cropRect!.width),
                  (_cropRect!.top + details.delta.dy).clamp(0,
                      MediaQuery.of(context).size.height - _cropRect!.height),
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
              final newLeft = (_cropRect!.left + details.delta.dx)
                  .clamp(0.0, _cropRect!.right - 100);
              final newTop = (_cropRect!.top + details.delta.dy)
                  .clamp(0.0, _cropRect!.bottom - 100);
              _cropRect = Rect.fromLTRB(
                  newLeft, newTop, _cropRect!.right, _cropRect!.bottom);
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
              final newRight = (_cropRect!.right + details.delta.dx).clamp(
                  _cropRect!.left + 100, MediaQuery.of(context).size.width);
              final newTop = (_cropRect!.top + details.delta.dy)
                  .clamp(0.0, _cropRect!.bottom - 100);
              _cropRect = Rect.fromLTRB(
                  _cropRect!.left, newTop, newRight, _cropRect!.bottom);
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
              final newLeft = (_cropRect!.left + details.delta.dx)
                  .clamp(0.0, _cropRect!.right - 100);
              final newBottom = (_cropRect!.bottom + details.delta.dy).clamp(
                  _cropRect!.top + 100, MediaQuery.of(context).size.height);
              _cropRect = Rect.fromLTRB(
                  newLeft, _cropRect!.top, _cropRect!.right, newBottom);
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
              final newRight = (_cropRect!.right + details.delta.dx).clamp(
                  _cropRect!.left + 100, MediaQuery.of(context).size.width);
              final newBottom = (_cropRect!.bottom + details.delta.dy).clamp(
                  _cropRect!.top + 100, MediaQuery.of(context).size.height);
              _cropRect = Rect.fromLTRB(
                  _cropRect!.left, _cropRect!.top, newRight, newBottom);
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

  Future<String> _generateCloudinaryCropUrl(String originalUrl, Rect cropRect) async {
    try {
      // Download image to get actual dimensions
      final response = await http.get(Uri.parse(originalUrl));
      if (response.statusCode != 200) return originalUrl;

      final imageBytes = response.bodyBytes;
      final originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) return originalUrl;

      // Calculate crop coordinates (same logic as _applyCrop)
      final screenSize = MediaQuery.of(context).size;
      final imageAspectRatio = originalImage.width / originalImage.height;
      final screenAspectRatio = screenSize.width / screenSize.height;

      double displayWidth, displayHeight;
      double offsetX = 0, offsetY = 0;

      if (imageAspectRatio > screenAspectRatio) {
        displayHeight = screenSize.height;
        displayWidth = displayHeight * imageAspectRatio;
        offsetX = (displayWidth - screenSize.width) / 2;
      } else {
        displayWidth = screenSize.width;
        displayHeight = displayWidth / imageAspectRatio;
        offsetY = (displayHeight - screenSize.height) / 2;
      }

      final scaleX = originalImage.width / displayWidth;
      final scaleY = originalImage.height / displayHeight;

      final cropX = ((cropRect.left + offsetX) * scaleX).round().clamp(0, originalImage.width);
      final cropY = ((cropRect.top + offsetY) * scaleY).round().clamp(0, originalImage.height);
      final cropWidth = (cropRect.width * scaleX).round().clamp(1, originalImage.width - cropX);
      final cropHeight = (cropRect.height * scaleY).round().clamp(1, originalImage.height - cropY);

      // Build Cloudinary transformation URL
      final uri = Uri.parse(originalUrl);
      final pathSegments = uri.pathSegments.toList();
      final uploadIndex = pathSegments.indexOf('upload');
      if (uploadIndex == -1) return originalUrl;

      // Insert crop transformation
      final cropTransform = 'c_crop,w_$cropWidth,h_$cropHeight,x_$cropX,y_$cropY';
      pathSegments.insert(uploadIndex + 1, cropTransform);

      return Uri(
        scheme: uri.scheme,
        host: uri.host,
        pathSegments: pathSegments,
      ).toString();
    } catch (e) {
      print('Error generating Cloudinary crop URL: $e');
      return originalUrl;
    }
  }

  Future<void> _applyCrop() async {
    if (_cropRect == null) return;

    try {
      Uint8List imageBytes;

      // Get the image bytes
      if (widget.imageUrl != null) {
        final response = await http.get(Uri.parse(widget.imageUrl!));
        if (response.statusCode != 200) {
          throw Exception('Failed to download image');
        }
        imageBytes = response.bodyBytes;
      } else {
        final imagesState = ref.read(selectedImagesProvider);
        final selectedImage = imagesState.currentImage;
        if (selectedImage == null) return;
        imageBytes = await File(selectedImage.path).readAsBytes();
      }

      // Decode the image
      final originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) {
        throw Exception('Failed to decode image');
      }

      // Get the screen dimensions to calculate the actual crop coordinates
      final screenSize = MediaQuery.of(context).size;
      final imageAspectRatio = originalImage.width / originalImage.height;
      final screenAspectRatio = screenSize.width / screenSize.height;

      double displayWidth, displayHeight;
      double offsetX = 0, offsetY = 0;

      // Calculate how the image is displayed (BoxFit.cover behavior)
      if (imageAspectRatio > screenAspectRatio) {
        // Image is wider than screen
        displayHeight = screenSize.height;
        displayWidth = displayHeight * imageAspectRatio;
        offsetX = (displayWidth - screenSize.width) / 2;
      } else {
        // Image is taller than screen
        displayWidth = screenSize.width;
        displayHeight = displayWidth / imageAspectRatio;
        offsetY = (displayHeight - screenSize.height) / 2;
      }

      // Convert screen coordinates to image coordinates
      final scaleX = originalImage.width / displayWidth;
      final scaleY = originalImage.height / displayHeight;

      final cropX = ((_cropRect!.left + offsetX) * scaleX).round().clamp(0, originalImage.width);
      final cropY = ((_cropRect!.top + offsetY) * scaleY).round().clamp(0, originalImage.height);
      final cropWidth = (_cropRect!.width * scaleX).round().clamp(1, originalImage.width - cropX);
      final cropHeight = (_cropRect!.height * scaleY).round().clamp(1, originalImage.height - cropY);

      // Crop the image
      final croppedImage = img.copyCrop(
        originalImage,
        x: cropX,
        y: cropY,
        width: cropWidth,
        height: cropHeight,
      );

      // Encode to bytes
      _croppedImageBytes = Uint8List.fromList(img.encodeJpg(croppedImage, quality: 90));

      print('Crop applied successfully');
    } catch (e) {
      print('Error applying crop: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to crop image: $e',
              style: const TextStyle(fontFamily: 'PlusJakartaSans'),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(milliseconds: 2500),
          ),
        );
      }
    }
  }

  void _startDetection() async {
    print('Starting detection process...');

    try {
      XFile? imageToAnalyze;
      String? imageUrl;

      // Handle cropped images differently based on source
      if (_isCropMode && _cropRect != null && widget.imageUrl != null) {
        // For Cloudinary URLs, use transformation API instead of downloading/re-uploading
        if (widget.imageUrl!.contains('cloudinary.com')) {
          print('Using Cloudinary transformation for crop');
          imageUrl = await _generateCloudinaryCropUrl(widget.imageUrl!, _cropRect!);
          print('Cloudinary crop URL: $imageUrl');
          // Don't create XFile - we'll pass URL directly
        } else {
          // For non-Cloudinary URLs, crop locally
          await _applyCrop();
          if (_croppedImageBytes != null) {
            final tempDir = Directory.systemTemp;
            final fileName = 'cropped_${DateTime.now().millisecondsSinceEpoch}.jpg';
            final file = File('${tempDir.path}/$fileName');
            await file.writeAsBytes(_croppedImageBytes!);
            imageToAnalyze = XFile(file.path);
          }
        }
      } else if (_croppedImageBytes != null) {
        // Local image was cropped
        print('Using locally cropped image for analysis');
        final tempDir = Directory.systemTemp;
        final fileName = 'cropped_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(_croppedImageBytes!);
        imageToAnalyze = XFile(file.path);
      } else if (widget.imageUrl != null) {
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

      // Skip YOLO detection if user manually cropped the image
      final skipDetection = _croppedImageBytes != null || (_isCropMode && _cropRect != null);

      final results = await ref
          .read(detectionProvider.notifier)
          .analyzeImage(
            imageToAnalyze,
            skipDetection: skipDetection,
            cloudinaryUrl: imageUrl,
          );

      if (mounted && results.isNotEmpty) {
        // Haptic feedback for successful detection
        HapticFeedback.mediumImpact();

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
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Detection failed: $e',
              style: const TextStyle(fontFamily: 'PlusJakartaSans'),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(milliseconds: 2500),
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
    final cornerRadius = 20.0;
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
