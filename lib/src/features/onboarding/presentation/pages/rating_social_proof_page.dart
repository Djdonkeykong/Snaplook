import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../shared/widgets/snaplook_back_button.dart';
import '../widgets/onboarding_bottom_bar.dart';
import '../widgets/progress_indicator.dart';
import 'notification_permission_page.dart';

class RatingSocialProofPage extends StatelessWidget {
  const RatingSocialProofPage({
    super.key,
    this.continueToTrialFlow = false,
  });

  final bool continueToTrialFlow;

  static const _avatarImages = [
    'assets/images/instagram_tutorial.jpg',
    'assets/images/pinterest_tutorial.jpg',
    'assets/images/tiktok_tutorial.jpg',
  ];

  static const _testimonials = [
    _Testimonial(
      name: 'Jake Sullivan',
      quote:
          'I lost 15 lbs in 2 months! I was about to go on Ozempic but decided to give this app a shot and it worked :)',
      avatarPath: 'assets/images/instagram_tutorial.jpg',
    ),
    _Testimonial(
      name: 'Benny Marcs',
      quote:
          'Snaplook keeps me inspired every day. I never run out of outfit ideas anymore.',
      avatarPath: 'assets/images/pinterest_tutorial.jpg',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final radius = context.radius;
    final currentStep = continueToTrialFlow ? 5 : 4;
    final totalSteps = continueToTrialFlow ? 10 : 6;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const SnaplookBackButton(),
        centerTitle: true,
        title: OnboardingProgressIndicator(
          currentStep: currentStep,
          totalSteps: totalSteps,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              EdgeInsets.symmetric(horizontal: spacing.l, vertical: spacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Give us a rating',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontFamily: 'PlusJakartaSans',
                  letterSpacing: -1.0,
                  height: 1.3,
                ),
              ),
              SizedBox(height: spacing.l),
              _RatingHighlightCard(radius: radius.large),
              SizedBox(height: spacing.xl),
              const Text(
                'Snaplook was made for\npeople like you',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                  fontFamily: 'PlusJakartaSans',
                  letterSpacing: -0.6,
                  height: 1.3,
                ),
              ),
              SizedBox(height: spacing.m),
              _AvatarRow(images: _avatarImages),
              SizedBox(height: spacing.s),
              const Text(
                '5M+ Snaplook users',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              SizedBox(height: spacing.xl),
              ..._testimonials.map(
                (testimonial) => Padding(
                  padding: EdgeInsets.only(bottom: spacing.m),
                  child: _TestimonialCard(testimonial: testimonial),
                ),
              ),
              SizedBox(height: spacing.l),
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
                  builder: (context) => NotificationPermissionPage(
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

class _RatingHighlightCard extends StatelessWidget {
  const _RatingHighlightCard({
    required this.radius,
  });

  final double radius;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Container(
      width: double.infinity,
      padding:
          EdgeInsets.symmetric(horizontal: spacing.l, vertical: spacing.l + 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFFFFF4E5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events_outlined,
              color: Color(0xFFFFA726),
              size: 30,
            ),
          ),
          SizedBox(width: spacing.m),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    '4.8',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      fontFamily: 'PlusJakartaSans',
                    ),
                  ),
                  SizedBox(width: spacing.s),
                  ...List.generate(
                    5,
                    (index) => const Padding(
                      padding: EdgeInsets.only(right: 2),
                      child: Icon(
                        Icons.star,
                        color: Color(0xFFFFA726),
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: spacing.xs),
              const Text(
                '200K+ App Ratings',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AvatarRow extends StatelessWidget {
  const _AvatarRow({required this.images});

  final List<String> images;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Stack(
        children: images.asMap().entries.map((entry) {
          final index = entry.key;
          final image = entry.value;
          return Positioned(
            left: index * 48,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: ClipOval(
                child: Image.asset(
                  image,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TestimonialCard extends StatelessWidget {
  const _TestimonialCard({required this.testimonial});

  final _Testimonial testimonial;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final radius = context.radius;

    return Container(
      padding: EdgeInsets.all(spacing.m),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius.large),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: AssetImage(testimonial.avatarPath),
              ),
              SizedBox(width: spacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      testimonial.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: List.generate(
                        5,
                        (index) => const Padding(
                          padding: EdgeInsets.only(right: 2),
                          child: Icon(
                            Icons.star,
                            size: 16,
                            color: Color(0xFFFFA726),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.m),
          Text(
            testimonial.quote,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _Testimonial {
  final String name;
  final String quote;
  final String avatarPath;

  const _Testimonial({
    required this.name,
    required this.quote,
    required this.avatarPath,
  });
}
