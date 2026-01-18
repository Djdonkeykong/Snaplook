import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/snaplook_icons.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../shared/widgets/bottom_sheet_handle.dart';
import '../../../detection/domain/models/detection_result.dart';
import '../../../favorites/domain/providers/favorites_provider.dart';

class ResultsBottomSheetContent extends StatelessWidget {
  final List<DetectionResult> results;
  final ScrollController scrollController;
  final ValueChanged<DetectionResult> onProductTap;
  final bool showFavoriteButton;
  final dynamic analyzedImage; // Can be XFile, String (URL), or null

  const ResultsBottomSheetContent({
    super.key,
    required this.results,
    required this.scrollController,
    required this.onProductTap,
    this.showFavoriteButton = true,
    this.analyzedImage,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final mediaQuery = MediaQuery.of(context);
    final safeAreaBottom = mediaQuery.padding.bottom;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.only(
                left: spacing.m,
                right: spacing.m,
                top: spacing.l,
                bottom: spacing.m,
              ),
              child: BottomSheetHandle(),
            ),
            Expanded(
              child: CustomScrollView(
                controller: scrollController,
                physics: const ClampingScrollPhysics(),
                slivers: [
                  // Image comparison card that scrolls
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: spacing.m),
                      child: _ImageComparisonCard(analyzedImage: analyzedImage),
                    ),
                  ),
                  // Results count label
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        spacing.m,
                        spacing.m,
                        spacing.m,
                        spacing.sm,
                      ),
                      child: Text(
                        'Found ${results.length} similar match${results.length == 1 ? '' : 'es'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.secondary,
                          fontFamily: 'PlusJakartaSans',
                        ),
                      ),
                    ),
                  ),
                  // Product list
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: spacing.m),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final result = results[index];
                          return Column(
                            children: [
                              _ProductCard(
                                result: result,
                                onTap: () => onProductTap(result),
                                isFirst: index == 0,
                                showFavoriteButton: showFavoriteButton,
                              ),
                              if (index < results.length - 1)
                                Padding(
                                  padding: EdgeInsets.only(left: spacing.m),
                                  child: Divider(
                                    color: colorScheme.outlineVariant,
                                    height: 1,
                                    thickness: 1,
                                  ),
                                ),
                            ],
                          );
                        },
                        childCount: results.length,
                      ),
                    ),
                  ),
                  // Bottom padding
                  SliverPadding(
                    padding: EdgeInsets.only(bottom: safeAreaBottom + spacing.l),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final DetectionResult result;
  final VoidCallback onTap;
  final bool isFirst;
  final bool showFavoriteButton;

  const _ProductCard({
    required this.result,
    required this.onTap,
    required this.isFirst,
    this.showFavoriteButton = true,
  });


  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final radius = context.radius;
    final mediaQuery = MediaQuery.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.only(
          top: spacing.m,
          bottom: spacing.m,
        ),
        color: colorScheme.surface,
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius.small),
                    color: colorScheme.surfaceContainerHighest,
                    image: DecorationImage(
                      image: CachedNetworkImageProvider(result.imageUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                if (showFavoriteButton)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: _SheetFavoriteButton(product: result),
                  ),
              ],
            ),
            SizedBox(width: spacing.m),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: spacing.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.brand.toUpperCase(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                        fontFamily: 'PlusJakartaSans',
                        letterSpacing: 0.2,
                      ),
                    ),
                    SizedBox(height: spacing.xs),
                    Text(
                      result.productName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'PlusJakartaSans',
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: spacing.sm),
                    Text(
                      (result.priceDisplay != null &&
                              result.priceDisplay!.trim().isNotEmpty)
                          ? result.priceDisplay!
                          : 'See store',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondary,
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(right: mediaQuery.size.width * 0.01),
              child: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageComparisonCard extends StatefulWidget {
  final dynamic analyzedImage; // Can be XFile, String (URL), or null

  const _ImageComparisonCard({this.analyzedImage});

  @override
  State<_ImageComparisonCard> createState() => _ImageComparisonCardState();
}

class _ImageComparisonCardState extends State<_ImageComparisonCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _rotationController.forward();
      } else {
        _rotationController.reverse();
      }
    });
  }

  Widget _buildThumbnail() {
    final colorScheme = Theme.of(context).colorScheme;

    if (widget.analyzedImage == null) {
      // Placeholder when no image
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: colorScheme.surfaceContainerHighest,
        ),
        child: Icon(
          Icons.image_outlined,
          color: colorScheme.onSurfaceVariant,
          size: 24,
        ),
      );
    }

    // Handle String (URL or asset path)
    if (widget.analyzedImage is String) {
      final imageString = widget.analyzedImage as String;

      // Check if it's an asset path
      if (imageString.startsWith('assets/')) {
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: colorScheme.surfaceContainerHighest,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              imageString,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.image_outlined,
                color: colorScheme.onSurfaceVariant,
                size: 24,
              ),
            ),
          ),
        );
      }

      // Otherwise treat as network URL
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: colorScheme.surfaceContainerHighest,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: imageString,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: colorScheme.surfaceContainerHighest,
            ),
            errorWidget: (context, url, error) => Icon(
              Icons.image_outlined,
              color: colorScheme.onSurfaceVariant,
              size: 24,
            ),
          ),
        ),
      );
    }

    // Handle XFile (local file)
    if (widget.analyzedImage.runtimeType.toString().contains('XFile')) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: colorScheme.surfaceContainerHighest,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(widget.analyzedImage.path),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.image_outlined,
              color: colorScheme.onSurfaceVariant,
              size: 24,
            ),
          ),
        ),
      );
    }

    // Fallback
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: colorScheme.surfaceContainerHighest,
      ),
      child: Icon(
        Icons.image_outlined,
        color: colorScheme.onSurfaceVariant,
        size: 24,
      ),
    );
  }

  Widget _buildFullImage() {
    final colorScheme = Theme.of(context).colorScheme;

    if (widget.analyzedImage == null) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: colorScheme.surfaceContainerHighest,
        ),
        child: Center(
          child: Icon(
            Icons.image_outlined,
            color: colorScheme.onSurfaceVariant,
            size: 48,
          ),
        ),
      );
    }

    // Handle String (URL or asset path)
    if (widget.analyzedImage is String) {
      final imageString = widget.analyzedImage as String;

      // Asset path
      if (imageString.startsWith('assets/')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            imageString,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: colorScheme.surfaceContainerHighest,
              ),
              child: Center(
                child: Icon(
                  Icons.image_outlined,
                  color: colorScheme.onSurfaceVariant,
                  size: 48,
                ),
              ),
            ),
          ),
        );
      }

      // Network URL
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: imageString,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: colorScheme.surfaceContainerHighest,
          ),
          errorWidget: (context, url, error) => Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: colorScheme.surfaceContainerHighest,
            ),
            child: Center(
              child: Icon(
                Icons.image_outlined,
                color: colorScheme.onSurfaceVariant,
                size: 48,
              ),
            ),
          ),
        ),
      );
    }

    // XFile (local file)
    if (widget.analyzedImage.runtimeType.toString().contains('XFile')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(widget.analyzedImage.path),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: colorScheme.surfaceContainerHighest,
            ),
            child: Center(
              child: Icon(
                Icons.image_outlined,
                color: colorScheme.onSurfaceVariant,
                size: 48,
              ),
            ),
          ),
        ),
      );
    }

    // Fallback
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: colorScheme.surfaceContainerHighest,
      ),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          color: colorScheme.onSurfaceVariant,
          size: 48,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final screenWidth = MediaQuery.of(context).size.width;
    final colorScheme = Theme.of(context).colorScheme;

    // Calculate expanded height similar to iOS (max 400px)
    // Assume a typical aspect ratio for the image
    final containerWidth = screenWidth - (spacing.m * 2);
    final expandedHeight = 400.0; // Match iOS max height

    return GestureDetector(
      onTap: _toggleExpanded,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        height: _isExpanded ? expandedHeight : 68,
        padding: EdgeInsets.symmetric(
          horizontal: spacing.m,
          vertical: _isExpanded ? 12 : 10,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: _isExpanded
            ? _buildFullImage()
            : Row(
                children: [
                  // Thumbnail image
                  _buildThumbnail(),
                  SizedBox(width: spacing.m),
                  // "Compare with original" text
                  Expanded(
                    child: Text(
                      'Compare with original',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'PlusJakartaSans',
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  // Chevron icon with rotation
                  RotationTransition(
                    turns: _rotationAnimation,
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SheetFavoriteButton extends ConsumerStatefulWidget {
  final DetectionResult product;

  const _SheetFavoriteButton({required this.product});

  @override
  ConsumerState<_SheetFavoriteButton> createState() =>
      _SheetFavoriteButtonState();
}

class _SheetFavoriteButtonState extends ConsumerState<_SheetFavoriteButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

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

  Future<void> _onTap(BuildContext context) async {
    HapticFeedback.mediumImpact();
    _controller.forward().then((_) => _controller.reverse());

    final wasAlreadyFavorited = ref.read(isFavoriteProvider(widget.product.id));

    try {
      await ref.read(favoritesProvider.notifier).toggleFavorite(widget.product);

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              wasAlreadyFavorited
                  ? 'Removed from favorites'
                  : 'Added to favorites',
              style: const TextStyle(fontFamily: 'PlusJakartaSans'),
            ),
            duration: const Duration(milliseconds: 2500),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update favorites: ${e.toString()}',
              style: const TextStyle(fontFamily: 'PlusJakartaSans'),
            ),
            duration: const Duration(milliseconds: 2500),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isFavorite = ref.watch(isFavoriteProvider(widget.product.id));

    // Tailored defaults for bottom-sheet cards
    const containerSize = 28.0;
    const containerOpacity = 0.75;
    const shadowBlur = 3.0;
    const shadowOffset = Offset(0, 1.5);
    const filledIconSize = 12.0;
    const outlineIconSize = 10.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onTap(context),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: containerSize,
              height: containerSize,
              decoration: BoxDecoration(
                color: colorScheme.surface.withOpacity(containerOpacity),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withOpacity(0.12),
                    blurRadius: shadowBlur,
                    offset: shadowOffset,
                  ),
                ],
              ),
              child: Center(
                child: Transform.translate(
                  offset: isFavorite ? Offset.zero : const Offset(-1, 0),
                  child: Icon(
                    isFavorite
                        ? SnaplookIcons.heartFilled
                        : SnaplookIcons.heartOutline,
                    size: isFavorite ? filledIconSize : outlineIconSize,
                    color: isFavorite
                        ? AppColors.secondary
                        : colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
