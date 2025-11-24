import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../shared/navigation/main_navigation.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../auth/domain/providers/auth_provider.dart';
import '../../../../services/onboarding_state_service.dart';
import '../../../../services/subscription_sync_service.dart';
import '../../../onboarding/presentation/pages/gender_selection_page.dart';
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
    final authStateAsync = ref.read(authStateProvider);

    await Future.wait([
      Future.delayed(const Duration(milliseconds: 1000)),
      authStateAsync.when(
        data: (_) => Future.value(),
        loading: () => Future.value(),
        error: (_, __) => Future.value(),
      ),
    ]);

    if (!mounted) return;

    // Check if user is authenticated
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
          // Sync subscription data from RevenueCat
          // TODO: Re-enable when RevenueCat is configured in production
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
              // Onboarding not completed - check state
              if (onboardingStateValue == 'payment_complete') {
                // Paid but haven't completed onboarding - go to welcome
                nextPage = const WelcomeFreeAnalysisPage();
              } else if (onboardingStateValue == 'in_progress') {
                // Onboarding in progress - reset and start over (per user requirement)
                await onboardingService.resetOnboarding(user.id);
                nextPage = const GenderSelectionPage();
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
