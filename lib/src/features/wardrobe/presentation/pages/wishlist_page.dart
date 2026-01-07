import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import 'dart:typed_data';
import 'dart:ui' as ui;
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
import '../../../../shared/widgets/snaplook_circular_icon_button.dart';
import '../../../detection/presentation/pages/detection_page.dart';
import '../../../detection/presentation/pages/share_payload.dart';

Future<bool?> _showWishlistActionDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
}) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final spacing = context.spacing;
  final outlineColor = colorScheme.outline;

  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(0.45),
    builder: (dialogContext) {
      return Dialog(
        clipBehavior: Clip.antiAlias,
        backgroundColor: colorScheme.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(spacing.l, spacing.l, spacing.l, spacing.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  SnaplookCircularIconButton(
                    icon: Icons.close,
                    size: 40,
                    iconSize: 18,
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    semanticLabel: 'Close',
                  ),
                ],
              ),
              SizedBox(height: spacing.sm),
              Text(
                message,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: spacing.l),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          side: BorderSide(color: outlineColor, width: 1.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          foregroundColor: colorScheme.onSurface,
                          textStyle: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: Text(cancelLabel, textAlign: TextAlign.center),
                      ),
                    ),
                  ),
                  SizedBox(width: spacing.sm),
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          minimumSize: const Size.fromHeight(56),
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          textStyle: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: Text(confirmLabel, textAlign: TextAlign.center),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

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
    final confirmed = await _showWishlistActionDialog(
      context,
      title: 'Delete favorite',
      message: 'Are you sure you want to remove this item from your favorites?',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
    );

    if (confirmed != true) return false;

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
        padding: EdgeInsets.only(
          top: spacing.m,
          bottom: spacing.m,
        ),
        itemCount: favorites.length,
        itemBuilder: (context, index) {
          final favorite = favorites[index];
          return Padding(
            padding: EdgeInsets.only(bottom: spacing.m),
            child: Slidable(
              key: ValueKey(favorite.id),
              endActionPane: ActionPane(
                motion: const ScrollMotion(),
                extentRatio: 0.25,
                children: [
                  CustomSlidableAction(
                    onPressed: (_) async {
                      await _removeItem(favorite.productId);
                    },
                    backgroundColor: AppColors.secondary,
                    autoClose: false, // keep open while confirm dialog shows
                    padding: EdgeInsets.zero,
                    child: SizedBox(
                      width: 86,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                           Icon(
                             SnaplookIcons.trashBin,
                             color: Colors.white,
                             size: 18,
                           ),
                          const SizedBox(height: 4),
                          Text(
                            'Delete',
                            softWrap: false,
                            overflow: TextOverflow.visible,
                             style: TextStyle(
                               fontFamily: 'PlusJakartaSans',
                               fontWeight: FontWeight.w600,
                               fontSize: 13,
                               color: Colors.white,
                             ),
                          ),
                        ],
                      ),
                    ),
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
        padding: EdgeInsets.only(
          top: spacing.m,
          bottom: spacing.m,
        ),
        itemCount: searches.length,
        itemBuilder: (context, index) {
          final search = searches[index];
          return Padding(
            padding: EdgeInsets.only(bottom: spacing.m),
            child: _HistoryCard(
              search: search,
              spacing: spacing,
              radius: radius,
            ),
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

  Future<void> _shareProductUrl(BuildContext context) async {
    HapticFeedback.mediumImpact();

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

    final shareOrigin = _shareOriginForContext(context);
    await Share.share(
      productUrl,
      subject: favorite.productName.isNotEmpty ? favorite.productName : null,
      sharePositionOrigin: shareOrigin,
    );
  }

  void _showShareMenu(BuildContext context) {
    final productBrand = favorite.brand;
    final productTitle = favorite.productName;
    final productUrl = _resolveProductUrl();

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
        width: double.infinity,
        color: Colors.transparent,
        padding: EdgeInsets.symmetric(horizontal: spacing.m, vertical: spacing.s * 0.75),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Square Product Image
            ClipRRect(
              borderRadius: BorderRadius.circular(radius.medium),
              child: SizedBox(
                width: 88,
                height: 88,
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              favorite.brand,
                              style: textTheme.titleMedium?.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                                fontFamily: 'PlusJakartaSans',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              favorite.productName,
                              style: textTheme.bodyMedium?.copyWith(
                                fontSize: 14,
                                color: colorScheme.onSurfaceVariant,
                                fontFamily: 'PlusJakartaSans',
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _ActionIcon(
                            icon: Icons.share_outlined,
                            backgroundColor: Colors.black,
                            iconColor: Colors.white,
                            borderColor: null,
                            iconOffset: const Offset(-1, 0),
                            onTap: () => _shareProductUrl(context),
                          ),
                          const SizedBox(height: 8),
                          _ActionIcon(
                            icon: Icons.more_horiz,
                            backgroundColor: Colors.transparent,
                            iconColor: colorScheme.secondary,
                            borderColor: colorScheme.secondary,
                            onTap: () => _showShareMenu(context),
                          ),
                        ],
                      ),
                    ],
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
  static const Size _shareCardSize = Size(1080, 1350);
  static const double _shareCardPixelRatio = 2.0;

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
    final shareItems = _buildShareItems(fullSearch);
    final cloudinaryUrl =
        (fullSearch['cloudinary_url'] as String?)?.trim() ?? '';
    XFile? shareImage;
    if (cloudinaryUrl.isNotEmpty) {
      shareImage = await _downloadAndSquare(cloudinaryUrl);
    }

    final ImageProvider<Object>? heroProvider;
    if (shareImage != null) {
      heroProvider = FileImage(File(shareImage.path));
    } else if (cloudinaryUrl.isNotEmpty) {
      heroProvider = CachedNetworkImageProvider(cloudinaryUrl);
    } else {
      heroProvider = null;
    }
    final shareCard = await _buildShareCardFile(
      context,
      heroImage: heroProvider,
      shareItems: shareItems,
    );

    final primaryFile = shareCard ?? shareImage;

    if (primaryFile != null) {
      final handled = await NativeShareHelper.shareImageFirst(
        file: primaryFile,
        text: payload.message,
        subject: payload.subject,
        origin: origin,
      );
      if (!handled) {
        await Share.shareXFiles(
          [primaryFile],
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
    final totalResults = (searchData['total_results'] as num?)?.toInt() ?? 0;
    final matchLabel =
        totalResults == 1 ? '1 match' : '$totalResults matches';
    final message = totalResults > 0
        ? 'Snaplook found $matchLabel for this look.'
        : 'Snaplook analyzed this look.';

    return SharePayload(
      subject: 'Snaplook Matches',
      message: message,
    );
  }

  List<_ShareCardItem> _buildShareItems(Map<String, dynamic> searchData) {
    final results = _extractSearchResults(searchData['search_results']);
    if (results.isEmpty) return const [];

    final items = <_ShareCardItem>[];
    for (final result in results.take(5)) {
      final item = _ShareCardItem.fromSearch(result);
      if (item != null) {
        items.add(item);
      }
    }
    return items;
  }

  List<Map<String, dynamic>> _extractSearchResults(dynamic rawResults) {
    dynamic decoded = rawResults;
    if (rawResults is String) {
      try {
        decoded = jsonDecode(rawResults);
      } catch (_) {
        return const [];
      }
    }

    if (decoded is List) {
      final results = <Map<String, dynamic>>[];
      for (final item in decoded) {
        if (item is Map) {
          results.add(Map<String, dynamic>.from(item));
        }
      }
      return results;
    }

    return const [];
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
          '${Directory.systemTemp.path}/snaplook_share_fashion_${DateTime.now().millisecondsSinceEpoch}.png';
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
                    child: _HistoryShareCard(
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

    final confirmed = await _showWishlistActionDialog(
      context,
      title: 'Delete search',
      message: 'Are you sure you want to remove this search from your history?',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
    );

    if (confirmed != true) return false;

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
    // Match favorite card height: 88px image + symmetric padding (spacing.s * 0.75 * 2)
    final double cardHeight = 88.0 + (spacing.s * 1.5);
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

    return Slidable(
      key: ValueKey(search['id'] ?? search['created_at'] ?? cloudinaryUrl ?? UniqueKey()),
      endActionPane: ActionPane(
        extentRatio: 0.25,
        motion: const ScrollMotion(),
        children: [
          CustomSlidableAction(
            onPressed: (_) async {
              await _deleteSearch(context, ref);
            },
            backgroundColor: AppColors.secondary,
            autoClose: false, // keep open while confirm dialog shows
            padding: EdgeInsets.zero,
            child: SizedBox(
              width: 86,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    SnaplookIcons.trashBin,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Delete',
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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

          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              builder: (context) => DetectionPage(searchId: searchId),
            ),
          );
        },
        child: Container(
          height: cardHeight,
          color: Colors.transparent,
          padding: EdgeInsets.symmetric(horizontal: spacing.m, vertical: spacing.s * 0.75),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(radius.medium),
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: cloudinaryUrl != null
                      ? CachedNetworkImage(
                          imageUrl: cloudinaryUrl,
                          width: 88,
                          height: 88,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: colorScheme.surfaceVariant,
                            width: 88,
                            height: 88,
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: colorScheme.surfaceVariant,
                            width: 88,
                            height: 88,
                            child: Icon(
                              Icons.image,
                              color: colorScheme.onSurfaceVariant,
                              size: 24,
                            ),
                          ),
                        )
                      : Container(
                          width: 88,
                          height: 88,
                          color: colorScheme.surfaceVariant,
                          child: Icon(
                            Icons.image,
                            color: colorScheme.onSurfaceVariant,
                            size: 24,
                          ),
                        ),
                ),
              ),
              SizedBox(width: spacing.m),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getSourceLabel(),
                          style: textTheme.titleMedium?.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                            fontFamily: 'PlusJakartaSans',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        if (hasUsername) ...[
                          Text(
                            '@$trimmedUsername',
                            style: textTheme.bodyMedium?.copyWith(
                              fontSize: 14,
                              color: colorScheme.onSurfaceVariant,
                              fontFamily: 'PlusJakartaSans',
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
                            fontFamily: 'PlusJakartaSans',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (createdLabel != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            createdLabel,
                            style: textTheme.bodySmall?.copyWith(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                              fontFamily: 'PlusJakartaSans',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ActionIcon(
                          icon: Icons.search_rounded,
                          backgroundColor: colorScheme.secondary,
                          iconColor: colorScheme.onSecondary,
                          onTap: () => _rescanSearch(context),
                        ),
                        const SizedBox(height: 8),
                        _ActionIcon(
                          icon: Icons.share_outlined,
                          backgroundColor: Colors.transparent,
                          iconColor: colorScheme.secondary,
                          borderColor: colorScheme.secondary,
                          iconOffset: const Offset(-1, 0), // nudge icon only 1px left
                          onTap: () => _shareSearch(context),
                        ),
                      ],
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
  final Offset iconOffset;

  const _ActionIcon({
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    this.borderColor,
    this.iconOffset = Offset.zero,
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
        child: Transform.translate(
          offset: iconOffset,
          child: Icon(
            icon,
            color: iconColor,
            size: 16,
          ),
        ),
      ),
    );
  }
}

class _HistoryShareCard extends StatelessWidget {
  final ImageProvider<Object>? heroImage;
  final List<_ShareCardItem> shareItems;

  const _HistoryShareCard({
    required this.heroImage,
    required this.shareItems,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final scale = width / 1080;
        double s(double value) => value * scale;

        final heroSize = s(520);
        final heroRadius = s(40);
        final cardWidth = s(980);
        final cardRadius = s(32);
        final rowImageSize = s(108);
        final rowVerticalPadding = s(20);
        final rowHeight = rowImageSize + (rowVerticalPadding * 2);
        final listHeight = rowHeight * 4.2;

        return ClipRRect(
          borderRadius: BorderRadius.circular(s(52)),
          child: Container(
            color: Colors.white,
            child: Column(
              children: [
                SizedBox(height: s(52)),
                Image.asset(
                  'assets/images/logo.png',
                  height: s(52),
                  fit: BoxFit.contain,
                ),
                SizedBox(height: s(36)),
                Center(
                  child: SizedBox(
                    width: heroSize,
                    height: heroSize,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(heroRadius),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: s(28),
                                offset: Offset(0, s(14)),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(heroRadius),
                            child: heroImage != null
                                ? Image(
                                    image: heroImage!,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    color: const Color(0xFFEFEFEF),
                                    child: const Icon(
                                      Icons.image_rounded,
                                      color: Color(0xFFBDBDBD),
                                      size: 48,
                                    ),
                                  ),
                          ),
                        ),
                        Positioned(
                        left: s(-48),
                        top: s(24),
                          child: _ShareBadge(
                          size: s(120),
                            icon: Icons.favorite,
                            iconColor: AppColors.secondary,
                            backgroundColor: const Color(0xFFF0F0F0),
                            shadowOpacity: 0.18,
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: -36,
                          child: Center(
                            child: _TopMatchesTag(
                              height: s(74),
                              padding: EdgeInsets.symmetric(
                                horizontal: s(34),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: s(36)),
                if (shareItems.isNotEmpty)
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: SizedBox(
                        width: cardWidth,
                        height: listHeight,
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(cardRadius),
                              child: Container(
                                color: Colors.white,
                                child: ListView.separated(
                                  physics: const NeverScrollableScrollPhysics(),
                                  padding: EdgeInsets.zero,
                                  itemCount: shareItems.length,
                                  itemBuilder: (context, index) {
                                    return _ShareResultRow(
                                      item: shareItems[index],
                                      imageSize: rowImageSize,
                                    padding: EdgeInsets.symmetric(
                                        horizontal: s(30),
                                        vertical: rowVerticalPadding,
                                      ),
                                    );
                                  },
                                  separatorBuilder: (context, index) => Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: const Color(0xFFEDEDED),
                                    indent: s(30),
                                    endIndent: s(30),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: IgnorePointer(
                                child: Container(
                                  height: s(110),
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0x00FFFFFF),
                                        Color(0xB3FFFFFF),
                                        Color(0xFFFFFFFF),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ShareResultRow extends StatelessWidget {
  final _ShareCardItem item;
  final double imageSize;
  final EdgeInsets padding;

  const _ShareResultRow({
    required this.item,
    required this.imageSize,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final textWidth = imageSize * 3.6;
    return Padding(
      padding: padding,
      child: Align(
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(imageSize * 0.2),
              child: SizedBox(
                width: imageSize,
                height: imageSize,
                child: item.imageProvider != null
                    ? Image(
                        image: item.imageProvider!,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: const Color(0xFFF2F2F2),
                        child: const Icon(
                          Icons.image_rounded,
                          color: Color(0xFFBDBDBD),
                          size: 28,
                        ),
                      ),
              ),
            ),
            SizedBox(width: imageSize * 0.18),
            SizedBox(
              width: textWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.brand.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.w700,
                      fontSize: imageSize * 0.24,
                      color: const Color(0xFF111111),
                    ),
                  ),
                  SizedBox(height: imageSize * 0.08),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.w500,
                      fontSize: imageSize * 0.2,
                      color: const Color(0xFF343434),
                    ),
                  ),
                  SizedBox(height: imageSize * 0.12),
                  Text(
                    'See store',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.w700,
                      fontSize: imageSize * 0.23,
                      color: AppColors.secondary,
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

class _ShareBadge extends StatelessWidget {
  final double size;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final double shadowOpacity;

  const _ShareBadge({
    required this.size,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.shadowOpacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(shadowOpacity),
            blurRadius: size * 0.25,
            offset: Offset(0, size * 0.12),
          ),
        ],
      ),
      child: Icon(
        icon,
        size: size * 0.44,
        color: iconColor,
      ),
    );
  }
}

class _TopMatchesTag extends StatelessWidget {
  final double height;
  final EdgeInsets padding;

  const _TopMatchesTag({
    required this.height,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(height * 0.35),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: height * 0.5,
            offset: Offset(0, height * 0.25),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'TOP MATCHES',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: height * 0.38,
              fontWeight: FontWeight.w800,
              color: Colors.black,
              letterSpacing: 0.8,
            ),
          ),
          SizedBox(width: height * 0.22),
          Text(
            '🔥',
            style: TextStyle(fontSize: height * 0.42),
          ),
        ],
      ),
    );
  }
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

  static _ShareCardItem? fromSearch(Map<String, dynamic> data) {
    final brand =
        (data['brand'] as String?)?.trim().isNotEmpty == true
            ? (data['brand'] as String).trim()
            : 'Brand';
    final title =
        (data['product_name'] as String?)?.trim().isNotEmpty == true
            ? (data['product_name'] as String).trim()
            : 'Item';
    final priceText = _formatSharePrice(data);
    final imageUrl = (data['image_url'] as String?)?.trim();
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

String? _formatSharePrice(Map<String, dynamic> data) {
  String? currency = (data['currency'] as String?)?.toUpperCase();
  String? display;
  final priceData = data['price'];

  if (priceData is Map<String, dynamic>) {
    display = (priceData['display'] as String?) ??
        (priceData['text'] as String?) ??
        (priceData['raw'] as String?) ??
        (priceData['formatted'] as String?);
    currency ??= (priceData['currency'] as String?)?.toUpperCase();
    final extracted = (priceData['extracted_value'] as num?)?.toDouble();
    if ((display == null || display.isEmpty) && extracted != null) {
      display = _formatCurrency(extracted, currency);
    }
  } else if (priceData is num) {
    display = _formatCurrency(priceData.toDouble(), currency);
  } else if (priceData is String) {
    display = priceData.trim();
  }

  display ??= (data['price_display'] as String?) ??
      (data['price_text'] as String?) ??
      (data['price_raw'] as String?) ??
      (data['price_formatted'] as String?);

  return display != null && display.trim().isNotEmpty ? display.trim() : null;
}

String _formatCurrency(double value, String? currency) {
  final formatted = value.toStringAsFixed(2);
  if (currency == null || currency.isEmpty || currency == 'USD') {
    return '\$$formatted';
  }
  return '$currency $formatted';
}
