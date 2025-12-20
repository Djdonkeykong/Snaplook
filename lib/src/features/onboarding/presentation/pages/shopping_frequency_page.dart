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
import 'awesome_intro_page.dart';

class ShoppingFrequencyPage extends ConsumerStatefulWidget {
  const ShoppingFrequencyPage({super.key});

  @override
  ConsumerState<ShoppingFrequencyPage> createState() =>
      _ShoppingFrequencyPageState();
}

class _ShoppingFrequencyPageState extends ConsumerState<ShoppingFrequencyPage>
    with TickerProviderStateMixin, RouteAware {
  static const List<String> _frequencyOptions = [
    'Weekly',
    'Monthly',
    'A few times a year',
    'Only when needed',
    'I\'m a window shopper',
  ];

  late List<AnimationController> _animationControllers;
  late List<Animation<double>> _fadeAnimations;
  late List<Animation<double>> _scaleAnimations;
  bool _isRouteAware = false;

  @override
  void initState() {
    super.initState();

    _animationControllers = List.generate(_frequencyOptions.length, (index) {
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
    final selectedFrequency = ref.watch(shoppingFrequencyProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const SnaplookBackButton(enableHaptics: true),
        centerTitle: true,
        title: const OnboardingProgressIndicator(
          currentStep: 8,
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
                'How often do you shop for clothes?',
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
                'This helps us customize your notifications',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.3,
                ),
              ),

              SizedBox(height: spacing.xl),

              // Options list scrolls while header stays fixed
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ..._frequencyOptions.asMap().entries.map((entry) {
                        final index = entry.key;
                        final frequency = entry.value;
                        final isSelected = selectedFrequency == frequency;

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
                                    label: frequency,
                                    isSelected: isSelected,
                                    onTap: () {
                                      ref
                                          .read(shoppingFrequencyProvider
                                              .notifier)
                                          .state = frequency;
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
            onPressed: selectedFrequency == null
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const AwesomeIntroPage(),
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
