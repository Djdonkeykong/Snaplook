import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:share_plus/share_plus.dart';
import '../../../favorites/domain/providers/favorites_provider.dart';
import '../../../favorites/domain/models/favorite_item.dart';
import '../../../product/presentation/pages/product_detail_page.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/theme/snaplook_icons.dart';
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
    final favoritesAsync = ref.watch(favoritesProvider);

    // Always show data if we have it, even during refresh
    final favorites = favoritesAsync.valueOrNull ?? [];
    final isInitialLoading =
        favoritesAsync.isLoading && !favoritesAsync.hasValue;
    final hasError = favoritesAsync.hasError && !favoritesAsync.hasValue;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fixed Header
            Padding(
              padding: EdgeInsets.all(spacing.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'My Wishlist',
                    style: TextStyle(
                      fontSize: 30,
                      fontFamily: 'PlusJakartaSans',
                      letterSpacing: -1.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'These are the items you liked the most.',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'PlusJakartaSans',
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Removed from favorites',
          style: TextStyle(fontFamily: 'PlusJakartaSans'),
        ),
        backgroundColor: Colors.black,
        duration: Duration(milliseconds: 2500),
      ),
    );
  }

  Widget _buildAllFavoritesTab(bool isInitialLoading, bool hasError,
      List<FavoriteItem> favorites, dynamic spacing) {
    if (isInitialLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFf2003c),
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
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: ${favoritesAsync.error}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(favoritesProvider.notifier).refresh();
              },
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
        backgroundColor: Colors.white,
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
                  color: Colors.black,
                  width: 1.5,
                ),
              ),
              child: Transform.translate(
                offset: const Offset(-2, 0),
                child: const Icon(
                  SnaplookIcons.heartOutline,
                  size: 32,
                  color: Colors.black,
                ),
              ),
            ),
            SizedBox(height: spacing.l),
            Text(
              'Tap the heart on pieces you love to build your personal shortlist.',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                fontFamily: 'PlusJakartaSans',
                color: Colors.black87,
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
                  color: const Color(0xFFf2003c),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Text(
                  'Browse Items',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'PlusJakartaSans',
                    color: Colors.white,
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

  void _showShareMenu(BuildContext context) {
    final productBrand = favorite.brand;
    final productTitle = favorite.productName;
    final productUrl = favorite.purchaseUrl ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final messenger = ScaffoldMessenger.of(context);
        final shareTitle = '$productBrand $productTitle'.trim();
        final shareMessage = productUrl.isNotEmpty
            ? 'Check out this $productBrand $productTitle on Snaplook! $productUrl'
            : 'Check out this $productBrand $productTitle on Snaplook!';

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading:
                      const Icon(Icons.share_outlined, color: Colors.black, size: 24),
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
                      shareMessage,
                      subject: shareTitle.isEmpty ? null : shareTitle,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.link, color: Colors.black, size: 24),
                  title: const Text(
                    'Copy Link',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    if (productUrl.isEmpty) {
                      messenger.hideCurrentSnackBar();
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Link unavailable for this item.',
                            style: TextStyle(fontFamily: 'PlusJakartaSans'),
                          ),
                          backgroundColor: Colors.black,
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return;
                    }
                    Clipboard.setData(ClipboardData(text: productUrl));
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Link copied to clipboard',
                          style: TextStyle(fontFamily: 'PlusJakartaSans'),
                        ),
                        backgroundColor: Colors.black,
                        duration: Duration(seconds: 2),
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
                    color: Colors.grey.shade200,
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey.shade200,
                    child:
                        const Icon(Icons.error, color: AppColors.textTertiary, size: 24),
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'PlusJakartaSans',
                      color: Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    favorite.productName,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      fontFamily: 'PlusJakartaSans',
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
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        SnaplookIcons.trashBin,
                        color: Colors.white,
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
                          color: Colors.black,
                          width: 1.0,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.more_horiz,
                          color: Colors.black,
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
