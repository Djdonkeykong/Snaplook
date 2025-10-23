import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../home/domain/providers/inspiration_provider.dart';
import '../../../home/domain/services/inspiration_service.dart';
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
  bool _isLiked = false;
  final _inspirationService = InspirationService();

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final radius = context.radius;
    final relatedProducts = ref.watch(inspirationProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // Floating App Bar
          SliverAppBar(
            expandedHeight: MediaQuery.of(context).size.height * 0.65,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.black,
                  size: 20,
                ),
              ),
            ),
            actions: [],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
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

          // Product Details - Zalando Style
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: EdgeInsets.all(spacing.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Brand Name
                  if (widget.product['brand'] != null) ...[
                    Text(
                      widget.product['brand'],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],

                  // Product Title
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
                    SizedBox(height: spacing.m),
                  ],

                  // Action Row - Zalando Style
                  Row(
                    children: [
                      // View Product Button
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final productUrl = widget.product['product_url'] as String?;
                            if (productUrl != null) {
                              // TODO: Open URL
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFf2003c),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
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
                      ),

                      SizedBox(width: spacing.m),

                      // Search Icon
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(
                              builder: (context) => VisualSearchPage(
                                product: widget.product,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xFFE5E7EB),
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Center(
                            child: SvgPicture.asset(
                              'assets/icons/search-icon-sparkle.svg',
                              width: 22,
                              height: 22,
                              colorFilter: const ColorFilter.mode(
                                Colors.black,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
                      ),

                      SizedBox(width: spacing.sm),

                      // Heart Icon
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isLiked = !_isLiked;
                          });
                        },
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xFFE5E7EB),
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Center(
                            child: Icon(
                              _isLiked ? Icons.favorite : Icons.favorite_border,
                              color: _isLiked ? const Color(0xFFf2003c) : Colors.black,
                              size: 22,
                            ),
                          ),
                        ),
                      ),

                      SizedBox(width: spacing.sm),

                      // Three Dots
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFFE5E7EB),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.more_horiz,
                            color: Colors.black,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: spacing.l),
                ],
              ),
            ),
          ),

          // More to Explore Section
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(spacing.l, 0, spacing.l, spacing.l),
              child: const Text(
                'More to explore',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
          ),

          // Related Products Grid
          SliverPadding(
            padding: EdgeInsets.zero,
            sliver: _buildRelatedProductsSliver(relatedProducts, spacing, radius),
          ),

          // Bottom Padding
          SliverToBoxAdapter(
            child: SizedBox(height: spacing.xxl),
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedProductsSliver(InspirationState relatedProducts, dynamic spacing, dynamic radius) {
    if (relatedProducts.isLoading) {
      return SliverToBoxAdapter(
        child: Container(
          height: 200,
          child: const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFf2003c),
            ),
          ),
        ),
      );
    }

    if (relatedProducts.error != null) {
      return SliverToBoxAdapter(
        child: Container(
          height: 200,
          child: const Center(
            child: Text('Failed to load related products'),
          ),
        ),
      );
    }

    // Filter out current product, apply quality filter, and show more related items
    final related = relatedProducts.images
        .where((p) {
          if (p['id'] == widget.product['id']) return false; // Exclude current product
          final imageUrl = p['image_url'] as String?;
          return imageUrl != null && _inspirationService.isHighQualityImage(imageUrl);
        })
        .take(20) // Show more images like home page
        .toList();

    if (related.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          height: 100,
          child: const Center(
            child: Text('No related products found'),
          ),
        ),
      );
    }

    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 3,
        mainAxisSpacing: 3,
        childAspectRatio: 0.75,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final product = related[index];
          return _RelatedProductCard(
            product: product,
            index: index,
          );
        },
        childCount: related.length,
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _RelatedProductCard extends StatefulWidget {
  final Map<String, dynamic> product;
  final int index;

  const _RelatedProductCard({
    required this.product,
    required this.index,
  });

  @override
  State<_RelatedProductCard> createState() => _RelatedProductCardState();
}

class _RelatedProductCardState extends State<_RelatedProductCard> {
  BoxFit? _boxFit;

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.product['image_url'] as String?;
    final category = (widget.product['category'] as String?)?.toLowerCase() ?? '';
    final isShoeCategory = category.contains('shoe') || category.contains('sneaker') || category.contains('boot');

    // Default fit based on category
    final defaultFit = isShoeCategory ? BoxFit.contain : BoxFit.cover;
    final currentFit = _boxFit ?? defaultFit;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ProductDetailPage(
              product: widget.product,
              heroTag: 'related_${widget.product['id']}_${widget.index}',
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
        ),
        child: Hero(
          tag: 'related_${widget.product['id']}_${widget.index}',
          child: ClipRect(
            child: imageUrl != null
                ? Image.network(
                    imageUrl,
                    fit: currentFit,
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
                      return Container(
                        color: Colors.grey.shade100,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFf2003c),
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey.shade100,
                        child: const Icon(
                          Icons.image_not_supported,
                          size: 30,
                          color: Colors.grey,
                        ),
                      );
                    },
                  )
                : Container(
                    color: Colors.grey.shade100,
                    child: const Icon(
                      Icons.checkroom,
                      size: 30,
                      color: Colors.grey,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  void _determineOptimalFit() {
    if (!mounted) return;

    final imageUrl = widget.product['image_url'] as String?;
    if (imageUrl == null) return;

    // For shoes, check if the image would look better with cover vs contain
    final image = NetworkImage(imageUrl);

    image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        if (!mounted) return;

        final imageAspectRatio = info.image.width / info.image.height;
        const containerAspectRatio = 0.75; // Related products grid aspect ratio

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

