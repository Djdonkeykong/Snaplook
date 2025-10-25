import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:easy_refresh/easy_refresh.dart';
import '../../domain/providers/image_provider.dart';
import '../../domain/providers/inspiration_provider.dart';
import '../../domain/providers/pending_share_provider.dart';
import '../../../detection/presentation/pages/detection_page.dart';
import '../../../product/presentation/pages/product_detail_page.dart';
import '../../../product/presentation/pages/detected_products_page.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/theme/snaplook_ai_icon.dart';
import '../../../detection/domain/models/detection_result.dart';
import '../../../favorites/presentation/widgets/favorite_button.dart';
import '../../../../../shared/navigation/main_navigation.dart'
    show scrollToTopTriggerProvider, isAtHomeRootProvider;

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final ImagePicker _picker = ImagePicker();
  final ScrollController _scrollController = ScrollController();
  final Set<String> _preloadedImages = <String>{};
  ProviderSubscription<XFile?>? _pendingShareListener;
  bool _isProcessingPendingNavigation = false;

  @override
  void initState() {
    super.initState();

    print("[HOME PAGE] initState called");

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
          print(
              '[HOME PAGE] pendingSharedImageProvider changed -> navigating to detection');
          _handlePendingSharedImage(next);
        }
      },
    );

    // Setup infinite scrolling
    _scrollController.addListener(_onScroll);
  }

  void _checkPendingSharedImage() {
    print('[HOME PAGE] Checking for pending shared image');
    final pendingImage = ref.read(pendingSharedImageProvider);
    print('[HOME PAGE] Pending image: ${pendingImage?.path ?? 'null'}');

    if (pendingImage != null && mounted) {
      _handlePendingSharedImage(pendingImage);
    } else {
      print('[HOME PAGE] No pending shared image found');
    }
  }

  void _handlePendingSharedImage(XFile image) {
    if (_isProcessingPendingNavigation || !mounted) {
      print(
          '[HOME PAGE] Ignoring pending share navigation because a navigation is already in progress');
      return;
    }

    if (ref.read(shareNavigationInProgressProvider)) {
      print(
          '[HOME PAGE] Share navigation already handled by native flow - skipping duplicate push');
      return;
    }

    print('[HOME PAGE] Navigating to DetectionPage for shared image');
    _isProcessingPendingNavigation = true;

    ref.read(pendingSharedImageProvider.notifier).state = null;

    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (context) {
          print('[HOME PAGE] DetectionPage builder called for shared image');
          return const DetectionPage();
        },
      ),
    ).whenComplete(() {
      print('[HOME PAGE] Returned from DetectionPage (shared image)');
      _isProcessingPendingNavigation = false;
    });
  }

  @override
  void dispose() {
    _pendingShareListener?.close();
    _scrollController.dispose();
    super.dispose();
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
              iconTheme: const IconThemeData(
                color: Color(0xFFf2003c),
                size: 24,
              ),
              backgroundColor: Colors.white,
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
            left: MediaQuery.of(context).size.width * 0.125,
            right: MediaQuery.of(context).size.width * 0.125,
            bottom: 24,
            child: _FloatingActionBar(
              onSnapTap: () => _pickImage(ImageSource.camera),
              onUploadTap: () => _pickImage(ImageSource.gallery),
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

    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => ProductDetailPage(
          product: image,
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
    print(
        "[IMAGE PICKER] Starting image picker - source: ${source == ImageSource.camera ? 'CAMERA' : 'GALLERY'}");
    try {
      print("[IMAGE PICKER] Calling ImagePicker.pickImage...");
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      print(
          "[IMAGE PICKER] pickImage returned - image: ${image?.path ?? 'null'}");

      if (image != null) {
        print("[IMAGE PICKER] Image selected: ${image.path}");
        print("[IMAGE PICKER] Setting image in provider...");
        ref.read(selectedImagesProvider.notifier).setImage(image);
        print("[IMAGE PICKER] Image set in provider");

        if (mounted) {
          print(
              "[IMAGE PICKER] Widget is mounted - navigating to DetectionPage");
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              builder: (context) {
                print("[IMAGE PICKER] DetectionPage builder called");
                return const DetectionPage();
              },
            ),
          ).then((value) {
            print("[IMAGE PICKER] Returned from DetectionPage");
          });
        } else {
          print("[IMAGE PICKER ERROR] Widget not mounted - cannot navigate");
        }
      } else {
        print("[IMAGE PICKER] No image selected (user cancelled)");
      }
    } catch (e) {
      print("[IMAGE PICKER ERROR] Error picking image: $e");
      print("[IMAGE PICKER ERROR] Error type: ${e.runtimeType}");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _shareApp() {
    Share.share(
      'Check out Snaplook - The AI-powered fashion discovery app! Find similar clothing items by taking photos. Download now!',
      subject: 'Discover Fashion with Snaplook',
    );
  }

  void _showInfoBottomSheet(BuildContext context) {
    final spacing = context.spacing;

    // TODO: Replace with actual user data from provider
    final membershipType = 'Trial';
    final creditsRemaining = 42;
    final maxCredits = 50;
    final creditsPercentage = creditsRemaining / maxCredits;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.all(spacing.l),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: spacing.m),

                    // Membership type
                    Text(
                      '$membershipType Membership',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
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
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFf2003c),
                            fontFamily: 'PlusJakartaSans',
                            letterSpacing: -2,
                          ),
                        ),
                        Text(
                          ' / $maxCredits',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade400,
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
                        color: Colors.grey.shade600,
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
                        backgroundColor: Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFf2003c)),
                      ),
                    ),

                    SizedBox(height: spacing.m),

                    // Info text
                    Text(
                      'Resets monthly on the 1st',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),

                    SizedBox(height: spacing.m),
                  ],
                ),
              ),

              // Close button at top left
              Positioned(
                top: 12,
                left: 12,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.black, size: 24),
                ),
              ),
            ],
          ),
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
        builder: (context) => DetectionPage(imageUrl: imageUrl),
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
                child: Hero(
                  tag: 'product_${widget.image['id']}_${widget.index}',
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
                  purchaseUrl: null,
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

  static void _navigateToDetectionPage(BuildContext context, String imageUrl) {
    // Navigate to detection page with the image URL as parameter - use root navigator
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (context) => DetectionPage(imageUrl: imageUrl),
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
                child: Hero(
                  tag: 'product_${image['id']}_$index',
                  child: imageUrl != null
                      ? _AdaptiveProductImage(
                          imageUrl: imageUrl,
                          isShoeCategory: isShoeCategory,
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
                  purchaseUrl: null,
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
  BoxFit? _boxFit;

  @override
  Widget build(BuildContext context) {
    // Default fit based on category
    final defaultFit = widget.isShoeCategory ? BoxFit.contain : BoxFit.cover;
    final currentFit = _boxFit ?? defaultFit;

    return SizedBox.expand(
      child: FutureBuilder<void>(
        future: Future.delayed(const Duration(milliseconds: 100)),
        builder: (context, snapshot) {
          return Image.network(
            widget.imageUrl,
            fit: currentFit,
            alignment: Alignment.center,
            // Removed cache size limits to preserve original image quality
            headers: const {
              'User-Agent': 'Mozilla/5.0 (compatible; Flutter app)',
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                // Image loaded, check if we need to adjust fit for shoes
                if (widget.isShoeCategory && _boxFit == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _determineOptimalFit();
                  });
                }
                return AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: child,
                );
              }

              // Simple loading indicator without timeout complexity

              return Container(
                color: AppColors.surface,
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.secondary,
                    strokeWidth: 2,
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
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
              );
            },
          );
        },
      ),
    );
  }

  void _determineOptimalFit() {
    if (!mounted || !widget.isShoeCategory) return;

    // For shoes, check if the image would look better with cover vs contain
    final image = NetworkImage(widget.imageUrl);

    image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        if (!mounted) return;

        final imageAspectRatio = info.image.width / info.image.height;
        const containerAspectRatio = 0.85; // Our grid aspect ratio

        // If the image aspect ratio is close to container ratio, use cover
        // If it's very different (too wide or too tall), use contain
        final aspectRatioDifference =
            (imageAspectRatio - containerAspectRatio).abs();

        // If difference is small (< 0.3), the image should fit well with cover
        // If difference is large, keep using contain to show full product
        final shouldUseCover = aspectRatioDifference < 0.3;

        if (mounted && shouldUseCover && _boxFit != BoxFit.cover) {
          setState(() {
            _boxFit = BoxFit.cover;
          });
        }
      }),
    );
  }
}

class _FloatingActionBar extends StatelessWidget {
  final VoidCallback onSnapTap;
  final VoidCallback onUploadTap;
  final VoidCallback onInfoTap;

  const _FloatingActionBar({
    required this.onSnapTap,
    required this.onUploadTap,
    required this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: const Color(0xFFf2003c),
        borderRadius: BorderRadius.circular(35),
        border: Border.all(
          color: const Color(0xFFf2003c),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.20),
            blurRadius: 35,
            offset: const Offset(0, 6),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _FloatingActionButtonSvg(
              svgIcon: 'assets/icons/camera_filled.svg',
              label: 'Snap',
              onTap: onSnapTap,
              iconSize: 25,
              spacing: 3,
            ),
            _FloatingActionButtonSvg(
              svgIcon: 'assets/icons/upload_filled.svg',
              label: 'Upload',
              onTap: onUploadTap,
            ),
            _FloatingActionButtonSvg(
              svgIcon: 'assets/icons/tutorials_filled.svg',
              label: 'Tutorials',
              onTap: () {},
            ),
            _FloatingActionButtonSvg(
              svgIcon: 'assets/icons/info_icon.svg',
              label: 'Info',
              onTap: onInfoTap,
            ),
          ],
        ),
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

  const _FloatingActionButtonSvg({
    required this.svgIcon,
    required this.label,
    required this.onTap,
    this.iconSize = 24,
    this.spacing = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                svgIcon,
                width: iconSize,
                height: iconSize,
                colorFilter:
                    const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              ),
              SizedBox(height: spacing),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
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

