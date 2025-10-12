import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../widgets/progress_indicator.dart';
import 'trial_intro_page.dart';
import 'instagram_tutorial_page.dart';

class AddFirstStylePage extends ConsumerWidget {
  const AddFirstStylePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          currentStep: 5,
          totalSteps: 6,
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
              'Choose from the options below',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black,
                fontWeight: FontWeight.w500,
                fontFamily: 'PlusJakartaSans',
                letterSpacing: -0.3,
              ),
            ),

            SizedBox(height: spacing.xl),

            // Style Options Carousel
            Expanded(
              child: _CarouselSliderWidget(),
            ),

            SizedBox(height: spacing.l),

            // Skip Button
            GestureDetector(
              onTap: () {
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
                      color: Colors.grey,
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.2,
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

class _CarouselSliderWidget extends ConsumerWidget {
  const _CarouselSliderWidget();

  final List<Map<String, dynamic>> _cards = const [
    {
      'title': 'Evening Wear',
      'subtitle': 'Special occasions',
      'hasImage': false,
      'isInstagramTutorial': false,
    },
    {
      'title': 'Instagram Post',
      'subtitle': 'Learn to share from Instagram',
      'hasImage': true,
      'isInstagramTutorial': true,
    },
    {
      'title': 'Formal Wear',
      'subtitle': 'Business & Events',
      'hasImage': false,
      'isInstagramTutorial': false,
    },
    {
      'title': 'Streetwear',
      'subtitle': 'Urban fashion',
      'hasImage': false,
      'isInstagramTutorial': false,
    },
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CarouselSlider.builder(
      itemCount: _cards.length,
      itemBuilder: (context, index, realIndex) {
        final card = _cards[index];
        return _BigStyleCard(
          title: card['title'],
          subtitle: card['subtitle'],
          hasImage: card['hasImage'],
          isInstagramTutorial: card['isInstagramTutorial'],
        );
      },
      options: CarouselOptions(
        height: double.infinity,
        viewportFraction: 0.8,
        initialPage: 1, // Start with Instagram card (index 1)
        enableInfiniteScroll: true,
        enlargeCenterPage: true,
        enlargeFactor: 0.2,
        scrollDirection: Axis.horizontal,
      ),
    );
  }
}

class _BigStyleCard extends ConsumerWidget {
  final String title;
  final String subtitle;
  final bool hasImage;
  final bool isInstagramTutorial;

  const _BigStyleCard({
    required this.title,
    required this.subtitle,
    required this.hasImage,
    this.isInstagramTutorial = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;

    return GestureDetector(
      onTap: () {
        if (isInstagramTutorial) {
          // Reset tutorial to beginning before navigating
          ref.read(tutorialStepProvider.notifier).state = TutorialStep.viewPost;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const InstagramTutorialPage(),
            ),
          );
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
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            // Image area
            Expanded(
              flex: 4,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: hasImage ? null : Colors.grey.shade100,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: hasImage
                  ? ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                      child: Image.asset(
                        'assets/images/tutorial_analysis_image_2.jpg',
                        fit: BoxFit.cover,
                      ),
                    )
                  : Center(
                      child: Icon(
                        Icons.image_outlined,
                        size: 80,
                        color: Colors.grey.shade400,
                      ),
                    ),
              ),
            ),
            // Text area
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(spacing.l),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontFamily: 'PlusJakartaSans',
                    ),
                  ),
                  SizedBox(height: spacing.xs),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      fontFamily: 'PlusJakartaSans',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
