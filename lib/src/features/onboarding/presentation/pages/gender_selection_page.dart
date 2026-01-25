import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/navigation/route_observer.dart';
import '../../../../shared/widgets/snaplook_back_button.dart';
import '../../domain/providers/gender_provider.dart';
import '../../../auth/domain/providers/auth_provider.dart';
import '../widgets/onboarding_bottom_bar.dart';
import '../widgets/progress_indicator.dart';
import '../mixins/screen_tracking_mixin.dart';
import 'style_direction_page.dart';
import '../../../../services/fraud_prevention_service.dart';
import '../../../../services/onboarding_state_service.dart';

class GenderSelectionPage extends ConsumerStatefulWidget {
  const GenderSelectionPage({super.key});

  @override
  ConsumerState<GenderSelectionPage> createState() =>
      _GenderSelectionPageState();
}

class _GenderSelectionPageState extends ConsumerState<GenderSelectionPage>
    with TickerProviderStateMixin, RouteAware, ScreenTrackingMixin {
  @override
  String get screenName => 'onboarding_gender_selection';
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

    // Start onboarding tracking if user is authenticated
    _initializeOnboarding();
  }

  Future<void> _initializeOnboarding() async {
    try {
      final user = ref.read(authServiceProvider).currentUser;
      if (user != null) {
        debugPrint(
            '[GenderSelection] Initializing onboarding for user ${user.id}');

        // Start onboarding tracking
        await OnboardingStateService().startOnboarding(user.id);

        // Update device fingerprint for fraud prevention
        await FraudPreventionService.updateUserDeviceFingerprint(user.id);

        debugPrint('[GenderSelection] Onboarding initialized successfully');
      } else {
        debugPrint(
            '[GenderSelection] No authenticated user - skipping onboarding init');
      }
    } catch (e) {
      debugPrint('[GenderSelection] Error initializing onboarding: $e');
      // Non-critical error - allow user to continue
    }
  }

  Future<void> _saveGenderPreference() async {
    try {
      final selectedGender = ref.read(selectedGenderProvider);
      if (selectedGender == null) return;

      final user = ref.read(authServiceProvider).currentUser;
      if (user == null) {
        debugPrint(
            '[GenderSelection] No authenticated user - preferences will be saved after login');
        return;
      }

      debugPrint(
          '[GenderSelection] Saving gender preference: ${selectedGender.name}');

      // Map Gender enum to preferred_gender_filter
      String filterValue;
      switch (selectedGender) {
        case Gender.male:
          filterValue = 'men';
          break;
        case Gender.female:
          filterValue = 'women';
          break;
        case Gender.other:
          filterValue = 'all'; // Show all products in feed
          break;
      }

      // Save preferences to database
      await OnboardingStateService().saveUserPreferences(
        userId: user.id,
        preferredGenderFilter: filterValue,
      );

      // Update checkpoint
      await OnboardingStateService().updateCheckpoint(
        user.id,
        OnboardingCheckpoint.gender,
      );

      debugPrint('[GenderSelection] Gender preference saved successfully');
    } catch (e) {
      debugPrint('[GenderSelection] Error saving gender preference: $e');
      // Non-critical error - allow user to continue
    }
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
    super.didPush();
    _startStaggeredAnimation();
  }

  @override
  void didPopNext() {
    super.didPopNext();
    _startStaggeredAnimation();
  }

  @override
  Widget build(BuildContext context) {
    final selectedGender = ref.watch(selectedGenderProvider);
    final spacing = context.spacing;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        // Always show back button to mirror other onboarding pages.
        // Pop this page (non-root so it works when pushed from the auth sheet flow).
        leading: SnaplookBackButton(
          enableHaptics: true,
          backgroundColor: colorScheme.surface,
          iconColor: colorScheme.onSurface,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        centerTitle: true,
        title: const OnboardingProgressIndicator(
          currentStep: 6,
          totalSteps: 14,
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
                'Choose your catalog',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                  fontFamily: 'PlusJakartaSans',
                  letterSpacing: -1.0,
                  height: 1.3,
                ),
              ),

              SizedBox(height: spacing.xs),

              // Subtitle
              Text(
                "Pick what you want to see and we'll tailor the feed",
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.onSurfaceVariant,
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w500,
                ),
              ),

              SizedBox(height: spacing.l),

              // Gender Options
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                debugPrint(
                                    '[GenderSelection] User selected: male');
                                ref
                                    .read(selectedGenderProvider.notifier)
                                    .state = Gender.male;
                                debugPrint(
                                    '[GenderSelection] Provider updated to: ${ref.read(selectedGenderProvider)?.name}');
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
                                debugPrint(
                                    '[GenderSelection] User selected: female');
                                ref
                                    .read(selectedGenderProvider.notifier)
                                    .state = Gender.female;
                                debugPrint(
                                    '[GenderSelection] Provider updated to: ${ref.read(selectedGenderProvider)?.name}');
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
                                debugPrint(
                                    '[GenderSelection] User selected: other');
                                ref
                                    .read(selectedGenderProvider.notifier)
                                    .state = Gender.other;
                                debugPrint(
                                    '[GenderSelection] Provider updated to: ${ref.read(selectedGenderProvider)?.name}');
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

                    // Save gender preference to database in background
                    unawaited(_saveGenderPreference());

                    // Navigate to next page immediately
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const StyleDirectionPage(),
                      ),
                    );
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: selectedGender != null
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
                color: selectedGender != null
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
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.secondary
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
