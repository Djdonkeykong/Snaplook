import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

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
  bool _isSnapping = false;

  @override
  void initState() {
    super.initState();
    _startSequence();

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

  Future<void> _startSequence() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    setState(() => _showStep1 = true);
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
        .whenComplete(() => _isSnapping = false);
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    const double buttonHeight = 56;
    const double appBarHeight = kToolbarHeight;

    final double topInset = MediaQuery.of(context).padding.top;
    final double bottomInset = MediaQuery.of(context).padding.bottom;

    // How close you want the button to the bottom (above the home indicator zone).
    const double buttonGap = 8;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ✅ Paint background edge-to-edge (kills any white bars behind system UI)
          Positioned.fill(
            child: Container(color: AppColors.background),
          ),

          // 🔹 SCROLL CONTENT
          NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n is ScrollEndNotification ||
                  (n is UserScrollNotification &&
                      n.direction == ScrollDirection.idle)) {
                _snapBackToAnchor();
              }
              return false;
            },
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    spacing.l,
                    // content starts below status bar + app bar
                    spacing.l + topInset + appBarHeight,
                    spacing.l,
                    // reserve space so last content doesn't hide under the button
                    bottomInset + buttonHeight + buttonGap,
                  ),
                  sliver: SliverToBoxAdapter(
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
                            maxWidth: 320,
                            aspectRatio: 0.56,
                          ),
                        ),
                        SizedBox(height: spacing.l),
                      ],
                    ),
                  ),
                ),

                // ✅ Makes the scroll view "fill the screen" so it doesn't look like there's
                // empty space when content is short.
                const SliverFillRemaining(
                  hasScrollBody: false,
                  fillOverscroll: true,
                  child: SizedBox.shrink(),
                ),
              ],
            ),
          ),

          // 🔹 APP BAR OVERLAY (positioned manually; background is already filled)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SizedBox(
              height: topInset + appBarHeight,
              child: Padding(
                padding: EdgeInsets.only(top: topInset),
                child: AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  leading: SnaplookBackButton(),
                ),
              ),
            ),
          ),

          // ✅ Fill ONLY the home-indicator area with your background color
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: bottomInset,
            child: Container(color: AppColors.background),
          ),

          // 🔹 FIXED BUTTON OVERLAY (sits on top at the bottom)
          Positioned(
            left: spacing.l,
            right: spacing.l,
            bottom: 52,
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
