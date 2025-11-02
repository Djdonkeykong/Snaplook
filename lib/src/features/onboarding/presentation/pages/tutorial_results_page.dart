import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_confetti/flutter_confetti.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import '../../../detection/domain/models/detection_result.dart';
import '../../domain/services/tutorial_service.dart';
import 'trial_intro_page.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../favorites/presentation/widgets/favorite_button.dart';

class TutorialResultsPage extends ConsumerStatefulWidget {
  final String? imagePath;
  final String scenario;

  const TutorialResultsPage({
    super.key,
    this.imagePath,
    this.scenario = 'Instagram',
  });

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
        HapticFeedback.mediumImpact();
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
      final results = await _tutorialService.getTutorialProducts(scenario: widget.scenario);
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
        automaticallyImplyLeading: false,
        actions: [
          // Finish Button at top right matching real results page style
          _TopIconButton(
            icon: Icons.check,
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => const TrialIntroPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              widget.imagePath ?? 'assets/images/tutorial_analysis_image_2.jpg',
              fit: BoxFit.cover,
            ),
          ),

          // Sliding Up Panel matching real results page
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
                                '${_getFilteredResults().length} results',
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
                    // Category filter chips
                    SizedBox(
                      height: 50,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(horizontal: spacing.m),
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          final isSelected = selectedCategory == category;
                          return Container(
                            margin: EdgeInsets.only(
                              right: index < categories.length - 1
                                  ? spacing.sm
                                  : 0,
                            ),
                            child: FilterChip(
                              label: Text(
                                category,
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: isSelected ? Colors.white : Colors.black,
                                ),
                              ),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  selectedCategory = category;
                                });
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
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFFf2003c),
                              ),
                            )
                          : ListView.separated(
                              controller: scrollController,
                              physics: const ClampingScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(
                                spacing.m,
                                0,
                                spacing.m,
                                safeAreaBottom + spacing.l,
                              ),
                              itemCount: _getFilteredResults().length,
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
              Text(
                '${widget.scenario} insights unlocked.',
                style: const TextStyle(
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

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: spacing.m,
        ),
        color: Theme.of(context).colorScheme.surface,
        child: Row(
          children: [
            // Image with favorite button
            Stack(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius.small),
                    color: Colors.grey[200],
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
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.black, size: 18),
      ),
    );
  }
}