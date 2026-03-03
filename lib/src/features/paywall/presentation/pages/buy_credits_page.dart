import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../shared/widgets/snaplook_back_button.dart';
import '../../../../services/revenuecat_service.dart';
import '../../../../services/credit_service.dart';
import '../../../../services/subscription_sync_service.dart';
import '../../models/credit_pack.dart';

class BuyCreditsPage extends StatefulWidget {
  const BuyCreditsPage({super.key});

  @override
  State<BuyCreditsPage> createState() => _BuyCreditsPageState();
}

class _BuyCreditsPageState extends State<BuyCreditsPage> {
  List<StoreProduct> _products = [];
  bool _isLoading = true;
  String? _purchasingProductId;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await RevenueCatService()
          .getStoreProducts(CreditPack.allProductIds)
          .timeout(const Duration(seconds: 10));

      if (mounted) {
        setState(() {
          _products = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[BuyCredits] Error loading products: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _purchase(StoreProduct product) async {
    if (_purchasingProductId != null) return;

    final pack = CreditPack.byProductId(product.identifier);
    if (pack == null) return;

    setState(() {
      _purchasingProductId = product.identifier;
    });

    HapticFeedback.mediumImpact();

    try {
      final success = await RevenueCatService().purchaseStoreProduct(product);

      if (!mounted) return;

      if (success) {
        await CreditService().addPurchasedCredits(pack.credits);
        await SubscriptionSyncService().syncSubscriptionToSupabase();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${pack.credits} credits added to your account.',
                style: const TextStyle(fontFamily: 'PlusJakartaSans'),
              ),
              backgroundColor: const Color(0xFF22C55E),
              duration: const Duration(seconds: 3),
            ),
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      debugPrint('[BuyCredits] Purchase error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Purchase failed. Please try again.',
              style: const TextStyle(fontFamily: 'PlusJakartaSans'),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _purchasingProductId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final viewPadding = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const SnaplookBackButton(),
        centerTitle: true,
        title: const Text(
          'Buy Credits',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'PlusJakartaSans',
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.secondary),
              ),
            )
          : _products.isEmpty
              ? _EmptyState(onRetry: _loadProducts)
              : ListView(
                  padding: EdgeInsets.fromLTRB(
                    spacing.l,
                    spacing.m,
                    spacing.l,
                    spacing.l + viewPadding.bottom,
                  ),
                  children: [
                    const Text(
                      'No subscription needed',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.8,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: spacing.xs),
                    const Text(
                      '1 credit = 1 garment match. Credits never expire.',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: spacing.l),
                    ..._buildPackCards(spacing),
                    SizedBox(height: spacing.m),
                    const Text(
                      'Purchases are processed through the App Store. Credits are added instantly.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
    );
  }

  List<Widget> _buildPackCards(dynamic spacing) {
    final orderedProducts = <StoreProduct>[];
    for (final id in CreditPack.allProductIds) {
      final match = _products.where((p) => p.identifier == id).toList();
      if (match.isNotEmpty) orderedProducts.add(match.first);
    }

    return orderedProducts.map((product) {
      final pack = CreditPack.byProductId(product.identifier);
      if (pack == null) return const SizedBox.shrink();

      final isPopular = product.identifier == CreditPack.pack50.productId;
      final isPurchasing = _purchasingProductId == product.identifier;

      return Padding(
        padding: EdgeInsets.only(bottom: spacing.m),
        child: _PackCard(
          pack: pack,
          priceString: product.priceString,
          isPopular: isPopular,
          isPurchasing: isPurchasing,
          isDisabled: _purchasingProductId != null,
          onTap: () => _purchase(product),
        ),
      );
    }).toList();
  }
}

class _PackCard extends StatelessWidget {
  final CreditPack pack;
  final String priceString;
  final bool isPopular;
  final bool isPurchasing;
  final bool isDisabled;
  final VoidCallback onTap;

  const _PackCard({
    required this.pack,
    required this.priceString,
    required this.isPopular,
    required this.isPurchasing,
    required this.isDisabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: isDisabled ? null : onTap,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: isDisabled && !isPurchasing ? 0.5 : 1.0,
            child: Container(
              padding: EdgeInsets.fromLTRB(20, isPopular ? 28 : 20, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isPopular
                      ? AppColors.secondary
                      : AppColors.outline,
                  width: isPopular ? 2 : 1.5,
                ),
                boxShadow: isPopular
                    ? [
                        BoxShadow(
                          color: AppColors.secondary.withOpacity(0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pack.title,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          pack.description,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: isDisabled ? null : onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isPopular
                            ? AppColors.secondary
                            : AppColors.textPrimary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: isPurchasing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              priceString,
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isPopular)
          Positioned(
            top: -12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Most Popular',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onRetry;

  const _EmptyState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Unable to load credit packs.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
