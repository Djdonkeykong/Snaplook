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

  Future<void> _startSequence() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    setState(() => _showStep1 = true);
  }

  void _snapBackToAnchor() {
    if (!_scrollController.hasClients || _isSnapping) return;

    final currentOffset = _scrollController.offset;
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

    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          /// 🔹 SCROLL CONTENT
          NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n is ScrollEndNotification ||
                  (n is UserScrollNotification &&
                      n.direction == ScrollDirection.idle)) {
                _snapBackToAnchor();
              }
              return false;
            },
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(
                spacing.l,
                spacing.l + appBarHeight + topInset,
                spacing.l,
                buttonHeight + 12, // only reserve for button
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'How Snaplook works',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
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
                ],
              ),
            ),
          ),

          /// 🔹 APP BAR
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: SnaplookBackButton(),
              ),
            ),
          ),

          /// 🔹 BOTTOM BACKGROUND (kills white bar)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: bottomInset,
            child: Container(color: AppColors.background),
          ),

          /// 🔹 FIXED BUTTON
          Positioned(
            left: spacing.l,
            right: spacing.l,
            bottom: 6, // visually flush
            child: SizedBox(
              height: buttonHeight,
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const GenderSelectionPage(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFf2003c),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: const Text(
                  'Set up my style',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
