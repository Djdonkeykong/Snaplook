import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../shared/widgets/snaplook_back_button.dart';
import '../widgets/onboarding_bottom_bar.dart';
import '../widgets/progress_indicator.dart';
import 'budget_page.dart';

class WhatYouWantPage extends StatefulWidget {
  final Set<String> initialStyles;

  const WhatYouWantPage({super.key, required this.initialStyles});

  @override
  State<WhatYouWantPage> createState() => _WhatYouWantPageState();
}

class _WhatYouWantPageState extends State<WhatYouWantPage>
    with TickerProviderStateMixin {
  static const _options = [
    'Outfits',
    'Shoes',
    'Tops',
    'Accessories',
    'Everything',
  ];

  late Set<String> _selected;

  late List<AnimationController> _animationControllers;
  late List<Animation<double>> _fadeAnimations;
  late List<Animation<double>> _scaleAnimations;

  @override
  void initState() {
    super.initState();
    _selected = {'Outfits', 'Accessories'};

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

  void _startStaggeredAnimation() {
    for (int i = 0; i < _animationControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 80), () {
        if (mounted) _animationControllers[i].forward();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _animationControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _toggle(String value) {
    setState(() {
      if (_selected.contains(value)) {
        _selected.remove(value);
      } else {
        _selected.add(value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: SnaplookBackButton(
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        centerTitle: true,
        title: const OnboardingProgressIndicator(
          currentStep: 2,
          totalSteps: 3,
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
                  fontSize: 28,
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
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              SizedBox(height: spacing.l),
              Column(
                children: List.generate(_options.length, (index) {
                  final option = _options[index];
                  final isSelected = _selected.contains(option);
                  return Padding(
                    padding: EdgeInsets.only(bottom: spacing.s),
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
            onPressed: _selected.isNotEmpty
                ? () {
                    HapticFeedback.mediumImpact();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => BudgetPage(
                          selectedStyles: widget.initialStyles,
                          selectedInterests: _selected,
                        ),
                      ),
                    );
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _selected.isNotEmpty
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
                    _selected.isNotEmpty ? Colors.white : Colors.grey.shade600,
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
