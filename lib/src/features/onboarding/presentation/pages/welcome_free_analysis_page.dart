import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../shared/navigation/main_navigation.dart';
import '../../../auth/domain/providers/auth_provider.dart';
import '../../../home/domain/providers/inspiration_provider.dart';
import '../../../paywall/providers/credit_provider.dart';
import '../../../user/repositories/user_profile_repository.dart';
import 'notification_permission_page.dart';
import '../../../../services/onboarding_state_service.dart';
import '../../../../services/notification_service.dart';
import '../widgets/onboarding_bottom_bar.dart';
import '../../domain/providers/gender_provider.dart';

class WelcomeFreeAnalysisPage extends ConsumerStatefulWidget {
  const WelcomeFreeAnalysisPage({super.key});

  @override
  ConsumerState<WelcomeFreeAnalysisPage> createState() => _WelcomeFreeAnalysisPageState();
}

class _WelcomeFreeAnalysisPageState extends ConsumerState<WelcomeFreeAnalysisPage>
    with SingleTickerProviderStateMixin {
  Future<void>? _initializationFuture;
  bool _isInitialized = false;
  bool _animationLoaded = false;
  late AnimationController _textAnimationController;
  late Animation<double> _textFadeAnimation;

  @override
  void initState() {
    super.initState();

    // Precache Lottie animation to prevent jitter
    _precacheLottieAnimation();

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

  Future<void> _precacheLottieAnimation() async {
    try {
      // Load the Lottie animation into cache
      await rootBundle.load('assets/animations/congratulations.json');
      if (mounted) {
        setState(() {
          _animationLoaded = true;
        });
      }
    } catch (e) {
      print('[WelcomePage] Error precaching animation: $e');
      // Still show the page even if animation fails to load
      if (mounted) {
        setState(() {
          _animationLoaded = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _textAnimationController.dispose();
    super.dispose();
  }

  Future<void> _initializeFreeAnalysis() async {
    try {
      final userId = ref.read(authServiceProvider).currentUser?.id;
      debugPrint('');
      debugPrint('=====================================================');
      debugPrint('[WelcomePage] ==> Starting initialization');
      debugPrint('[WelcomePage] User ID: $userId');
      debugPrint('=====================================================');

      if (userId == null) {
        debugPrint('[WelcomePage] ERROR: No user ID found!');
        if (mounted) setState(() => _isInitialized = true);
        return;
      }

      // Update checkpoint to 'welcome' to mark this stage of onboarding
      debugPrint('[WelcomePage] Updating checkpoint to welcome...');
      try {
        await OnboardingStateService().updateCheckpoint(
          userId,
          OnboardingCheckpoint.welcome,
        );
        debugPrint('[WelcomePage] Checkpoint updated to welcome');
      } catch (checkpointError) {
        debugPrint('[WelcomePage] Error updating checkpoint: $checkpointError');
        // Non-critical - continue
      }

      // IMPORTANT: If user went through onboarding BEFORE account creation,
      // preferences are stored in providers but NOT saved to database yet.
      // We need to save them now that we have a user ID.

      // Read preferences from providers
      final selectedGender = ref.read(selectedGenderProvider);
      final notificationGranted = ref.read(notificationPermissionGrantedProvider);

      debugPrint('');
      debugPrint('[WelcomePage] ===== CHECKING PROVIDERS =====');
      debugPrint('[WelcomePage] Gender from provider: ${selectedGender?.name}');
      debugPrint('[WelcomePage] Notification permission from provider: $notificationGranted');
      debugPrint('[WelcomePage] ================================');

      // Map Gender enum to preferred_gender_filter
      String? preferredGenderFilter;
      if (selectedGender != null) {
        switch (selectedGender) {
          case Gender.male:
            preferredGenderFilter = 'men';
            break;
          case Gender.female:
            preferredGenderFilter = 'women';
            break;
          case Gender.other:
            preferredGenderFilter = 'all';
            break;
        }
        debugPrint('[WelcomePage] Mapped gender ${selectedGender.name} to filter: $preferredGenderFilter');
      }

      // Save preferences to database
      if (preferredGenderFilter != null || notificationGranted != null) {
        debugPrint('');
        debugPrint('[WelcomePage] ===== SAVING PREFERENCES TO DATABASE =====');
        debugPrint('[WelcomePage] User ID: $userId');
        debugPrint('[WelcomePage] Gender filter: $preferredGenderFilter');
        debugPrint('[WelcomePage] Notification enabled: $notificationGranted');
        try {
          await OnboardingStateService().saveUserPreferences(
            userId: userId,
            preferredGenderFilter: preferredGenderFilter,
            notificationEnabled: notificationGranted,
          );
          debugPrint('[WelcomePage] SUCCESS: Preferences saved to database');
          debugPrint('[WelcomePage] ==========================================');
        } catch (saveError, stackTrace) {
          debugPrint('[WelcomePage] ERROR saving preferences: $saveError');
          debugPrint('[WelcomePage] Stack trace: $stackTrace');
          debugPrint('[WelcomePage] ==========================================');
          // Non-critical - allow user to continue
        }
      } else {
        debugPrint('[WelcomePage] WARNING: No preferences to save!');
        debugPrint('[WelcomePage] - preferredGenderFilter: $preferredGenderFilter');
        debugPrint('[WelcomePage] - notificationGranted: $notificationGranted');
      }

      // If notification permission was granted, initialize FCM and register token
      // This needs to happen AFTER account creation so we have a user ID
      if (notificationGranted == true) {
        debugPrint('');
        debugPrint('[WelcomePage] ===== INITIALIZING FCM =====');
        debugPrint('[WelcomePage] Notification permission was granted, initializing FCM...');
        try {
          await NotificationService().initialize();
          debugPrint('[WelcomePage] FCM initialized, now registering token for user...');
          // Also explicitly register token for the new user
          await NotificationService().registerTokenForUser();
          debugPrint('[WelcomePage] SUCCESS: FCM initialized and token registered');
          debugPrint('[WelcomePage] ==============================');
        } catch (fcmError, stackTrace) {
          debugPrint('[WelcomePage] ERROR initializing FCM: $fcmError');
          debugPrint('[WelcomePage] Stack trace: $stackTrace');
          debugPrint('[WelcomePage] ==============================');
          // Non-critical - allow user to continue
        }
      } else {
        debugPrint('[WelcomePage] Skipping FCM initialization (notification permission not granted or null)');
      }

      // Mark onboarding as completed
      print('[WelcomePage] Marking onboarding as completed...');
      try {
        await OnboardingStateService().completeOnboarding(userId);
        print('[WelcomePage] SUCCESS: Onboarding marked as completed');
      } catch (completeError) {
        print('[WelcomePage] ERROR completing onboarding: $completeError');
        // Non-critical - allow user to continue
      }

      // NOTE: Device locale/location tracking disabled
      // The user_profiles table doesn't exist in database
      // Location detection can be added later if needed
      debugPrint('[WelcomePage] Skipping device locale setup (user_profiles table not configured)');

      // Initialize credits (auto-initialized when first accessed)
      print('[WelcomePage] Initializing credits...');
      final creditService = ref.read(creditServiceProvider);
      await creditService.getCreditBalance();
      print('[WelcomePage] Credits initialized');

      // Invalidate credit status to refresh UI
      ref.invalidate(creditBalanceProvider);

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
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: spacing.l),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(height: 24),

                      // Only show content after animation is loaded to prevent jitter
                      if (_animationLoaded) ...[
                        _CompletionBadge(),
                      ] else ...[
                        SizedBox(
                          width: 600,
                          height: 600,
                        ),
                      ],

                      FadeTransition(
                        opacity: _textFadeAnimation,
                        child: Transform.translate(
                          offset: const Offset(0, -154),
                          child: const Text(
                            'Your fashion search\nstarts now!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              fontFamily: 'PlusJakartaSans',
                              letterSpacing: -0.5,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: OnboardingBottomBar(
        primaryButton: SizedBox(
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
      ),
    );
  }
}

class _CompletionBadge extends StatefulWidget {
  const _CompletionBadge();

  @override
  State<_CompletionBadge> createState() => _CompletionBadgeState();
}

class _CompletionBadgeState extends State<_CompletionBadge> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 600,
      height: 600,
      child: Lottie.asset(
        'assets/animations/congratulations.json',
        repeat: false,
        fit: BoxFit.contain,
        frameRate: FrameRate.max, // Ensure smooth animation
      ),
    );
  }
}
