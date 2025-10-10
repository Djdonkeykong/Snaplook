import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_confetti/flutter_confetti.dart';
import '../../../detection/domain/models/detection_result.dart';
import '../../domain/services/tutorial_service.dart';
import 'trial_intro_page.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/custom_button.dart';

class TutorialResultsPage extends ConsumerStatefulWidget {
  const TutorialResultsPage({super.key});

  @override
  ConsumerState<TutorialResultsPage> createState() => _TutorialResultsPageState();
}

class _TutorialResultsPageState extends ConsumerState<TutorialResultsPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String selectedCategory = 'All';
  bool _showCongratulations = true;
  List<DetectionResult> tutorialResults = [];
  bool _isLoading = true;
  final TutorialService _tutorialService = TutorialService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // Load tutorial products from database
    _loadTutorialProducts();

    // Start confetti animation after a short delay and hide overlay after 4-5 seconds
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _launchConfetti();
      }
    });

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _showCongratulations = false;
        });
      }
    });
  }

  Future<void> _loadTutorialProducts() async {
    try {
      final results = await _tutorialService.getTutorialProducts(scenario: 'Instagram');
      if (mounted) {
        setState(() {
          tutorialResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading tutorial products: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ['All', 'Tops', 'Bottoms', 'Outerwear', 'Shoes', 'Headwear', 'Accessories'];
    final spacing = context.spacing;
    final radius = context.radius;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Image (tutorial image)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.6,
            child: Image.asset(
              'assets/images/tutorial_analysis_image_2.jpg',
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
                                '${tutorialResults.length} results',
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


                          // Category Tabs
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: categories.map((category) {
                                final isSelected = selectedCategory == category;
                                return Container(
                                  margin: EdgeInsets.only(right: spacing.sm),
                                  child: FilterChip(
                                    label: Text(
                                      category,
                                      style: TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? Colors.white : Colors.black,
                                      ),
                                    ),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      setState(() {
                                        selectedCategory = category;
                                      });
                                    },
                                    backgroundColor: Colors.grey[100],
                                    selectedColor: const Color(0xFFf2003c),
                                    checkmarkColor: Colors.white,
                                    side: BorderSide.none,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: spacing.sm),

                    // Results List
                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFFf2003c),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              padding: EdgeInsets.symmetric(
                                horizontal: spacing.m,
                              ),
                              itemCount: _getFilteredResults().length + 1, // +1 for finish button
                              itemBuilder: (context, index) {
                                if (index == _getFilteredResults().length) {
                                  // Finish button at the bottom
                                  return Padding(
                                    padding: EdgeInsets.all(spacing.l),
                                    child: CustomButton(
                                      onPressed: () {
                                        // Navigate back to main app or close tutorial
                                        Navigator.of(context).popUntil((route) => route.isFirst);
                                      },
                                      text: 'Finish',
                                    ),
                                  );
                                }

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

          // Finish Button positioned at top right
          Positioned(
            top: 50,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                    spreadRadius: 2,
                  ),
                ],
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const TrialIntroPage(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFf2003c),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Finish',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
              ),
            ),
          ),

          // Congratulations Overlay
          if (_showCongratulations)
            _buildCongratulationsOverlay(),
        ],
      ),
    );
  }

  List<DetectionResult> _getFilteredResults() {
    List<DetectionResult> filtered;
    if (selectedCategory == 'All') {
      filtered = List.from(tutorialResults);
    } else {
      filtered = tutorialResults
          .where((result) => result.category.toLowerCase().contains(selectedCategory.toLowerCase()))
          .toList();
    }

    // Sort by confidence score (highest first) to show best matches first
    filtered.sort((a, b) => b.confidence.compareTo(a.confidence));
    return filtered;
  }

  bool _hasHighQualityMatches() {
    return tutorialResults.any((result) => result.confidence >= 0.85);
  }

  String _getSearchInsightText() {
    final highQualityCount = tutorialResults.where((r) => r.confidence >= 0.85).length;
    final mediumQualityCount = tutorialResults.where((r) => r.confidence >= 0.75 && r.confidence < 0.85).length;

    if (highQualityCount > 0) {
      return 'Found ${highQualityCount} precise color matches using smart matching';
    } else if (mediumQualityCount > 0) {
      return 'Found ${mediumQualityCount} good matches using enhanced color database';
    } else {
      return 'Smart search analyzed ${tutorialResults.length} potential matches';
    }
  }

  void _launchConfetti() {
    // Launch multiple confetti bursts for better effect
    Confetti.launch(
      context,
      options: const ConfettiOptions(
        particleCount: 100,
        spread: 70,
        y: 0.6,
        colors: [
          Color(0xFFf2003c),
          Colors.yellow,
          Colors.blue,
          Colors.green,
          Colors.purple,
          Colors.orange,
        ],
      ),
    );

    // Additional bursts from left and right
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        Confetti.launch(
          context,
          options: const ConfettiOptions(
            particleCount: 50,
            spread: 55,
            angle: 60,
            x: 0.1,
            y: 0.7,
            colors: [
              Color(0xFFf2003c),
              Colors.yellow,
              Colors.blue,
              Colors.green,
            ],
          ),
        );
      }
    });

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        Confetti.launch(
          context,
          options: const ConfettiOptions(
            particleCount: 50,
            spread: 55,
            angle: 120,
            x: 0.9,
            y: 0.7,
            colors: [
              Color(0xFFf2003c),
              Colors.yellow,
              Colors.blue,
              Colors.green,
            ],
          ),
        );
      }
    });
  }

  Widget _buildCongratulationsOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.8),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Congratulations!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Instagram insights unlocked.',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white70,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
            ],
          ),
        ),
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