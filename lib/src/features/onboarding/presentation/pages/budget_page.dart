import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/navigation/route_observer.dart';
import '../../../../shared/widgets/snaplook_back_button.dart';
import '../widgets/onboarding_bottom_bar.dart';
import '../widgets/progress_indicator.dart';
import '../mixins/screen_tracking_mixin.dart';
import '../../domain/providers/onboarding_preferences_provider.dart';
import 'generate_profile_prep_page.dart';

class BudgetPage extends ConsumerStatefulWidget {
  const BudgetPage({super.key});

  @override
  ConsumerState<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends ConsumerState<BudgetPage>
    with TickerProviderStateMixin, RouteAware, ScreenTrackingMixin {
  @override
  String get screenName => 'onboarding_budget';
  static const _options = [
    'Affordable',
    'Mid-range',
    'Premium',
    'It varies',
  ];

  late List<AnimationController> _animationControllers;
  late List<Animation<double>> _fadeAnimations;
  late List<Animation<double>> _scaleAnimations;
  bool _isRouteAware = false;

  @override
  void initState() {
    super.initState();
    _animationControllers = List.generate(
      _options.length,
      (_) => AnimationController(
        duration: const Duration(milliseconds: 400),
        vsync: this,
      ),
    );
    _fadeAnimations = _animationControllers
        .map((c) => Tween<double>(begin: 0, end: 1).animate(
              CurvedAnimation(parent: c, curve: Curves.easeOut),
            ))
        .toList();
    _scaleAnimations = _animationControllers
        .map((c) => Tween<double>(begin: 0.8, end: 1).animate(
              CurvedAnimation(parent: c, curve: Curves.easeOutBack),
            ))
        .toList();

    Future.microtask(_startStaggeredAnimation);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (!_isRouteAware && route is PageRoute) {
      routeObserver.subscribe(this, route);
      _isRouteAware = true;
    }
  }

  @override
  void dispose() {
    if (_isRouteAware) {
      routeObserver.unsubscribe(this);
    }
    for (final c in _animationControllers) {
      c.dispose();
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

  void _startStaggeredAnimation() {
    for (final c in _animationControllers) {
      c.reset();
    }
    for (int i = 0; i < _animationControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 80), () {
        if (mounted) _animationControllers[i].forward();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final selected = ref.watch(budgetProvider);
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
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        centerTitle: true,
        title: const OnboardingProgressIndicator(
          currentStep: 8,
          totalSteps: 14,
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(spacing.l, spacing.l, spacing.l, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What price range feels right?',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                  fontFamily: 'PlusJakartaSans',
                  letterSpacing: -0.8,
                ),
              ),
              SizedBox(height: spacing.xs),
              Text(
                'Pick one that fits',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurfaceVariant,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              SizedBox(height: spacing.l),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(_options.length, (index) {
                  final option = _options[index];
                  final isSelected = selected == option;
                  return Padding(
                    padding: EdgeInsets.only(bottom: spacing.m),
                    child: FadeTransition(
                      opacity: _fadeAnimations[index],
                      child: ScaleTransition(
                        scale: _scaleAnimations[index],
                        child: _RadioTile(
                          label: option,
                          selected: isSelected,
                          onTap: () {
                            ref.read(budgetProvider.notifier).state = option;
                          },
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: OnboardingBottomBar(
        primaryButton: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: selected != null && selected.isNotEmpty
                ? () {
                    HapticFeedback.mediumImpact();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const GenerateProfilePrepPage(),
                      ),
                    );
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: selected != null && selected.isNotEmpty
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
                color: selected != null && selected.isNotEmpty
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

class _RadioTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RadioTile({
    required this.label,
    required this.selected,
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
          color: selected
              ? AppColors.secondary
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : colorScheme.onSurface,
            fontFamily: 'PlusJakartaSans',
          ),
        ),
      ),
    );
  }
}
