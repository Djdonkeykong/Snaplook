import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/providers/image_provider.dart';
import '../../domain/providers/inspiration_provider.dart';
import '../../domain/providers/pending_share_provider.dart';
import '../../../profile/domain/providers/feed_preference_provider.dart';
import '../../../detection/presentation/pages/detection_page.dart';
import '../../../product/presentation/pages/product_detail_page.dart';
import '../../../product/presentation/pages/detected_products_page.dart';
import '../../../paywall/models/subscription_plan.dart';
import '../../../paywall/providers/credit_provider.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/theme/snaplook_ai_icon.dart';
import '../../../detection/domain/models/detection_result.dart';
import '../../../favorites/presentation/widgets/favorite_button.dart';
import '../../../../../shared/navigation/main_navigation.dart'
    show scrollToTopTriggerProvider, isAtHomeRootProvider;
import '../../../../shared/widgets/bottom_sheet_handle.dart';
import '../../../../shared/widgets/snaplook_circular_icon_button.dart';
import '../services/pip_tutorial_service.dart';

String? _extractProductUrl(Map<String, dynamic> product) {
  final candidates = [
    product['purchase_url'],
    product['purchaseUrl'],
    product['url'],
    product['link'],
    product['product_url'],
  ];

  for (final candidate in candidates) {
    if (candidate == null) continue;
    final trimmed = candidate.toString().trim();
    if (trimmed.isNotEmpty && trimmed.startsWith('http')) {
      return trimmed;
    }
  }
  return null;
}

enum _TutorialSource {
  instagram,
  pinterest,
  tiktok,
  safari,
  photos,
  imdb,
  x,
  other,
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> with WidgetsBindingObserver {
  final ImagePicker _picker = ImagePicker();
  final ScrollController _scrollController = ScrollController();
  final Set<String> _preloadedImages = <String>{};
  ProviderSubscription<XFile?>? _pendingShareListener;
  bool _isProcessingPendingNavigation = false;
  final PipTutorialService _pipTutorialService = PipTutorialService();
  _TutorialSource? _loadingTutorialSource;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);


    // Load initial inspiration images
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(inspirationProvider.notifier).loadImages();

      // Check for pending shared image after a delay to ensure UI is ready
      Future.delayed(const Duration(milliseconds: 1000), () {
        _checkPendingSharedImage();
      });
    });

    _pendingShareListener ??= ref.listenManual<XFile?>(
      pendingSharedImageProvider,
      (previous, next) {
        if (next != null && mounted) {
          _handlePendingSharedImage(next);
        }
      },
    );

    // Setup infinite scrolling
    _scrollController.addListener(_onScroll);
  }

  void _checkPendingSharedImage() {
    final pendingImage = ref.read(pendingSharedImageProvider);

    if (pendingImage != null && mounted) {
      _handlePendingSharedImage(pendingImage);
    }
  }

  void _handlePendingSharedImage(XFile image) {
    if (_isProcessingPendingNavigation || !mounted) {
      return;
    }

    if (ref.read(shareNavigationInProgressProvider)) {
      return;
    }

    _isProcessingPendingNavigation = true;

    // Get source URL for cache matching
    final sourceUrl = ref.read(pendingShareSourceUrlProvider);

    ref.read(pendingSharedImageProvider.notifier).state = null;
    ref.read(pendingShareSourceUrlProvider.notifier).state = null;

    () async {
      try {
        // Ensure the shared image is available to DetectionPage immediately.
        ref.read(selectedImagesProvider.notifier).setImage(image);

        // Pre-cache the image to avoid any white/black flash during navigation.
        final fileImage = FileImage(File(image.path));
        await precacheImage(fileImage, context).catchError((_) {});

        if (!mounted) return;

        await Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (context) {
              return DetectionPage(
                searchType: 'share',
                sourceUrl: sourceUrl,
              );
            },
          ),
        );

      } catch (e) {
        debugPrint('Error handling pending shared image: $e');
      } finally {
        _isProcessingPendingNavigation = false;
      }
    }();
  }

  @override
  void dispose() {
    _pendingShareListener?.close();
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _pipTutorialService.stopTutorial();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _pipTutorialService.stopTutorial();
    }
  }

  void _onScroll() {
    final currentPixels = _scrollController.position.pixels;
    final maxExtent = _scrollController.position.maxScrollExtent;

    if (currentPixels >= maxExtent * 0.7) {
      ref.read(inspirationProvider.notifier).loadMoreImages();
    }

    // Preload images when user scrolls past 50%
    if (currentPixels >= maxExtent * 0.5) {
      _preloadNearbyImages();
    }
  }

  void _preloadNearbyImages() {
    final state = ref.read(inspirationProvider);
    if (state.images.isEmpty) return;

    // Preload next 10 images that aren't loaded yet
    final imagesToPreload = state.images
        .where((image) => !_preloadedImages.contains(image['image_url']))
        .take(10)
        .toList();

    for (final image in imagesToPreload) {
      final imageUrl = image['image_url'] as String?;
      if (imageUrl != null && imageUrl.isNotEmpty) {
        _preloadedImages.add(imageUrl);
        // Preload in background without blocking UI
        precacheImage(
          NetworkImage(imageUrl),
          context,
          onError: (exception, stackTrace) {
            // Remove from preloaded set if it fails
            _preloadedImages.remove(imageUrl);
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inspirationState = ref.watch(inspirationProvider);

    // Listen to scroll to top trigger
    ref.listen(scrollToTopTriggerProvider, (previous, next) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    // Listen to feed preference changes and refresh feed
    ref.listen(feedPreferenceChangeProvider, (previous, next) {
      if (previous != next) {
        ref.read(inspirationProvider.notifier).refreshImages();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Main content - full screen
          EasyRefresh(
            onRefresh: () async {
              HapticFeedback.selectionClick();
              await ref.read(inspirationProvider.notifier).refreshImages();
            },
            header: ClassicHeader(
              dragText: '',
              armedText: '',
              readyText: '',
              processingText: '',
              processedText: '',
              noMoreText: '',
              failedText: '',
              messageText: '',
              safeArea: false,
              showMessage: false,
              showText: false,
              processedDuration: Duration.zero,
              succeededIcon: const SizedBox.shrink(),
              iconTheme: const IconThemeData(
                color: Color(0xFFf2003c),
                size: 24,
              ),
              backgroundColor: Theme.of(context).colorScheme.surface,
            ),
            child: _buildInspirationGrid(inspirationState),
          ),
          // Floating logo overlay
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 0,
            right: 0,
            child: Center(
              child: Image.asset(
                'assets/images/logo.png',
                height: 32,
                fit: BoxFit.contain,
              ),
            ),
          ),
          // Floating Action Bar
          Positioned(
            left: MediaQuery.of(context).size.width * 0.09,
            right: MediaQuery.of(context).size.width * 0.09,
            bottom: 24,
            child: _FloatingActionBar(
              onSnapTap: () => _pickImage(ImageSource.camera),
              onUploadTap: () => _pickImage(ImageSource.gallery),
              onTutorialsTap: _showTutorialOptionsSheet,
              onInfoTap: () {
                _showInfoBottomSheet(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInspirationGrid(InspirationState state) {
    if (state.images.isEmpty && state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.secondary,
          strokeWidth: 2,
        ),
      );
    }

    if (state.images.isEmpty && state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.tertiary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load inspiration',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.onSurface,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              state.error!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.tertiary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  ref.read(inspirationProvider.notifier).loadImages(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: AppColors.primary,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.images.isEmpty) {
      return const Center(
        child: Text('No inspiration images available'),
      );
    }

    return _buildBurberryStyleGrid(state);
  }

  Widget _buildBurberryStyleGrid(InspirationState state) {
    final images = state.images.cast<Map<String, dynamic>>();

    if (images.length < 3) {
      return _buildFallbackGrid(images);
    }

    final rows = <_MagazineGridRow>[];
    var patternStart = 0;

    while (patternStart + 2 < images.length) {
      rows.add(
        _MagazineGridRow.large(
          image: images[patternStart],
          startIndex: patternStart,
        ),
      );
      rows.add(
        _MagazineGridRow.pair(
          images: [
            images[patternStart + 1],
            images[patternStart + 2],
          ],
          startIndex: patternStart + 1,
        ),
      );
      patternStart += 3;
    }

    final remaining = images.length - patternStart;
    if (remaining == 1) {
      rows.add(
        _MagazineGridRow.large(
          image: images[patternStart],
          startIndex: patternStart,
        ),
      );
    } else if (remaining == 2) {
      rows.add(
        _MagazineGridRow.pair(
          images: [
            images[patternStart],
            images[patternStart + 1],
          ],
          startIndex: patternStart,
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.zero,
      itemCount: rows.length,
      itemBuilder: (context, rowIndex) {
        final descriptor = rows[rowIndex];
        if (descriptor.isLarge) {
          return _buildLargeImageRow(descriptor.image!, descriptor.startIndex);
        }

        return _buildTwoImageRow(descriptor.images!, descriptor.startIndex);
      },
    );
  }

  Widget _buildStrictPatternRow(
      int rowIndex,
      List<Map<String, dynamic>> premiumImages,
      List<Map<String, dynamic>> regularImages) {
    final isLargeRow = rowIndex.isEven;

    if (isLargeRow) {
      // Large image row - use premium images in order
      final largeImageIndex = rowIndex ~/ 2;
      final image = premiumImages[largeImageIndex % premiumImages.length];
      return _buildLargeImageRow(image, largeImageIndex);
    } else {
      // Two image row - use regular images in order, avoiding duplicates within same pattern
      final patternIndex = rowIndex ~/ 2;
      final baseIndex = patternIndex * 2;

      final List<Map<String, dynamic>> twoImages = [
        regularImages[baseIndex % regularImages.length],
        regularImages[(baseIndex + 1) % regularImages.length],
      ];

      return _buildTwoImageRow(twoImages, baseIndex);
    }
  }

  Widget _buildPremiumPatternRow(
      int rowIndex,
      List<Map<String, dynamic>> premiumImages,
      List<Map<String, dynamic>> regularImages) {
    final isLargeRow = rowIndex.isEven;

    if (isLargeRow) {
      // Large image row - use premium images
      final largeImageIndex = rowIndex ~/ 2;
      final image = premiumImages[largeImageIndex % premiumImages.length];
      return _buildLargeImageRow(image, largeImageIndex);
    } else {
      // Two image row - use regular images
      final patternIndex = rowIndex ~/ 2;
      final baseIndex = patternIndex * 2;

      final List<Map<String, dynamic>> twoImages = [
        regularImages[baseIndex % regularImages.length],
        regularImages[(baseIndex + 1) % regularImages.length],
      ];

      return _buildTwoImageRow(twoImages, baseIndex);
    }
  }

  bool _isImageSuitableForLarge(Map<String, dynamic> image) {
    final brand = (image['brand'] as String?)?.toLowerCase() ?? '';
    final category = (image['category'] as String?)?.toLowerCase() ?? '';

    // Only H&M, Zara, PrincessPolly for large images
    final allowedBrands = ['h&m', 'zara', 'princesspolly'];
    final hasPremiumBrand =
        allowedBrands.any((allowedBrand) => brand.contains(allowedBrand));

    if (!hasPremiumBrand) {
      return false;
    }

    // Exclude shoes
    if (category.contains('shoe') || category.contains('shoes')) {
      return false;
    }

    return true;
  }

  Widget _buildFallbackGrid(List<Map<String, dynamic>> images) {
    final itemCount = (images.length / 2).ceil();

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.zero,
      itemCount: itemCount,
      itemBuilder: (context, rowIndex) {
        final startIndex = rowIndex * 2;
        final endIndex = (startIndex + 2).clamp(0, images.length);
        final rowImages = images.sublist(startIndex, endIndex);

        if (rowImages.length == 1) {
          return _buildLargeImageRow(rowImages[0], startIndex);
        } else {
          return _buildTwoImageRow(rowImages, startIndex);
        }
      },
    );
  }

  Widget _buildLargeImageRow(Map<String, dynamic> image, int imageIndex) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 0.75, // Portrait aspect ratio for hero images
          child: _MagazineStyleImageCard(
            image: image,
            index: imageIndex,
            isLarge: true,
            onTap: () => _onImageTap(image, imageIndex),
          ),
        ),
        Container(
          height: 3,
          color: Colors.white.withOpacity(0.3),
        ),
      ],
    );
  }

  Widget _buildTwoImageRow(List<Map<String, dynamic>> images, int startIndex) {
    if (images.isEmpty) {
      return const SizedBox.shrink();
    }

    if (images.length < 2) {
      return _buildLargeImageRow(images.first, startIndex);
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: 0.85, // Slightly more square for side-by-side
                child: _MagazineStyleImageCard(
                  image: images[0],
                  index: startIndex,
                  isLarge: false,
                  onTap: () => _onImageTap(images[0], startIndex),
                ),
              ),
            ),
            Container(
              width: 3,
              color: Colors.white.withOpacity(0.3),
            ),
            Expanded(
              child: AspectRatio(
                aspectRatio: 0.85,
                child: _MagazineStyleImageCard(
                  image: images[1],
                  index: startIndex + 1,
                  isLarge: false,
                  onTap: () => _onImageTap(images[1], startIndex + 1),
                ),
              ),
            ),
          ],
        ),
        Container(
          height: 3,
          color: Colors.white.withOpacity(0.3),
        ),
      ],
    );
  }

  void _onImageTap(Map<String, dynamic> image, int index) {
    // Hide floating bar when navigating away
    ref.read(isAtHomeRootProvider.notifier).state = false;

    final product = Map<String, dynamic>.from(image);
    final resolvedUrl = _extractProductUrl(product);
    if (resolvedUrl != null) {
      product.putIfAbsent('url', () => resolvedUrl);
      product.putIfAbsent('purchase_url', () => resolvedUrl);
    }

    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => ProductDetailPage(
          product: product,
          heroTag: 'product_${image['id']}_$index',
        ),
      ),
    )
        .then((_) {
      // Show floating bar again when coming back
      ref.read(isAtHomeRootProvider.notifier).state = true;
    });
  }

  void _showImageSourceDialog(BuildContext context) {
    final spacing = context.spacing;
    final radius = context.radius;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(radius.large),
        ),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(spacing.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 6,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            SizedBox(height: spacing.l),
            Text(
              'Choose Image Source',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            SizedBox(height: spacing.l),
            Row(
              children: [
                Expanded(
                  child: _SourceOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onTap: () => _pickImage(ImageSource.camera),
                  ),
                ),
                SizedBox(width: spacing.m),
                Expanded(
                  child: _SourceOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: () => _pickImage(ImageSource.gallery),
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing.l),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final isCamera = source == ImageSource.camera;
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: isCamera ? 1600 : 1024,
        maxHeight: isCamera ? 1600 : 1024,
        imageQuality: isCamera ? 95 : 85,
      );

      if (image != null) {
        ref.read(selectedImagesProvider.notifier).setImage(image);

        if (mounted) {
          final fileImage = FileImage(File(image.path));
          await precacheImage(fileImage, context).catchError((_) {});
        }

        if (mounted) {
          await Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              builder: (context) {
                return DetectionPage(
                  searchType: isCamera ? 'camera' : 'photos',
                );
              },
            ),
          );
        } else {
          debugPrint("[IMAGE PICKER ERROR] Widget not mounted - cannot navigate");
        }
      }
    } catch (e) {
      debugPrint("[IMAGE PICKER ERROR] Error picking image: $e");
      debugPrint("[IMAGE PICKER ERROR] Error type: ${e.runtimeType}");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error picking image: $e',
              style: context.snackTextStyle(),
            ),
          ),
        );
      }
    }
  }

  void _shareApp() {
    final renderBox = context.findRenderObject() as RenderBox?;
    final mediaSize = MediaQuery.of(context).size;

    Rect shareOrigin = Offset.zero & mediaSize;
    if (renderBox != null && renderBox.hasSize) {
      final size = renderBox.size;
      if (!size.isEmpty) {
        final position = renderBox.localToGlobal(Offset.zero);
        shareOrigin = position & size;
      }
    }

    Share.share(
      'Check out Snaplook - The AI-powered fashion discovery app! Find similar clothing items by taking photos. Download now!',
      subject: 'Discover Fashion with Snaplook',
      sharePositionOrigin: shareOrigin,
    );
  }

  void _showTutorialOptionsSheet() {
    final options = [
      _TutorialOptionData(
        label: 'Instagram',
        source: _TutorialSource.instagram,
        iconBuilder: () => Image.asset(
          'assets/icons/insta.png',
          width: 24,
          height: 24,
          gaplessPlayback: true,
        ),
      ),
      _TutorialOptionData(
        label: 'Pinterest',
        source: _TutorialSource.pinterest,
        iconBuilder: () => SvgPicture.asset(
          'assets/icons/pinterest.svg',
          width: 24,
          height: 24,
        ),
      ),
      _TutorialOptionData(
        label: 'TikTok',
        source: _TutorialSource.tiktok,
        iconBuilder: () => SvgPicture.asset(
          'assets/icons/4362958_tiktok_logo_social media_icon.svg',
          width: 24,
          height: 24,
        ),
      ),
      _TutorialOptionData(
        label: 'Photos',
        source: _TutorialSource.photos,
        iconBuilder: () => Image.asset(
          'assets/icons/photos.png',
          width: 24,
          height: 24,
          gaplessPlayback: true,
        ),
      ),
      _TutorialOptionData(
        label: 'IMDb',
        source: _TutorialSource.imdb,
        iconBuilder: () => Image.asset(
          'assets/icons/imdb.png',
          width: 24,
          height: 24,
          gaplessPlayback: true,
        ),
      ),
      _TutorialOptionData(
        label: 'Web Browsers',
        source: _TutorialSource.safari,
        iconBuilder: () => const _BrowserIconStack(),
      ),
      _TutorialOptionData(
        label: 'X',
        source: _TutorialSource.x,
        iconBuilder: () => Image.asset(
          'assets/icons/x-logo.png',
          width: 24,
          height: 24,
          gaplessPlayback: true,
        ),
      ),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (sheetContext) {
        final spacing = sheetContext.spacing;
        return StatefulBuilder(
          builder: (context, sheetSetState) {
            return FractionallySizedBox(
              heightFactor: 0.9,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(sheetContext).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Stack(
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: spacing.l,
                          vertical: spacing.l,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            BottomSheetHandle(
                              margin: EdgeInsets.only(bottom: spacing.m),
                            ),
                            const Text(
                              'Share your look',
                              style: TextStyle(
                                fontSize: 34,
                                fontFamily: 'PlusJakartaSans',
                                letterSpacing: -1.0,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                                height: 1.3,
                              ),
                            ),
                            SizedBox(height: spacing.xs),
                            const Text(
                              'Learn to share from your favorite apps',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black54,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'PlusJakartaSans',
                              ),
                            ),
                            SizedBox(height: spacing.l),
                            Expanded(
                              child: ListView.separated(
                                physics: const BouncingScrollPhysics(),
                                padding: EdgeInsets.only(bottom: spacing.l),
                                itemCount: options.length,
                                separatorBuilder: (_, __) =>
                                    SizedBox(height: spacing.l),
                                itemBuilder: (_, index) {
                                  final option = options[index];
                                  return _TutorialAppCard(
                                    label: option.label,
                                    iconWidget: option.iconBuilder(),
                                    isEnabled: option.isEnabled,
                                    statusLabel: option.statusLabel,
                                    isLoading:
                                        _loadingTutorialSource == option.source,
                                    onTap: () => _onTutorialOptionSelected(
                                      option.source,
                                      sheetContext,
                                      sheetSetState,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: spacing.l,
                        right: spacing.l,
                        child: SnaplookCircularIconButton(
                          icon: Icons.close,
                          iconSize: 18,
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          tooltip: 'Close',
                          semanticLabel: 'Close',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _onTutorialOptionSelected(
    _TutorialSource source,
    BuildContext sheetContext,
    StateSetter sheetSetState,
  ) async {
    if (!mounted) return;

    PipTutorialTarget? target;
    switch (source) {
      case _TutorialSource.instagram:
        target = PipTutorialTarget.instagram;
        break;
      case _TutorialSource.pinterest:
        target = PipTutorialTarget.pinterest;
        break;
      case _TutorialSource.photos:
        target = PipTutorialTarget.photos;
        break;
      case _TutorialSource.imdb:
        target = PipTutorialTarget.imdb;
        break;
      case _TutorialSource.safari:
        target = PipTutorialTarget.safari;
        break;
      case _TutorialSource.tiktok:
        target = PipTutorialTarget.tiktok;
        break;
      case _TutorialSource.x:
        target = PipTutorialTarget.x;
        break;
      default:
        return; // Other apps still disabled for now
    }

    if (_loadingTutorialSource != null) {
      return;
    }

    setState(() {
      _loadingTutorialSource = source;
    });
    sheetSetState(() {});

    try {
      HapticFeedback.mediumImpact();

      // Keep spinner visible on the row while we stage things
      await Future.delayed(const Duration(milliseconds: 1500));

      // Close sheet and wait for animation to FULLY complete
      if (sheetContext.mounted) {
        await Navigator.of(sheetContext).maybePop();
        // Standard Material bottom sheet animation is ~300ms
        // Wait for it to completely finish before doing anything else
        await Future.delayed(const Duration(milliseconds: 300));
      }

      if (!mounted) return;
      await _launchPipTutorial(target);
    } finally {
      if (mounted) {
        setState(() {
          _loadingTutorialSource = null;
        });
      }
      sheetSetState(() {});
    }
  }

  Future<void> _launchPipTutorial(PipTutorialTarget target) async {
    const instagramDeepLink =
        'https://www.instagram.com/p/DQSaR_FEsU8/?igsh=MTEyNzJuaXF6cDlmNA==';
    const pinterestDeepLink = 'https://pin.it/223au9vpX';
    const tiktokDeepLink = 'https://vm.tiktok.com/ZNRr4FE31/';
    const imdbDeepLink = 'https://www.imdb.com/';
    const xDeepLink =
        'https://x.com/iamjhud/status/1962314855802651108?s=46'; // specific post
    const safariDeepLink =
        'https://media.glamour.com/photos/5ae09534ed441129f636ed0b/master/w_1600%2Cc_limit/Aimee_song_of_style_caroline_constas_polka_dot_puffer_sleeves_top_amo_distressed_jeans_dior_kitten_heels_pumps_le_specs_adam_selman_sunglasses_straw_bag_earrings.jpg';
    final videoAsset = switch (target) {
      PipTutorialTarget.instagram => 'assets/videos/instagram-tutorial.mp4',
      PipTutorialTarget.pinterest => 'assets/videos/pinterest-tutorial.mp4',
      PipTutorialTarget.tiktok => 'assets/videos/tiktok-tutorial.mp4',
      PipTutorialTarget.photos => 'assets/videos/photos-tutorial.mp4',
      PipTutorialTarget.imdb => 'assets/videos/imdb-tutorial.mp4',
      PipTutorialTarget.x => 'assets/videos/x-tutorial.mp4',
      PipTutorialTarget.safari => 'assets/videos/web-tutorial.mp4',
      _ => 'assets/videos/pip-test.mp4',
    };
    final deepLink = switch (target) {
      PipTutorialTarget.instagram => instagramDeepLink,
      PipTutorialTarget.pinterest => pinterestDeepLink,
      PipTutorialTarget.tiktok => tiktokDeepLink,
      PipTutorialTarget.photos => null,
      PipTutorialTarget.imdb => imdbDeepLink,
      PipTutorialTarget.x => xDeepLink,
      PipTutorialTarget.safari => safariDeepLink,
      _ => null,
    };
    try {
      await _pipTutorialService.startTutorial(
        target: target,
        videoAsset: videoAsset,
        deepLink: deepLink,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Picture-in-Picture tutorial not available right now.',
            style: context.snackTextStyle(
              merge: const TextStyle(fontFamily: 'PlusJakartaSans'),
            ),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _showInfoBottomSheet(BuildContext context) async {
    final spacing = context.spacing;

    // Fetch credit balance before opening the modal to prevent jitter
    await ref.read(creditBalanceProvider.notifier).refresh();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (context) => _InfoBottomSheetContent(spacing: spacing),
    );
  }
}

class _InfoBottomSheetContent extends ConsumerWidget {
  final AppSpacingExtension spacing;

  const _InfoBottomSheetContent({required this.spacing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creditBalance = ref.watch(creditBalanceProvider);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.all(spacing.l),
              child: creditBalance.when(
                      data: (balance) {
                        // Format membership type based on subscription status and trial
                        final membershipType = balance.hasActiveSubscription
                            ? (balance.isTrialSubscription ? 'Premium (Trial)' : 'Premium')
                            : 'Free';
                        final maxCredits =
                            SubscriptionPlan.monthly.creditsPerMonth;
                        final creditsRemaining =
                            balance.availableCredits.clamp(0, maxCredits).toInt();
                        final creditsPercentage = maxCredits > 0
                            ? (creditsRemaining / maxCredits).clamp(0.0, 1.0)
                            : 0.0;

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            BottomSheetHandle(
                              margin: EdgeInsets.only(bottom: spacing.m),
                            ),

                            // Membership label
                            Text(
                              'Membership',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontFamily: 'PlusJakartaSans',
                              ),
                            ),

                            const SizedBox(height: 2),

                            // Membership type
                            Text(
                              membershipType,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                                fontFamily: 'PlusJakartaSans',
                                letterSpacing: -0.3,
                              ),
                            ),

                            SizedBox(height: spacing.l),

                            // Credits display
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '$creditsRemaining',
                                  style: TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white
                                        : const Color(0xFFf2003c),
                                    fontFamily: 'PlusJakartaSans',
                                    letterSpacing: -2,
                                  ),
                                ),
                                Text(
                                  ' / $maxCredits',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontFamily: 'PlusJakartaSans',
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: spacing.xs),

                            // Credits label
                            Text(
                              'Credits Remaining',
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontFamily: 'PlusJakartaSans',
                              ),
                            ),

                            SizedBox(height: spacing.l),

                            // Progress bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: creditsPercentage,
                                minHeight: 6,
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white
                                      : const Color(0xFFf2003c),
                                ),
                              ),
                            ),

                            SizedBox(height: spacing.m),

                            // Info text
                            Text(
                              'Resets monthly on the 1st',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontFamily: 'PlusJakartaSans',
                              ),
                            ),

                            SizedBox(height: spacing.l),

                            // Note about credits & cropping
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(spacing.m),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withOpacity(
                                      Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? 0.4
                                          : 0.6,
                                    ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 20,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                  SizedBox(width: spacing.m),
                                  Expanded(
                                    child: Text(
                                      'Each garment costs 1 credit. If there are multiple items in a photo, cropping to just one helps conserve credits.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.4,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                        fontFamily: 'PlusJakartaSans',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: spacing.l),
                          ],
                        );
                      },
                      loading: () => const SizedBox.shrink(), // Handled by shouldShowLoading
                      error: (error, stackTrace) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          BottomSheetHandle(
                            margin: EdgeInsets.only(bottom: spacing.m),
                          ),
                          Icon(
                            Icons.error_outline,
                            size: 28,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          SizedBox(height: spacing.s),
                          Text(
                            'Unable to load credits',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                              fontFamily: 'PlusJakartaSans',
                            ),
                          ),
                          SizedBox(height: spacing.xs),
                          Text(
                            'Please try again.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontFamily: 'PlusJakartaSans',
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: spacing.m),
                        ],
                      ),
                    ),
            ),
            // Close button at top right
            Positioned(
              top: spacing.l,
              right: spacing.l,
              child: SnaplookCircularIconButton(
                icon: Icons.close,
                iconSize: 18,
                onPressed: () => Navigator.pop(context),
                tooltip: 'Close',
                semanticLabel: 'Close',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MagazineGridRow {
  const _MagazineGridRow._({
    this.image,
    this.images,
    required this.startIndex,
    required this.isLarge,
  });

  const _MagazineGridRow.large({
    required Map<String, dynamic> image,
    required int startIndex,
  }) : this._(
          image: image,
          images: null,
          startIndex: startIndex,
          isLarge: true,
        );

  const _MagazineGridRow.pair({
    required List<Map<String, dynamic>> images,
    required int startIndex,
  }) : this._(
          image: null,
          images: images,
          startIndex: startIndex,
          isLarge: false,
        );

  final Map<String, dynamic>? image;
  final List<Map<String, dynamic>>? images;
  final int startIndex;
  final bool isLarge;
}

class _SourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final radius = context.radius;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius.medium),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: spacing.l),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(
              color: AppColors.secondary.withOpacity(0.3),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(radius.medium),
          ),
          child: Column(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Icon(
                  icon,
                  size: 26,
                  color: AppColors.secondary,
                ),
              ),
              SizedBox(height: spacing.sm),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InspirationImageCard extends StatelessWidget {
  final Map<String, dynamic> image;
  final VoidCallback onTap;

  const _InspirationImageCard({
    required this.image,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = image['image_url'] as String?;
    final category = (image['category'] as String?)?.toLowerCase() ?? '';
    final isShoeCategory = category.contains('shoe') ||
        category.contains('sneaker') ||
        category.contains('boot');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            // No border radius for clean corners as requested
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Main image with adaptive fitting for different product types
              Expanded(
                child: ClipRect(
                  child: imageUrl != null
                      ? _AdaptiveProductImage(
                          imageUrl: imageUrl,
                          isShoeCategory: isShoeCategory,
                        )
                      : Container(
                          color: AppColors.surface,
                          child: Icon(
                            Icons.image_outlined,
                            size: 32,
                            color: AppColors.tertiary.withOpacity(0.5),
                          ),
                        ),
                ),
              ),
              // Clean Pinterest-style: No overlays, just pure image
            ],
          ),
        ),
      ),
    );
  }
}

class _StaggeredInspirationImageCard extends StatefulWidget {
  final Map<String, dynamic> image;
  final int index;
  final VoidCallback onTap;

  const _StaggeredInspirationImageCard({
    required this.image,
    required this.index,
    required this.onTap,
  });

  @override
  State<_StaggeredInspirationImageCard> createState() =>
      _StaggeredInspirationImageCardState();
}

class _StaggeredInspirationImageCardState
    extends State<_StaggeredInspirationImageCard> {
  bool _isLiked = false;

  void _navigateToDetectionPage(String imageUrl) {
    // Navigate to detection page with the image URL as parameter - use root navigator
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (context) => DetectionPage(
          imageUrl: imageUrl,
          searchType: 'home',
          sourceUrl: imageUrl, // Use imageUrl as cache key for inspiration feed
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.image['image_url'] as String?;
    final category = (widget.image['category'] as String?)?.toLowerCase() ?? '';
    final isShoeCategory = category.contains('shoe') ||
        category.contains('sneaker') ||
        category.contains('boot');

    // Create varied heights for staggered effect - alternating between different sizes
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth - 12) / 2; // Account for padding and spacing

    // Generate pseudo-random height based on image ID for consistent staggering
    final imageId = widget.image['id']?.toString() ?? '0';
    final heightVariant = imageId.hashCode % 3; // Only 3 variants now

    late double aspectRatio;
    switch (heightVariant) {
      case 0:
        aspectRatio = 0.7; // Tall
        break;
      case 1:
        aspectRatio = 1.0; // Square
        break;
      case 2:
        aspectRatio = 0.8; // Medium tall
        break;
    }

    final cardHeight = cardWidth / aspectRatio;
    final heroTag = 'product_${widget.image['id']}_${widget.index}';

    return Material(
      color: Colors.transparent,
      child: Container(
        height: cardHeight,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          // No border radius for clean corners as requested
        ),
        child: Stack(
          children: [
            // Main image content - tappable background
            Positioned.fill(
              child: GestureDetector(
                onTap: widget.onTap,
                child: imageUrl != null
                    ? Hero(
                        tag: heroTag,
                        child: _AdaptiveProductImage(
                          imageUrl: imageUrl,
                          isShoeCategory: isShoeCategory,
                        ),
                      )
                    : Container(
                        color: AppColors.surface,
                        child: Icon(
                          Icons.image_outlined,
                          size: 32,
                          color: AppColors.tertiary.withOpacity(0.5),
                        ),
                      ),
              ),
            ),
            // Favorite button overlay - positioned at top right
            Positioned(
              top: 8,
              right: 8,
              child: FavoriteButton(
                product: DetectionResult(
                  id: widget.image['id']?.toString() ?? '',
                  productName: widget.image['title'] ?? 'Unknown',
                  brand: widget.image['brand'] ?? 'Unknown',
                  price: double.tryParse(
                          widget.image['price']?.toString() ?? '0') ??
                      0.0,
                  imageUrl: widget.image['image_url'] ?? '',
                  purchaseUrl: _extractProductUrl(widget.image),
                  category: widget.image['category'] ?? 'Unknown',
                  confidence: 1.0,
                ),
                size: 18,
              ),
            ),
            // Scan button overlay - positioned at bottom left
            Positioned(
              bottom: 8,
              left: 8,
              child: GestureDetector(
                onTap: () {
                  if (imageUrl != null) {
                    _navigateToDetectionPage(imageUrl);
                  }
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.crop_free,
                    size: 18,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MagazineStyleImageCard extends ConsumerWidget {
  final Map<String, dynamic> image;
  final int index;
  final bool isLarge;
  final VoidCallback onTap;

  const _MagazineStyleImageCard({
    required this.image,
    required this.index,
    required this.isLarge,
    required this.onTap,
  });

  static void _navigateToDetectionPage(
    BuildContext context,
    String imageUrl,
  ) {
    // Navigate to detection page with the image URL as parameter - use root navigator
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (context) => DetectionPage(
          imageUrl: imageUrl,
          searchType: 'home',
          sourceUrl: imageUrl, // Use imageUrl as cache key for inspiration feed
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageUrl = image['image_url'] as String?;
    final category = (image['category'] as String?)?.toLowerCase() ?? '';
    final isShoeCategory = category.contains('shoe') ||
        category.contains('sneaker') ||
        category.contains('boot');

    final heroTag = 'product_${image['id']}_$index';

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          // Clean corners like Burberry - no border radius
        ),
        child: Stack(
          children: [
            // Main image - fills entire container - tappable
            Positioned.fill(
              child: GestureDetector(
                onTap: onTap,
                child: imageUrl != null
                    ? Hero(
                        tag: heroTag,
                        child: _AdaptiveProductImage(
                          imageUrl: imageUrl,
                          isShoeCategory: isShoeCategory,
                        ),
                      )
                    : Container(
                        color: AppColors.surface,
                        child: Icon(
                          Icons.image_outlined,
                          size: isLarge ? 48 : 32,
                          color: AppColors.tertiary.withOpacity(0.5),
                        ),
                      ),
              ),
            ),
            // Favorite button - positioned at bottom right
            Positioned(
              bottom: isLarge ? 16 : 12,
              right: isLarge ? 16 : 12,
              child: FavoriteButton(
                product: DetectionResult(
                  id: image['id']?.toString() ?? '',
                  productName: image['title'] ?? 'Unknown',
                  brand: image['brand'] ?? 'Unknown',
                  price:
                      double.tryParse(image['price']?.toString() ?? '0') ?? 0.0,
                  imageUrl: image['image_url'] ?? '',
                  purchaseUrl: _extractProductUrl(image),
                  category: image['category'] ?? 'Unknown',
                  confidence: 1.0,
                ),
                size: 20,
              ),
            ),
            // Scan button - positioned at bottom left
            Positioned(
              bottom: isLarge ? 16 : 12,
              left: isLarge ? 16 : 12,
              child: _ScanIcon(
                size: 36,
                onTap: () {
                  _navigateToDetectionPage(context, imageUrl!);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeartIcon extends StatefulWidget {
  final double size;
  final VoidCallback onTap;

  const _HeartIcon({
    required this.size,
    required this.onTap,
  });

  @override
  State<_HeartIcon> createState() => _HeartIconState();
}

class _HeartIconState extends State<_HeartIcon> {
  bool _isLiked = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isLiked = !_isLiked;
        });
        widget.onTap();
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          _isLiked ? Icons.favorite : Icons.favorite_border,
          size: widget.size * 0.5,
          color: _isLiked ? Colors.red : Colors.black,
        ),
      ),
    );
  }
}

class _ScanIcon extends StatelessWidget {
  final double size;
  final VoidCallback onTap;

  const _ScanIcon({
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Transform.translate(
            offset: const Offset(0, -0.5),
            child: Icon(
              SnaplookAiIcon.aiSearchIcon,
              size: size * 0.4675,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}

class _AdaptiveProductImage extends StatefulWidget {
  final String imageUrl;
  final bool isShoeCategory;

  const _AdaptiveProductImage({
    required this.imageUrl,
    required this.isShoeCategory,
  });

  @override
  State<_AdaptiveProductImage> createState() => _AdaptiveProductImageState();
}

class _AdaptiveProductImageState extends State<_AdaptiveProductImage> {
  @override
  Widget build(BuildContext context) {
    // All images use cover to fill the container
    return SizedBox.expand(
      child: CachedNetworkImage(
        imageUrl: widget.imageUrl,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        fadeInDuration: const Duration(milliseconds: 200),
        fadeOutDuration: Duration.zero,
        placeholderFadeInDuration: Duration.zero,
        httpHeaders: const {
          'User-Agent': 'Mozilla/5.0 (compatible; Flutter app)',
        },
        placeholder: (context, url) => Container(
          color: AppColors.surface,
          child: Center(
            child: CircularProgressIndicator(
              color: AppColors.secondary,
              strokeWidth: 2,
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: AppColors.surface,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.broken_image_outlined,
                size: 32,
                color: AppColors.tertiary.withOpacity(0.5),
              ),
              const SizedBox(height: 8),
              Text(
                'Image unavailable',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.tertiary.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloatingActionBar extends StatelessWidget {
  final VoidCallback onSnapTap;
  final VoidCallback onUploadTap;
  final VoidCallback onTutorialsTap;
  final VoidCallback onInfoTap;

  const _FloatingActionBar({
    required this.onSnapTap,
    required this.onUploadTap,
    required this.onTutorialsTap,
    required this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    final navColors = context.navigation;

    return Container(
      height: 70,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: navColors.actionBarBackground,
        borderRadius: BorderRadius.circular(35),
        border: Border.all(
          color: navColors.actionBarBackground.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, 6),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Expanded(
              child: _FloatingActionButtonSvg(
                svgIcon: 'assets/icons/solar--camera-square-bold-new.svg',
                label: 'Snap',
                onTap: onSnapTap,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _FloatingActionButtonSvg(
                svgIcon: 'assets/icons/upload_filled.svg',
                label: 'Upload',
                onTap: onUploadTap,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _FloatingActionButtonSvg(
                svgIcon: 'assets/icons/tutorials_filled.svg',
                label: 'Tutorials',
                onTap: onTutorialsTap,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _FloatingActionButtonSvg(
                svgIcon: 'assets/icons/info_icon.svg',
                label: 'Info',
                onTap: onInfoTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TutorialOptionData {
  final String label;
  final _TutorialSource source;
  final Widget Function() iconBuilder;
  final bool isEnabled;
  final String? statusLabel;

  const _TutorialOptionData({
    required this.label,
    required this.source,
    required this.iconBuilder,
    this.isEnabled = true,
    this.statusLabel,
  });
}

class _TutorialAppCard extends StatelessWidget {
  final String label;
  final Widget iconWidget;
  final VoidCallback onTap;
  final bool isLoading;
  final bool isEnabled;
  final String? statusLabel;

  const _TutorialAppCard({
    required this.label,
    required this.iconWidget,
    required this.onTap,
    this.isLoading = false,
    this.isEnabled = true,
    this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (isLoading) return;
        if (!isEnabled) {
          HapticFeedback.lightImpact();
          return;
        }
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 56),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
                          ),
                        )
                      : Opacity(
                          opacity: isEnabled ? 1 : 0.5,
                          child: iconWidget,
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  isLoading ? 'Preparing your tutorial...' : label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isEnabled ? Colors.black : Colors.grey.shade500,
                    fontFamily: 'PlusJakartaSans',
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (isLoading)
                const SizedBox.shrink()
              else if (!isEnabled)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel ?? 'Coming soon',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      fontFamily: 'PlusJakartaSans',
                      letterSpacing: -0.2,
                    ),
                  ),
                )
              else
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrowserIconStack extends StatelessWidget {
  final double size;

  const _BrowserIconStack({this.size = 28});

  @override
  Widget build(BuildContext context) {
    final iconSize = size * 0.62; // slightly smaller to avoid touching edges
    final step = iconSize * 0.6; // overlap ~40%
    final totalWidth = iconSize + (step * 2);

    return SizedBox(
      width: totalWidth,
      height: iconSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            child: Image.asset(
              'assets/icons/firefox.png',
              width: iconSize,
              height: iconSize,
              gaplessPlayback: true,
            ),
          ),
          Positioned(
            left: step,
            child: Image.asset(
              'assets/icons/brave.png',
              width: iconSize,
              height: iconSize,
              gaplessPlayback: true,
            ),
          ),
          Positioned(
            left: step * 2,
            child: Image.asset(
              'assets/icons/safari.png',
              width: iconSize,
              height: iconSize,
              gaplessPlayback: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingActionButtonSvg extends StatelessWidget {
  final String svgIcon;
  final String label;
  final VoidCallback onTap;
  final double iconSize;
  final double spacing;
  final Offset? labelOffset;
  final Offset? iconOffset;

  const _FloatingActionButtonSvg({
    required this.svgIcon,
    required this.label,
    required this.onTap,
    this.iconSize = 24,
    this.spacing = 4,
    this.labelOffset,
    this.iconOffset,
  });

  @override
  Widget build(BuildContext context) {
    final navColors = context.navigation;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Transform.translate(
                offset: iconOffset ?? Offset.zero,
                child: SvgPicture.asset(
                  svgIcon,
                  width: iconSize,
                  height: iconSize,
                  colorFilter: ColorFilter.mode(
                    navColors.actionBarIcon,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              SizedBox(height: spacing),
              Transform.translate(
                offset: labelOffset ?? Offset.zero,
                child: Text(
                  label,
                  style: TextStyle(
                    color: navColors.actionBarLabel,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
