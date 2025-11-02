import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import 'tutorial_image_analysis_page.dart';

class TutorialAnalysisPage extends StatefulWidget {
  final String? imagePath;
  final String scenario;

  const TutorialAnalysisPage({
    super.key,
    this.imagePath,
    this.scenario = 'Instagram',
  });

  @override
  State<TutorialAnalysisPage> createState() => _TutorialAnalysisPageState();
}

class _TutorialAnalysisPageState extends State<TutorialAnalysisPage> with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();

    // Create animation controller for smooth progress
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 2800),
      vsync: this,
    );

    // Animate from 0 to 0.95 (never quite reaches 100%, matching Swift controller)
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));

    // Start the animation
    _progressController.forward();

    // Auto-navigate to results after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => TutorialImageAnalysisPage(
              imagePath: widget.imagePath,
              scenario: widget.scenario,
            ),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(spacing.l),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Importing text
                const Text(
                  'Importing image...',
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: spacing.m),

                // Linear progress bar matching Swift controller
                AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, child) {
                    return Container(
                      width: 180,
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: Colors.grey.shade300,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: _progressAnimation.value,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFf2003c), // Munsell red matching Swift controller
                          ),
                          minHeight: 6,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

