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

  final ScrollController _scrollController = ScrollController();
  double _anchorOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _startSequence();

    // Capture the initial "anchor" scroll offset after first layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        _anchorOffset = _scrollController.offset;
      } else {
        _anchorOffset = 0.0;
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startSequence() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    setState(() => _showStep1 = true);
  }

  void _snapBackToAnchorIfNeeded() {
    if (!_scrollController.hasClients) return;

    // "Wrong way" = user pulled/scrolls above the anchor (typically overscroll / negative direction).
    if (_scrollController.offset < _anchorOffset) {
      _scrollController.animateTo(
        _anchorOffset,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    const double buttonHeight = 56;
    const double appBarHeight = kToolbarHeight; // 56

    final double topInset = MediaQuery.of(context).padding.top;
    final double bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,

      // ✅ no scaffold appBar
      body: Stack(
        children: [
          // 🔹 SCROLL CONTENT (goes behind app bar + button)
          NotificationListener<ScrollNotification>(
            onNotification: (n) {
              // Snap back when user lets go / scrolling ends.
              if (n is ScrollEndNotification) {
                _snapBackToAnchorIfNeeded();
              }
              return false;
            },
            child: SingleChildScrollView(
              controller: _scrollController,

              // Force overscroll behavior consistently (Android + iOS),
              // so "pulling the wrong way" can happen and then snap back.
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),

              padding: EdgeInsets.fromLTRB(
                spacing.l,
                spacing.l + appBarHeight + topInset, // keep title readable at rest
                spacing.l,
                spacing.l + buttonHeight + bottomInset, // allow content behind button
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

          // 🔹 FIXED BUTTON OVERLAY (no background overlay)
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
