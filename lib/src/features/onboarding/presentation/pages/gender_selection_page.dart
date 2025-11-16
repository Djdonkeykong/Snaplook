import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../shared/navigation/route_observer.dart';
import '../widgets/progress_indicator.dart';
import '../widgets/onboarding_bottom_bar.dart';
import 'discovery_source_page.dart';

enum Gender { male, female, other }

final selectedGenderProvider = StateProvider<Gender?>((ref) => null);

class GenderSelectionPage extends ConsumerStatefulWidget {
  const GenderSelectionPage({super.key});

  @override
  ConsumerState<GenderSelectionPage> createState() => _GenderSelectionPageState();
}

class _GenderSelectionPageState extends ConsumerState<GenderSelectionPage>
    with TickerProviderStateMixin, RouteAware {
  late List<AnimationController> _animationControllers;
  late List<Animation<double>> _fadeAnimations;
  late List<Animation<double>> _scaleAnimations;

  bool _isRouteAware = false;

  @override
  void initState() {
    super.initState();

    _animationControllers = List.generate(3, (index) {
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
    // Reset all controllers first
    for (var controller in _animationControllers) {
      controller.reset();
    }

    // Then start staggered animation
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
    final selectedGender = ref.watch(selectedGenderProvider);
    final spacing = context.spacing;

    // Check if we can pop (if there are routes to go back to)
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: canPop ? IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_back,
              color: Colors.black,
              size: 20,
            ),
          ),
        ) : null,
        centerTitle: true,
        title: const OnboardingProgressIndicator(
          currentStep: 1,
          totalSteps: 8,
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
                'Choose your style',
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
                'Select your style preference to personalize\nyour experience.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.3,
                ),
              ),

              SizedBox(height: spacing.l),

              // Gender Options
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                        // Men's Clothing
                        AnimatedBuilder(
                          animation: _animationControllers[0],
                          builder: (context, child) {
                            return FadeTransition(
                              opacity: _fadeAnimations[0],
                              child: ScaleTransition(
                                scale: _scaleAnimations[0],
                                child: _GenderOption(
                                  gender: Gender.male,
                                  label: "Men's Clothing",
                                  isSelected: selectedGender == Gender.male,
                                  onTap: () {
                                    print('[GenderSelection] User selected: male');
                                    ref.read(selectedGenderProvider.notifier).state = Gender.male;
                                    print('[GenderSelection] Provider updated to: ${ref.read(selectedGenderProvider)?.name}');
                                  },
                                ),
                              ),
                            );
                          },
                        ),

                        SizedBox(height: spacing.l),

                        // Women's Clothing
                        AnimatedBuilder(
                          animation: _animationControllers[1],
                          builder: (context, child) {
                            return FadeTransition(
                              opacity: _fadeAnimations[1],
                              child: ScaleTransition(
                                scale: _scaleAnimations[1],
                                child: _GenderOption(
                                  gender: Gender.female,
                                  label: "Women's Clothing",
                                  isSelected: selectedGender == Gender.female,
                                  onTap: () {
                                    print('[GenderSelection] User selected: female');
                                    ref.read(selectedGenderProvider.notifier).state = Gender.female;
                                    print('[GenderSelection] Provider updated to: ${ref.read(selectedGenderProvider)?.name}');
                                  },
                                ),
                              ),
                            );
                          },
                        ),

                        SizedBox(height: spacing.l),

                        // Both
                        AnimatedBuilder(
                          animation: _animationControllers[2],
                          builder: (context, child) {
                            return FadeTransition(
                              opacity: _fadeAnimations[2],
                              child: ScaleTransition(
                                scale: _scaleAnimations[2],
                                child: _GenderOption(
                                  gender: Gender.other,
                                  label: 'Both',
                                  isSelected: selectedGender == Gender.other,
                                  onTap: () {
                                    print('[GenderSelection] User selected: other');
                                    ref.read(selectedGenderProvider.notifier).state = Gender.other;
                                    print('[GenderSelection] Provider updated to: ${ref.read(selectedGenderProvider)?.name}');
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ],
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
            onPressed: selectedGender != null
                ? () {
                    HapticFeedback.mediumImpact();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const DiscoverySourcePage(),
                      ),
                    );
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: selectedGender != null ? const Color(0xFFf2003c) : Colors.grey.shade300,
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
                color: selectedGender != null ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GenderOption extends StatelessWidget {
  final Gender gender;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _GenderOption({
    required this.gender,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 64,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFf2003c) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}
