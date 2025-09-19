import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../detection/domain/models/detection_result.dart';
import '../../../home/domain/providers/image_provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../../core/theme/theme_extensions.dart';

class ResultsPage extends ConsumerStatefulWidget {
  final List<DetectionResult> results;

  const ResultsPage({
    super.key,
    required this.results,
  });

  @override
  ConsumerState<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends ConsumerState<ResultsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String selectedCategory = 'All';

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
    final categories = ['All', 'Tops', 'Bottoms', 'Shoes', 'Headwear', 'Accessories'];
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
          if (selectedImage != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 0.6,
              child: Image.file(
                File(selectedImage.path),
                fit: BoxFit.cover,
              ),
            ),

          // Results Bottom Sheet
          DraggableScrollableSheet(
            initialChildSize: 0.5,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(radius.large),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Enhanced Drag Handle Area
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        vertical: spacing.l,
                        horizontal: spacing.m,
                      ),
                      child: Column(
                        children: [
                          // Larger, more visible handle
                          Container(
                            width: 50,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.grey[400],
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          SizedBox(height: spacing.m),

                          // Header with improved search indicator
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Smart matches',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Enhanced color matching active',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${widget.results.length} results',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (widget.results.isNotEmpty && _hasHighQualityMatches())
                                    Container(
                                      margin: const EdgeInsets.only(top: 2),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'High quality',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.green[700],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(height: spacing.m),

                          // Smart search insights
                          if (widget.results.isNotEmpty)
                            Container(
                              padding: EdgeInsets.all(spacing.sm),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(radius.small),
                                border: Border.all(color: Colors.blue[200]!, width: 1),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.auto_awesome,
                                    size: 16,
                                    color: Colors.blue[600],
                                  ),
                                  SizedBox(width: spacing.xs),
                                  Expanded(
                                    child: Text(
                                      _getSearchInsightText(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (widget.results.isNotEmpty)
                            SizedBox(height: spacing.m),

                          // Category Tabs (non-scrollable to avoid conflicts)
                          SizedBox(
                            height: 40,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const NeverScrollableScrollPhysics(), // Prevent scroll conflicts
                              itemCount: categories.length,
                              itemBuilder: (context, index) {
                                final category = categories[index];
                                final isSelected = selectedCategory == category;

                                return Container(
                                  margin: EdgeInsets.only(right: spacing.sm),
                                  child: FilterChip(
                                    label: Text(category),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      setState(() {
                                        selectedCategory = category;
                                      });
                                    },
                                    backgroundColor: Colors.grey[100],
                                    selectedColor: Theme.of(context).colorScheme.primary,
                                    labelStyle: TextStyle(
                                      color: isSelected ? Colors.white : Colors.black,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                    side: BorderSide.none,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: spacing.sm),

                    // Results List
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.defaultPadding,
                        ),
                        itemCount: _getFilteredResults().length,
                        itemBuilder: (context, index) {
                          final result = _getFilteredResults()[index];
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

  List<DetectionResult> _getFilteredResults() {
    List<DetectionResult> filtered;
    if (selectedCategory == 'All') {
      filtered = List.from(widget.results);
    } else {
      filtered = widget.results
          .where((result) => result.category.toLowerCase().contains(selectedCategory.toLowerCase()))
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
    final highQualityCount = widget.results.where((r) => r.confidence >= 0.85).length;
    final mediumQualityCount = widget.results.where((r) => r.confidence >= 0.75 && r.confidence < 0.85).length;

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
          padding: EdgeInsets.all(spacing.m),
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
              // Product Image
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

              SizedBox(width: spacing.sm),

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
                      ),
                    ),
                    SizedBox(height: spacing.xs),
                    Text(
                      result.productName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
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
                      ),
                    ),
                  ],
                ),
              ),

              // Enhanced Confidence & Match Info
              Column(
                children: [
                  Column(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: spacing.sm,
                          vertical: spacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: _getConfidenceColor(result.confidence).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(radius.medium),
                        ),
                        child: Text(
                          '${(result.confidence * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _getConfidenceColor(result.confidence),
                          ),
                        ),
                      ),
                      if (result.confidence >= 0.85)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Precise',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Colors.green[700],
                            ),
                          ),
                        )
                      else if (result.confidence >= 0.75)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Good',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: spacing.sm),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
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