import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../../../home/domain/providers/image_provider.dart';
import '../../../results/presentation/widgets/results_bottom_sheet.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/snaplook_ai_icon.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../detection/domain/models/detection_result.dart';
import '../providers/detection_provider.dart';
import '../widgets/detection_progress_overlay.dart';
import '../../../paywall/providers/credit_provider.dart';

class DetectionPage extends ConsumerStatefulWidget {
  final String? imageUrl;

  const DetectionPage({super.key, this.imageUrl});

  @override
  ConsumerState<DetectionPage> createState() => _DetectionPageState();
}

class _DetectionPageState extends ConsumerState<DetectionPage> {
  final PageController _pageController = PageController();

  // Crop selection state
  bool _isCropMode = false;
  Rect? _cropRect;
  Uint8List? _croppedImageBytes;

  // Loading overlay state
  bool _isAnalysisOverlayVisible = false;
  bool _hasEnteredSearchPhase = false;
  double _currentProgress = 0.0;
  double _targetProgress = 0.0;
  String _activeStatusText = 'Preparing photo...';
  Timer? _progressTimer;
  Timer? _statusRotationTimer;
  final List<Timer> _overlayTimers = [];
  int _statusIndex = 0;

  // Results sheet state
  static const double _resultsMinExtent = 0.4;
  static const double _resultsInitialExtent = 0.6;
  static const double _resultsMaxExtent = 0.85;
  final DraggableScrollableController _resultsSheetController =
      DraggableScrollableController();
  double _currentResultsExtent = _resultsInitialExtent;
  bool _isResultsSheetVisible = false;
  List<DetectionResult> _results = [];

  static const List<String> _detectionPhaseMessages = [
    'Detecting garments...',
    'Analyzing clothing...',
    'Identifying items...',
  ];

  static const List<String> _searchPhaseMessages = [
    'Searching for products...',
    'Finding similar items...',
    'Analyzing style...',
    'Checking retailers...',
    'Almost there...',
    'Finalizing results...',
    'Preparing your matches...',
  ];

  @override
  void initState() {
    super.initState();
    print("[DETECTION PAGE] initState called");
    print("[DETECTION PAGE] imageUrl: ${widget.imageUrl}");
  }

  @override
  void dispose() {
    _hideAnalysisOverlay();
    _pageController.dispose();
    _resultsSheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imagesState = ref.watch(selectedImagesProvider);
    final selectedImage = imagesState.currentImage;
    final detectionState = ref.watch(detectionProvider);
    final bool hasImage = selectedImage != null || widget.imageUrl != null;
    final bool showShareAction = _isResultsSheetVisible && _results.isNotEmpty;
    final bool isCropActionActive = !showShareAction && _isCropMode;
    final Color actionBackgroundColor = isCropActionActive
        ? AppColors.secondary
        : Colors.white.withOpacity(0.9);
    final Color actionIconColor =
        isCropActionActive ? Colors.white : Colors.black;

    print("[DETECTION PAGE] build called");
    print("[DETECTION PAGE] selectedImage: ${selectedImage?.path ?? 'null'}");
    print("[DETECTION PAGE] widget.imageUrl: ${widget.imageUrl ?? 'null'}");
    print(
        "[DETECTION PAGE] hasMultipleImages: ${imagesState.hasMultipleImages}");
    print("[DETECTION PAGE] totalImages: ${imagesState.totalImages}");

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        extendBody: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarBrightness: Brightness.dark,
            statusBarIconBrightness: Brightness.light,
          ),
          leading: _isAnalysisOverlayVisible
              ? null
              : Container(
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
          actions: _isAnalysisOverlayVisible
              ? null
              : [
                  Container(
                    margin: const EdgeInsets.all(8),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: actionBackgroundColor,
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
                      onPressed: showShareAction
                          ? _shareImage
                          : (hasImage ? _toggleCropMode : null),
                      icon: Icon(
                        showShareAction ? Icons.ios_share : Icons.crop_free,
                        color: actionIconColor,
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
                          child: Stack(
                            children: [
                              Positioned.fill(child: _buildNetworkImage()),
                              if (_isAnalysisOverlayVisible)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: Container(
                                      color: Colors.black.withOpacity(0.6),
                                    ),
                                  ),
                                ),
                            ],
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
                                  gaplessPlayback: true,
                                );
                              },
                            )
                          : Image.file(
                              File(selectedImage!.path),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              gaplessPlayback: true,
                            ),
                ),
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
                        child: _isAnalysisOverlayVisible
                            || _isResultsSheetVisible
                            ? const SizedBox.shrink()
                            : _buildScanButton(),
                      ),
                    ],
                  ),
                ),
                if (_isResultsSheetVisible && _results.isNotEmpty) ...[
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      ignoring: true,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        color: Colors.black
                            .withOpacity(_resultsOverlayOpacity),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height,
                      child:
                          NotificationListener<DraggableScrollableNotification>(
                        onNotification: (notification) {
                          final extent = notification.extent
                              .clamp(_resultsMinExtent, _resultsMaxExtent)
                              .toDouble();
                          setState(() => _currentResultsExtent = extent);
                          return false;
                        },
                        child: DraggableScrollableSheet(
                          controller: _resultsSheetController,
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
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
                if (_isAnalysisOverlayVisible) _buildDetectionOverlay(),
              ],
            ),
      ),
    );
  }

  Widget _buildDetectionOverlay() {
    return DetectionProgressOverlay(
      statusText: _activeStatusText,
      progress: _currentProgress,
    );
  }

  Future<void> _openProduct(DetectionResult result) async {
    if (result.purchaseUrl != null) {
      final uri = Uri.parse(result.purchaseUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  Future<void> _shareImage() async {
    try {
      if (widget.imageUrl != null) {
        final uri = Uri.parse(widget.imageUrl!);
        final response = await http.get(uri);
        final bytes = response.bodyBytes;
        final temp = await File('${Directory.systemTemp.path}/share_image.jpg').create();
        await temp.writeAsBytes(bytes);
        await Share.shareXFiles([XFile(temp.path)], text: 'Check out what I found with Snaplook!');
      } else {
        final imagesState = ref.read(selectedImagesProvider);
        final selectedImage = imagesState.currentImage;
        if (selectedImage != null) {
          await Share.shareXFiles([XFile(selectedImage.path)], text: 'Check out what I found with Snaplook!');
        }
      }
    } catch (e) {
      print('Error sharing image: $e');
    }
  }

  void _toggleCropMode() {
    if (!mounted) return;

    setState(() {
      if (_isCropMode) {
        _isCropMode = false;
        _croppedImageBytes = null;
      } else {
        _isCropMode = true;
        _initializeCropRectIfNeeded();
      }
    });
  }


  void _initializeCropRectIfNeeded() {
    if (_cropRect != null) return;

    final size = MediaQuery.of(context).size;
    final width = size.width * 0.72;
    final height = size.height * 0.48;
    final left = (size.width - width) / 2;
    final top = (size.height - height) / 2;

    _cropRect = Rect.fromLTWH(left, top, width, height);
  }

  Widget _buildNetworkPlaceholder() {
    return Container(
      color: AppColors.surface,
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

  Widget _buildNetworkImage() {
    if (widget.imageUrl == null) {
      return const SizedBox.shrink();
    }

    return CachedNetworkImage(
      imageUrl: widget.imageUrl!,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholderFadeInDuration: Duration.zero,
      placeholder: (_, __) => _buildNetworkPlaceholder(),
      errorWidget: (_, __, ___) => _buildNetworkError(),
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
              style: context.snackTextStyle(
                merge: const TextStyle(fontFamily: 'PlusJakartaSans'),
              ),
            ),
            duration: const Duration(milliseconds: 2500),
          ),
        );
      }
    }
  }

  void _showAnalysisOverlayIfNeeded() {
    _clearOverlayTimers();
    _stopStatusRotation();
    _stopProgressTimer();

    setState(() {
      _isAnalysisOverlayVisible = true;
      _hasEnteredSearchPhase = false;
      _currentProgress = 0.0;
      _targetProgress = 0.18;
      _activeStatusText = 'Preparing photo...';
      _statusIndex = 0;
    });

    _startSmoothProgressTimer();
    _startStatusRotation(_detectionPhaseMessages);

    _setTargetProgress(0.24);
    _scheduleOverlayTimer(const Duration(milliseconds: 900),
        () => _setTargetProgress(0.32));
    _scheduleOverlayTimer(const Duration(milliseconds: 2100),
        () => _setTargetProgress(0.45));
    _scheduleOverlayTimer(const Duration(milliseconds: 3600),
        () => _setTargetProgress(0.58));
    _scheduleOverlayTimer(const Duration(milliseconds: 5200),
        () => _setTargetProgress(0.68));
  }

  void _enterSearchPhase() {
    if (!_isAnalysisOverlayVisible || _hasEnteredSearchPhase) return;
    _hasEnteredSearchPhase = true;
    _setTargetProgress(0.78);
    _startStatusRotation(_searchPhaseMessages, stopAtLast: true);
  }

  void _finishOverlayForNavigation() {
    if (!_isAnalysisOverlayVisible) return;
    _enterSearchPhase();
    _stopStatusRotation();
    setState(() {
      _activeStatusText = 'Opening results...';
    });
    _setTargetProgress(0.92);
    _scheduleOverlayTimer(
      const Duration(milliseconds: 180),
      () => _setTargetProgress(1.0),
    );
  }

  void _hideAnalysisOverlay() {
    _clearOverlayTimers();
    _stopStatusRotation();
    _stopProgressTimer();

    if (!_isAnalysisOverlayVisible) return;
    if (!mounted) {
      _isAnalysisOverlayVisible = false;
      _currentProgress = 0.0;
      _targetProgress = 0.0;
      _activeStatusText = 'Preparing photo...';
      _hasEnteredSearchPhase = false;
      _statusIndex = 0;
      return;
    }

    setState(() {
      _isAnalysisOverlayVisible = false;
      _currentProgress = 0.0;
      _targetProgress = 0.0;
      _activeStatusText = 'Preparing photo...';
      _hasEnteredSearchPhase = false;
      _statusIndex = 0;
    });
  }

  double get _resultsOverlayOpacity {
    if (!_isResultsSheetVisible) return 0;
    final range = _resultsMaxExtent - _resultsMinExtent;
    if (range <= 0) return 0.7;
    final normalized = ((_currentResultsExtent - _resultsMinExtent) / range)
        .clamp(0.0, 1.0);
    return 0.15 + (0.55 * normalized);
  }

  void _startSmoothProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted || !_isAnalysisOverlayVisible) {
        timer.cancel();
        return;
      }

      double nextProgress = _currentProgress;

      if (_currentProgress < _targetProgress) {
        const increment = 0.004;
        nextProgress = (_currentProgress + increment).clamp(0.0, _targetProgress);
      } else if (_currentProgress < 0.95) {
        const slowIncrement = 0.0006;
        nextProgress = (_currentProgress + slowIncrement).clamp(0.0, 0.95);
      } else {
        return;
      }

      if ((nextProgress - _currentProgress).abs() > 0.0001) {
        setState(() {
          _currentProgress = nextProgress;
        });
      }
    });
  }

  void _stopProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  void _setTargetProgress(double value) {
    _targetProgress = value.clamp(0.0, 1.0);
  }

  void _startStatusRotation(List<String> messages, {bool stopAtLast = false}) {
    if (messages.isEmpty) return;

    _statusRotationTimer?.cancel();
    _statusIndex = 0;

    setState(() {
      _activeStatusText = messages.first;
    });

    if (messages.length == 1 && stopAtLast) {
      return;
    }

    _statusRotationTimer =
        Timer.periodic(const Duration(milliseconds: 2500), (timer) {
      if (!mounted || !_isAnalysisOverlayVisible) {
        timer.cancel();
        return;
      }

      if (stopAtLast && _statusIndex >= messages.length - 1) {
        timer.cancel();
        return;
      }

      _statusIndex = stopAtLast
          ? (_statusIndex + 1).clamp(0, messages.length - 1)
          : (_statusIndex + 1) % messages.length;

      setState(() {
        _activeStatusText = messages[_statusIndex];
      });
    });
  }

  void _stopStatusRotation() {
    _statusRotationTimer?.cancel();
    _statusRotationTimer = null;
    _statusIndex = 0;
  }

  void _scheduleOverlayTimer(Duration delay, VoidCallback action) {
    final timer = Timer(delay, () {
      if (!mounted || !_isAnalysisOverlayVisible) return;
      action();
    });
    _overlayTimers.add(timer);
  }

  void _clearOverlayTimers() {
    for (final timer in _overlayTimers) {
      timer.cancel();
    }
    _overlayTimers.clear();
  }

  void _startDetection() async {
    print('Starting detection process...');

    try {
      if (_isAnalysisOverlayVisible || ref.read(detectionProvider).isAnalyzing) {
        return;
      }

      if (_isResultsSheetVisible || _results.isNotEmpty) {
        setState(() {
          _isResultsSheetVisible = false;
          _results = [];
        });
      }

      HapticFeedback.mediumImpact();
      _showAnalysisOverlayIfNeeded();

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
        final remoteUri = Uri.tryParse(widget.imageUrl!);
        final isCloudAsset =
            remoteUri != null && remoteUri.host.contains('cloudinary');

        if (isCloudAsset) {
          print('Using existing Cloudinary URL for detection');
          imageUrl = widget.imageUrl;
        } else {
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
        }
      } else {
        // Local image from camera/gallery - use existing logic
        final imagesState = ref.read(selectedImagesProvider);
        final selectedImage = imagesState.currentImage;
        if (selectedImage == null) {
          _hideAnalysisOverlay();
          return;
        }
        imageToAnalyze = selectedImage;
      }

      // Skip YOLO detection if user manually cropped the image
      final skipDetection = _croppedImageBytes != null || (_isCropMode && _cropRect != null);

      _enterSearchPhase();
      _setTargetProgress(0.8);

      final results = await ref
          .read(detectionProvider.notifier)
          .analyzeImage(
            imageToAnalyze,
            skipDetection: skipDetection,
            cloudinaryUrl: imageUrl,
          );

      if (mounted && results.isNotEmpty) {
        _finishOverlayForNavigation();
        await Future.delayed(const Duration(milliseconds: 320));
        if (!mounted) return;

        // Trigger haptic feedback when results appear
        HapticFeedback.mediumImpact();

        // Consume credit for successful analysis
        try {
          await ref.read(creditBalanceProvider.notifier).consumeCredit();
          print('Credit consumed successfully');
        } catch (e) {
          print('Error consuming credit: $e');
        }

        setState(() {
          _results = results;
          _isResultsSheetVisible = true;
          _currentResultsExtent = _resultsInitialExtent;
        });
        _hideAnalysisOverlay();
      } else {
        _hideAnalysisOverlay();
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No similar items found. Try another photo.',
                style: context.snackTextStyle(
                  merge: const TextStyle(fontFamily: 'PlusJakartaSans'),
                ),
              ),
              duration: const Duration(milliseconds: 2500),
            ),
          );
        }
      }
    } catch (e) {
      print('DETECTION ERROR: $e');
      print('Error type: ${e.runtimeType}');
      _hideAnalysisOverlay();
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Detection failed: $e',
              style: context.snackTextStyle(
                merge: const TextStyle(fontFamily: 'PlusJakartaSans'),
              ),
            ),
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
