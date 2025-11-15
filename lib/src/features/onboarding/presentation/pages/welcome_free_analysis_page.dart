import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../shared/navigation/main_navigation.dart';
import '../../../auth/domain/providers/auth_provider.dart';
import '../../../home/domain/providers/inspiration_provider.dart';
import '../../../credits/providers/credit_provider.dart';
import 'gender_selection_page.dart';
import 'notification_permission_page.dart';

class WelcomeFreeAnalysisPage extends ConsumerStatefulWidget {
  const WelcomeFreeAnalysisPage({super.key});

  @override
  ConsumerState<WelcomeFreeAnalysisPage> createState() => _WelcomeFreeAnalysisPageState();
}

class _WelcomeFreeAnalysisPageState extends ConsumerState<WelcomeFreeAnalysisPage>
    with SingleTickerProviderStateMixin {
  Future<void>? _initializationFuture;
  bool _isInitialized = false;
  late AnimationController _textAnimationController;
  late Animation<double> _textFadeAnimation;

  @override
  void initState() {
    super.initState();
    // Initialize user's free analysis
    _initializationFuture = _initializeFreeAnalysis();

    // Setup text fade animation
    _textAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textAnimationController, curve: Curves.easeIn),
    );

    // Start text fade-in after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _textAnimationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _textAnimationController.dispose();
    super.dispose();
  }

  Future<void> _initializeFreeAnalysis() async {
    try {
      final userId = ref.read(authServiceProvider).currentUser?.id;
      print('[WelcomePage] ==> Starting initialization');
      print('[WelcomePage] User ID: $userId');

      if (userId == null) {
        print('[WelcomePage] ERROR: No user ID found!');
        if (mounted) setState(() => _isInitialized = true);
        return;
      }

      // Save onboarding preferences FIRST
      final selectedGender = ref.read(selectedGenderProvider);
      final notificationGranted = ref.read(notificationPermissionGrantedProvider) ?? false;

      print('[WelcomePage] Selected gender from provider: ${selectedGender?.name}');
      print('[WelcomePage] Notification granted from provider: $notificationGranted');

      if (selectedGender == null) {
        print('[WelcomePage] ERROR: selectedGender is NULL! Cannot save preferences!');
        print('[WelcomePage] This should not happen - user should have selected gender');
        // Don't fail completely, but mark as initialized
        if (mounted) setState(() => _isInitialized = true);
        return;
      }

      print('[WelcomePage] Saving onboarding preferences...');
      final userService = ref.read(userServiceProvider);

      try {
        await userService.saveOnboardingPreferences(
          gender: selectedGender.name,
          notificationEnabled: notificationGranted,
        );
        print('[WelcomePage] SUCCESS: Saved gender=${selectedGender.name}, notifications=$notificationGranted');
      } catch (saveError) {
        print('[WelcomePage] ERROR saving preferences: $saveError');
        print('[WelcomePage] Stack trace: ${StackTrace.current}');
        rethrow;
      }

      // Initialize credits
      print('[WelcomePage] Initializing credits...');
      final creditService = ref.read(creditServiceProvider);
      await creditService.initializeNewUser(userId);
      print('[WelcomePage] Credits initialized');

      // Invalidate credit status to refresh UI
      ref.invalidate(creditStatusProvider);

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
      print('[WelcomePage] ==> Initialization complete successfully');
    } catch (e, stackTrace) {
      print('[WelcomePage] CRITICAL ERROR during initialization: $e');
      print('[WelcomePage] Stack trace: $stackTrace');

      if (mounted) {
        // Show error to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving preferences: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );

        setState(() {
          _isInitialized = true; // Allow navigation even if there's an error
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.l),
          child: Column(
            children: [
              const Spacer(),

              _CompletionBadge(),

              FadeTransition(
                opacity: _textFadeAnimation,
                child: Transform.translate(
                  offset: const Offset(0, -170),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.check_circle, color: Color(0xFF50d05c), size: 16),
                      SizedBox(width: 6),
                      Text(
                        'All done!',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'PlusJakartaSans',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              FadeTransition(
                opacity: _textFadeAnimation,
                child: Transform.translate(
                  offset: const Offset(0, -154),
                  child: const Text(
                    'Your fashion search\nstarts now!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: AppColors.tertiary,
                      fontFamily: 'PlusJakartaSans',
                      letterSpacing: -0.5,
                      height: 1.3,
                    ),
                  ),
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, -6),
              spreadRadius: 1,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, -1),
              spreadRadius: 0,
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          minimum: EdgeInsets.only(
            left: spacing.l,
            right: spacing.l,
            bottom: spacing.m,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: spacing.m),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () async {
                    HapticFeedback.mediumImpact();

                    // Wait for initialization to complete before navigating
                    if (_initializationFuture != null) {
                      print('[WelcomePage] Waiting for initialization to complete...');
                      await _initializationFuture;
                      print('[WelcomePage] Initialization finished, navigating to app');
                    }

                    if (mounted) {
                      // Reset to home tab and navigate to main app
                      ref.read(selectedIndexProvider.notifier).state = 0;
                      ref.invalidate(inspirationProvider);
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const MainNavigation(),
                        ),
                        (route) => false,
                      );
                    }
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
                    'Start Exploring',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'PlusJakartaSans',
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
              SizedBox(height: spacing.m),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: spacing.m),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: const TextSpan(
                    text: 'You get ',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                      fontFamily: 'PlusJakartaSans',
                      height: 1.5,
                    ),
                    children: [
                      TextSpan(
                        text: '1 free analysis',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFf2003c),
                          fontFamily: 'PlusJakartaSans',
                          fontWeight: FontWeight.bold,
                          height: 1.5,
                        ),
                      ),
                      TextSpan(
                        text: ' to try the app!',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                          fontFamily: 'PlusJakartaSans',
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: spacing.m),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletionBadge extends StatelessWidget {
  const _CompletionBadge();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 600,
      height: 600,
      child: Lottie.asset(
        'assets/animations/success_animation.json',
        repeat: false,
        fit: BoxFit.contain,
      ),
    );
  }
}
