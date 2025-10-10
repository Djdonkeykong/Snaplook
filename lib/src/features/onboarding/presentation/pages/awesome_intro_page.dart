import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../widgets/progress_indicator.dart';
import 'share_extension_page.dart';

class AwesomeIntroPage extends ConsumerWidget {
  const AwesomeIntroPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_back,
              color: Colors.black,
              size: 20,
            ),
          ),
        ),
        centerTitle: true,
        title: const OnboardingProgressIndicator(
          currentStep: 3,
          totalSteps: 5,
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: spacing.l),
        child: Column(
          children: [
            SizedBox(height: spacing.l),

            // Title
            const Text(
              'Share your style,\nfind the look',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 38,
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
                child: Stack(
                  children: [
                    Image.asset(
                      'assets/images/test.png',
                      fit: BoxFit.contain,
                      scale: 0.77,
                    ),
                    // White gradient overlay for fade effect
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.center,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.transparent,
                              Color(0x10FFFFFF),
                              Color(0x20FFFFFF),
                              Color(0x30FFFFFF),
                              Color(0x50FFFFFF),
                              Color(0x70FFFFFF),
                              Color(0x90FFFFFF),
                              Color(0xB0FFFFFF),
                              Color(0xD0FFFFFF),
                              Colors.white,
                            ],
                            stops: [0.0, 0.4, 0.5, 0.55, 0.6, 0.65, 0.7, 0.8, 0.85, 0.92, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: spacing.xl),

            // Description text
            const Text(
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

            SizedBox(height: spacing.xl * 2),

            // Show me how button
            Container(
              width: double.infinity,
              height: 56,
              margin: EdgeInsets.only(bottom: spacing.xxl),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ShareExtensionPage(),
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
          ],
        ),
      ),
    );
  }
}