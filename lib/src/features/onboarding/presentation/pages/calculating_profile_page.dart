import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../services/analytics_service.dart';
import '../widgets/progress_indicator.dart';
import 'profile_ready_page.dart';

class CalculatingProfilePage extends StatefulWidget {
  const CalculatingProfilePage({super.key});

  @override
  State<CalculatingProfilePage> createState() => _CalculatingProfilePageState();
}

class _CalculatingProfilePageState extends State<CalculatingProfilePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;
  String _statusText = 'Analyzing your style preferences...';

  // Checklist items
  final List<String> _checklistItems = [
    'Style picks locked in',
    'Outfits matched to your taste',
    'Brand mix tuned to you',
    'Feed ready to explore',
  ];

  final List<bool> _checklistCompleted = [false, false, false, false];

  @override
  void initState() {
    super.initState();
    AnalyticsService().trackScreenView('onboarding_calculating_profile');

    _controller = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 100.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    )..addListener(() {
        setState(() {
          final progress = _progressAnimation.value;

          // Update status text
          if (progress < 25) {
            _statusText = 'Analyzing your style preferences...';
          } else if (progress < 50) {
            _statusText = 'Finding brands you\'ll love...';
          } else if (progress < 75) {
            _statusText = 'Matching products to your taste...';
          } else {
            _statusText = 'Finalizing results...';
          }

          // Update checklist
          if (progress >= 25 && !_checklistCompleted[0]) {
            _checklistCompleted[0] = true;
            HapticFeedback.mediumImpact();
          }
          if (progress >= 50 && !_checklistCompleted[1]) {
            _checklistCompleted[1] = true;
            HapticFeedback.mediumImpact();
          }
          if (progress >= 75 && !_checklistCompleted[2]) {
            _checklistCompleted[2] = true;
            HapticFeedback.mediumImpact();
          }
          if (progress >= 95 && !_checklistCompleted[3]) {
            _checklistCompleted[3] = true;
            HapticFeedback.mediumImpact();
          }
        });
      });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const ProfileReadyPage(),
              ),
            );
          }
        });
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const SizedBox(),
        centerTitle: true,
        title: const OnboardingProgressIndicator(
          currentStep: 10,
          totalSteps: 14,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.l),
          child: Column(
            children: [
              const Spacer(),

              // Large percentage display
              Text(
                '${_progressAnimation.value.round()}%',
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                  fontFamily: 'PlusJakartaSans',
                  letterSpacing: -1.5,
                  height: 1,
                ),
              ),

              SizedBox(height: spacing.l),

              // Title
              Text(
                'We\'re setting everything\nup for you',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                  fontFamily: 'PlusJakartaSans',
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),

              SizedBox(height: spacing.xl),

              // Progress bar
              AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _progressAnimation.value / 100,
                      minHeight: 8,
                      backgroundColor: colorScheme.outlineVariant,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.secondary,
                      ),
                    ),
                  );
                },
              ),

              SizedBox(height: spacing.l),

              // Status text
              Text(
                _statusText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurfaceVariant,
                  fontFamily: 'PlusJakartaSans',
                  height: 1.5,
                ),
              ),

              SizedBox(height: spacing.xl),

              // Checklist section
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(spacing.l),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Here\'s what we tuned for you',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                    SizedBox(height: spacing.m),
                    ..._checklistItems.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      final isCompleted = _checklistCompleted[index];

                      return Padding(
                        padding: EdgeInsets.only(bottom: spacing.s),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: isCompleted
                                    ? colorScheme.onSurface
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isCompleted
                                      ? colorScheme.onSurface
                                      : colorScheme.outline,
                                  width: 2,
                                ),
                              ),
                              child: isCompleted
                                  ? Icon(
                                      Icons.check,
                                      size: 16,
                                      color: colorScheme.surface,
                                    )
                                  : null,
                            ),
                            SizedBox(width: spacing.m),
                            Text(
                              item,
                              style: TextStyle(
                                fontSize: 14,
                                color: isCompleted
                                    ? colorScheme.onSurface
                                    : colorScheme.onSurfaceVariant,
                                fontFamily: 'PlusJakartaSans',
                                fontWeight: isCompleted
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),

              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
