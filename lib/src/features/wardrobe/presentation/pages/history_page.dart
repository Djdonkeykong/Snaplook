import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../shared/services/supabase_service.dart';
import 'package:timeago/timeago.dart' as timeago;

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

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final radius = context.radius;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final historyAsync = ref.watch(historyProvider);

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: colorScheme.onSurface,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Search History',
          style: textTheme.headlineMedium?.copyWith(
            fontSize: 24,
            letterSpacing: -0.5,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
      ),
      body: SafeArea(
        child: historyAsync.when(
          data: (searches) {
            if (searches.isEmpty) {
              return _buildEmptyState(context, spacing);
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
                controller: _scrollController,
                padding: EdgeInsets.all(spacing.m),
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
          },
          loading: () => Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.secondary),
              strokeWidth: 2,
            ),
          ),
          error: (error, stack) => Center(
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
          ),
        ),
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
              child: Icon(
                Icons.history,
                size: 32,
                color: colorScheme.onSurface,
              ),
            ),
            SizedBox(height: spacing.l),
            Text(
              'No search history yet',
              style: textTheme.bodyMedium?.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
                height: 1.35,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: spacing.sm),
            Text(
              'Your analyzed images will appear here',
              style: textTheme.bodySmall?.copyWith(
                fontSize: 13,
                color: colorScheme.onSurface.withOpacity(0.7),
                height: 1.35,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Map<String, dynamic> search;
  final dynamic spacing;
  final dynamic radius;

  const _HistoryCard({
    required this.search,
    required this.spacing,
    required this.radius,
  });

  void _shareSearch(BuildContext context) {
    final sourceLabel = _getSourceLabel();
    final totalResults = (search['total_results'] as num?)?.toInt() ?? 0;
    final resultsLabel =
        totalResults == 1 ? '1 product' : '$totalResults products';
    final sourceUrl = (search['source_url'] as String?)?.trim() ?? '';

    final message = sourceUrl.isNotEmpty
        ? 'Check out this $sourceLabel Snaplook search – $resultsLabel found: $sourceUrl'
        : 'Check out this $sourceLabel Snaplook search – $resultsLabel found!';

    Share.share(
      message,
      subject: 'Snaplook $sourceLabel search',
    );
  }

  void _copyLink(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    final sourceUrl = (search['source_url'] as String?)?.trim() ?? '';

    if (sourceUrl.isEmpty) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'No link available for this search.',
            style: context.snackTextStyle(
              merge: const TextStyle(fontFamily: 'PlusJakartaSans'),
            ),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    Clipboard.setData(ClipboardData(text: sourceUrl));
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Search link copied to clipboard',
          style: context.snackTextStyle(
            merge: const TextStyle(fontFamily: 'PlusJakartaSans'),
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _getSourceLabel() {
    final searchType = search['search_type'] as String?;
    switch (searchType) {
      case 'instagram':
        return 'Instagram';
      case 'photos':
        return 'Photos';
      case 'camera':
        return 'Camera';
      case 'web':
        return 'Web';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // TODO: Navigate to results page with search data
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'View search details - Coming soon!',
              style: context.snackTextStyle(
                merge: const TextStyle(fontFamily: 'PlusJakartaSans'),
              ),
            ),
            duration: const Duration(seconds: 2),
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
              child: SizedBox(
                width: 100,
                height: 100,
                child: cloudinaryUrl != null
                    ? CachedNetworkImage(
                        imageUrl: cloudinaryUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: colorScheme.surfaceVariant,
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: colorScheme.surfaceVariant,
                          child: Icon(
                            Icons.image,
                            color: colorScheme.onSurfaceVariant,
                            size: 24,
                          ),
                        ),
                      )
                    : Container(
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
                        color: colorScheme.onSurfaceVariant.withOpacity(0.7),
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
                    onTap: () => _shareSearch(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: colorScheme.secondary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.share_outlined,
                        color: colorScheme.onSecondary,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _copyLink(context),
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
                          Icons.link,
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
