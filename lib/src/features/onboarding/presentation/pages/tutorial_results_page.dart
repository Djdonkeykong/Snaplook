import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    with SingleTickerProviderStateMixin {
  static const double _minSheetExtent = 0.35;
  static const double _initialSheetExtent = 0.6;
  static const double _maxSheetExtent = 0.85;

  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  bool _isSheetVisible = false;
  double _currentSheetExtent = _initialSheetExtent;

  bool _showCongratulations = true;
  List<DetectionResult> tutorialResults = [];
  bool _isLoading = true;
  final TutorialService _tutorialService = TutorialService();

  @override
  void initState() {
    super.initState();

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

    // Show sheet after a short delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _isSheetVisible = true;
      });
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
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

          // Congratulations Overlay
          if (_showCongratulations)
            _buildCongratulationsOverlay(),

          // Dynamic overlay behind sheet (only when sheet is visible and congrats is done)
          if (_isSheetVisible && !_showCongratulations) ...[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {}, // Do nothing - can't dismiss in tutorial
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  color: Colors.black.withOpacity(_overlayOpacity),
                ),
              ),
            ),
            // Bottom sheet
            Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                height: MediaQuery.of(context).size.height,
                child: NotificationListener<DraggableScrollableNotification>(
                  onNotification: (notification) {
                    if (!mounted) return false;
                    final extent = notification.extent
                        .clamp(_minSheetExtent, _maxSheetExtent)
                        .toDouble();
                    setState(() => _currentSheetExtent = extent);
                    return false;
                  },
                  child: DraggableScrollableSheet(
                    controller: _sheetController,
                    initialChildSize: _initialSheetExtent,
                    minChildSize: _minSheetExtent,
                    maxChildSize: _maxSheetExtent,
                    snap: false,
                    expand: false,
                    builder: (context, scrollController) {
                      return _TutorialModalContent(
                        filteredResults: tutorialResults,
                        isLoading: _isLoading,
                        scrollController: scrollController,
                        onProductTap: _openProduct,
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  double get _overlayOpacity {
    final range = _maxSheetExtent - _minSheetExtent;
    if (range <= 0) return 0.7;
    final normalized =
        ((_currentSheetExtent - _minSheetExtent) / range).clamp(0.0, 1.0);
    return 0.15 + (0.55 * normalized);
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

class _TutorialModalContent extends StatelessWidget {
  final List<DetectionResult> filteredResults;
  final bool isLoading;
  final ScrollController scrollController;
  final Function(DetectionResult) onProductTap;

  const _TutorialModalContent({
    required this.filteredResults,
    required this.isLoading,
    required this.scrollController,
    required this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final mediaQuery = MediaQuery.of(context);
    final safeAreaBottom = mediaQuery.padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
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
                        '${filteredResults.length} results',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: SizedBox(
                height: 36,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: spacing.m),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        _AllResultsChip(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: spacing.sm),
            Expanded(
              child: isLoading
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
                      itemCount: filteredResults.length,
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
                        final result = filteredResults[index];
                        return _ProductCard(
                          result: result,
                          onTap: () => onProductTap(result),
                          isFirst: index == 0,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final DetectionResult result;
  final VoidCallback onTap;
  final bool isFirst;

  const _ProductCard({
    required this.result,
    required this.onTap,
    required this.isFirst,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final radius = context.radius;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.only(
          top: isFirst ? 0 : spacing.m,
          bottom: spacing.m,
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
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _AllResultsChip extends StatelessWidget {
  const _AllResultsChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF2003C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFF2003C),
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: const Text(
        'All',
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: Colors.white,
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
