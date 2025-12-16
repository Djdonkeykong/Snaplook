import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../shared/widgets/snaplook_back_button.dart';
import 'gender_selection_page.dart';

class HowItWorksPage extends StatefulWidget {
  const HowItWorksPage({super.key});

  @override
  State<HowItWorksPage> createState() => _HowItWorksPageState();
}

class _HowItWorksPageState extends State<HowItWorksPage> {
  bool _showStep1 = false;

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
  const double buttonHeight = 56;
  final double topInset = MediaQuery.of(context).padding.top;
  final double bottomInset = MediaQuery.of(context).padding.bottom;

  const double appBarHeight = kToolbarHeight; // 56

  return Scaffold(
    backgroundColor: AppColors.background,

    // ✅ no scaffold appBar
    body: Stack(
      children: [
        // 🔹 SCROLL CONTENT (goes behind app bar + button)
        SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            spacing.l,
            spacing.l + appBarHeight + topInset, // keep title readable
            spacing.l,
            spacing.l + buttonHeight + bottomInset,
          ),
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

        // 🔹 APP BAR OVERLAY (no reserved space)
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: appBarHeight,
              child: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                leading: SnaplookBackButton(),
              ),
            ),
          ),
        ),

        // 🔹 FIXED BUTTON OVERLAY
        Positioned(
          left: spacing.l,
          right: spacing.l,
          bottom: spacing.l + bottomInset,
          child: SizedBox(
            height: buttonHeight,
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
      ],
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
            LayoutBuilder(
              builder: (context, constraints) {
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
              },
            ),
          ],
        ),
      ),
    );
  }
}
