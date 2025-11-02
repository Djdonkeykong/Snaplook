import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../widgets/progress_indicator.dart';
import 'trial_intro_page.dart';
import 'instagram_tutorial_page.dart';
import 'pinterest_tutorial_page.dart';
import 'tiktok_tutorial_page.dart';
import 'safari_tutorial_page.dart';
import 'photos_tutorial_page.dart';

class AddFirstStylePage extends ConsumerStatefulWidget {
  const AddFirstStylePage({super.key});

  @override
  ConsumerState<AddFirstStylePage> createState() => _AddFirstStylePageState();
}

class _AddFirstStylePageState extends ConsumerState<AddFirstStylePage> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Precache all images for instant loading
    precacheImage(const AssetImage('assets/images/tutorial_analysis_image_2.jpg'), context);
    precacheImage(const AssetImage('assets/images/pinterest_tutorial.jpg'), context);
    precacheImage(const AssetImage('assets/images/tiktok_tutorial.jpg'), context);
    precacheImage(const AssetImage('assets/images/safari_tutorial.webp'), context);
    precacheImage(const AssetImage('assets/images/photos_tutorial.jpg'), context);
    precacheImage(const AssetImage('assets/icons/insta.png'), context);
    precacheImage(const AssetImage('assets/icons/tiktok.png'), context);
    precacheImage(const AssetImage('assets/icons/safari.png'), context);
    precacheImage(const AssetImage('assets/icons/photos.png'), context);
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
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
          currentStep: 4,
          totalSteps: 5,
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
              'Add your first style',
              style: TextStyle(
                fontSize: 34,
                fontFamily: 'PlusJakartaSans',
                letterSpacing: -1.0,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                height: 1.3,
              ),
            ),

            SizedBox(height: spacing.m),

            // Subtitle
            const Text(
              'Learn to share from your favorite apps',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black,
                fontWeight: FontWeight.w500,
                fontFamily: 'PlusJakartaSans',
                letterSpacing: -0.3,
              ),
            ),

            SizedBox(height: spacing.xl),

            // App Grid
            Expanded(
              child: _AppGrid(),
            ),

            SizedBox(height: spacing.l),

            // Skip Button
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const TrialIntroPage(),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                margin: EdgeInsets.only(bottom: spacing.xxl),
                child: const Center(
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.black,
                      decorationThickness: 1.5,
                    ),
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

class _AppGrid extends ConsumerWidget {
  const _AppGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;

    return GridView.builder(
      padding: EdgeInsets.only(bottom: spacing.m),
      physics: const BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: spacing.m,
        mainAxisSpacing: spacing.m,
        childAspectRatio: 1.0,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        switch (index) {
          case 0:
            return _AppCard(
              name: 'Instagram',
              iconWidget:
                  Image.asset('assets/icons/insta.png', width: 28, height: 28, gaplessPlayback: true),
              hasTutorial: true,
              imagePath: 'assets/images/tutorial_analysis_image_2.jpg',
            );
          case 1:
            return _AppCard(
              name: 'Pinterest',
              iconWidget: SvgPicture.asset('assets/icons/pinterest.svg',
                  width: 28, height: 28),
              hasTutorial: true,
              imagePath: 'assets/images/pinterest_tutorial.jpg',
              imageAlignment: Alignment.topCenter,
              isPinterest: true,
            );
          case 2:
            return _AppCard(
              name: 'TikTok',
              iconWidget:
                  Image.asset('assets/icons/tiktok.png', width: 48, height: 48, gaplessPlayback: true),
              hasTutorial: true,
              imagePath: 'assets/images/tiktok_tutorial.jpg',
              isTikTok: true,
            );
          case 3:
            return _AppCard(
              name: 'Safari',
              iconWidget:
                  Image.asset('assets/icons/safari.png', width: 28, height: 28, gaplessPlayback: true),
              hasTutorial: true,
              imagePath: 'assets/images/safari_tutorial.webp',
              isSafari: true,
            );
          case 4:
            return _AppCard(
              name: 'Photos',
              iconWidget:
                  Image.asset('assets/icons/photos.png', width: 28, height: 28, gaplessPlayback: true),
              hasTutorial: true,
              imagePath: 'assets/images/photos_tutorial.jpg',
              isPhotos: true,
            );
          case 5:
          default:
            return _AppCard(
              name: 'Other Apps',
              iconWidget:
                  Icon(Icons.apps, size: 28, color: Colors.grey.shade700),
              hasTutorial: false,
              imagePath: null,
            );
        }
      },
    );
  }
}

class _AppCard extends ConsumerWidget {
  final String name;
  final Widget iconWidget;
  final bool hasTutorial;
  final String? imagePath;
  final Alignment? imageAlignment;
  final bool isPinterest;
  final bool isTikTok;
  final bool isSafari;
  final bool isPhotos;

  const _AppCard({
    required this.name,
    required this.iconWidget,
    required this.hasTutorial,
    this.imagePath,
    this.imageAlignment,
    this.isPinterest = false,
    this.isTikTok = false,
    this.isSafari = false,
    this.isPhotos = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        if (hasTutorial) {
          if (isPinterest) {
            // Reset Pinterest tutorial to beginning before navigating
            ref.read(pinterestTutorialStepProvider.notifier).state =
                PinterestTutorialStep.step1;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const PinterestTutorialPage(),
              ),
            );
          } else if (isTikTok) {
            // Reset TikTok tutorial to beginning before navigating
            ref.read(tiktokTutorialStepProvider.notifier).state =
                TikTokTutorialStep.step1;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const TikTokTutorialPage(),
              ),
            );
          } else if (isSafari) {
            ref.read(safariTutorialStepProvider.notifier).state =
                SafariTutorialStep.step1;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const SafariTutorialPage(),
              ),
            );
          } else if (isPhotos) {
            // Reset Photos tutorial to beginning before navigating
            ref.read(photosTutorialStepProvider.notifier).state =
                PhotosTutorialStep.step1;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const PhotosTutorialPage(),
              ),
            );
          } else {
            // Reset Instagram tutorial to beginning before navigating
            ref.read(tutorialStepProvider.notifier).state =
                TutorialStep.tapShare;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const InstagramTutorialPage(),
              ),
            );
          }
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const TrialIntroPage(),
            ),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: imagePath != null
              ? null
              : Border.all(color: Colors.grey.shade200, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            children: [
              // Background image (if available)
              if (imagePath != null)
                Positioned.fill(
                  child: Image.asset(
                    imagePath!,
                    fit: BoxFit.cover,
                    alignment: imageAlignment ?? Alignment.center,
                    gaplessPlayback: true,
                  ),
                ),

              // Flat overlay for readability
              if (imagePath != null)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.4),
                  ),
                ),

              // Content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // App Icon
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: imagePath != null
                            ? Colors.white.withOpacity(0.95)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: imagePath != null
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(child: iconWidget),
                    ),

                    SizedBox(height: spacing.m),

                    // App Name
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: imagePath != null ? Colors.white : Colors.black,
                        fontFamily: 'PlusJakartaSans',
                        letterSpacing: -0.2,
                        shadows: imagePath != null
                            ? [
                                const Shadow(
                                  offset: Offset(0, 1),
                                  blurRadius: 3,
                                  color: Colors.black45,
                                ),
                              ]
                            : null,
                      ),
                    ),

                    SizedBox(height: spacing.xs),

                    // Tap to learn hint
                    Text(
                      'Tap to learn',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: imagePath != null
                            ? Colors.white.withOpacity(0.9)
                            : Colors.grey.shade500,
                        fontFamily: 'PlusJakartaSans',
                        letterSpacing: -0.1,
                        shadows: imagePath != null
                            ? [
                                const Shadow(
                                  offset: Offset(0, 1),
                                  blurRadius: 2,
                                  color: Colors.black45,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
