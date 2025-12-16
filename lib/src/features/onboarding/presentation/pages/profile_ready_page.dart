import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../shared/widgets/snaplook_back_button.dart';
import '../widgets/onboarding_bottom_bar.dart';
import '../widgets/progress_indicator.dart';
import 'rating_social_proof_page.dart';

class ProfileReadyPage extends StatelessWidget {
  const ProfileReadyPage({
    super.key,
    this.continueToTrialFlow = true,
  });

  final bool continueToTrialFlow;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const SnaplookBackButton(),
        centerTitle: true,
        title: const OnboardingProgressIndicator(
          currentStep: 11,
          totalSteps: 14,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: spacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: spacing.xl),
              _HeroCard(spacing: spacing),
              SizedBox(height: spacing.xl),
              _SnapshotCard(spacing: spacing),
              SizedBox(height: spacing.xl),
              _HighlightsCard(spacing: spacing),
              SizedBox(height: spacing.xl),
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
                  builder: (context) => const RatingSocialProofPage(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 2,
              shadowColor: Colors.black.withOpacity(0.18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              splashFactory: InkSparkle.splashFactory,
            ),
            child: const Text(
              "Let's get started",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                fontFamily: 'PlusJakartaSans',
                letterSpacing: -0.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.spacing});

  final ThemeSpacing spacing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(spacing.l),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            Colors.black.withOpacity(0.04),
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.14),
                  blurRadius: 16,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.check,
              size: 28,
              color: Colors.white,
            ),
          ),
          SizedBox(height: spacing.m),
          const Text(
            'Your Snaplook is ready',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Colors.black,
              fontFamily: 'PlusJakartaSans',
              letterSpacing: -0.3,
              height: 1.25,
            ),
          ),
          SizedBox(height: spacing.sm),
          const Text(
            'We matched your preferred brands and silhouettes. A clean, ready-to-browse feed awaits.',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              fontFamily: 'PlusJakartaSans',
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SnapshotCard extends StatelessWidget {
  const _SnapshotCard({required this.spacing});

  final ThemeSpacing spacing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(spacing.l),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profile snapshot',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black,
              fontFamily: 'PlusJakartaSans',
              letterSpacing: -0.1,
            ),
          ),
          SizedBox(height: spacing.s),
          const Text(
            "Catalog: Men's & Women's • Balanced fits",
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              fontFamily: 'PlusJakartaSans',
              height: 1.45,
            ),
          ),
          const Text(
            'Focus brands: Nike, Zara, Uniqlo',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              fontFamily: 'PlusJakartaSans',
              height: 1.45,
            ),
          ),
          SizedBox(height: spacing.s),
          const Text(
            'Style direction',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              fontFamily: 'PlusJakartaSans',
              letterSpacing: -0.1,
            ),
          ),
          SizedBox(height: spacing.s),
          Wrap(
            spacing: spacing.s,
            runSpacing: spacing.s,
            children: const [
              _TagChip(label: 'Streetwear'),
              _TagChip(label: 'Casual comfort'),
              _TagChip(label: 'Clean lines'),
            ],
          ),
          SizedBox(height: spacing.l),
          Row(
            children: [
              _MiniTile(
                title: 'Weekday',
                caption: 'Tailored picks',
              ),
              SizedBox(width: spacing.s),
              _MiniTile(
                title: 'Weekend',
                caption: 'Relaxed layers',
              ),
              SizedBox(width: spacing.s),
              _MiniTile(
                title: 'Sport',
                caption: 'Performance first',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HighlightsCard extends StatelessWidget {
  const _HighlightsCard({required this.spacing});

  final ThemeSpacing spacing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(spacing.l),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Highlights ready',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black,
              fontFamily: 'PlusJakartaSans',
            ),
          ),
          SizedBox(height: spacing.m),
          const _HighlightRow(label: 'Looks calibrated to your picks'),
          SizedBox(height: spacing.s),
          const _HighlightRow(label: 'Feeds tuned for weekday and weekend'),
          SizedBox(height: spacing.s),
          const _HighlightRow(label: 'Ready to browse immediately'),
          SizedBox(height: spacing.l),
          Divider(
            height: 1,
            color: Colors.black.withOpacity(0.08),
          ),
          SizedBox(height: spacing.m),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.black.withOpacity(0.08)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(
                  Icons.auto_awesome,
                  size: 16,
                  color: Colors.black,
                ),
                SizedBox(width: 6),
                Text(
                  'Powered by Snaplook AI',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.black,
          fontFamily: 'PlusJakartaSans',
        ),
      ),
    );
  }
}

class _HighlightRow extends StatelessWidget {
  const _HighlightRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.06),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check,
            size: 16,
            color: Colors.black,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black,
              fontFamily: 'PlusJakartaSans',
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniTile extends StatelessWidget {
  const _MiniTile({
    required this.title,
    required this.caption,
  });

  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Expanded(
      child: Container(
        padding: EdgeInsets.all(spacing.m),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F6F6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withOpacity(0.04)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.black,
                fontFamily: 'PlusJakartaSans',
              ),
            ),
            SizedBox(height: spacing.xs),
            Text(
              caption,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                fontFamily: 'PlusJakartaSans',
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
