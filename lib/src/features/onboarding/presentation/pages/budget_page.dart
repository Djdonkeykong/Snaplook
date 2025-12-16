import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../shared/widgets/snaplook_back_button.dart';
import '../widgets/onboarding_bottom_bar.dart';

class BudgetPage extends StatefulWidget {
  final Set<String> selectedStyles;
  final Set<String> selectedInterests;

  const BudgetPage({
    super.key,
    required this.selectedStyles,
    required this.selectedInterests,
  });

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  static const _options = [
    'Affordable',
    'Mid-range',
    'Premium',
    'It varies',
  ];

  String _selected = 'Affordable';

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
                'What price range feels right?',
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
                'Pick one',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              SizedBox(height: spacing.l),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _options
                    .map(
                      (option) => Padding(
                        padding: EdgeInsets.only(bottom: spacing.s),
                        child: _RadioTile(
                          label: option,
                          selected: _selected == option,
                          onTap: () {
                            setState(() {
                              _selected = option;
                            });
                          },
                        ),
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
              // TODO: Hook into next step or save preferences.
              Navigator.of(context).popUntil((route) => route.isFirst);
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
    final spacing = context.spacing;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.m,
            vertical: spacing.m,
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? Colors.black : Colors.black26,
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? Colors.black : Colors.transparent,
                  ),
                ),
              ),
              SizedBox(width: spacing.m),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
