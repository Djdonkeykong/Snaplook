import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/snaplook_icons.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../shared/widgets/bottom_sheet_handle.dart';
import '../../../detection/domain/models/detection_result.dart';
import '../../../favorites/domain/providers/favorites_provider.dart';

class ResultsBottomSheetContent extends StatelessWidget {
  final List<DetectionResult> results;
  final ScrollController scrollController;
  final ValueChanged<DetectionResult> onProductTap;
  final bool showFavoriteButton;

  const ResultsBottomSheetContent({
    super.key,
    required this.results,
    required this.scrollController,
    required this.onProductTap,
    this.showFavoriteButton = true,
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  BottomSheetHandle(
                    margin: EdgeInsets.only(bottom: spacing.m),
                  ),
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
                    onTap: () => onProductTap(result),
                    isFirst: index == 0,
                    showFavoriteButton: showFavoriteButton,
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
  final bool showFavoriteButton;

  const _ProductCard({
    required this.result,
    required this.onTap,
    required this.isFirst,
    this.showFavoriteButton = true,
  });

  String _formatPrice(BuildContext context, double price, String? currency) {
    try {
      final locale = Localizations.localeOf(context).toString();
      final effectiveLocale = _localeForCurrency(locale, currency);
      final formatter = currency != null && currency.isNotEmpty
          ? NumberFormat.simpleCurrency(
              locale: effectiveLocale,
              name: currency,
            )
          : NumberFormat.simpleCurrency(locale: effectiveLocale);
      return formatter.format(price);
    } catch (_) {
      final symbol = currency ?? '\$';
      return '$symbol${price.toStringAsFixed(2)}';
    }
  }

  String _localeForCurrency(String locale, String? currencyCode) {
    if (currencyCode == null || currencyCode.isEmpty) return locale;
    final lower = locale.toLowerCase();
    if (lower.contains(currencyCode.toLowerCase())) return locale;

    const currencyLocales = {
      'NOK': 'nb_NO',
      'SEK': 'sv_SE',
      'DKK': 'da_DK',
      'EUR': 'de_DE',
      'GBP': 'en_GB',
      'USD': 'en_US',
      'CAD': 'en_CA',
      'AUD': 'en_AU',
    };
    return currencyLocales[currencyCode.toUpperCase()] ?? locale;
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final radius = context.radius;
    final mediaQuery = MediaQuery.of(context);

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
                if (showFavoriteButton)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: _SheetFavoriteButton(product: result),
                  ),
              ],
            ),
            SizedBox(width: spacing.m),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: spacing.m),
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
                      (result.priceDisplay != null &&
                              result.priceDisplay!.trim().isNotEmpty)
                          ? result.priceDisplay!
                          : result.price > 0
                              ? _formatPrice(
                                  context, result.price, result.currencyCode)
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
            ),
            Padding(
              padding: EdgeInsets.only(right: mediaQuery.size.width * 0.01),
              child: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.textTertiary,
              ),
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

class _SheetFavoriteButton extends ConsumerStatefulWidget {
  final DetectionResult product;

  const _SheetFavoriteButton({required this.product});

  @override
  ConsumerState<_SheetFavoriteButton> createState() =>
      _SheetFavoriteButtonState();
}

class _SheetFavoriteButtonState extends ConsumerState<_SheetFavoriteButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onTap(BuildContext context) async {
    HapticFeedback.mediumImpact();
    _controller.forward().then((_) => _controller.reverse());

    final wasAlreadyFavorited = ref.read(isFavoriteProvider(widget.product.id));

    try {
      await ref.read(favoritesProvider.notifier).toggleFavorite(widget.product);

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              wasAlreadyFavorited
                  ? 'Removed from favorites'
                  : 'Added to favorites',
              style: const TextStyle(fontFamily: 'PlusJakartaSans'),
            ),
            duration: const Duration(milliseconds: 2500),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update favorites: ${e.toString()}',
              style: const TextStyle(fontFamily: 'PlusJakartaSans'),
            ),
            duration: const Duration(milliseconds: 2500),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFavorite = ref.watch(isFavoriteProvider(widget.product.id));

    // Tailored defaults for bottom-sheet cards
    const containerSize = 28.0;
    const containerOpacity = 0.75;
    const shadowBlur = 3.0;
    const shadowOffset = Offset(0, 1.5);
    const filledIconSize = 12.0;
    const outlineIconSize = 10.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onTap(context),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: containerSize,
              height: containerSize,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(containerOpacity),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: shadowBlur,
                    offset: shadowOffset,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  isFavorite
                      ? SnaplookIcons.heartFilled
                      : SnaplookIcons.heartOutline,
                  size: isFavorite ? filledIconSize : outlineIconSize,
                  color: isFavorite ? const Color(0xFFf2003c) : Colors.black,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
