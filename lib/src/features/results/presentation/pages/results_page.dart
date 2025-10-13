import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../detection/domain/models/detection_result.dart';
import '../../../home/domain/providers/image_provider.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../favorites/presentation/widgets/favorite_button.dart';

class ResultsPage extends ConsumerStatefulWidget {
  final List<DetectionResult> results;
  final String? originalImageUrl; // For network images from scan button

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
  static const double _minSheetExtent = 0.35;
  static const double _initialSheetExtent = 0.45;
  static const double _midSheetExtent = 0.65;
  static const double _maxSheetExtent = 0.9;

  late TabController _tabController;
  String selectedCategory = 'All';
  late final DraggableScrollableController _sheetController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _sheetController = DraggableScrollableController();
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedImage = ref.watch(selectedImageProvider);
    final categories = [
      'All',
      'Tops',
      'Bottoms',
      'Outerwear',
      'Shoes',
      'Headwear',
      'Accessories'
    ];
    final spacing = context.spacing;
    final radius = context.radius;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.share,
              color: Colors.white,
            ),
            onPressed: _shareResults,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background Image (smaller, top portion)
          if (selectedImage != null || widget.originalImageUrl != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 0.6,
              child: widget.originalImageUrl != null
                  // Network image from scan button
                  ? Image.network(
                      widget.originalImageUrl!,
                      fit: BoxFit.cover,
                    )
                  // Local image from camera/gallery
                  : Image.file(
                      File(selectedImage!.path),
                      fit: BoxFit.cover,
                    ),
            ),

          // Results Bottom Sheet
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: _initialSheetExtent,
            minChildSize: _minSheetExtent,
            maxChildSize: _maxSheetExtent,
            expand: false,
            snap: true,
            snapSizes: const [
              _minSheetExtent,
              _initialSheetExtent,
              _midSheetExtent,
              _maxSheetExtent
            ],
            builder: (context, scrollController) {
              final filteredResults = _getFilteredResults();
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(radius.large),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(radius.large),
                  ),
                  child: Container(
                    color: Theme.of(context).colorScheme.surface,
                    child: Column(
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onVerticalDragUpdate: (details) {
                            if (!_sheetController.isAttached) return;
                            const minExtent = _minSheetExtent;
                            const maxExtent = _maxSheetExtent;
                            final height = MediaQuery.of(context).size.height;
                            final delta = details.delta.dy / height;
                            final newExtent = (_sheetController.size - delta)
                                .clamp(minExtent, maxExtent);
                            _sheetController.jumpTo(newExtent);
                          },
                          onVerticalDragEnd: (details) {
                            if (!_sheetController.isAttached) return;
                            const minExtent = _minSheetExtent;
                            const maxExtent = _maxSheetExtent;
                            final velocity =
                                details.velocity.pixelsPerSecond.dy;
                            const snapTargets = [
                              _minSheetExtent,
                              _midSheetExtent,
                              _maxSheetExtent,
                            ];

                            double targetExtent;
                            if (velocity.abs() > 600) {
                              targetExtent =
                                  velocity < 0 ? maxExtent : minExtent;
                            } else {
                              final current = _sheetController.size;
                              targetExtent = snapTargets.reduce(
                                (a, b) =>
                                    (a - current).abs() < (b - current).abs()
                                        ? a
                                        : b,
                              );
                            }

                            _sheetController.animateTo(
                              targetExtent.clamp(minExtent, maxExtent),
                              duration: AppConstants.mediumAnimation,
                              curve: Curves.easeOut,
                            );
                          },
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: spacing.l,
                              horizontal: spacing.m,
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 36,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[400],
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                SizedBox(height: spacing.m),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: const [
                                          Text(
                                            'Similar matches',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'PlusJakartaSans',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${widget.results.length} results',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.green[600],
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'PlusJakartaSans',
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: spacing.m),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: categories.map((category) {
                                      final isSelected =
                                          selectedCategory == category;
                                      return Container(
                                        margin:
                                            EdgeInsets.only(right: spacing.sm),
                                        child: FilterChip(
                                          label: Text(
                                            category,
                                            style: TextStyle(
                                              fontFamily: 'PlusJakartaSans',
                                              fontWeight: FontWeight.bold,
                                              color: isSelected
                                                  ? Colors.white
                                                  : Colors.black,
                                            ),
                                          ),
                                          selected: isSelected,
                                          onSelected: (selected) {
                                            setState(() {
                                              selectedCategory = category;
                                            });
                                          },
                                          backgroundColor: Colors.grey[100],
                                          selectedColor:
                                              const Color(0xFFf2003c),
                                          checkmarkColor: Colors.white,
                                          side: BorderSide.none,
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            controller: scrollController,
                            physics: const BouncingScrollPhysics(),
                            padding: EdgeInsets.symmetric(
                              horizontal: spacing.m,
                            ),
                            itemCount: filteredResults.length,
                            itemBuilder: (context, index) {
                              final result = filteredResults[index];
                              return _ProductCard(
                                result: result,
                                onTap: () => _openProduct(result),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<DetectionResult> _getFilteredResults() {
    List<DetectionResult> filtered;
    if (selectedCategory == 'All') {
      filtered = List.from(widget.results);
    } else {
      filtered = widget.results
          .where((result) => result.category
              .toLowerCase()
              .contains(selectedCategory.toLowerCase()))
          .toList();
    }

    // Sort by confidence score (highest first) to show best matches first
    filtered.sort((a, b) => b.confidence.compareTo(a.confidence));
    return filtered;
  }

  bool _hasHighQualityMatches() {
    return widget.results.any((result) => result.confidence >= 0.85);
  }

  String _getSearchInsightText() {
    final highQualityCount =
        widget.results.where((r) => r.confidence >= 0.85).length;
    final mediumQualityCount = widget.results
        .where((r) => r.confidence >= 0.75 && r.confidence < 0.85)
        .length;

    if (highQualityCount > 0) {
      return 'Found ${highQualityCount} precise color matches using smart matching';
    } else if (mediumQualityCount > 0) {
      return 'Found ${mediumQualityCount} good matches using enhanced color database';
    } else {
      return 'Smart search analyzed ${widget.results.length} potential matches';
    }
  }

  void _shareResults() {
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share functionality coming soon!'),
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

  const _ProductCard({
    required this.result,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final radius = context.radius;

    return Container(
      margin: EdgeInsets.only(bottom: spacing.m),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius.medium),
        child: Container(
          padding: EdgeInsets.only(
            top: spacing.m,
            bottom: spacing.m,
            left: 0,
            right: spacing.m,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(radius.medium),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Product Image with Favorite Button
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(radius.small),
                    child: CachedNetworkImage(
                      imageUrl: result.imageUrl,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[200],
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported),
                      ),
                    ),
                  ),
                  // Favorite button in top-right corner
                  Positioned(
                    top: 4,
                    right: 4,
                    child: FavoriteButton(
                      product: result,
                      size: 18,
                    ),
                  ),
                ],
              ),

              SizedBox(width: spacing.m),

              // Product Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.brand.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                        letterSpacing: 0.5,
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                    SizedBox(height: spacing.xs),
                    Text(
                      result.productName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'PlusJakartaSans',
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: spacing.sm),
                    Text(
                      '\$${result.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow indicator
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.6) return Colors.orange;
    return Colors.red;
  }
}
