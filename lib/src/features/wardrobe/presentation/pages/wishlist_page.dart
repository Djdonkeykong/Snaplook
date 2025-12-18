import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:share_plus/share_plus.dart';
import 'package:snaplook/src/shared/utils/native_share_helper.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../favorites/domain/providers/favorites_provider.dart';
import '../../../favorites/domain/models/favorite_item.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/snaplook_icons.dart';
import '../../../../../shared/navigation/main_navigation.dart';
import '../../../../shared/services/supabase_service.dart';
import '../../../detection/presentation/pages/detection_page.dart';
import '../../../detection/presentation/pages/share_payload.dart';

final historyProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final supabaseService = SupabaseService();
  final userId = Supabase.instance.client.auth.currentUser?.id;

  if (userId == null) {
    debugPrint('[History] No authenticated user - returning empty history');
    return const [];
  }

  debugPrint('[History] Fetching history for user $userId');
  return await supabaseService.getUserSearches(userId: userId);
});

class WishlistPage extends ConsumerStatefulWidget {
  const WishlistPage({super.key});

  @override
  ConsumerState<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends ConsumerState<WishlistPage>
  with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final ScrollController _historyScrollController = ScrollController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _historyScrollController.dispose();
    _tabController.dispose();
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
    final historyAsync = ref.watch(historyProvider);

    // Always show data if we have it, even during refresh
    final favorites = favoritesAsync.valueOrNull ?? [];
    final isInitialLoading =
        favoritesAsync.isLoading && !favoritesAsync.hasValue;
    final hasError = favoritesAsync.hasError && !favoritesAsync.hasValue;

    final searches = historyAsync.valueOrNull ?? [];
    final isHistoryLoading = historyAsync.isLoading && !historyAsync.hasValue;
    final hasHistoryError = historyAsync.hasError && !historyAsync.hasValue;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          'My Wishlist',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: 'PlusJakartaSans',
            color: colorScheme.onSurface,
            letterSpacing: -0.3,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.secondary,
          labelColor: colorScheme.onSurface,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
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
            Tab(text: 'Favorites'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildAllFavoritesTab(
              isInitialLoading,
              hasError,
              favorites,
              spacing,
            ),
            _buildHistoryTab(
              isHistoryLoading,
              hasHistoryError,
              searches,
              spacing,
              radius,
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _removeItem(String productId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text(
          'Delete Favorite',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Are you sure you want to remove this item from your favorites?',
          style: TextStyle(fontFamily: 'PlusJakartaSans'),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              textStyle: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.secondary,
              textStyle: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;

    HapticFeedback.mediumImpact();

    await ref.read(favoritesProvider.notifier).removeFavorite(productId);

    if (!mounted) return true;

    ScaffoldMessenger.of(context).clearSnackBars();
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
    return true;
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
          spacing.m,
          spacing.m,
          spacing.m,
        ),
        itemCount: favorites.length,
        itemBuilder: (context, index) {
          final favorite = favorites[index];
          return Padding(
            padding: EdgeInsets.only(bottom: spacing.m),
            child: Slidable(
              key: ValueKey(favorite.id),
              endActionPane: ActionPane(
                motion: const StretchMotion(),
                extentRatio: 0.25,
                children: [
                  SlidableAction(
                    onPressed: (_) async {
                      await _removeItem(favorite.productId);
                    },
                    backgroundColor: colorScheme.error,
                    foregroundColor: colorScheme.onError,
                    icon: SnaplookIcons.trashBin,
                    label: 'Delete',
                  ),
                ],
              ),
              child: _FavoriteCard(
                favorite: favorite,
                spacing: spacing,
              ),
            ),
          );
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
                  color: const Color(0xFFf2003c),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Text(
                  'Browse Items',
                  style: textTheme.labelLarge?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
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

  Widget _buildHistoryTab(bool isLoading, bool hasError,
      List<Map<String, dynamic>> searches, dynamic spacing, dynamic radius) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
          strokeWidth: 2,
        ),
      );
    }

    if (hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Error loading history',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.invalidate(historyProvider);
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

    if (searches.isEmpty) {
      return _buildHistoryEmptyState(context, spacing);
    }

    return EasyRefresh(
      onRefresh: () async {
        HapticFeedback.selectionClick();
        ref.invalidate(historyProvider);
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
        controller: _historyScrollController,
        padding: EdgeInsets.fromLTRB(
          spacing.m,
          spacing.m,
          spacing.m,
          spacing.m,
        ),
        itemCount: searches.length,
        itemBuilder: (context, index) {
          final search = searches[index];
          return _HistoryCard(
            search: search,
            spacing: spacing,
            radius: radius,
          );
        },
      ),
    );
  }

  Widget _buildHistoryEmptyState(BuildContext context, dynamic spacing) {
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
              child: Icon(
                Icons.history,
                size: 32,
                color: colorScheme.onSurface,
              ),
            ),
            SizedBox(height: spacing.l),
            Text(
              'Upload an image to analyze and discover similar fashion items.',
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
                // Switch to home tab
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
                child: Text(
                  'Upload Image',
                  style: textTheme.labelLarge?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
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

  const _FavoriteCard({
    required this.favorite,
    required this.spacing,
  });

  Future<void> _openProductLink(BuildContext context, String productUrl) async {
    final uri = Uri.parse(productUrl);

    // Prefer in-app browser (keeps the user inside Snaplook with a SafariViewController/Custom Tab)
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

    // Last resort: external (but warn the user)
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not open product link',
              style: context.snackTextStyle(
                merge: const TextStyle(fontFamily: 'PlusJakartaSans'),
              ),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

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

  void _rescanFavorite(BuildContext context) {
    final imageUrl = favorite.imageUrl.trim();
    if (imageUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No image available for this item.',
            style: context.snackTextStyle(
              merge: const TextStyle(fontFamily: 'PlusJakartaSans'),
            ),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    HapticFeedback.selectionClick();

    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (context) => DetectionPage(
          imageUrl: imageUrl,
          searchType: 'favorite_rescan',
          sourceUrl: favorite.purchaseUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final radius = context.radius;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final productUrl = _resolveProductUrl();

        if (productUrl.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Product link unavailable',
                style: context.snackTextStyle(
                  merge: const TextStyle(fontFamily: 'PlusJakartaSans'),
                ),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
          return;
        }

        await _openProductLink(context, productUrl);
      },
      child: Container(
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

            // Product Details + Actions
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          favorite.brand,
                          style: textTheme.titleMedium?.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _ActionIcon(
                        icon: Icons.search_rounded,
                        backgroundColor: colorScheme.secondary,
                        iconColor: colorScheme.onSecondary,
                        onTap: () => _rescanFavorite(context),
                      ),
                      const SizedBox(width: 8),
                      _ActionIcon(
                        icon: Icons.more_horiz,
                        backgroundColor: Colors.transparent,
                        iconColor: colorScheme.secondary,
                        borderColor: colorScheme.secondary,
                        onTap: () => _showShareMenu(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
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

class _HistoryCard extends ConsumerWidget {
  final Map<String, dynamic> search;
  final dynamic spacing;
  final dynamic radius;
  static const Set<String> _snaplookOriginTypes = {
    'camera',
    'photos',
    'home',
  };

  const _HistoryCard({
    required this.search,
    required this.spacing,
    required this.radius,
  });

  Future<void> _shareSearch(BuildContext context) async {
    HapticFeedback.mediumImpact();

    final box = context.findRenderObject() as RenderBox?;
    final origin = (box != null && box.hasSize)
        ? box.localToGlobal(Offset.zero) & box.size
        : const Rect.fromLTWH(0, 0, 1, 1);

    final searchId = search['id'] as String?;
    if (searchId == null) {
      _showToast(context, 'Unable to share this search.');
      return;
    }

    final supabaseService = SupabaseService();
    final fullSearch = await supabaseService.getSearchById(searchId);
    if (fullSearch == null) {
      _showToast(context, 'Unable to load search details to share.');
      return;
    }

    final payload = _buildSharePayload(fullSearch);
    final cloudinaryUrl =
        (fullSearch['cloudinary_url'] as String?)?.trim() ?? '';
    XFile? shareImage;
    if (cloudinaryUrl.isNotEmpty) {
      shareImage = await _downloadAndSquare(cloudinaryUrl);
    }

    if (shareImage != null) {
      final handled = await NativeShareHelper.shareImageFirst(
        file: shareImage,
        text: payload.message,
        subject: payload.subject,
        origin: origin,
      );
      if (!handled) {
        await Share.shareXFiles(
          [shareImage],
          text: payload.message,
          subject: payload.subject,
          sharePositionOrigin: origin,
        );
      }
    } else {
      await Share.share(
        payload.message,
        subject: payload.subject,
        sharePositionOrigin: origin,
      );
    }
  }

  SharePayload _buildSharePayload(Map<String, dynamic> searchData) {
    final rawResults = searchData['search_results'];
    List<dynamic> results;
    if (rawResults is List) {
      results = rawResults;
    } else if (rawResults is String) {
      try {
        final decoded = jsonDecode(rawResults);
        results = decoded is List ? decoded : <dynamic>[];
      } catch (_) {
        results = <dynamic>[];
      }
    } else {
      results = <dynamic>[];
    }

    final topResults = results.take(5).toList();
    final totalResults = (searchData['total_results'] as num?)?.toInt() ?? 0;

    final buffer = StringBuffer();
    buffer.writeln('I analyzed this look on Snaplook and found $totalResults matches!\n');

    if (topResults.isNotEmpty) {
      buffer.writeln('Top finds:');
      for (var i = 0; i < topResults.length; i++) {
        final r = topResults[i] as Map<String, dynamic>;
        final name = (r['product_name'] as String?)?.trim();
        final brand = (r['brand'] as String?)?.trim();
        final link = (r['purchase_url'] as String?)?.trim() ?? '';

        final safeName = (name != null && name.isNotEmpty) ? name : 'Item';
        final safeBrand = (brand != null && brand.isNotEmpty) ? brand : 'Unknown brand';
        final safeLink = link.isNotEmpty ? link : 'URL not available';

        buffer.writeln('${i + 1}. $safeBrand - $safeName - $safeLink');
      }
      buffer.writeln();
    }

    buffer.write('Get Snaplook to find your fashion matches: https://snaplook.app');

    return SharePayload(
      subject: 'Snaplook Fashion Matches',
      message: buffer.toString(),
    );
  }

  Future<XFile?> _downloadAndSquare(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) return null;

      final decoded = img.decodeImage(response.bodyBytes);
      if (decoded == null) return null;

      final maxDim =
          decoded.width > decoded.height ? decoded.width : decoded.height;
      const cap = 1200;
      final targetSize = maxDim > cap ? cap : maxDim;
      final minDim =
          decoded.width < decoded.height ? decoded.width : decoded.height;
      final scale = targetSize / minDim;

      final resized = img.copyResize(
        decoded,
        width: (decoded.width * scale).round(),
        height: (decoded.height * scale).round(),
      );

      final cropX =
          ((resized.width - targetSize) / 2).round().clamp(0, resized.width - targetSize);
      final cropY = ((resized.height - targetSize) / 2)
          .round()
          .clamp(0, resized.height - targetSize);

      final square = img.copyCrop(
        resized,
        x: cropX,
        y: cropY,
        width: targetSize,
        height: targetSize,
      );

      final jpg = img.encodeJpg(square, quality: 90);
      final tempPath = '${Directory.systemTemp.path}/snaplook_fashion_search.jpg';
      await File(tempPath).writeAsBytes(jpg, flush: true);
      return XFile(
        tempPath,
        mimeType: 'image/jpeg',
        name: 'snaplook_fashion_search.jpg',
      );
    } catch (e) {
      debugPrint('Error preparing share image: $e');
      return null;
    }
  }

  void _showToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: context.snackTextStyle(
            merge: const TextStyle(fontFamily: 'PlusJakartaSans'),
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<bool> _deleteSearch(BuildContext context, WidgetRef ref) async {
    final searchId = search['id'] as String?;
    if (searchId == null) {
      _showToast(context, 'Unable to delete this search.');
      return false;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text(
          'Delete Search',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Are you sure you want to remove this search from your history?',
          style: TextStyle(fontFamily: 'PlusJakartaSans'),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              textStyle: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.secondary,
              textStyle: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;

    HapticFeedback.mediumImpact();

    final supabaseService = SupabaseService();
    final success = await supabaseService.deleteSearch(searchId);

    if (success) {
      ref.invalidate(historyProvider);
      if (context.mounted) {
        _showToast(context, 'Search deleted from history');
      }
      return true;
    } else {
      if (context.mounted) {
        _showToast(context, 'Failed to delete search');
      }
      return false;
    }
  }

  Future<void> _rescanSearch(BuildContext context) async {
    final cloudinaryUrl = search['cloudinary_url'] as String?;
    if (cloudinaryUrl == null || cloudinaryUrl.isEmpty) {
      _showToast(context, 'No image available for re-search.');
      return;
    }

    HapticFeedback.selectionClick();

    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (context) => DetectionPage(
          imageUrl: cloudinaryUrl,
          searchType: 'history_rescan',
          sourceUrl: search['source_url'] as String?,
        ),
      ),
    );
  }

  String _getSourceLabel() {
    final rawType = (search['search_type'] as String?)?.trim();
    final type = rawType?.toLowerCase();
    final sourceUrl = (search['source_url'] as String?)?.toLowerCase() ?? '';

    switch (type) {
      case 'instagram':
        return 'Instagram';
      case 'tiktok':
        return 'TikTok';
      case 'pinterest':
        return 'Pinterest';
      case 'twitter':
        return 'Twitter';
      case 'facebook':
        return 'Facebook';
      case 'youtube':
        final isShorts = sourceUrl.contains('youtube.com/shorts') ||
            sourceUrl.contains('youtu.be/shorts');
        return isShorts ? 'YouTube Shorts' : 'YouTube';
      case 'chrome':
        return 'Chrome';
      case 'firefox':
        return 'Firefox';
      case 'safari':
        return 'Safari';
      case 'web':
      case 'browser':
        return 'Web';
      case 'share':
      case 'share_extension':
      case 'shareextension':
        return 'Snaplook';
    }

    if (type == null || _snaplookOriginTypes.contains(type)) {
      return 'Snaplook';
    }

    if (rawType != null && rawType.isNotEmpty) {
      return rawType
          .split(RegExp(r'[_-]+'))
          .map((word) =>
              word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1)}')
          .join(' ');
    }

    return 'Snaplook';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final cloudinaryUrl = search['cloudinary_url'] as String?;
    final totalResults = (search['total_results'] as num?)?.toInt() ?? 0;
    final createdAt = search['created_at'] as String?;
    final sourceUsername = search['source_username'] as String?;
    final isSaved = search['is_saved'] as bool? ?? false;

    DateTime? createdDate;
    if (createdAt != null) {
      try {
        createdDate = DateTime.parse(createdAt);
      } catch (e) {
        print('Error parsing date: $e');
      }
    }

    final trimmedUsername = sourceUsername?.trim();
    final hasUsername = trimmedUsername != null && trimmedUsername.isNotEmpty;
    final createdLabel = createdDate != null ? timeago.format(createdDate) : null;
    final hasResults = totalResults > 0;

    return Dismissible(
      key: ValueKey(search['id'] ?? search['created_at'] ?? cloudinaryUrl ?? UniqueKey()),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _deleteSearch(context, ref),
      background: Container(
        margin: EdgeInsets.only(bottom: spacing.m),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: colorScheme.error.withOpacity(0.12),
          borderRadius: BorderRadius.circular(radius.medium),
        ),
        alignment: Alignment.centerRight,
        child: Icon(
          SnaplookIcons.trashBin,
          color: colorScheme.error,
          size: 20,
        ),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          if (!hasResults) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'No results to show for this search.',
                  style: context.snackTextStyle(
                    merge: const TextStyle(fontFamily: 'PlusJakartaSans'),
                  ),
                ),
                duration: const Duration(seconds: 2),
              ),
            );
            return;
          }

          final searchId = search['id'] as String?;
          if (searchId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Unable to load search results',
                  style: context.snackTextStyle(
                    merge: const TextStyle(fontFamily: 'PlusJakartaSans'),
                  ),
                ),
                duration: const Duration(seconds: 2),
              ),
            );
            return;
          }

          // Navigate to detection page with search results
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              builder: (context) => DetectionPage(searchId: searchId),
            ),
          );
        },
        child: Container(
          margin: EdgeInsets.only(bottom: spacing.m),
          color: Colors.transparent,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(radius.medium),
                child: cloudinaryUrl != null
                    ? CachedNetworkImage(
                        imageUrl: cloudinaryUrl,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: colorScheme.surfaceVariant,
                          width: 100,
                          height: 100,
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: colorScheme.surfaceVariant,
                          width: 100,
                          height: 100,
                          child: Icon(
                            Icons.image,
                            color: colorScheme.onSurfaceVariant,
                            size: 24,
                          ),
                        ),
                      )
                    : Container(
                        width: 100,
                        height: 100,
                        color: colorScheme.surfaceVariant,
                        child: Icon(
                          Icons.image,
                          color: colorScheme.onSurfaceVariant,
                          size: 24,
                        ),
                      ),
              ),
              SizedBox(width: spacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            _getSourceLabel(),
                            style: textTheme.titleMedium?.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSaved) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.bookmark,
                            size: 16,
                            color: colorScheme.secondary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (hasUsername) ...[
                      Text(
                        '@$trimmedUsername',
                        style: textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      totalResults == 1
                          ? '1 product found'
                          : '$totalResults products found',
                      style: textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (createdLabel != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        createdLabel,
                        style: textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          color:
                              colorScheme.onSurfaceVariant.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: spacing.sm),
              SizedBox(
                height: 100,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => _rescanSearch(context),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: colorScheme.secondary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.search_rounded,
                          color: colorScheme.onSecondary,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _shareSearch(context),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          border: Border.all(
                            color: colorScheme.secondary,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.share_outlined,
                          color: colorScheme.secondary,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final Color? borderColor;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: borderColor != null
              ? Border.all(color: borderColor!, width: 1.3)
              : null,
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: 16,
        ),
      ),
    );
  }
}
