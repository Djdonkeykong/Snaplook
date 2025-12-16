import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../shared/widgets/snaplook_back_button.dart';
import '../widgets/onboarding_bottom_bar.dart';
import 'gender_selection_page.dart';

class HowItWorksPage extends StatefulWidget {
  const HowItWorksPage({super.key});

  @override
  State<HowItWorksPage> createState() => _HowItWorksPageState();
}

class _HowItWorksPageState extends State<HowItWorksPage> {
  bool _showStep1 = false;
  double _fade = 1.0;
  static const double _fadeThreshold = 140;

  @override
  void initState() {
    super.initState();
    _startSequence();
  }

  Future<void> _startSequence() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    setState(() => _showStep1 = true);
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: SnaplookBackButton(),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            spacing.l,
            spacing.l,
            spacing.l,
            spacing.l,
          ),
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollUpdateNotification) {
                final offset = notification.metrics.pixels;
                final fade = (1 - (offset / _fadeThreshold)).clamp(0.0, 1.0);
                if (fade != _fade) setState(() => _fade = fade);
              }
              return false;
            },
            child: Stack(
              children: [
                SingleChildScrollView(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 160),
                    opacity: _fade,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'How Snaplook works',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            fontFamily: 'PlusJakartaSans',
                            letterSpacing: -1.0,
                            height: 1.2,
                          ),
                        ),
                        SizedBox(height: spacing.l),
                        Center(
                          child: _StepFrame(
                            label: '1',
                            assetPath: 'assets/images/photos_step1.png',
                            visible: _showStep1,
                            maxWidth: 360,
                            aspectRatio: 0.56,
                          ),
                        ),
                        SizedBox(height: spacing.l),
                      ],
                    ),
                  ),
                ),
                IgnorePointer(
                  child: Container(
                    height: 120,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white,
                          Colors.white54,
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
  final double maxWidth;
  final double aspectRatio;

  const _StepFrame({
    required this.label,
    required this.assetPath,
    required this.visible,
    required this.maxWidth,
    required this.aspectRatio,
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
            LayoutBuilder(builder: (context, constraints) {
              final double width =
                  constraints.maxWidth.clamp(0, maxWidth).toDouble(); // limit desktop
              return Align(
                alignment: Alignment.center,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: SizedBox(
                    width: width,
                    height: width / aspectRatio,
                    child: Image.asset(
                      assetPath,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
