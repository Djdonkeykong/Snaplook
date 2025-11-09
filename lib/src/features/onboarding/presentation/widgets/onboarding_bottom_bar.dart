import 'package:flutter/material.dart';
import '../../../../../core/theme/theme_extensions.dart';

/// A fixed bottom bar for onboarding pages with subtle shadow separation
class OnboardingBottomBar extends StatelessWidget {
  final Widget? primaryButton;
  final Widget? secondaryButton;

  const OnboardingBottomBar({
    super.key,
    this.primaryButton,
    this.secondaryButton,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, -8),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: SafeArea(
        minimum: EdgeInsets.only(
          left: spacing.l,
          right: spacing.l,
          bottom: spacing.m,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: spacing.m),
            if (primaryButton != null) ...[
              primaryButton!,
              if (secondaryButton != null) SizedBox(height: spacing.m),
            ],
            if (secondaryButton != null) secondaryButton!,
            SizedBox(height: spacing.m),
          ],
        ),
      ),
    );
  }
}
