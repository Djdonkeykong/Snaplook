import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_refresh/easy_refresh.dart';
import '../../../favorites/domain/providers/favorites_provider.dart';
import '../../../favorites/domain/models/favorite_item.dart';
import '../../../product/presentation/pages/product_detail_page.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../shared/navigation/main_navigation.dart';

class WishlistPage extends ConsumerStatefulWidget {
  const WishlistPage({super.key});

  @override
  ConsumerState<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends ConsumerState<WishlistPage> with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final Set<String> _hapticTriggered = {};
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
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
    final isInitialLoading = favoritesAsync.isLoading && !favoritesAsync.hasValue;
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
              child: const Text(
                'My Wishlist',
                style: TextStyle(
                  fontSize: 38,
                  fontFamily: 'PlusJakartaSans',
                  letterSpacing: -1.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  height: 1.3,
                ),
              ),
            ),

            // Tab Bar
            TabBar(
              controller: _tabController,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFFf2003c),
              indicatorWeight: 2,
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'PlusJakartaSans',
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'PlusJakartaSans',
              ),
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Collections'),
              ],
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAllFavoritesTab(isInitialLoading, hasError, favorites, spacing),
                  _buildCollectionsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllFavoritesTab(bool isInitialLoading, bool hasError, List<FavoriteItem> favorites, dynamic spacing) {
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
        padding: EdgeInsets.all(spacing.m),
        itemCount: favorites.length,
        itemBuilder: (context, index) {
          final favorite = favorites[index];
          return Dismissible(
            key: Key(favorite.id),
            direction: DismissDirection.endToStart,
            dismissThresholds: const {
              DismissDirection.endToStart: 0.4,
            },
            movementDuration: const Duration(milliseconds: 250),
            resizeDuration: const Duration(milliseconds: 250),
            background: Container(
              alignment: Alignment.centerRight,
              margin: EdgeInsets.only(bottom: spacing.m),
              padding: EdgeInsets.only(right: spacing.m),
              decoration: BoxDecoration(
                color: const Color(0xFFf2003c),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.delete_outline,
                color: Colors.white,
                size: 28,
              ),
            ),
            onUpdate: (details) {
              // Trigger haptic feedback when swipe crosses threshold
              if (details.progress > 0.5 && !_hapticTriggered.contains(favorite.id)) {
                HapticFeedback.mediumImpact();
                _hapticTriggered.add(favorite.id);
              } else if (details.progress < 0.5 && _hapticTriggered.contains(favorite.id)) {
                // Reset if user swipes back
                _hapticTriggered.remove(favorite.id);
              }
            },
            onDismissed: (direction) {
              _hapticTriggered.remove(favorite.id);
              ref.read(favoritesProvider.notifier).removeFavorite(favorite.productId);

              // Show snackbar
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: const [
                      Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Removed from favorites',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.black,
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            child: _FavoriteCard(favorite: favorite, spacing: spacing),
          );
        },
      ),
    );
  }

  Widget _buildCollectionsTab() {
    return const Center(
      child: Text(
        'Collections coming soon!',
        style: TextStyle(
          fontSize: 16,
          color: Colors.grey,
          fontFamily: 'PlusJakartaSans',
        ),
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
            Text(
              'No favorites yet',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                fontFamily: 'PlusJakartaSans',
                color: Colors.black,
              ),
            ),
            SizedBox(height: spacing.sm),
            Text(
              'Start exploring to find items you love',
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'PlusJakartaSans',
                color: Colors.grey.shade500,
              ),
            ),
            SizedBox(height: spacing.xl),
            GestureDetector(
              onTap: () {
                // Switch to home tab (index 0)
                ref.read(selectedIndexProvider.notifier).state = 0;
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.l,
                  vertical: 12,
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

  const _FavoriteCard({
    required this.favorite,
    required this.spacing,
  });

  void _showOptionsMenu(BuildContext context, WidgetRef ref) {
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
                  leading: const Icon(Icons.collections_bookmark_outlined, color: Colors.black),
                  title: const Text(
                    'Add to Collection',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Show collection selector
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Collections feature coming soon!')),
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
                    child: const Icon(Icons.error, color: Colors.grey, size: 24),
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
                      color: Colors.grey,
                      fontFamily: 'PlusJakartaSans',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            SizedBox(width: spacing.sm),

            // Three Dots Menu
            GestureDetector(
              onTap: () => _showOptionsMenu(context, ref),
              child: SizedBox(
                height: 100,
                width: 44,
                child: Center(
                  child: Icon(
                    Icons.more_horiz,
                    color: Colors.grey.shade400,
                    size: 24,
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
