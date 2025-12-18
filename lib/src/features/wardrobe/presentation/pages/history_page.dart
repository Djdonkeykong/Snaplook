import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:snaplook/src/shared/utils/native_share_helper.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/snaplook_icons.dart';
import '../../../../shared/services/supabase_service.dart';
import '../../../../shared/widgets/snaplook_back_button.dart';
import '../../../../shared/widgets/snaplook_circular_icon_button.dart';
import '../../../../../shared/navigation/main_navigation.dart'
    show selectedIndexProvider;
import 'package:timeago/timeago.dart' as timeago;
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
        leadingWidth: 56,
        leading: const SnaplookBackButton(),
        centerTitle: true,
        title: Text(
          'Search History',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: 'PlusJakartaSans',
            color: colorScheme.onSurface,
            letterSpacing: -0.3,
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
          loading: () => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
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
                // Switch to home tab like empty favorites CTA
                ref.read(selectedIndexProvider.notifier).state = 0;
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
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

  bool _isZeroishPrice(String price) {
    final trimmed = price.trim();
    if (trimmed.isEmpty) return true;
    // Common zero patterns
    const zeroTokens = {'0', '0.0', '0.00', '\$0', '\$0.0', '\$0.00'};
    if (zeroTokens.contains(trimmed.toLowerCase())) return true;
    // If it parses to 0, treat as zero
    final cleaned = trimmed.replaceAll(RegExp(r'[^0-9\\.-]'), '');
    if (cleaned.isEmpty) return false;
    final value = double.tryParse(cleaned);
    return value != null && value == 0.0;
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

    return Slidable(
      key: ValueKey(search['id'] ?? search['created_at'] ?? cloudinaryUrl ?? UniqueKey()),
      endActionPane: ActionPane(
        extentRatio: 0.45,
        motion: const StretchMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => _rescanSearch(context),
            backgroundColor: AppColors.secondary,
            foregroundColor: Colors.white,
            icon: Icons.search_rounded,
            label: 'Search',
          ),
          SlidableAction(
            onPressed: (_) async {
              await _deleteSearch(context, ref);
            },
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
            icon: SnaplookIcons.trashBin,
            label: 'Delete',
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
