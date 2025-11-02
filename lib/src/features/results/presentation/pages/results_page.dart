import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../detection/domain/models/detection_result.dart';
import '../../../home/domain/providers/image_provider.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../favorites/presentation/widgets/favorite_button.dart';
import '../../../detection/presentation/providers/detection_provider.dart';

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
    final notifier = ref.read(detectionProvider.notifier);

    final categories = notifier.availableCategories;
    final selectedCategory = detectionState.selectedCategory;
    final results = notifier.filteredResults;

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
        leading: _TopIconButton(
          icon: Icons.arrow_back,
          onPressed: () => Navigator.of(context).pop(),
        ),
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
                                  color: Colors.grey[600],
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
                    // Category filter chips - edge to edge with 16px content inset
                    SizedBox(
                      height: 50,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(horizontal: spacing.m),
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          final isSelected =
                              selectedCategory == category.toLowerCase();
                          return Container(
                            margin: EdgeInsets.only(
                              right: index < categories.length - 1
                                  ? spacing.sm
                                  : 0,
                            ),
                            child: FilterChip(
                              label: Text(
                                category[0].toUpperCase() +
                                    category.substring(1),
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: isSelected ? Colors.white : Colors.black,
                                ),
                              ),
                              selected: isSelected,
                              onSelected: (selected) {
                                notifier.setSelectedCategory(category);
                              },
                              backgroundColor: Colors.white,
                              selectedColor: const Color(0xFFf2003c),
                              showCheckmark: false,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                                side: BorderSide(
                                  color: isSelected
                                      ? const Color(0xFFf2003c)
                                      : const Color(0xFFD1D5DB),
                                  width: 1,
                                ),
                              ),
                              side: BorderSide.none,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          );
                        },
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

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: spacing.m,
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
                    child: FavoriteButton(
                      product: result,
                      size: 18,
                    ),
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
              color: Colors.grey[400],
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

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        padding: icon == Icons.share
            ? const EdgeInsets.fromLTRB(2, 8, 4, 8)
            : const EdgeInsets.all(8),
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.black, size: 18),
      ),
    );
  }
}
