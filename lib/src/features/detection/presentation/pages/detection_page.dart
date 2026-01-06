import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
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
import 'package:snaplook/src/shared/utils/native_share_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'share_payload.dart';
import '../../../home/domain/providers/image_provider.dart';
import '../../../results/presentation/widgets/results_bottom_sheet.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/snaplook_ai_icon.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../detection/domain/models/detection_result.dart';
import '../providers/detection_provider.dart';
import '../widgets/detection_progress_overlay.dart';
import '../../../paywall/providers/credit_provider.dart';
import '../../../paywall/presentation/pages/paywall_page.dart';
import '../../../../shared/services/supabase_service.dart';
import '../../../auth/domain/providers/auth_provider.dart';
import '../../../../shared/widgets/snaplook_circular_icon_button.dart';
import '../../../../services/paywall_helper.dart';

class DetectionPage extends ConsumerStatefulWidget {
  final String? imageUrl;
  final String? searchId;
  final String searchType;

  /// Source URL for cache lookup (e.g., Instagram post URL)
  /// This is separate from imageUrl which is used for loading images
  final String? sourceUrl;

  const DetectionPage({
    super.key,
    this.imageUrl,
    this.searchId,
    this.searchType = 'camera',
    this.sourceUrl,
  });

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
  bool _isBoostingProgress = false;
  String _activeStatusText = 'Preparing photo...';
  Timer? _progressTimer;
  Timer? _statusRotationTimer;
  final List<Timer> _overlayTimers = [];
  int _statusIndex = 0;
  Map<String, dynamic>? _loadedSearchData;

  // Results sheet state
  static const double _resultsMinExtent = 0.4;
  static const double _resultsInitialExtent = 0.6;
  static const double _resultsMaxExtent = 0.85;
  final DraggableScrollableController _resultsSheetController =
      DraggableScrollableController();

  // Share card constants - 9:16 aspect ratio for social media
  static const Size _shareCardSize = Size(1080, 1920);
  static const double _shareCardPixelRatio = 2.0;
  double _currentResultsExtent = _resultsInitialExtent;
  bool _isResultsSheetVisible = false;
  List<DetectionResult> _results = [];
  bool _isLoadingExistingResults = false;

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
    print("[DETECTION PAGE] searchId: ${widget.searchId}");

    // If searchId is provided, load existing results from Supabase
    if (widget.searchId != null) {
      // Clear any previously selected images so the loaded image takes precedence
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(selectedImagesProvider.notifier).clearImages();
      });
      setState(() {
        _isLoadingExistingResults = true;
      });
      _loadExistingResults(widget.searchId!);
    } else if (widget.imageUrl != null) {
      // Clear any previously selected images when loading a network image (e.g., from inspiration)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(selectedImagesProvider.notifier).clearImages();
      });
    }
  }

  String? _loadedImageUrl;

  Future<void> _loadExistingResults(String searchId) async {
    final start = DateTime.now();
    try {
      print(
          "[DETECTION PAGE] Loading existing results for searchId: $searchId");

      final supabaseService = SupabaseService();
      final searchData = await supabaseService.getSearchById(searchId);

      if (searchData == null) {
        print("[DETECTION PAGE] No search data found for searchId: $searchId");
        setState(() {
          _isLoadingExistingResults = false;
        });
        return;
      }

      final searchResults = searchData['search_results'] as List<dynamic>?;
      if (searchResults == null || searchResults.isEmpty) {
        print("[DETECTION PAGE] No results found in search data");
        setState(() {
          _isLoadingExistingResults = false;
        });
        return;
      }

      // Parse results into DetectionResult objects
      print("[DETECTION PAGE] Raw search results: $searchResults");

      final results = <DetectionResult>[];
      for (var i = 0; i < searchResults.length; i++) {
        try {
          final jsonData = Map<String, dynamic>.from(searchResults[i]);
          print("[DETECTION PAGE] Parsing result $i: $jsonData");
          final result = DetectionResult.fromJson(jsonData);
          results.add(result);
        } catch (e, stack) {
          print("[DETECTION PAGE] Error parsing result $i: $e");
          print("[DETECTION PAGE] Stack trace: $stack");
          print("[DETECTION PAGE] Problematic data: ${searchResults[i]}");
        }
      }

      if (results.isEmpty) {
        print("[DETECTION PAGE] Failed to parse any results");
        setState(() {
          _isLoadingExistingResults = false;
        });
        return;
      }

      print(
          "[DETECTION PAGE] Successfully loaded ${results.length} existing results");

      _loadedSearchData = searchData;

      // Get the Cloudinary URL for the analyzed image
      final cloudinaryUrl = searchData['cloudinary_url'] as String?;
      print("[DETECTION PAGE] Cloudinary URL: $cloudinaryUrl");

      // Pre-cache the image so it displays instantly
      if (cloudinaryUrl != null && mounted) {
        try {
          await precacheImage(
            CachedNetworkImageProvider(cloudinaryUrl),
            context,
          );
          print("[DETECTION PAGE] Image pre-cached successfully");
        } catch (e) {
          print("[DETECTION PAGE] Failed to pre-cache image: $e");
          // Continue anyway - image will load when displayed
        }
      }

      if (!mounted) return;
      await _ensureMinimumLoadDuration(start);

      // Show results directly - image is already in memory
      if (!mounted) return;
      setState(() {
        _results = results;
        _isResultsSheetVisible = true;
        _loadedImageUrl = cloudinaryUrl;
        _isLoadingExistingResults = false;
      });
    } catch (e) {
      print("[DETECTION PAGE] Error loading existing results: $e");
      await _ensureMinimumLoadDuration(start);
      if (mounted) {
        setState(() {
          _isLoadingExistingResults = false;
        });
      }
    }
  }

  Future<void> _ensureMinimumLoadDuration(DateTime start) async {
    const minDuration = Duration(seconds: 1);
    final elapsed = DateTime.now().difference(start);
    final remaining = minDuration - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }
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
    final bool hasImage = selectedImage != null ||
        widget.imageUrl != null ||
        _loadedImageUrl != null;
    final bool showShareAction = _isResultsSheetVisible && _results.isNotEmpty;
    final bool isCropActionActive = !showShareAction && _isCropMode;
    final Color actionBackgroundColor =
        isCropActionActive ? AppColors.secondary : const Color(0xFFF3F4F6);
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
        // Dark (black) status bar icons
        statusBarBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
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
            // Dark (black) status bar icons
            statusBarBrightness: Brightness.light,
            statusBarIconBrightness: Brightness.dark,
          ),
          leading: _isAnalysisOverlayVisible || _isLoadingExistingResults
              ? null
              : SnaplookCircularIconButton(
                  icon: Icons.close,
                  iconSize: 20,
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                  semanticLabel: 'Close',
                  margin: const EdgeInsets.all(8),
                ),
          actions: _isAnalysisOverlayVisible || _isLoadingExistingResults
              ? null
              : [
                  if (!showShareAction)
                    SnaplookCircularIconButton(
                      icon: Icons.info_outline,
                      iconSize: 20,
                      onPressed: _showAnalysisInfoDialog,
                      backgroundColor: AppColors.secondary,
                      iconColor: Colors.white,
                      tooltip: 'Analysis info',
                      semanticLabel: 'Analysis information',
                      margin: const EdgeInsets.all(8),
                      elevation: 10,
                    ),
                  SnaplookCircularIconButton(
                    icon: showShareAction
                        ? Icons.share_outlined
                        : Icons.crop_free,
                    iconSize: showShareAction ? 18 : 20,
                    iconOffset:
                        showShareAction ? const Offset(-1, 0) : Offset.zero,
                    onPressed: showShareAction
                        ? _shareImage
                        : (hasImage ? _toggleCropMode : null),
                    backgroundColor: actionBackgroundColor,
                    iconColor: actionIconColor,
                    tooltip: showShareAction ? 'Share' : 'Crop',
                    semanticLabel:
                        showShareAction ? 'Share image' : 'Crop image',
                    margin: const EdgeInsets.all(8),
                    elevation: 10,
                  ),
                ],
        ),
        body: _isLoadingExistingResults
            ? Center(
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: const CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.secondary),
                    strokeWidth: 2,
                  ),
                ),
              )
            : selectedImage == null &&
                    widget.imageUrl == null &&
                    _loadedImageUrl == null
                ? const Center(
                    child: Text(
                      'No image selected',
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                : Stack(
                    children: [
                      Positioned.fill(
                        // Only use network image if we don't have a local selectedImage
                        // widget.imageUrl may be a source URL (e.g., Instagram post) not a direct image URL
                        child: selectedImage == null &&
                                (widget.imageUrl != null ||
                                    _loadedImageUrl != null)
                            ? SizedBox.expand(
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                        child: _buildNetworkImage()),
                                    if (_isAnalysisOverlayVisible)
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          child: Container(
                                            color:
                                                Colors.black.withOpacity(0.6),
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
                                      return Container(
                                        color: Colors.black,
                                        child: Image.file(
                                          File(imagesState.images[index].path),
                                          fit: BoxFit.cover,
                                          alignment: Alignment.center,
                                          width: double.infinity,
                                          height: double.infinity,
                                          gaplessPlayback: true,
                                        ),
                                      );
                                    },
                                  )
                                : Image.file(
                                    File(selectedImage!.path),
                                    fit: BoxFit.cover,
                                    alignment: Alignment.center,
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
                              child: _isAnalysisOverlayVisible ||
                                      _isResultsSheetVisible
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
                            child: NotificationListener<
                                DraggableScrollableNotification>(
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
                                  // Determine which image to show in comparison card
                                  dynamic analyzedImage;
                                  if (_loadedImageUrl != null && _loadedImageUrl!.isNotEmpty) {
                                    analyzedImage = _loadedImageUrl;
                                  } else if (widget.imageUrl != null) {
                                    analyzedImage = widget.imageUrl;
                                  } else {
                                    analyzedImage = imagesState.currentImage;
                                  }

                                  return ResultsBottomSheetContent(
                                    results: _results,
                                    scrollController: scrollController,
                                    onProductTap: _openProduct,
                                    analyzedImage: analyzedImage,
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
      // Give tactile response when the share action is available (results showing).
      HapticFeedback.mediumImpact();

      final renderBox = context.findRenderObject() as RenderBox?;
      final origin = (renderBox != null && renderBox.hasSize)
          ? renderBox.localToGlobal(Offset.zero) & renderBox.size
          : const Rect.fromLTWH(0, 0, 1, 1);

      final sharePayload = _buildSharePayload();
      final message = sharePayload.message;
      final subject = sharePayload.subject;

      // Build share card items from results - take top 3 for stacked display
      final shareItems = <_ShareCardItem>[];
      for (final result in _results.take(3)) {
        final item = _ShareCardItem.fromDetectionResult(result);
        if (item != null) {
          shareItems.add(item);
        }
      }

      // Get hero image
      ImageProvider<Object>? heroImage;
      final imageFile = await _resolveShareImage();
      if (imageFile != null) {
        heroImage = FileImage(File(imageFile.path));
      } else if (_loadedImageUrl != null && _loadedImageUrl!.isNotEmpty) {
        heroImage = CachedNetworkImageProvider(_loadedImageUrl!);
      } else if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
        heroImage = CachedNetworkImageProvider(widget.imageUrl!);
      }

      // Generate share card
      final shareCard = await _buildShareCardFile(
        context,
        heroImage: heroImage,
        shareItems: shareItems,
      );

      final primaryFile = shareCard ?? imageFile;

      if (primaryFile != null) {
        final handled = await NativeShareHelper.shareImageFirst(
          file: primaryFile,
          text: message,
          subject: subject,
          origin: origin,
        );
        if (!handled) {
          await Share.shareXFiles(
            [primaryFile],
            text: message,
            subject: subject,
            sharePositionOrigin: origin,
          );
        }
      } else {
        await Share.share(
          message,
          subject: subject,
          sharePositionOrigin: origin,
        );
      }
    } catch (e) {
      print('Error sharing image: $e');
    }
  }

  SharePayload _buildSharePayload() {
    final buffer = StringBuffer();
    final topResults = _results.take(5).toList();
    final totalResults = _results.length;

    buffer.writeln('I analyzed this look on Snaplook and found $totalResults matches!\n');

    if (topResults.isNotEmpty) {
      buffer.writeln('Top finds:');
      for (var i = 0; i < topResults.length; i++) {
        final r = topResults[i];
        final name = r.productName.isNotEmpty ? r.productName : 'Item';
        final brand = r.brand.isNotEmpty ? r.brand : 'Unknown brand';
        final link = r.purchaseUrl ?? 'URL not available';

        buffer.writeln('${i + 1}. $brand - $name - $link');
      }
      buffer.writeln();
    }

    buffer.write('Get Snaplook to find your fashion matches: https://snaplook.app');

    return SharePayload(
      subject: 'Snaplook Fashion Matches',
      message: buffer.toString(),
    );
  }

  Future<XFile?> _resolveShareImage() async {
    try {
      // If we loaded from history, prefer the stored Cloudinary image
      if (_loadedImageUrl != null && _loadedImageUrl!.isNotEmpty) {
        final file = await _downloadTempImage(_loadedImageUrl!);
        if (file != null) return file;
      }

      // If a direct imageUrl exists on the widget (live detection)
      if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
        final file = await _downloadTempImage(widget.imageUrl!);
        if (file != null) return file;
      }

      // Fallback to currently selected image in memory
      final imagesState = ref.read(selectedImagesProvider);
      final selectedImage = imagesState.currentImage;
      if (selectedImage != null) {
        return XFile(selectedImage.path);
      }
    } catch (e) {
      print('Error resolving share image: $e');
    }
    return null;
  }

  Future<XFile?> _squareImageForShare(XFile original) async {
    try {
      final bytes = await original.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return original;

      // Scale so the shorter side meets the target size, then center-crop to a square
      final maxDim = math.max(decoded.width, decoded.height);
      const cap = 1200; // avoid huge share payloads
      final targetSize = maxDim > cap ? cap : maxDim;
      final minDim = math.min(decoded.width, decoded.height);
      final scale = targetSize / minDim;

      final resized = img.copyResize(
        decoded,
        width: (decoded.width * scale).round(),
        height: (decoded.height * scale).round(),
      );

      final cropX = ((resized.width - targetSize) / 2).round().clamp(0, resized.width - targetSize);
      final cropY =
          ((resized.height - targetSize) / 2).round().clamp(0, resized.height - targetSize);

      final square = img.copyCrop(
        resized,
        x: cropX,
        y: cropY,
        width: targetSize,
        height: targetSize,
      );

      final jpg = img.encodeJpg(square, quality: 90);
      final tempPath = '${Directory.systemTemp.path}/snaplook_fashion_search.jpg';
      final file = await File(tempPath).create();
      await file.writeAsBytes(jpg, flush: true);
      return XFile(
        file.path,
        mimeType: 'image/jpeg',
        name: 'snaplook_fashion_search.jpg',
      );
    } catch (e) {
      print('Error squaring share image: $e');
      return original;
    }
  }

  Future<XFile?> _downloadTempImage(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return null;
      }
      final temp = await File(
        '${Directory.systemTemp.path}/snaplook_share_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ).create();
      await temp.writeAsBytes(response.bodyBytes);
      return XFile(
        temp.path,
        mimeType: 'image/jpeg',
        name: 'snaplook.jpg',
      );
    } catch (e) {
      print('Error downloading share image: $e');
      return null;
    }
  }

  String _buildHistoryShareMessage(Map<String, dynamic> data) {
    final rawType = (data['search_type'] as String?)?.trim();
    final type = rawType?.toLowerCase();
    final sourceUrl = (data['source_url'] as String?)?.trim() ?? '';
    final totalResults = (data['total_results'] as num?)?.toInt() ?? 0;
    final resultsLabel =
        totalResults == 1 ? '1 product' : '$totalResults products';
    final sourceLabel = _getSourceLabel(type, rawType, sourceUrl);

    if (sourceUrl.isNotEmpty) {
      return 'Check out this $sourceLabel Snaplook search – $resultsLabel found: $sourceUrl';
    }
    return 'Check out this $sourceLabel Snaplook search – $resultsLabel found!';
  }

  String _getSourceLabel(String? type, String? rawType, String sourceUrl) {
    switch (type) {
      case 'instagram':
        return 'Instagram';
      case 'tiktok':
        return 'TikTok';
      case 'pinterest':
        return 'Pinterest';
      case 'twitter':
        return 'Twitter';
      case 'facebook':
        return 'Facebook';
      case 'youtube':
        final lowerUrl = sourceUrl.toLowerCase();
        final isShorts = lowerUrl.contains('youtube.com/shorts') ||
            lowerUrl.contains('youtu.be/shorts');
        return isShorts ? 'YouTube Shorts' : 'YouTube';
      case 'chrome':
        return 'Chrome';
      case 'firefox':
        return 'Firefox';
      case 'safari':
        return 'Safari';
      case 'web':
      case 'browser':
        return 'Web';
      case 'share':
      case 'share_extension':
      case 'shareextension':
        return 'Snaplook';
    }

    if (type == null ||
        type == 'camera' ||
        type == 'photos' ||
        type == 'home') {
      return 'Snaplook';
    }

    if (rawType != null && rawType.isNotEmpty) {
      return rawType
          .split(RegExp(r'[_-]+'))
          .map((word) =>
              word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1)}')
          .join(' ');
    }

    return 'Snaplook';
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
    // Use loaded image URL from Supabase if available, otherwise fallback to widget.imageUrl
    final imageUrl = _loadedImageUrl ?? widget.imageUrl;

    if (imageUrl == null) {
      return const SizedBox.shrink();
    }

    return CachedNetworkImage(
      key: ValueKey(imageUrl),
      imageUrl: imageUrl,
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
            // Check if user has credits before starting detection
            final creditBalance = ref.read(creditBalanceProvider);
            final hasCredits = creditBalance.when(
              data: (balance) => balance.availableCredits > 0,
              loading: () => false,
              error: (_, __) => false,
            );

            if (!hasCredits) {
              // User has no credits - show paywall
              print('[Detection] User has no credits - showing paywall');
              HapticFeedback.mediumImpact();

              if (mounted) {
                final userId = ref.read(authServiceProvider).currentUser?.id;

                // Present paywall with detection-specific placement
                final didPurchase = await PaywallHelper.presentPaywall(
                  context: context,
                  userId: userId,
                  placement: 'out_of_credits',
                );

                if (!mounted) return;

                // If user purchased, sync credits with subscription and proceed
                if (didPurchase) {
                  print('[Detection] User purchased - syncing credits with subscription');

                  // Sync credits with subscription (clears cache and refills)
                  await ref.read(creditBalanceProvider.notifier).syncWithSubscription();

                  if (!mounted) return;

                  // Check if credits are now available
                  final newCreditBalance = ref.read(creditBalanceProvider);
                  final nowHasCredits = newCreditBalance.when(
                    data: (balance) => balance.availableCredits > 0,
                    loading: () => false,
                    error: (_, __) => false,
                  );

                  if (nowHasCredits) {
                    print('[Detection] Credits available after purchase - starting detection');
                    _startDetection();
                  } else {
                    print('[Detection] No credits available after purchase - showing error');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Credits not available yet. Please try again.',
                            style: TextStyle(fontFamily: 'PlusJakartaSans'),
                          ),
                          duration: Duration(milliseconds: 2500),
                        ),
                      );
                    }
                  }
                } else {
                  print('[Detection] User dismissed paywall without purchasing');
                }
              }
              return;
            }

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

  Future<String> _generateCloudinaryCropUrl(
      String originalUrl, Rect cropRect) async {
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

      final cropX = ((cropRect.left + offsetX) * scaleX)
          .round()
          .clamp(0, originalImage.width);
      final cropY = ((cropRect.top + offsetY) * scaleY)
          .round()
          .clamp(0, originalImage.height);
      final cropWidth = (cropRect.width * scaleX)
          .round()
          .clamp(1, originalImage.width - cropX);
      final cropHeight = (cropRect.height * scaleY)
          .round()
          .clamp(1, originalImage.height - cropY);

      // Build Cloudinary transformation URL
      final uri = Uri.parse(originalUrl);
      final pathSegments = uri.pathSegments.toList();
      final uploadIndex = pathSegments.indexOf('upload');
      if (uploadIndex == -1) return originalUrl;

      // Insert crop transformation
      final cropTransform =
          'c_crop,w_$cropWidth,h_$cropHeight,x_$cropX,y_$cropY';
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

      final cropX = ((_cropRect!.left + offsetX) * scaleX)
          .round()
          .clamp(0, originalImage.width);
      final cropY = ((_cropRect!.top + offsetY) * scaleY)
          .round()
          .clamp(0, originalImage.height);
      final cropWidth = (_cropRect!.width * scaleX)
          .round()
          .clamp(1, originalImage.width - cropX);
      final cropHeight = (_cropRect!.height * scaleY)
          .round()
          .clamp(1, originalImage.height - cropY);

      // Crop the image
      final croppedImage = img.copyCrop(
        originalImage,
        x: cropX,
        y: cropY,
        width: cropWidth,
        height: cropHeight,
      );

      // Encode to bytes
      _croppedImageBytes =
          Uint8List.fromList(img.encodeJpg(croppedImage, quality: 90));

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
    _scheduleOverlayTimer(
        const Duration(milliseconds: 900), () => _setTargetProgress(0.32));
    _scheduleOverlayTimer(
        const Duration(milliseconds: 2100), () => _setTargetProgress(0.45));
    _scheduleOverlayTimer(
        const Duration(milliseconds: 3600), () => _setTargetProgress(0.58));
    _scheduleOverlayTimer(
        const Duration(milliseconds: 5200), () => _setTargetProgress(0.68));
  }

  void _enterSearchPhase() {
    if (!_isAnalysisOverlayVisible || _hasEnteredSearchPhase) return;
    _hasEnteredSearchPhase = true;
    _setTargetProgress(0.78);
    _startStatusRotation(_searchPhaseMessages, stopAtLast: true);
  }

  void _finishOverlayForNavigation({bool immediate = false}) {
    if (!_isAnalysisOverlayVisible) return;
    _enterSearchPhase();
    _stopStatusRotation();
    setState(() {
      _activeStatusText =
          immediate ? 'Loaded saved results...' : 'Opening results...';
    });
    if (immediate) {
      // Force to 100% immediately for cache hits to avoid visible backtracking
      _isBoostingProgress = false;
      _targetProgress = 1.0;
      _currentProgress = 1.0;
    } else {
      _isBoostingProgress = true;
      _setTargetProgress(1.0);
    }
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
      _isBoostingProgress = false;
      _activeStatusText = 'Preparing photo...';
      _hasEnteredSearchPhase = false;
      _statusIndex = 0;
      return;
    }

    setState(() {
      _isAnalysisOverlayVisible = false;
      _currentProgress = 0.0;
      _targetProgress = 0.0;
      _isBoostingProgress = false;
      _activeStatusText = 'Preparing photo...';
      _hasEnteredSearchPhase = false;
      _statusIndex = 0;
    });
  }

  void _showAnalysisInfoDialog() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final spacing = context.spacing;

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (dialogContext) {
        return Dialog(
          clipBehavior: Clip.antiAlias,
          backgroundColor: colorScheme.surface,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(spacing.l, spacing.l, spacing.l, spacing.l),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        'How It Works',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    SnaplookCircularIconButton(
                      icon: Icons.close,
                      size: 40,
                      iconSize: 18,
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      semanticLabel: 'Close',
                    ),
                  ],
                ),
                SizedBox(height: spacing.m),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule_outlined,
                        size: 20,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Analyses take 5-15 seconds on average. During peak hours, you may experience longer wait times.',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: spacing.sm),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.crop_free,
                        size: 20,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Cropping can help you save credits because each garment scanned uses one.',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: spacing.l),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      textStyle: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Got it', textAlign: TextAlign.center),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showNoResultsDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(dialogContext).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Icon(
              Icons.search_off,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Results Found',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We couldn\'t find any matching products.\nTry a different image with clearer clothing items.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.secondary,
            ),
            child: const Text(
              'OK',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
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

  void _startSmoothProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted || !_isAnalysisOverlayVisible) {
        timer.cancel();
        return;
      }

      double nextProgress = _currentProgress;

      if (_isBoostingProgress) {
        const boostIncrement = 0.02;
        nextProgress =
            (_currentProgress + boostIncrement).clamp(0.0, _targetProgress);
      } else if (_currentProgress < _targetProgress) {
        const increment = 0.004;
        nextProgress =
            (_currentProgress + increment).clamp(0.0, _targetProgress);
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
        if (_isBoostingProgress && _currentProgress >= 0.999) {
          _isBoostingProgress = false;
          _currentProgress = 1.0;
        }
      }
    });
  }

  void _stopProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
    _isBoostingProgress = false;
  }

  Future<void> _waitForProgressCompletion({
    Duration timeout = const Duration(milliseconds: 800),
  }) async {
    if (!_isAnalysisOverlayVisible) return;
    final stopwatch = Stopwatch()..start();
    while (mounted && _isAnalysisOverlayVisible && _currentProgress < 0.999) {
      if (stopwatch.elapsed > timeout) break;
      await Future.delayed(const Duration(milliseconds: 16));
    }
    if (mounted && _isAnalysisOverlayVisible) {
      setState(() => _currentProgress = 1.0);
    } else {
      _currentProgress = 1.0;
    }
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
    print('[SAVE] _startDetection() called');

    try {
      if (_isAnalysisOverlayVisible ||
          ref.read(detectionProvider).isAnalyzing) {
        print('[SAVE] Early return - overlay visible or already analyzing');
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
          imageUrl =
              await _generateCloudinaryCropUrl(widget.imageUrl!, _cropRect!);
          print('Cloudinary crop URL: $imageUrl');
          // Don't create XFile - we'll pass URL directly
        } else {
          // For non-Cloudinary URLs, crop locally
          await _applyCrop();
          if (_croppedImageBytes != null) {
            final tempDir = Directory.systemTemp;
            final fileName =
                'cropped_${DateTime.now().millisecondsSinceEpoch}.jpg';
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
            final fileName =
                'scan_${DateTime.now().millisecondsSinceEpoch}.jpg';
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
      final skipDetection =
          _croppedImageBytes != null || (_isCropMode && _cropRect != null);

      _enterSearchPhase();
      _setTargetProgress(0.8);

      print(
          '[SAVE] Calling analyzeImage with searchType: ${widget.searchType}');
      print(
          '[CACHE] Source URL for cache lookup: ${widget.sourceUrl ?? widget.imageUrl}');
      final results = await ref.read(detectionProvider.notifier).analyzeImage(
            imageToAnalyze,
            skipDetection: skipDetection,
            cloudinaryUrl: imageUrl,
            searchType: widget.searchType,
            sourceUrl: widget.sourceUrl ?? widget.imageUrl,
          );
      final wasCacheHit =
          ref.read(detectionServiceProvider).lastResponseFromCache;

      if (mounted && results.isNotEmpty) {
        _finishOverlayForNavigation(immediate: wasCacheHit);
        await _waitForProgressCompletion();
        await Future.delayed(
          wasCacheHit
              ? const Duration(milliseconds: 200)
              : const Duration(milliseconds: 320),
        );
        if (!mounted) return;

        // Trigger haptic feedback when results appear
        HapticFeedback.mediumImpact();

        // Deduct credits based on garment count
        try {
          // Get the actual number of garments searched from the server response
          final garmentCount = ref.read(detectionServiceProvider).lastGarmentsSearched;

          print('[Credits] Server reported $garmentCount garments searched');

          // Call Supabase function to deduct credits
          final userId = Supabase.instance.client.auth.currentUser?.id;
          if (userId != null) {
            final response = await Supabase.instance.client
                .rpc('deduct_credits', params: {
              'p_user_id': userId,
              'p_garment_count': garmentCount,
            });

            print('[Credits] Deduction response: $response');

            if (response != null && response is List && response.isNotEmpty) {
              final result = response.first;
              if (result['success'] == true) {
                print('[Credits] Successfully deducted $garmentCount credits');
                print('[Credits] Remaining: ${result['paid_credits_remaining']}');

                // Re-sync auth state to update credits in iOS share extension
                await ref.read(authServiceProvider).syncAuthState();
              } else {
                print('[Credits] Deduction failed: ${result['message']}');
              }
            }
          }
        } catch (e) {
          print('[Credits] Error deducting credits: $e');
          // Don't block the user from seeing results if credit deduction fails
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
          _showNoResultsDialog();
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

  Future<XFile?> _buildShareCardFile(
    BuildContext context, {
    required ImageProvider<Object>? heroImage,
    required List<_ShareCardItem> shareItems,
  }) async {
    try {
      await _precacheShareImages(
        context,
        [
          heroImage,
          ...shareItems.map((item) => item.imageProvider),
        ],
      );
      final bytes = await _captureShareCardBytes(
        context,
        heroImage: heroImage,
        shareItems: shareItems,
      );
      if (bytes == null || bytes.isEmpty) return null;

      final filePath =
          '${Directory.systemTemp.path}/snaplook_share_card_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);
      return XFile(
        filePath,
        mimeType: 'image/png',
        name: 'snaplook_share_card.png',
      );
    } catch (e) {
      debugPrint('Error creating share card: $e');
      return null;
    }
  }

  Future<void> _precacheShareImages(
    BuildContext context,
    List<ImageProvider<Object>?> images,
  ) async {
    for (final image in images) {
      if (image == null) continue;
      try {
        await precacheImage(image, context);
      } catch (e) {
        debugPrint('Error precaching share image: $e');
      }
    }
  }

  Future<Uint8List?> _captureShareCardBytes(
    BuildContext context, {
    required ImageProvider<Object>? heroImage,
    required List<_ShareCardItem> shareItems,
  }) async {
    final overlay = Overlay.of(context, rootOverlay: true);
    if (overlay == null) return null;

    final boundaryKey = GlobalKey();
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (overlayContext) {
        return Positioned(
          left: -_shareCardSize.width - 20,
          top: 0,
          child: Material(
            type: MaterialType.transparency,
            child: MediaQuery(
              data: MediaQuery.of(overlayContext).copyWith(
                size: _shareCardSize,
              ),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: RepaintBoundary(
                  key: boundaryKey,
                  child: SizedBox(
                    width: _shareCardSize.width,
                    height: _shareCardSize.height,
                    child: _DetectionShareCard(
                      heroImage: heroImage,
                      shareItems: shareItems,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(entry);

    try {
      await Future.delayed(const Duration(milliseconds: 30));
      final boundary =
          boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: _shareCardPixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      return byteData.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing share card: $e');
      return null;
    } finally {
      entry.remove();
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

class _DetectionShareCard extends StatelessWidget {
  final ImageProvider<Object>? heroImage;
  final List<_ShareCardItem> shareItems;

  const _DetectionShareCard({
    required this.heroImage,
    required this.shareItems,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final scale = width / 1080;
        double s(double value) => value * scale;

        final cardWidth = width * 0.88;
        final cardPadding = s(40);
        final heroHeight = s(600);
        final heroRadius = s(24);

        return Container(
          width: width,
          height: height,
          color: const Color(0xFFF5F3F0),
          child: Center(
            child: Container(
              width: cardWidth,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(s(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: s(40),
                    offset: Offset(0, s(20)),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: s(60)),

                  Text(
                    'I snapped this 📸',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: s(16),
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF6B6B6B),
                      letterSpacing: 0.3,
                    ),
                  ),

                  SizedBox(height: s(32)),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: cardPadding),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(heroRadius),
                          child: Container(
                            height: heroHeight,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(heroRadius),
                            ),
                            child: heroImage != null
                                ? Image(
                                    image: heroImage!,
                                    fit: BoxFit.cover,
                                  )
                                : const Icon(
                                    Icons.image_rounded,
                                    color: Color(0xFFBDBDBD),
                                    size: 64,
                                  ),
                          ),
                        ),
                        Positioned(
                          top: s(16),
                          left: s(16),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: s(12),
                              vertical: s(6),
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(s(6)),
                            ),
                            child: Text(
                              'MY PHOTO',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: s(10),
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF9B9B9B),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: s(40)),

                  Text(
                    '↓ Snaplook found',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: s(14),
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF9B9B9B),
                      letterSpacing: 0.2,
                    ),
                  ),

                  SizedBox(height: s(32)),

                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: s(24),
                      vertical: s(12),
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(s(20)),
                      border: Border.all(
                        color: const Color(0xFFEEEEEE),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'Top Visual Match 🔥',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: s(15),
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2B2B2B),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),

                  SizedBox(height: s(40)),

                  if (shareItems.isNotEmpty)
                    SizedBox(
                      height: s(360),
                      child: Center(
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            if (shareItems.length > 2)
                              Positioned(
                                left: s(40),
                                top: s(60),
                                child: Transform.rotate(
                                  angle: -0.08,
                                  child: _StackedProductImage(
                                    item: shareItems[2],
                                    size: s(180),
                                    radius: s(16),
                                    elevation: 2,
                                  ),
                                ),
                              ),
                            if (shareItems.length > 1)
                              Positioned(
                                right: s(40),
                                top: s(40),
                                child: Transform.rotate(
                                  angle: 0.08,
                                  child: _StackedProductImage(
                                    item: shareItems[1],
                                    size: s(200),
                                    radius: s(16),
                                    elevation: 4,
                                  ),
                                ),
                              ),
                            _StackedProductImage(
                              item: shareItems[0],
                              size: s(240),
                              radius: s(20),
                              elevation: 8,
                            ),
                          ],
                        ),
                      ),
                    ),

                  SizedBox(height: s(50)),

                  Text(
                    'snaplook',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: s(18),
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1C1C1C),
                      letterSpacing: -0.5,
                    ),
                  ),

                  SizedBox(height: s(60)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StackedProductImage extends StatelessWidget {
  final _ShareCardItem item;
  final double size;
  final double radius;
  final double elevation;

  const _StackedProductImage({
    required this.item,
    required this.size,
    required this.radius,
    required this.elevation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: elevation * 2,
            offset: Offset(0, elevation),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: item.imageProvider != null
            ? Image(
                image: item.imageProvider!,
                fit: BoxFit.cover,
              )
            : Container(
                color: const Color(0xFFF5F5F5),
                child: Icon(
                  Icons.image_rounded,
                  color: const Color(0xFFCCCCCC),
                  size: size * 0.4,
                ),
              ),
      ),
    );
  }
}

class _ShareCardItem {
  final String brand;
  final String title;
  final String? priceText;
  final ImageProvider<Object>? imageProvider;

  const _ShareCardItem({
    required this.brand,
    required this.title,
    required this.priceText,
    required this.imageProvider,
  });

  static _ShareCardItem? fromDetectionResult(DetectionResult result) {
    final brand = result.brand.isNotEmpty ? result.brand : 'Brand';
    final title = result.productName.isNotEmpty ? result.productName : 'Item';
    final priceText = result.price;
    final imageUrl = result.imageUrl;
    final imageProvider = imageUrl != null && imageUrl.isNotEmpty
        ? CachedNetworkImageProvider(imageUrl)
        : null;

    return _ShareCardItem(
      brand: brand,
      title: title,
      priceText: priceText,
      imageProvider: imageProvider,
    );
  }
}
