import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../shared/widgets/snaplook_back_button.dart';
import '../widgets/onboarding_bottom_bar.dart';
import 'style_direction_page.dart';
import '../widgets/progress_indicator.dart';

class PersonalizationIntroPage extends StatefulWidget {
  const PersonalizationIntroPage({super.key});

  @override
  State<PersonalizationIntroPage> createState() =>
      _PersonalizationIntroPageState();
}

class _PersonalizationIntroPageState extends State<PersonalizationIntroPage> {
  final ScrollController _scrollController = ScrollController();
  double _anchorOffset = 0.0;
  bool _isSnapping = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        _anchorOffset = _scrollController.offset;
      }
    });
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

    // Match HowItWorksPage pattern:
    // Keep a simple bottom padding; don't try to measure the bottom bar.
    final double bottomPadding = spacing.l;

    const double topFadeHeight = 36;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: SnaplookBackButton(
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        centerTitle: true,
        title: const OnboardingProgressIndicator(
          currentStep: 5,
          totalSteps: 14,
        ),
      ),
      body: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (n) {
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
                    Colors.transparent,
                    Colors.black,
                  ],
                  stops: [
                    0.0,
                    fadeStop,
                  ],
                ).createShader(rect);
              },
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  spacing.l,
                  spacing.l + appBarHeight + topInset,
                  spacing.l,
                  bottomPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Let\'s tailor Snaplook to you',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontFamily: 'PlusJakartaSans',
                        letterSpacing: -1.0,
                        height: 1.1,
                      ),
                    ),
                    SizedBox(height: spacing.s),
                    const Text(
                      'A few quick choices help us fine-tune recommendations just for you.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
                        fontFamily: 'PlusJakartaSans',
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: spacing.l),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 220,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: AspectRatio(
                            aspectRatio: 3 / 4,
                            child: Image.asset(
                              'assets/images/mannequin.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
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
                  builder: (context) => const StyleDirectionPage(),
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
              'Sounds good',
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
