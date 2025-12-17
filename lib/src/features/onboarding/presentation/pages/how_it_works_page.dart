import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../shared/widgets/snaplook_back_button.dart';
import '../widgets/onboarding_bottom_bar.dart';
import 'awesome_intro_page.dart';
import '../widgets/progress_indicator.dart';

class HowItWorksPage extends StatefulWidget {
  const HowItWorksPage({super.key});

  @override
  State<HowItWorksPage> createState() => _HowItWorksPageState();
}

class _HowItWorksPageState extends State<HowItWorksPage> {
  final ScrollController _scrollController = ScrollController();
  double _anchorOffset = 0.0;
  bool _isSnapping = false;
  bool _didPrecacheShareImage = false;

  @override
  void initState() {
    super.initState();
    // Capture anchor after first layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        _anchorOffset = _scrollController.offset;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrecacheShareImage) return;
    _didPrecacheShareImage = true;

    // Preload the "Share your style" artwork before navigating to that page to avoid a flash
    precacheImage(
      const AssetImage('assets/images/social_media_share_mobile_screen.png'),
      context,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _snapBackToAnchor() {
    if (!_scrollController.hasClients || _isSnapping) return;

    final double currentOffset = _scrollController.offset;
    if ((currentOffset - _anchorOffset).abs() < 0.5) return;

    _isSnapping = true;
    _scrollController
        .animateTo(
      _anchorOffset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    )
        .whenComplete(() {
      _isSnapping = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    const double appBarHeight = kToolbarHeight;

    final double topInset = MediaQuery.of(context).padding.top;

    // ✅ How tall the fade zone is at the very top of the scroll viewport.
    const double topFadeHeight = 36;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 🔹 SCROLL CONTENT (anchored) + TOP FADE
          NotificationListener<ScrollNotification>(
            onNotification: (n) {
              // Snap back to the anchor whenever a gesture ends in any direction.
              if (n is ScrollEndNotification ||
                  (n is UserScrollNotification &&
                      n.direction == ScrollDirection.idle)) {
                _snapBackToAnchor();
              }
              return false;
            },
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (Rect rect) {
                final double fadeStop =
                    (topFadeHeight / rect.height).clamp(0.0, 1.0);

                return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: const [
                    Colors.transparent, // fully faded at very top
                    Colors.black, // fully visible after fade zone
                  ],
                  stops: [
                    0.0,
                    fadeStop,
                  ],
                ).createShader(rect);
              },
              child: SingleChildScrollView(
                controller: _scrollController,

                // ✅ Remove "always scrollable" behavior so short pages don't create
                // extra scrollable space / bounce gap.
                physics: const BouncingScrollPhysics(),

                // ✅ Remove bottom padding completely.
                padding: EdgeInsets.fromLTRB(
                  spacing.l,
                  spacing.l + appBarHeight + topInset,
                  spacing.l,
                  0,
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
                        assetPath: 'assets/images/how_it_works.png',
                        maxWidth: 320,
                        aspectRatio: 792 / 1285,
                      ),
                    ),

                    // ✅ Removed the trailing SizedBox that added space under the image.
                    // SizedBox(height: spacing.l),
                  ],
                ),
              ),
            ),
          ),

          // 🔹 APP BAR OVERLAY
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
                  centerTitle: true,
                  title: const OnboardingProgressIndicator(
                    currentStep: 1,
                    totalSteps: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
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

class _StepFrame extends StatelessWidget {
  final String label;
  final String assetPath;
  final bool visible;
  final double maxWidth;
  final double aspectRatio;

  const _StepFrame({
    required this.label,
    required this.assetPath,
    this.visible = true,
    required this.maxWidth,
    required this.aspectRatio,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 450),
      opacity: visible ? 1 : 0,
      curve: Curves.easeOut,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 450),
        scale: visible ? 1 : 0.98,
        curve: Curves.easeOut,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double width =
                constraints.maxWidth.clamp(0, maxWidth).toDouble();
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
      ),
    );
  }
}
