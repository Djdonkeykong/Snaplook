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
import 'preferred_retailers_page.dart';

class StylePreferencesPage extends ConsumerStatefulWidget {
  const StylePreferencesPage({super.key});

  @override
  ConsumerState<StylePreferencesPage> createState() =>
      _StylePreferencesPageState();
}

class _StylePreferencesPageState extends ConsumerState<StylePreferencesPage>
    with TickerProviderStateMixin, RouteAware {
  static const List<String> _styleOptions = [
    'Minimalist & Classic',
    'Streetwear & Urban',
    'Vintage & Retro',
    'Boho & Romantic',
    'Athletic & Sporty',
    'Luxury & Designer',
    'Edgy & Alternative',
    'Casual & Comfy',
  ];

  late List<AnimationController> _animationControllers;
  late List<Animation<double>> _fadeAnimations;
  late List<Animation<double>> _scaleAnimations;
  bool _isRouteAware = false;

  @override
  void initState() {
    super.initState();

    _animationControllers = List.generate(_styleOptions.length, (index) {
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
    // Reverse all animations together for a quick fade-out
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
    final selectedStyles = ref.watch(stylePreferencesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: SnaplookBackButton(
          enableHaptics: true,
          backgroundColor: colorScheme.surface,
          iconColor: colorScheme.onSurface,
        ),
        centerTitle: true,
        title: const OnboardingProgressIndicator(
          currentStep: 4,
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
              Text(
                'Which style speaks to you?',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                  fontFamily: 'PlusJakartaSans',
                  letterSpacing: -1.0,
                  height: 1.3,
                ),
              ),

              SizedBox(height: spacing.m),

              // Subtitle
              Text(
                'Select all that apply',
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.onSurfaceVariant,
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
                      ..._styleOptions.asMap().entries.map((entry) {
                        final index = entry.key;
                        final label = entry.value;
                        final isSelected = selectedStyles.contains(label);

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
                                    label: label,
                                    isSelected: isSelected,
                                    onTap: () {
                                      if (isSelected) {
                                        ref
                                                .read(stylePreferencesProvider
                                                    .notifier)
                                                .state =
                                            selectedStyles
                                                .where((s) => s != label)
                                                .toList();
                                      } else {
                                        ref
                                            .read(stylePreferencesProvider
                                                .notifier)
                                            .state = [...selectedStyles, label];
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
            onPressed: selectedStyles.isEmpty
                ? null
                : () async {
                    HapticFeedback.mediumImpact();
                    await _playExitAnimation();
                    if (!mounted) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const PreferredRetailersPage(),
                      ),
                    );
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: selectedStyles.isNotEmpty
                  ? AppColors.secondary
                  : colorScheme.outlineVariant,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: Text(
              'Continue',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'PlusJakartaSans',
                letterSpacing: -0.2,
                color: selectedStyles.isNotEmpty
                    ? Colors.white
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
