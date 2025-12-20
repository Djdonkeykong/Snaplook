import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../widgets/progress_indicator.dart';
import '../widgets/onboarding_bottom_bar.dart';
import 'add_first_style_page.dart';
import '../../../../shared/widgets/snaplook_back_button.dart';
import '../../../../services/onboarding_state_service.dart';
import '../../../auth/domain/providers/auth_provider.dart';

class AwesomeIntroPage extends ConsumerStatefulWidget {
  const AwesomeIntroPage({super.key});

  @override
  ConsumerState<AwesomeIntroPage> createState() => _AwesomeIntroPageState();
}

class _AwesomeIntroPageState extends ConsumerState<AwesomeIntroPage> {
  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const SnaplookBackButton(enableHaptics: true),
        centerTitle: true,
        title: const OnboardingProgressIndicator(
          currentStep: 2,
          totalSteps: 14,
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: spacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: spacing.l),

            // Title
            const Text(
              'Share your style,\nfind the look',
              textAlign: TextAlign.start,
              style: TextStyle(
                fontSize: 34,
                fontFamily: 'PlusJakartaSans',
                letterSpacing: -1.0,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                height: 1.3,
              ),
            ),

            SizedBox(height: spacing.xl * 2),

            // Phone illustration
            Expanded(
              flex: 3,
              child: Center(
                child: FractionallySizedBox(
                  widthFactor: 1.3,
                  child: Image.asset(
                    'assets/images/social_media_share_mobile_screen.png',
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                  ),
                ),
              ),
            ),

            SizedBox(height: spacing.xl),

            // Description text
            const Center(
              child: Text(
                'Share fashion images from Instagram, Pinterest,\nor any app to find similar styles and products!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'PlusJakartaSans',
                  letterSpacing: -0.3,
                ),
              ),
            ),

            SizedBox(height: spacing.l),
          ],
        ),
      ),
      bottomNavigationBar: OnboardingBottomBar(
        primaryButton: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () async {
              HapticFeedback.mediumImpact();

              final user = ref.read(authServiceProvider).currentUser;
              if (user != null) {
                unawaited(OnboardingStateService().updateCheckpoint(
                  user.id,
                  OnboardingCheckpoint.tutorial,
                ));
              }

              if (!context.mounted) return;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AddFirstStylePage(),
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
              'Show me how',
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
