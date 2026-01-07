import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import '../../../../shared/utils/native_share_helper.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/theme/snaplook_ai_icon.dart';
import '../../../../../core/theme/snaplook_icons.dart';
import '../../../../shared/widgets/snaplook_back_button.dart';
import '../../../home/domain/providers/inspiration_provider.dart';
import '../../../home/domain/services/inspiration_service.dart';
import '../../../detection/presentation/pages/detection_page.dart';
import '../../../detection/domain/models/detection_result.dart';
import '../../../favorites/domain/providers/favorites_provider.dart';

String _resolveProductUrl(Map<String, dynamic> product) {
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
  return '';
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

  static _ShareCardItem fromProduct(Map<String, dynamic> product) {
    final brand = (product['brand'] ?? 'Brand').toString();
    final title = (product['title'] ?? product['product_name'] ?? 'Item').toString();
    final price = product['price'];
    final priceText = price != null ? '\$$price' : null;
    final imageUrl = product['image_url'] as String?;
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

class ProductDetailPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> product;
  final String heroTag;

  const ProductDetailPage({
    super.key,
    required this.product,
    required this.heroTag,
  });

  @override
  ConsumerState<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends ConsumerState<ProductDetailPage> {
  final _inspirationService = InspirationService();
  final _random = Random();
  late PageController _pageController;
  late List<Map<String, dynamic>> _products;
  int _currentIndex = 0;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _products = [widget.product];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMoreProducts();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _loadMoreProducts() async {
    if (_isLoadingMore) return;

    _isLoadingMore = true;
    final inspirationState = ref.read(inspirationProvider);

    if (!inspirationState.isLoading && inspirationState.images.isNotEmpty) {
      final filteredProducts = inspirationState.images
          .where((p) {
            final imageUrl = p['image_url'] as String?;
            return imageUrl != null && _inspirationService.isHighQualityImage(imageUrl);
          })
          .toList();

      final shuffledProducts = List<Map<String, dynamic>>.from(filteredProducts)
        ..shuffle(_random);

      setState(() {
        if (_products.length == 1) {
          _products = [widget.product, ...shuffledProducts.take(100).toList()];
        } else {
          _products.addAll(shuffledProducts.take(50).toList());
        }
      });
    }

    _isLoadingMore = false;

    if (inspirationState.images.isEmpty || inspirationState.hasMore) {
      ref.read(inspirationProvider.notifier).loadMoreImages();
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });

    if (index >= _products.length - 10 && !_isLoadingMore) {
      _loadMoreProducts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              if (index >= _products.length) {
                return Container(
                  color: Theme.of(context).colorScheme.surface,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFf2003c),
                      strokeWidth: 2,
                    ),
                  ),
                );
              }

              return _ProductDetailCard(
                product: _products[index],
                heroTag: index == 0 ? widget.heroTag : 'product_${_products[index]['id']}_$index',
              );
            },
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            child: SnaplookBackButton(
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductDetailCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> product;
  final String heroTag;

  const _ProductDetailCard({
    required this.product,
    required this.heroTag,
  });

  @override
  ConsumerState<_ProductDetailCard> createState() => _ProductDetailCardState();
}

class _ProductDetailCardState extends ConsumerState<_ProductDetailCard>
    with SingleTickerProviderStateMixin {
  static const Size _shareCardSize = Size(648, 1290);
  static const double _shareCardPixelRatio = 2.0;

  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );
  }

  void _navigateToDetection() {
    final imageUrl = widget.product['image_url'];
    if (imageUrl != null) {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (context) => DetectionPage(
            imageUrl: imageUrl,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'PlusJakartaSans'),
        ),
        duration: const Duration(milliseconds: 2500),
      ),
    );
  }

  Future<void> _openProductLink(String productUrl) async {
    final uri = Uri.parse(productUrl);

    // Prefer in-app browser (keeps user inside Snaplook)
    if (await canLaunchUrl(uri)) {
      final ok = await launchUrl(
        uri,
        mode: LaunchMode.inAppBrowserView,
      );
      if (ok) return;
    }

    // Fallback to in-app webview if custom tab/safari view fails
    if (await canLaunchUrl(uri)) {
      final ok = await launchUrl(
        uri,
        mode: LaunchMode.inAppWebView,
      );
      if (ok) return;
    }

    // Last resort: external
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnackBar('Cannot open product link');
    }
  }

  Future<void> _onLikeToggle() async {
    HapticFeedback.mediumImpact();

    _controller.forward().then((_) {
      _controller.reverse();
    });

    final productId = widget.product['id']?.toString() ?? '';
    final wasAlreadyFavorited = ref.read(isFavoriteProvider(productId));

    final resolvedUrl = _resolveProductUrl(widget.product);

    final productResult = DetectionResult(
      id: productId,
      productName: widget.product['title'] ?? 'Unknown',
      brand: widget.product['brand'] ?? 'Unknown',
      price: double.tryParse(widget.product['price']?.toString() ?? '0') ?? 0.0,
      imageUrl: widget.product['image_url'] ?? '',
      purchaseUrl: resolvedUrl.isEmpty ? null : resolvedUrl,
      category: widget.product['category'] ?? 'Unknown',
      confidence: 1.0,
    );

    try {
      await ref.read(favoritesProvider.notifier).toggleFavorite(productResult);

      // Show snackbar based on action
      _showSnackBar(
        wasAlreadyFavorited ? 'Removed from favorites' : 'Added to favorites',
      );
    } catch (e) {
      _showSnackBar(
        'Failed to update favorites: ${e.toString()}',
      );
    }
  }

  void _showOptionsMenu() {
    final product = widget.product;
    final productUrl = _resolveProductUrl(product);
    final productTitle = (product['title'] ?? product['product_name'] ?? 'Product').toString();
    final productBrand = (product['brand'] ?? '').toString();

    Rect _shareOriginForContext(BuildContext context) {
      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize) {
        return renderBox.localToGlobal(Offset.zero) & renderBox.size;
      }
      final mediaSize = MediaQuery.of(context).size;
      return Rect.fromCenter(
        center: Offset(mediaSize.width / 2, mediaSize.height / 2),
        width: 1,
        height: 1,
      );
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final shareOrigin = _shareOriginForContext(context);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ProductDetailSheetItem(
                  icon: Icons.share_outlined,
                  label: 'Share product',
                  onTap: () async {
                    Navigator.pop(context);

                    try {
                      const shareSubject = 'Snaplook Fashion Share';
                      final message = productUrl.isNotEmpty
                          ? 'Check out this $productBrand $productTitle on Snaplook! $productUrl'
                          : 'Check out this $productBrand $productTitle on Snaplook!';

                      final shareItem = _ShareCardItem.fromProduct(product);
                      final imageUrl = product['image_url'] as String?;
                      ImageProvider<Object>? heroImage;

                      if (imageUrl != null && imageUrl.isNotEmpty) {
                        heroImage = CachedNetworkImageProvider(imageUrl);
                      }

                      final shareCard = await _buildShareCardFile(
                        context,
                        heroImage: heroImage,
                        shareItems: [shareItem],
                      );

                      final thumbnailFile = await _downloadProductImage();

                      final primaryFile = shareCard ?? thumbnailFile;

                      if (primaryFile != null) {
                        final handled = await NativeShareHelper.shareImageFirst(
                          file: primaryFile,
                          text: message,
                          subject: shareSubject,
                          origin: shareOrigin,
                          thumbnailPath: thumbnailFile?.path,
                        );
                        if (!handled) {
                          await Share.shareXFiles(
                            [primaryFile],
                            text: message,
                            subject: shareSubject,
                            sharePositionOrigin: shareOrigin,
                          );
                        }
                      } else {
                        await Share.share(
                          message,
                          subject: shareSubject,
                          sharePositionOrigin: shareOrigin,
                        );
                      }
                    } catch (e) {
                      debugPrint('Error sharing product: $e');
                    }
                  },
                ),
                const SizedBox(height: 8),
                _ProductDetailSheetItem(
                  icon: Icons.link,
                  label: 'Copy link',
                  onTap: () {
                    Navigator.pop(context);
                    if (productUrl.isEmpty) {
                      _showSnackBar('No product link available');
                      return;
                    }
                    Clipboard.setData(ClipboardData(text: productUrl));
                    _showSnackBar('Link copied to clipboard');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<XFile?> _downloadProductImage() async {
    try {
      final imageUrl = widget.product['image_url'] as String?;
      if (imageUrl == null || imageUrl.isEmpty) return null;

      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) return null;

      final bytes = response.bodyBytes;
      final filePath = '${Directory.systemTemp.path}/product_share_image.jpg';
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);

      return XFile(
        filePath,
        mimeType: 'image/jpeg',
        name: 'product_share_image.jpg',
      );
    } catch (e) {
      debugPrint('Error downloading product image: $e');
      return null;
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
          '${Directory.systemTemp.path}/snaplook_share_fashion.png';
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);
      return XFile(
        filePath,
        mimeType: 'image/png',
        name: 'snaplook_share_fashion.png',
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
    if (!context.mounted) return null;
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
                    child: _ProductShareCard(
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

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final productId = widget.product['id']?.toString() ?? '';
    final isFavorite = ref.watch(isFavoriteProvider(productId));

    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _navigateToDetection,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  child: widget.product['image_url'] != null
                      ? Hero(
                          tag: widget.heroTag,
                          child: _AdaptiveMainProductImage(
                            imageUrl: widget.product['image_url'],
                            category: (widget.product['category'] as String?)?.toLowerCase() ?? '',
                          ),
                        )
                      : Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.checkroom,
                            size: 50,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                ),
              ),
            ),
            Container(
              color: Theme.of(context).colorScheme.surface,
              padding: EdgeInsets.all(spacing.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          try {
                            final productUrl = _resolveProductUrl(widget.product);

                            if (productUrl.isEmpty) {
                              _showSnackBar('No product link available');
                              return;
                            }

                            await _openProductLink(productUrl);
                          } catch (e) {
                            _showSnackBar('Error opening link: $e');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFf2003c),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 32),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'View product',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 12),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: _navigateToDetection,
                            child: SizedBox(
                              width: 44,
                              height: 48,
                              child: Center(
                                child: Transform.translate(
                                  offset: const Offset(0, -0.5),
                                  child: Icon(
                                    SnaplookAiIcon.aiSearchIcon,
                                    size: 21,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: _onLikeToggle,
                            child: AnimatedBuilder(
                              animation: _scaleAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _scaleAnimation.value,
                                  child: SizedBox(
                                    width: 44,
                                    height: 48,
                                    child: Center(
                                      child: Transform.translate(
                                        offset: isFavorite ? Offset.zero : const Offset(-1, 0),
                                        child: Icon(
                                          isFavorite ? SnaplookIcons.heartFilled : SnaplookIcons.heartOutline,
                                          size: isFavorite ? 24 * 0.85 : 17,
                                          color: isFavorite ? const Color(0xFFf2003c) : Theme.of(context).colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.more_horiz),
                            iconSize: 22,
                            onPressed: _showOptionsMenu,
                            tooltip: 'More options',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: spacing.l),
                  if (widget.product['brand'] != null) ...[
                    Text(
                      widget.product['brand'],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (widget.product['title'] != null) ...[
                    Text(
                      widget.product['title'],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                        height: 1.3,
                      ),
                    ),
                  ],
                  SizedBox(height: spacing.m),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProductDetailSheetItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ProductDetailSheetItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.onSurface, size: 24),
            const SizedBox(width: 24),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdaptiveMainProductImage extends StatefulWidget {
  final String imageUrl;
  final String category;

  const _AdaptiveMainProductImage({
    required this.imageUrl,
    required this.category,
  });

  @override
  State<_AdaptiveMainProductImage> createState() => _AdaptiveMainProductImageState();
}

class _AdaptiveMainProductImageState extends State<_AdaptiveMainProductImage> {
  BoxFit? _boxFit;

  @override
  Widget build(BuildContext context) {
    final isShoeCategory = widget.category.contains('shoe') ||
                          widget.category.contains('sneaker') ||
                          widget.category.contains('boot');

    // Default fit based on category
    final defaultFit = isShoeCategory ? BoxFit.contain : BoxFit.cover;
    final currentFit = _boxFit ?? defaultFit;

    return CachedNetworkImage(
      imageUrl: widget.imageUrl,
      fit: currentFit,
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholderFadeInDuration: Duration.zero,
      imageBuilder: (context, imageProvider) {
        // Image loaded, check if we need to adjust fit for shoes
        if (isShoeCategory && _boxFit == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _determineOptimalFit();
          });
        }
        return Image(
          image: imageProvider,
          fit: currentFit,
          width: double.infinity,
          height: double.infinity,
          alignment: Alignment.center,
        );
      },
      placeholder: (context, url) => Center(
        child: CircularProgressIndicator(
          color: Color(0xFFf2003c),
          strokeWidth: 2,
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.image_not_supported,
          size: 50,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  void _determineOptimalFit() {
    if (!mounted) return;

    final image = NetworkImage(widget.imageUrl);

    image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        if (!mounted) return;

        final imageAspectRatio = info.image.width / info.image.height;
        const containerAspectRatio = 0.5; // Detail page aspect ratio (50% height)

        // If the image aspect ratio is close to container ratio, use cover
        final aspectRatioDifference = (imageAspectRatio - containerAspectRatio).abs();

        // If difference is small (< 0.3), the image should fit well with cover
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

class _ProductShareCard extends StatelessWidget {
  final ImageProvider<Object>? heroImage;
  final List<_ShareCardItem> shareItems;

  const _ProductShareCard({
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

        final heroPadding = s(240);
        final heroHeight = s(600);
        final heroRadius = s(72);

        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(s(96)),
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
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: s(60)),

              Text(
                'I snapped this',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: s(48),
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2B2B2B),
                  letterSpacing: 0.3,
                ),
              ),

              SizedBox(height: s(32)),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: heroPadding),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(heroRadius),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.20),
                        blurRadius: s(40),
                        offset: Offset(0, s(16)),
                      ),
                    ],
                  ),
                  child: ClipRRect(
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
                              fit: BoxFit.fitWidth,
                            )
                          : const Icon(
                              Icons.image_rounded,
                              color: Color(0xFFBDBDBD),
                              size: 64,
                            ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: s(32)),

              Image.asset(
                'assets/images/arrow-share-card.png',
                height: s(120),
                fit: BoxFit.contain,
              ),

              SizedBox(height: s(24)),

              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: s(38),
                  vertical: s(19),
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(s(29)),
                  border: Border.all(
                    color: const Color(0xFFEEEEEE),
                    width: 1.2,
                  ),
                ),
                child: Text(
                  'Top Visual Match',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: s(48),
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2B2B2B),
                    letterSpacing: 0.3,
                  ),
                ),
              ),

              SizedBox(height: s(40)),

              if (shareItems.isNotEmpty)
                Center(
                  child: SizedBox(
                    height: s(480),
                    width: width,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        for (int i = shareItems.length - 1; i >= 0; i--)
                          _buildProductCard(
                            shareItems[i],
                            index: i,
                            total: shareItems.length,
                            scale: s,
                          ),
                      ],
                    ),
                  ),
                ),

              SizedBox(height: s(48)),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/icon-rounded.png',
                    width: s(80),
                    height: s(80),
                  ),
                  SizedBox(width: s(16)),
                  Text(
                    'snaplook',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: s(52),
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2B2B2B),
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),

              SizedBox(height: s(60)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductCard(
    _ShareCardItem item, {
    required int index,
    required int total,
    required double Function(double) scale,
  }) {
    final s = scale;
    final rotation = total > 1
        ? (index == 0 ? -0.02 : (index == 2 ? 0.02 : 0.0))
        : 0.0;
    final offsetY = total > 1 ? (index * s(12)) : 0.0;

    return Transform.translate(
      offset: Offset(0, offsetY),
      child: Transform.rotate(
        angle: rotation,
        child: Container(
          width: s(540),
          height: s(360),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(s(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: s(24),
                offset: Offset(0, s(8)),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: s(220),
                height: s(360),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(s(32)),
                    bottomLeft: Radius.circular(s(32)),
                  ),
                ),
                child: item.imageProvider != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(s(32)),
                          bottomLeft: Radius.circular(s(32)),
                        ),
                        child: Image(
                          image: item.imageProvider!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Icon(
                        Icons.image_rounded,
                        size: s(80),
                        color: const Color(0xFFCCCCCC),
                      ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(s(24)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.brand,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: s(30),
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF666666),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: s(8)),
                      Text(
                        item.title,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: s(36),
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF2B2B2B),
                          height: 1.2,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.priceText != null) ...[
                        SizedBox(height: s(12)),
                        Text(
                          item.priceText!,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: s(32),
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFf2003c),
                          ),
                        ),
                      ],
                    ],
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

