import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/theme/snaplook_ai_icon.dart';
import '../../../../../core/theme/snaplook_icons.dart';
import '../../../../shared/widgets/snaplook_back_button.dart';
import '../../../home/domain/providers/inspiration_provider.dart';
import '../../../home/domain/services/inspiration_service.dart';
import '../../../detection/presentation/pages/detection_page.dart';
import '../../../detection/domain/models/detection_result.dart';
import '../../../favorites/domain/providers/favorites_provider.dart';
import '../../../collections/presentation/widgets/add_to_collection_sheet.dart';
import 'visual_search_page.dart';

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
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              if (index >= _products.length) {
                return Container(
                  color: Colors.white,
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
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onLikeToggle() async {
    HapticFeedback.mediumImpact();

    _controller.forward().then((_) {
      _controller.reverse();
    });

    final productId = widget.product['id']?.toString() ?? '';
    final wasAlreadyFavorited = ref.read(isFavoriteProvider(productId));

    final productResult = DetectionResult(
      id: productId,
      productName: widget.product['title'] ?? 'Unknown',
      brand: widget.product['brand'] ?? 'Unknown',
      price: double.tryParse(widget.product['price']?.toString() ?? '0') ?? 0.0,
      imageUrl: widget.product['image_url'] ?? '',
      purchaseUrl: widget.product['url'],
      category: widget.product['category'] ?? 'Unknown',
      confidence: 1.0,
    );

    try {
      await ref.read(favoritesProvider.notifier).toggleFavorite(productResult);

      // Show snackbar based on action
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(wasAlreadyFavorited ? 'Removed from favorites' : 'Added to favorites'),
            backgroundColor: Colors.black,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update favorites: ${e.toString()}'),
            backgroundColor: Colors.black,
          ),
        );
      }
    }
  }

  void _showOptionsMenu() {
    final product = widget.product;
    final productUrl = product['url']?.toString() ?? '';
    final productTitle = product['title']?.toString() ?? 'Product';
    final productBrand = product['brand']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(SnaplookIcons.addCircleOutline,
                      color: Colors.black, size: 24),
                  title: const Text(
                    'Add to Collection',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => AddToCollectionSheet(
                        productId: product['id']?.toString() ?? '',
                        productName: product['title'] ?? 'Unknown',
                        brand: product['brand'] ?? 'Unknown',
                        price: double.tryParse(product['price']?.toString() ?? '0') ?? 0.0,
                        imageUrl: product['image_url'] ?? '',
                        purchaseUrl: product['url'],
                        category: product['category'] ?? 'Unknown',
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.share_outlined,
                      color: Colors.black, size: 24),
                  title: const Text(
                    'Share Product',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Share.share(
                      'Check out this $productBrand $productTitle on Snaplook! $productUrl',
                      subject: '$productBrand $productTitle',
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.link,
                      color: Colors.black, size: 24),
                  title: const Text(
                    'Copy Link',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    if (productUrl.isNotEmpty) {
                      Clipboard.setData(ClipboardData(text: productUrl));
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Link copied to clipboard',
                            style: TextStyle(fontFamily: 'PlusJakartaSans'),
                          ),
                          backgroundColor: Colors.black,
                          duration: Duration(milliseconds: 2000),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
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
                onTap: () {
                  if (widget.product['image_url'] != null) {
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                        builder: (context) => DetectionPage(
                          imageUrl: widget.product['image_url'],
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
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
                          color: Colors.grey.shade100,
                          child: const Icon(
                            Icons.checkroom,
                            size: 50,
                            color: Colors.grey,
                          ),
                        ),
                ),
              ),
            ),
            Container(
              color: Colors.white,
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
                            final productUrl = widget.product['url'] as String?;

                            if (productUrl == null || productUrl.isEmpty) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('No product link available'),
                                    backgroundColor: Colors.black,
                                  ),
                                );
                              }
                              return;
                            }

                            final uri = Uri.parse(productUrl);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            } else {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Cannot open product link'),
                                    backgroundColor: Colors.black,
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error opening link: $e'),
                                  backgroundColor: Colors.black,
                                ),
                              );
                            }
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
                            onTap: () {
                              Navigator.of(context, rootNavigator: true).push(
                                MaterialPageRoute(
                                  builder: (context) => DetectionPage(
                                    imageUrl: widget.product['image_url'] ?? '',
                                  ),
                                ),
                              );
                            },
                            child: SizedBox(
                              width: 44,
                              height: 48,
                              child: Center(
                                child: Transform.translate(
                                  offset: const Offset(0, -0.5),
                                  child: Icon(
                                    SnaplookAiIcon.aiSearchIcon,
                                    size: 21,
                                    color: Colors.black,
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
                                        offset: isFavorite ? Offset.zero : const Offset(-1, 1),
                                        child: Icon(
                                          isFavorite ? SnaplookIcons.heartFilled : SnaplookIcons.heartOutline,
                                          size: isFavorite ? 24 * 0.85 : 24 * 0.75,
                                          color: isFavorite ? const Color(0xFFf2003c) : Colors.black,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: _showOptionsMenu,
                            child: SizedBox(
                              width: 44,
                              height: 48,
                              child: Center(
                                child: Icon(
                                  Icons.more_horiz,
                                  color: Colors.black,
                                  size: 24,
                                ),
                              ),
                            ),
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
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (widget.product['title'] != null) ...[
                    Text(
                      widget.product['title'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
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

    return Image.network(
      widget.imageUrl,
      fit: currentFit,
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          // Image loaded, check if we need to adjust fit for shoes
          if (isShoeCategory && _boxFit == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _determineOptimalFit();
            });
          }
          return child;
        }
        return Center(
          child: CircularProgressIndicator(
            color: Color(0xFFf2003c),
            strokeWidth: 2,
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                : null,
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => Container(
        color: Colors.grey.shade100,
        child: const Icon(
          Icons.image_not_supported,
          size: 50,
          color: Colors.grey,
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

