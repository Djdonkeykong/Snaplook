import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:share_plus/share_plus.dart';
import '../../../favorites/domain/providers/favorites_provider.dart';
import '../../../favorites/domain/models/favorite_item.dart';
import '../../../product/presentation/pages/product_detail_page.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/theme/snaplook_icons.dart';
import '../../../../../core/constants/history_icon.dart';
import '../../../../../shared/navigation/main_navigation.dart';

class WishlistPage extends ConsumerStatefulWidget {
  const WishlistPage({super.key});

  @override
  ConsumerState<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends ConsumerState<WishlistPage>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final Map<String, AnimationController> _removeControllers = {};

  @override
  void dispose() {
    _scrollController.dispose();
    for (var controller in _removeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to scroll to top trigger for wishlist tab (index 1)
    ref.listen(scrollToTopTriggerProvider, (previous, next) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
    final spacing = context.spacing;
    final radius = context.radius;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final favoritesAsync = ref.watch(favoritesProvider);

    // Always show data if we have it, even during refresh
    final favorites = favoritesAsync.valueOrNull ?? [];
    final isInitialLoading =
        favoritesAsync.isLoading && !favoritesAsync.hasValue;
    final hasError = favoritesAsync.hasError && !favoritesAsync.hasValue;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: false,
        titleSpacing: spacing.l,
        title: Text(
          'My Wishlist',
          style: TextStyle(
            fontSize: 30,
            fontFamily: 'PlusJakartaSans',
            letterSpacing: -1.0,
            fontWeight: FontWeight.bold,
            height: 1.3,
            color: colorScheme.onSurface,
          ),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: spacing.l),
            child: IconButton(
              icon: Icon(
                Solar__history_bold_new.solarHistoryBoldNew,
                color: colorScheme.onSurface,
                size: 24,
              ),
              onPressed: () {
                Navigator.of(context).pushNamed('/history');
              },
              tooltip: 'Search History',
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subtitle
            Padding(
              padding: EdgeInsets.only(
                left: spacing.l,
                right: spacing.l,
                bottom: spacing.m,
              ),
              child: Text(
                'These are the items you liked the most.',
                style: textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ),

            // Favorites List
            Expanded(
              child: _buildAllFavoritesTab(
                  isInitialLoading, hasError, favorites, spacing),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeItem(String productId) async {
    final controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    controller.value = 1.0;

    setState(() {
      _removeControllers[productId] = controller;
    });

    await controller.reverse();

    if (!mounted) return;

    await ref.read(favoritesProvider.notifier).removeFavorite(productId);

    if (!mounted) return;

    setState(() {
      _removeControllers.remove(productId);
    });
    controller.dispose();

    ScaffoldMessenger.of(context).clearSnackBars();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Removed from favorites',
          style: context.snackTextStyle(
            merge: const TextStyle(fontFamily: 'PlusJakartaSans'),
          ),
        ),
        duration: const Duration(milliseconds: 2500),
      ),
    );
  }

  Widget _buildAllFavoritesTab(bool isInitialLoading, bool hasError,
      List<FavoriteItem> favorites, dynamic spacing) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (isInitialLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor:
              AlwaysStoppedAnimation<Color>(colorScheme.secondary),
          strokeWidth: 2,
        ),
      );
    }

    if (hasError) {
      final favoritesAsync = ref.watch(favoritesProvider);
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 64, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Error: ${favoritesAsync.error}',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(favoritesProvider.notifier).refresh();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.secondary,
                foregroundColor: colorScheme.onSecondary,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (favorites.isEmpty) {
      return _buildEmptyState(context, spacing);
    }

    return EasyRefresh(
      onRefresh: () async {
        HapticFeedback.selectionClick();
        await ref.read(favoritesProvider.notifier).refresh();
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
        backgroundColor: colorScheme.surface,
      ),
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(
          spacing.m,
          0,
          spacing.m,
          spacing.m,
        ),
        itemCount: favorites.length,
        itemBuilder: (context, index) {
          final favorite = favorites[index];
          final controller = _removeControllers[favorite.productId];

          Widget card = _FavoriteCard(
            favorite: favorite,
            spacing: spacing,
            onDelete: () {
              HapticFeedback.mediumImpact();
              _removeItem(favorite.productId);
            },
          );

          if (controller != null) {
            return SizeTransition(
              sizeFactor: controller,
              child: FadeTransition(
                opacity: controller,
                child: card,
              ),
            );
          }

          return card;
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, dynamic spacing) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(spacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorScheme.onSurface,
                  width: 1.5,
                ),
              ),
              child: Transform.translate(
                offset: const Offset(-2, 0),
                child: Icon(
                  SnaplookIcons.heartOutline,
                  size: 32,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            SizedBox(height: spacing.l),
            Text(
              'Tap the heart on pieces you love to build your personal shortlist.',
              style: textTheme.bodyMedium?.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
                height: 1.35,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: spacing.xl),
            GestureDetector(
              onTap: () {
                // Switch to home tab (index 0)
                ref.read(selectedIndexProvider.notifier).state = 0;
              },
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 16,
                  bottom: 18,
                ),
                constraints: const BoxConstraints(
                  minHeight: 52,
                  minWidth: 180,
                  maxWidth: 220,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : const Color(0xFFf2003c),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Text(
                  'Browse Items',
                  style: textTheme.labelLarge?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.black
                        : Colors.white,
                    height: 1.5,
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

class _FavoriteCard extends ConsumerWidget {
  final FavoriteItem favorite;
  final dynamic spacing;
  final VoidCallback? onDelete;

  const _FavoriteCard({
    required this.favorite,
    required this.spacing,
    this.onDelete,
  });

  String _resolveProductUrl() {
    final candidates = [
      favorite.purchaseUrl,
    ];

    for (final candidate in candidates) {
      if (candidate == null) continue;
      final trimmed = candidate.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return '';
  }

  void _showShareMenu(BuildContext context) {
    final productBrand = favorite.brand;
    final productTitle = favorite.productName;
    final productUrl = _resolveProductUrl();

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
        final messenger = ScaffoldMessenger.of(context);
        final shareTitle = '$productBrand $productTitle'.trim();
        final shareMessage = productUrl.isNotEmpty
            ? 'Check out this $productBrand $productTitle on Snaplook! $productUrl'
            : 'Check out this $productBrand $productTitle on Snaplook!';
        final shareOrigin = _shareOriginForContext(context);
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SheetActionItem(
                  icon: Icons.share_outlined,
                  label: 'Share product',
                  onTap: () {
                    Navigator.pop(context);
                    Share.share(
                      shareMessage,
                      subject: shareTitle.isEmpty ? null : shareTitle,
                      sharePositionOrigin: shareOrigin,
                    );
                  },
                ),
                const SizedBox(height: 8),
                _SheetActionItem(
                  icon: Icons.link,
                  label: 'Copy link',
                  onTap: () {
                    Navigator.pop(context);
                    if (productUrl.isEmpty) {
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          'Link unavailable for this item.',
                          style: context.snackTextStyle(
                            merge: const TextStyle(fontFamily: 'PlusJakartaSans'),
                          ),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                    return;
                  }
                    Clipboard.setData(ClipboardData(text: productUrl));
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          'Link copied to clipboard',
                          style: context.snackTextStyle(
                            merge: const TextStyle(fontFamily: 'PlusJakartaSans'),
                          ),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
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
  Widget build(BuildContext context, WidgetRef ref) {
    final radius = context.radius;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        final productMap = {
          'id': favorite.productId,
          'title': favorite.productName,
          'brand': favorite.brand,
          'price': favorite.price,
          'image_url': favorite.imageUrl,
          'url': favorite.purchaseUrl ?? '',
          'purchase_url': favorite.purchaseUrl ?? '',
          'link': favorite.purchaseUrl ?? '',
          'category': favorite.category,
        };

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ProductDetailPage(
              product: productMap,
              heroTag: 'wishlist_${favorite.productId}',
            ),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: spacing.m),
        color: Colors.transparent,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Square Product Image
            ClipRRect(
              borderRadius: BorderRadius.circular(radius.medium),
              child: SizedBox(
                width: 100,
                height: 100,
                child: CachedNetworkImage(
                  imageUrl: favorite.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: colorScheme.surfaceVariant,
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: colorScheme.surfaceVariant,
                    child: Icon(
                      Icons.error,
                      color: colorScheme.onSurfaceVariant,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),

            SizedBox(width: spacing.m),

            // Product Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  favorite.brand,
                  style: textTheme.titleMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  favorite.productName,
                  style: textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                ],
              ),
            ),

            SizedBox(width: spacing.sm),

            // Action Icons (Delete & Share)
            SizedBox(
              height: 100,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: onDelete,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: colorScheme.secondary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        SnaplookIcons.trashBin,
                        color: colorScheme.onSecondary,
                        size: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _showShareMenu(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: colorScheme.onSurface,
                          width: 1.0,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.more_horiz,
                          color: colorScheme.onSurface,
                          size: 16,
                        ),
                      ),
                    ),
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

class _SheetActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SheetActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: colorScheme.onSurface, size: 24),
            const SizedBox(width: 24),
            Expanded(
              child: Text(
                label,
                style: textTheme.bodyLarge?.copyWith(
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
