import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../detection/domain/models/detection_result.dart';
import '../../../home/domain/providers/image_provider.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../detection/presentation/providers/detection_provider.dart';
import '../../../../shared/widgets/snaplook_back_button.dart';
import '../../../../shared/widgets/snaplook_circular_icon_button.dart';
import '../../../favorites/domain/providers/favorites_provider.dart';
import '../../../../../core/theme/snaplook_icons.dart';

class ResultsPage extends ConsumerStatefulWidget {
  final List<DetectionResult> results;
  final String? originalImageUrl;

  const ResultsPage({
    super.key,
    required this.results,
    this.originalImageUrl,
  });

  @override
  ConsumerState<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends ConsumerState<ResultsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedImage = ref.watch(selectedImageProvider);
    final detectionState = ref.watch(detectionProvider);
    final results = detectionState.results;

    final spacing = context.spacing;
    final radius = context.radius;
    final mediaQuery = MediaQuery.of(context);
    final safeAreaBottom = mediaQuery.padding.bottom;
    final sheetMaxHeight = mediaQuery.size.height * 0.85;
    final sheetInitialHeight = sheetMaxHeight * 0.55;
    final sheetMinHeight = sheetInitialHeight;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: const SnaplookBackButton(),
        actions: [
          _TopIconButton(
            icon: Icons.share,
            onPressed: _shareResults,
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: _ResultsBackground(
              selectedImage: selectedImage,
              originalImageUrl: widget.originalImageUrl,
            ),
          ),
          SlidingUpPanel(
            minHeight: sheetMinHeight,
            maxHeight: sheetMaxHeight,
            parallaxEnabled: false,
            panelSnapping: true,
            snapPoint: (sheetInitialHeight / sheetMaxHeight).clamp(0.0, 1.0),
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(12),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
            body: const SizedBox.shrink(),
            panelBuilder: (scrollController) {
              return SafeArea(
                top: false,
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(
                        left: spacing.m,
                        right: spacing.m,
                        top: spacing.l,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey[400],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          SizedBox(height: spacing.m),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Similar matches',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'PlusJakartaSans',
                                  ),
                                ),
                              ),
                              Text(
                                '${results.length} results',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'PlusJakartaSans',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: spacing.m),
                    // Category filter chips - mirror share extension styling
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: SizedBox(
                        height: 36,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding:
                                EdgeInsets.symmetric(horizontal: spacing.m),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                _AllResultsChip(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: spacing.sm),
                    Expanded(
                      child: ListView.separated(
                        controller: scrollController,
                        physics: const ClampingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          spacing.m,
                          0,
                          spacing.m,
                          safeAreaBottom + spacing.l,
                        ),
                        itemCount: results.length,
                        separatorBuilder: (context, index) {
                          return Padding(
                            padding: EdgeInsets.only(left: spacing.m),
                            child: Divider(
                              color: Colors.grey[300],
                              height: 1,
                              thickness: 1,
                            ),
                          );
                        },
                        itemBuilder: (context, index) {
                          final result = results[index];
                          return _ProductCard(
                            result: result,
                            onTap: () => _openProduct(result),
                            isFirst: index == 0,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _shareResults() {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Share functionality coming soon!',
          style: context.snackTextStyle(
            merge: const TextStyle(fontFamily: 'PlusJakartaSans'),
          ),
        ),
        duration: const Duration(milliseconds: 2500),
      ),
    );
  }

  void _openProduct(DetectionResult result) async {
    if (result.purchaseUrl != null) {
      final uri = Uri.parse(result.purchaseUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }
}

class _ProductCard extends StatelessWidget {
  final DetectionResult result;
  final VoidCallback onTap;
  final bool isFirst;

  const _ProductCard({
    required this.result,
    required this.onTap,
    required this.isFirst,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final radius = context.radius;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.only(
          top: isFirst ? 0 : spacing.m,
          bottom: spacing.m,
        ),
        color: Theme.of(context).colorScheme.surface,
        child: Row(
          children: [
            // Image
            Stack(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius.small),
                    color: Colors.grey[100],
                    image: DecorationImage(
                      image: CachedNetworkImageProvider(result.imageUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: _ResultFavoriteButton(product: result),
                ),
              ],
            ),
            SizedBox(width: spacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.brand.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontFamily: 'PlusJakartaSans',
                      letterSpacing: 0.2,
                    ),
                  ),
                  SizedBox(height: spacing.xs),
                  Text(
                    result.productName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'PlusJakartaSans',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: spacing.sm),
                  Text(
                    result.price > 0
                        ? '\$${result.price.toStringAsFixed(2)}'
                        : 'See store',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFf2003c),
                      fontFamily: 'PlusJakartaSans',
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultsBackground extends StatelessWidget {
  const _ResultsBackground({
    this.selectedImage,
    this.originalImageUrl,
  });

  final XFile? selectedImage;
  final String? originalImageUrl;

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (originalImageUrl != null) {
      child = Image.network(
        originalImageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, _, __) => Container(color: Colors.black),
      );
    } else if (selectedImage != null) {
      child = Image.file(
        File(selectedImage!.path),
        fit: BoxFit.cover,
      );
    } else {
      child = const ColoredBox(color: Colors.black);
    }

    return SizedBox.expand(child: child);
  }
}

class _AllResultsChip extends StatelessWidget {
  const _AllResultsChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF2003C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFF2003C),
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: const Text(
        'All',
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SnaplookCircularIconButton(
      icon: icon,
      onPressed: onPressed,
      iconSize: 18,
      tooltip: icon == Icons.share ? 'Share' : null,
      semanticLabel: icon == Icons.share ? 'Share' : null,
      margin: const EdgeInsets.all(8),
    );
  }
}

class _ResultFavoriteButton extends ConsumerStatefulWidget {
  final DetectionResult product;

  const _ResultFavoriteButton({required this.product});

  @override
  ConsumerState<_ResultFavoriteButton> createState() =>
      _ResultFavoriteButtonState();
}

class _ResultFavoriteButtonState extends ConsumerState<_ResultFavoriteButton>
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
    final isFavorite = ref.watch(isFavoriteProvider(widget.product.id));

    // Tailored defaults for results cards (matches prior sizing on this card only)
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
                color: Colors.white.withOpacity(containerOpacity),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: shadowBlur,
                    offset: shadowOffset,
                  ),
                ],
              ),
              child: Center(
                child: Transform.translate(
                  offset: Offset.zero,
                  child: Icon(
                    isFavorite
                        ? SnaplookIcons.heartFilled
                        : SnaplookIcons.heartOutline,
                    size: isFavorite ? filledIconSize : outlineIconSize,
                    color: isFavorite ? const Color(0xFFf2003c) : Colors.black,
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
