import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../shared/navigation/route_observer.dart';
import '../../../../shared/widgets/snaplook_back_button.dart';
import '../widgets/onboarding_bottom_bar.dart';
import '../widgets/progress_indicator.dart';
import '../../domain/providers/onboarding_preferences_provider.dart';
import 'budget_page.dart';

class WhatYouWantPage extends ConsumerStatefulWidget {
  const WhatYouWantPage({super.key});

  @override
  ConsumerState<WhatYouWantPage> createState() => _WhatYouWantPageState();
}

class _WhatYouWantPageState extends ConsumerState<WhatYouWantPage>
    with TickerProviderStateMixin, RouteAware {
  static const _options = [
    'Complete outfits',
    'A specific item I saw',
    'Affordable alternatives',
    'Designer look-alikes',
    'Statement pieces',
    'Everyday basics',
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
    _startStaggeredAnimation();
  }

  @override
  void didPopNext() {
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

  void _toggle(String value) {
    final currentSelection = ref.read(whatYouWantProvider);
    if (currentSelection.contains(value)) {
      ref.read(whatYouWantProvider.notifier).state =
          currentSelection.where((item) => item != value).toList();
    } else {
      ref.read(whatYouWantProvider.notifier).state = [
        ...currentSelection,
        value
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final selected = ref.watch(whatYouWantProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: SnaplookBackButton(
          enableHaptics: true,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        centerTitle: true,
        title: const OnboardingProgressIndicator(
          currentStep: 7,
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
              const Text(
                'What are you mostly looking for?',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontFamily: 'PlusJakartaSans',
                  letterSpacing: -0.8,
                ),
              ),
              SizedBox(height: spacing.xs),
              const Text(
                'Pick as many as you want',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              SizedBox(height: spacing.l),
              Column(
                children: List.generate(_options.length, (index) {
                  final option = _options[index];
                  final isSelected = selected.contains(option);
                  return Padding(
                    padding: EdgeInsets.only(bottom: spacing.m),
                    child: FadeTransition(
                      opacity: _fadeAnimations[index],
                      child: ScaleTransition(
                        scale: _scaleAnimations[index],
                        child: _SelectableTile(
                          label: option,
                          isSelected: isSelected,
                          onTap: () => _toggle(option),
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
            onPressed: selected.isNotEmpty
                ? () {
                    HapticFeedback.mediumImpact();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const BudgetPage(),
                      ),
                    );
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: selected.isNotEmpty
                  ? const Color(0xFFf2003c)
                  : Colors.grey.shade300,
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
                color:
                    selected.isNotEmpty ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectableTile extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectableTile({
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
        height: 56,
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
              fontFamily: 'PlusJakartaSans',
            ),
          ),
        ),
      ),
    );
  }
}
