import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../shared/navigation/main_navigation.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../auth/domain/providers/auth_provider.dart';
import '../../../../services/onboarding_state_service.dart';
import '../../../../services/subscription_sync_service.dart';
import '../../../onboarding/presentation/pages/gender_selection_page.dart';
import '../../../onboarding/presentation/pages/discovery_source_page.dart';
import '../../../onboarding/presentation/pages/awesome_intro_page.dart';
import '../../../onboarding/presentation/pages/trial_intro_page.dart';
import '../../../onboarding/presentation/pages/account_creation_page.dart';
import '../../../onboarding/presentation/pages/welcome_free_analysis_page.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  static const _assetPath = 'assets/images/snaplook-logo-splash.png';
  // Keep launch and splash logos in sync: fixed width so it doesn't vary by device size.
  static const double _logoWidth = 93.027; // about +8% from original (~+1% from prior)

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheAndNavigate();
  }

  Future<void> _precacheAndNavigate() async {
    await precacheImage(const AssetImage(_assetPath), context);

    // Wait for auth state to be ready (with minimum 1.0s splash time)
    // CRITICAL: Wait for actual auth state data, not just the provider to be available
    // This ensures Supabase session restoration from SharedPreferences completes
    await Future.wait([
      Future.delayed(const Duration(milliseconds: 1000)),
      ref.read(authStateProvider.future).timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint('[Splash] Auth state timeout - assuming not authenticated');
          return ref.read(authServiceProvider).authStateChanges.first;
        },
      ),
    ]);

    if (!mounted) return;

    // Check if user is authenticated
    // By this point, the auth state stream has emitted and session restoration is complete
    final isAuthenticated = ref.read(isAuthenticatedProvider);

    // Ensure share extension receives the latest auth state via AuthService.
    // This avoids racing MethodChannel calls that might send a null userId.
    if (mounted) {
      final authService = ref.read(authServiceProvider);
      await authService.syncAuthState();
    }

    // Determine the next page based on auth status and onboarding state
    Widget nextPage;

    if (isAuthenticated) {
      // User is authenticated - check onboarding and subscription state
      final user = ref.read(authServiceProvider).currentUser;
      if (user == null) {
        // No user despite being authenticated - go to login
        nextPage = const LoginPage();
      } else {
        try {
          // Sync subscription data from Superwall
          // TODO: Re-enable when Superwall is configured in production
          // await SubscriptionSyncService().syncSubscriptionToSupabase();

          // Get onboarding state
          final onboardingService = OnboardingStateService();
          final onboardingState = await onboardingService.getOnboardingState(user.id);

          if (onboardingState == null) {
            // No database record found despite being authenticated
            // This can happen if the user was deleted or there's a sync issue
            // Sign them out and send to login
            debugPrint('[Splash] No database record found for authenticated user - signing out');
            await ref.read(authServiceProvider).signOut();
            nextPage = const LoginPage();
          } else {
            final subscriptionStatus = onboardingState['subscription_status'] ?? 'free';
            final isTrial = onboardingState['is_trial'] == true;
            final onboardingStateValue = onboardingState['onboarding_state'] ?? 'not_started';

            // Check if user has completed onboarding
            if (onboardingStateValue == 'completed') {
              // Check if subscription is active or in trial
              if (subscriptionStatus == 'active' || isTrial) {
                // Completed onboarding + active subscription = Home
                nextPage = const MainNavigation();
              } else {
                // Completed onboarding but subscription expired
                // For now, send to login (you can create a resubscribe paywall later)
                nextPage = const LoginPage();
              }
            } else {
              // Onboarding not completed - check state and checkpoint
              if (onboardingStateValue == 'payment_complete') {
                // Paid but haven't completed onboarding - go to welcome
                nextPage = const WelcomeFreeAnalysisPage();
              } else if (onboardingStateValue == 'in_progress') {
                // Onboarding in progress - resume from last checkpoint
                final checkpoint = onboardingState['onboarding_checkpoint'] ?? 'gender';
                debugPrint('[Splash] Resuming onboarding from checkpoint: $checkpoint');

                // Build navigation stack with all previous pages so back button works
                final needsStackBuilding = checkpoint != 'gender';

                if (!mounted) return;

                if (needsStackBuilding) {
                  // Replace splash with first page, then push subsequent pages
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const GenderSelectionPage()),
                  );

                  // Build the rest of the stack based on checkpoint
                  switch (checkpoint) {
                    case 'discovery':
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const DiscoverySourcePage()),
                      );
                      break;
                    case 'tutorial':
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const DiscoverySourcePage()),
                      );
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const AwesomeIntroPage()),
                      );
                      break;
                    case 'paywall':
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const DiscoverySourcePage()),
                      );
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const AwesomeIntroPage()),
                      );
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const TrialIntroPage()),
                      );
                      break;
                    case 'account':
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const DiscoverySourcePage()),
                      );
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const AwesomeIntroPage()),
                      );
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const AccountCreationPage()),
                      );
                      break;
                    case 'welcome':
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const DiscoverySourcePage()),
                      );
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const AwesomeIntroPage()),
                      );
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const AccountCreationPage()),
                      );
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const WelcomeFreeAnalysisPage()),
                      );
                      break;
                  }
                  return; // Early return since we've already navigated
                } else {
                  // Starting from beginning
                  nextPage = const GenderSelectionPage();
                }
              } else {
                // Not started - go to gender selection
                nextPage = const GenderSelectionPage();
              }
            }
          }
        } catch (e) {
          debugPrint('[Splash] Error determining onboarding state: $e');
          // On error, default to safe behavior
          nextPage = const GenderSelectionPage();
        }
      }
    } else {
      // No account → go to login/tutorials flow
      nextPage = const LoginPage();
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextPage,
        transitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        // iOS: dark background = light (white) icons
        statusBarBrightness: Brightness.dark,
        // Android: light icons directly
        statusBarIconBrightness: Brightness.light,
      ),
    child: Scaffold(
        backgroundColor: const Color(0xFFF2003C),
        body: Center(
          child: SizedBox(
            width: _logoWidth,
            child: Image.asset(
              _assetPath,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
