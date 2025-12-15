import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../shared/widgets/snaplook_back_button.dart';
import '../widgets/onboarding_bottom_bar.dart';
import '../widgets/progress_indicator.dart';
import 'calculating_profile_page.dart';

class GenerateProfilePrepPage extends StatefulWidget {
  const GenerateProfilePrepPage({super.key});

  @override
  State<GenerateProfilePrepPage> createState() => _GenerateProfilePrepPageState();
}

class _GenerateProfilePrepPageState extends State<GenerateProfilePrepPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _lottieController;

  @override
  void initState() {
    super.initState();
    _lottieController = AnimationController(vsync: this);

    // Keep the final frame visible after the animation completes.
    _lottieController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _lottieController.animateTo(1.0, duration: Duration.zero);
      }
    });
  }

  @override
  void dispose() {
    _lottieController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final mediaQuery = MediaQuery.of(context);
    final availableWidth = mediaQuery.size.width - spacing.l * 2;
    final outerSize = math.max(0.0, math.min(availableWidth, 640.0));
    final innerSize = outerSize * 0.82;
    const lottieScale = 1.2;

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
          totalSteps: 20,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing.l),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // Lottie illustration
                Container(
                  width: outerSize,
                  height: outerSize,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFFFFE5EC).withOpacity(0.5),
                        const Color(0xFFE5F0FF).withOpacity(0.5),
                      ],
                    ),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: innerSize,
                      height: innerSize,
                      child: Transform.scale(
                        scale: lottieScale,
                        child: Lottie.asset(
                          'assets/animations/clap.json',
                          controller: _lottieController,
                          repeat: false,
                          fit: BoxFit.contain,
                          onLoaded: (composition) {
                            if (!mounted) return;
                            _lottieController
                              ..duration = composition.duration
                              ..value = 0
                              ..forward();
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 0),

                // Badge
                Transform.translate(
                  offset: const Offset(0, -18),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.black,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'All done!',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            fontFamily: 'PlusJakartaSans',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 0),

                // Title
                Transform.translate(
                  offset: const Offset(0, -12),
                  child: const Text(
                    'Time to generate\nyour style profile!',
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
                ),

                const Spacer(flex: 2),
              ],
            ),
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
                  builder: (context) => const CalculatingProfilePage(),
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
