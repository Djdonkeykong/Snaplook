import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/theme/app_colors.dart';
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

class _HistoryCard extends StatelessWidget {
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
      await Share.shareXFiles(
        [shareImage],
        text: payload.message,
        subject: payload.subject,
        sharePositionOrigin: origin,
      );
    } else {
      await Share.share(
        payload.message,
        subject: payload.subject,
        sharePositionOrigin: origin,
      );
    }
  }

  SharePayload _buildSharePayload(Map<String, dynamic> searchData) {
    final results = (searchData['search_results'] as List<dynamic>?) ?? [];
    final topResults = results.take(5).toList();

    final buffer = StringBuffer();
    buffer.writeln('Snaplook matches for your photo:');
    buffer.writeln();

    if (topResults.isNotEmpty) {
      for (var i = 0; i < topResults.length; i++) {
        final r = topResults[i] as Map<String, dynamic>;
        final name = (r['product_name'] as String?)?.trim();
        final brand = (r['brand'] as String?)?.trim();
        final priceDisplay =
            (r['price_display'] as String?) ?? (r['price']?.toString() ?? '');
        final link = (r['purchase_url'] as String?)?.trim() ?? '';

        final safeName = (name != null && name.isNotEmpty) ? name : 'Item';
        final safeBrand = (brand != null && brand.isNotEmpty) ? brand : '';

        buffer.write('${i + 1}) ');
        if (safeBrand.isNotEmpty) buffer.write('$safeBrand - ');
        buffer.write(safeName);
        if (priceDisplay.isNotEmpty) buffer.write(' - $priceDisplay');
        if (link.isNotEmpty) buffer.write('\n$link');
        buffer.writeln();
      }
    } else {
      final total = (searchData['total_results'] as num?)?.toInt() ?? 0;
      final sourceUrl = (searchData['source_url'] as String?)?.trim() ?? '';
      if (total > 0) {
        buffer.writeln('$total products found with Snaplook.');
      } else {
        buffer.writeln('Check out what I found with Snaplook!');
      }
      if (sourceUrl.isNotEmpty) {
        buffer.writeln(sourceUrl);
      }
    }

    return SharePayload(
      subject: 'Snaplook matches for your photo',
      message: buffer.toString().trim(),
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
      final tempPath =
          '${Directory.systemTemp.path}/snaplook_history_share_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(tempPath).writeAsBytes(jpg, flush: true);
      return XFile(tempPath);
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
  void _copyLink(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    // Copy the rich share text (top matches + links) instead of a raw source URL.
    final payload = _buildSharePayload(search);
    Clipboard.setData(ClipboardData(text: payload.message));
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Share text copied to clipboard',
          style: context.snackTextStyle(
            merge: const TextStyle(fontFamily: 'PlusJakartaSans'),
          ),
        ),
        duration: const Duration(seconds: 2),
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
    final hasResults = totalResults > 0;

    return GestureDetector(
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
                        size: 14,
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
                        color: Colors.transparent,
                        border: Border.all(
                          color: colorScheme.secondary,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.link,
                        color: colorScheme.secondary,
                        size: 16,
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
