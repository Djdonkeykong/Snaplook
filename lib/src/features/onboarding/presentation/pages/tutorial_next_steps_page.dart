import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import 'rating_social_proof_page.dart';

class TutorialNextStepsPage extends StatelessWidget {
  const TutorialNextStepsPage({super.key, this.returnToOnboarding = true});

  final bool returnToOnboarding;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: spacing.l),
              const Text(
                "What's next?",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'PlusJakartaSans',
                  color: Colors.black,
                  letterSpacing: -0.8,
                ),
              ),
              SizedBox(height: spacing.sm),
              const Text(
                'Choose how you want to continue after trying the tutorial.',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              SizedBox(height: spacing.l),
              _ChoiceCard(
                title: 'Keep browsing in Snaplook',
                subtitle: 'Jump back to your feed and keep discovering outfits.',
                icon: Icons.check_circle_outline,
                iconColor: const Color(0xFF1A73E8),
                onTap: () => _handleKeepBrowsing(context),
                background: colorScheme.surface,
              ),
              SizedBox(height: spacing.m),
              _ChoiceCard(
                title: 'Try sharing an image from Instagram',
                subtitle: 'Open Instagram to share a post into Snaplook yourself.',
                icon: Icons.camera_alt_outlined,
                iconColor: const Color(0xFFF2003C),
                onTap: () => _openInstagram(context),
                background: colorScheme.surface,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleKeepBrowsing(BuildContext context) {
    HapticFeedback.selectionClick();

    if (returnToOnboarding) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const RatingSocialProofPage(
            continueToTrialFlow: true,
          ),
        ),
      );
    } else {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _openInstagram(BuildContext context) async {
    HapticFeedback.mediumImpact();

    final appUri = Uri.parse('instagram://app');
    final webUri = Uri.parse('https://www.instagram.com/');

    bool launched = false;

    try {
      launched = await launchUrl(
        appUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      launched = false;
    }

    if (!launched) {
      try {
        await launchUrl(
          webUri,
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open Instagram'),
            ),
          );
        }
      }
    }
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    required this.background,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final radius = context.radius;

    return InkWell(
      borderRadius: BorderRadius.circular(radius.large),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(spacing.l),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(radius.large),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 26,
                color: iconColor,
              ),
            ),
            SizedBox(width: spacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                      fontFamily: 'PlusJakartaSans',
                      letterSpacing: -0.2,
                    ),
                  ),
                  SizedBox(height: spacing.xs),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                      fontFamily: 'PlusJakartaSans',
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
