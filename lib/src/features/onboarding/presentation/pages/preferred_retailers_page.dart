import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../shared/navigation/route_observer.dart';
import '../../../../shared/widgets/snaplook_back_button.dart';
import '../widgets/onboarding_bottom_bar.dart';
import '../widgets/progress_indicator.dart';
import '../widgets/option_card.dart';
import '../../domain/providers/onboarding_preferences_provider.dart';
import 'price_range_page.dart';

class PreferredRetailersPage extends ConsumerStatefulWidget {
  const PreferredRetailersPage({super.key});

  @override
  ConsumerState<PreferredRetailersPage> createState() =>
      _PreferredRetailersPageState();
}

class _PreferredRetailersPageState extends ConsumerState<PreferredRetailersPage>
    with TickerProviderStateMixin, RouteAware {
  static const List<String> _retailerOptions = [
    'Fast fashion',
    'Streetwear',
    'Athletic/Athleisure',
    'Department store',
    'Online marketplace',
    'Secondhand/Vintage',
    'Luxury/Designer',
    'Budget/Big box',
    'Local boutiques',
    'Exploring new places',
  ];

  late List<AnimationController> _animationControllers;
  late List<Animation<double>> _fadeAnimations;
  late List<Animation<double>> _scaleAnimations;
  bool _isRouteAware = false;

  @override
  void initState() {
    super.initState();

    _animationControllers = List.generate(_retailerOptions.length, (index) {
      return AnimationController(
        duration: const Duration(milliseconds: 400),
        vsync: this,
      );
    });

    _fadeAnimations = _animationControllers.map((controller) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOut),
      );
    }).toList();

    _scaleAnimations = _animationControllers.map((controller) {
      return Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOutBack),
      );
    }).toList();
  }

  void _startStaggeredAnimation() {
    for (var controller in _animationControllers) {
      controller.reset();
    }

    for (int i = 0; i < _animationControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 100), () {
        if (mounted) {
          _animationControllers[i].forward();
        }
      });
    }
  }

  Future<void> _playExitAnimation() async {
    await Future.wait(_animationControllers.map(
      (c) => c.animateBack(
        0.0,
        duration: const Duration(milliseconds: 200),
      ),
    ));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (!_isRouteAware && route is PageRoute) {
      routeObserver.subscribe(this, route);
      _isRouteAware = true;
      if (route.isCurrent) {
        _startStaggeredAnimation();
      }
    }
  }

  @override
  void dispose() {
    if (_isRouteAware) {
      routeObserver.unsubscribe(this);
    }
    for (var controller in _animationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didPush() {
    _startStaggeredAnimation();
  }

  @override
  void didPopNext() {
    _startStaggeredAnimation();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final selectedRetailers = ref.watch(preferredRetailersProvider);
    const sublabels = {
      'Fast fashion': 'Zara, H&M, Uniqlo',
      'Streetwear': 'Nike, Adidas, Foot Locker',
      'Athletic/Athleisure': 'Lululemon, Alo',
      'Department store': 'Nordstrom, Bloomingdale\'s',
      'Online marketplace': 'Amazon, ASOS',
      'Secondhand/Vintage': 'Thrift, Depop, Poshmark',
      'Luxury/Designer': 'LV, Gucci, SSENSE',
      'Budget/Big box': 'Target, Walmart',
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const SnaplookBackButton(enableHaptics: true),
        centerTitle: true,
        title: const OnboardingProgressIndicator(
          currentStep: 5,
          totalSteps: 20,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: spacing.l),

              // Title
              const Text(
                'Where do you usually shop?',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontFamily: 'PlusJakartaSans',
                  letterSpacing: -1.0,
                  height: 1.3,
                ),
              ),

              SizedBox(height: spacing.m),

              // Subtitle
              const Text(
                'Select all that apply',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.3,
                ),
              ),

              SizedBox(height: spacing.xl),

              // Options (scrollable) with header fixed
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ..._retailerOptions.asMap().entries.map((entry) {
                        final index = entry.key;
                        final retailer = entry.value;
                        final isSelected = selectedRetailers.contains(retailer);

                        return Padding(
                          padding: EdgeInsets.only(bottom: spacing.m),
                          child: AnimatedBuilder(
                            animation: _animationControllers[index],
                            builder: (context, child) {
                              return FadeTransition(
                                opacity: _fadeAnimations[index],
                                child: ScaleTransition(
                                  scale: _scaleAnimations[index],
                                  child: OptionCard(
                                    label: retailer,
                                    sublabel: sublabels[retailer],
                                    isSelected: isSelected,
                                    onTap: () {
                                      if (isSelected) {
                                        ref
                                                .read(preferredRetailersProvider
                                                    .notifier)
                                                .state =
                                            selectedRetailers
                                                .where((r) => r != retailer)
                                                .toList();
                                      } else {
                                        ref
                                            .read(preferredRetailersProvider
                                                .notifier)
                                            .state = [
                                          ...selectedRetailers,
                                          retailer
                                        ];
                                      }
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      }).toList(),
                      SizedBox(height: spacing.xl),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: OnboardingBottomBar(
        primaryButton: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: selectedRetailers.isEmpty
                ? null
                : () async {
                    HapticFeedback.mediumImpact();
                    await _playExitAnimation();
                    if (!mounted) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const PriceRangePage(),
                      ),
                    );
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFf2003c),
              foregroundColor: Colors.white,
              elevation: 0,
              disabledBackgroundColor: const Color(0xFFE5E7EB),
              disabledForegroundColor: const Color(0xFF9CA3AF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: const Text(
              'Continue',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'PlusJakartaSans',
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
