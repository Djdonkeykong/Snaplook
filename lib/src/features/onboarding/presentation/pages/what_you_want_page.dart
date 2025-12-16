import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../shared/widgets/snaplook_back_button.dart';
import '../widgets/onboarding_bottom_bar.dart';
import 'budget_page.dart';

class WhatYouWantPage extends StatefulWidget {
  final Set<String> initialStyles;

  const WhatYouWantPage({super.key, required this.initialStyles});

  @override
  State<WhatYouWantPage> createState() => _WhatYouWantPageState();
}

class _WhatYouWantPageState extends State<WhatYouWantPage> {
  static const _options = [
    'Outfits',
    'Shoes',
    'Tops',
    'Accessories',
    'Everything',
  ];

  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {'Outfits', 'Accessories'};
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
              Wrap(
                spacing: spacing.s,
                runSpacing: spacing.s,
                children: _options
                    .map(
                      (option) => _SelectablePill(
                        label: option,
                        selected: _selected.contains(option),
                        onTap: () => _toggle(option),
                      ),
                    )
                    .toList(),
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
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => BudgetPage(
                    selectedStyles: widget.initialStyles,
                    selectedInterests: _selected,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFf2003c),
              foregroundColor: Colors.white,
              elevation: 0,
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

class _SelectablePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SelectablePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.black : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : Colors.black87,
              fontFamily: 'PlusJakartaSans',
            ),
          ),
        ),
      ),
    );
  }
}
