import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../shared/widgets/snaplook_back_button.dart';
import '../widgets/onboarding_bottom_bar.dart';
import '../widgets/progress_indicator.dart';
import 'awesome_intro_page.dart';

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
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  size: 32,
                  color: Colors.white,
                ),
              ),

              SizedBox(height: spacing.xl),

              // Title
              const Text(
                'Your Snaplook is ready',
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

              // Profile snapshot card
              SizedBox(height: spacing.l),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(spacing.l),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFDE8EF),
                      Color(0xFFE7EEFF),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Profile snapshot',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Catalog: Men's & Women's",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Focus: Nike, Zara, Uniqlo',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _TagChip(label: 'Streetwear'),
                        _TagChip(label: 'Casual'),
                        _TagChip(label: 'Clean lines'),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: spacing.l),

              // Feed preview strip
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 4,
                  separatorBuilder: (_, __) => SizedBox(width: spacing.m),
                  itemBuilder: (context, index) {
                    final labels = [
                      'Streetwear picks',
                      'Work-ready fits',
                      'Weekend casual',
                      'Clean layers',
                    ];
                    final colors = [
                      const Color(0xFFf2003c),
                      const Color(0xFF6B9DFF),
                      const Color(0xFFFFA726),
                      Colors.black,
                    ];
                    return Container(
                      width: 180,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colors[index % colors.length].withOpacity(0.1),
                            Colors.white,
                          ],
                        ),
                        border:
                            Border.all(color: Colors.black.withOpacity(0.05)),
                      ),
                      padding: EdgeInsets.all(spacing.m),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            color: colors[index % colors.length],
                          ),
                          Text(
                            labels[index % labels.length],
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                              fontFamily: 'PlusJakartaSans',
                            ),
                          ),
                          const Text(
                            'Peek the lineup we picked for you.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                              fontFamily: 'PlusJakartaSans',
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              SizedBox(height: spacing.l),

              // Quick highlights
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(spacing.l),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F9F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Here\'s what we tuned for you',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      '• Style picks locked in',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                        fontFamily: 'PlusJakartaSans',
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Outfits matched to your taste',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                        fontFamily: 'PlusJakartaSans',
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Feed ready to explore',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                        fontFamily: 'PlusJakartaSans',
                        height: 1.4,
                      ),
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
                  builder: (context) => const AwesomeIntroPage(),
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
