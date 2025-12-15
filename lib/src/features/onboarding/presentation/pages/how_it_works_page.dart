import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../shared/widgets/snaplook_back_button.dart';
import '../widgets/onboarding_bottom_bar.dart';
import '../widgets/progress_indicator.dart';
import 'gender_selection_page.dart';

class HowItWorksPage extends StatefulWidget {
  const HowItWorksPage({super.key});

  @override
  State<HowItWorksPage> createState() => _HowItWorksPageState();
}

class _HowItWorksPageState extends State<HowItWorksPage> {
  bool _showStep1 = false;
  bool _showStep2 = false;
  bool _showStep3 = false;

  @override
  void initState() {
    super.initState();
    _startSequence();
  }

  Future<void> _startSequence() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    setState(() => _showStep1 = true);

    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _showStep2 = true);

    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _showStep3 = true);
  }

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
          currentStep: 1,
          totalSteps: 20,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            spacing.l,
            spacing.m,
            spacing.l,
            spacing.l,
          ),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _StepFrame(
                      label: '1',
                      assetPath: 'assets/images/photos_step1.png',
                      visible: _showStep1,
                    ),
                    SizedBox(height: spacing.l),
                    _StepFrame(
                      label: '2',
                      assetPath: 'assets/images/photos-step-2.png',
                      visible: _showStep2,
                    ),
                    SizedBox(height: spacing.l),
                    _StepFrame(
                      label: '3',
                      assetPath: 'assets/images/photos-step-3-snaplook.png',
                      visible: _showStep3,
                    ),
                  ],
                ),
              ),
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
                  builder: (context) => const GenderSelectionPage(),
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
              'Set up my style',
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

class _StepFrame extends StatelessWidget {
  final String label;
  final String assetPath;
  final bool visible;

  const _StepFrame({
    required this.label,
    required this.assetPath,
    required this.visible,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 450),
      opacity: visible ? 1 : 0,
      curve: Curves.easeOut,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 450),
        scale: visible ? 1 : 0.98,
        curve: Curves.easeOut,
        child: Stack(
          alignment: Alignment.topLeft,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AspectRatio(
                aspectRatio: 0.58,
                child: Image.asset(
                  assetPath,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              top: spacing.s,
              left: spacing.s,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
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
