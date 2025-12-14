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
          currentStep: 13,
          totalSteps: 20,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: spacing.l),
          child: Column(
            children: [
              SizedBox(height: spacing.xl),

              // Check icon
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  size: 48,
                  color: Colors.white,
                ),
              ),

              SizedBox(height: spacing.xl),

              // Title
              const Text(
                'Congratulations\nyour style profile is ready!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontFamily: 'PlusJakartaSans',
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),

              SizedBox(height: spacing.m),

              // Subtitle
              const Text(
                'Based on your preferences',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF6B7280),
                  fontFamily: 'PlusJakartaSans',
                ),
              ),

              SizedBox(height: spacing.xl),

              // Daily recommendation section
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(spacing.l),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F9F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your personalized feed includes:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                    SizedBox(height: spacing.m),

                    // Feature items with icons
                    _FeatureItem(
                      icon: Icons.auto_awesome,
                      iconColor: const Color(0xFFf2003c),
                      title: 'AI-powered matches',
                      spacing: spacing,
                    ),
                    SizedBox(height: spacing.m),
                    _FeatureItem(
                      icon: Icons.style,
                      iconColor: const Color(0xFF6B9DFF),
                      title: 'Personalized style recommendations',
                      spacing: spacing,
                    ),
                    SizedBox(height: spacing.m),
                    _FeatureItem(
                      icon: Icons.local_offer,
                      iconColor: const Color(0xFFFFA726),
                      title: 'Exclusive deals from your favorite brands',
                      spacing: spacing,
                    ),
                    SizedBox(height: spacing.m),
                    _FeatureItem(
                      icon: Icons.bookmark,
                      iconColor: const Color(0xFF22C55E),
                      title: 'Save and organize your finds',
                      spacing: spacing,
                    ),
                  ],
                ),
              ),

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
                  builder: (context) => const RatingSocialProofPage(
                    continueToTrialFlow: continueToTrialFlow,
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
              'Let\'s get started!',
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

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.spacing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final AppSpacingExtension spacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: iconColor,
          ),
        ),
        SizedBox(width: spacing.m),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black,
              fontFamily: 'PlusJakartaSans',
            ),
          ),
        ),
        const Icon(
          Icons.check_circle,
          size: 20,
          color: Colors.black,
        ),
      ],
    );
  }
}
