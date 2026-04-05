import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../shared/navigation/main_navigation.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../auth/domain/providers/auth_provider.dart';
import '../../../../shared/services/image_preloader.dart';
import '../../../../services/onboarding_state_service.dart';
import '../../../../services/subscription_sync_service.dart';
import '../../../onboarding/presentation/pages/paywall_presentation_page.dart';
import '../../../onboarding/presentation/pages/welcome_free_analysis_page.dart';
import '../../../home/domain/providers/history_bootstrap_provider.dart';
import '../../../wardrobe/domain/providers/history_provider.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  static const _assetPath = 'assets/images/snaplook-logo-splash.png';
  // Keep launch and splash logos in sync: fixed width so it doesn't vary by device size.
  static const double _logoWidth =
      93.027; // about +8% from original (~+1% from prior)
  static const Color _loaderTextColor = Color(0xF2FFFFFF);
  static const double _loaderBottomSpacing = 44;
  bool _started = false;

  Future<void> _signOutIncompleteOnboardingSession() async {
    try {
      await ref.read(authServiceProvider).signOut();
      debugPrint('[Splash] Signed out incomplete onboarding session');
    } catch (e) {
      debugPrint('[Splash] Failed to sign out incomplete onboarding session: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _precacheAndNavigate();
  }

  Future<void> _precacheAndNavigate() async {
    try {
      await precacheImage(const AssetImage(_assetPath), context);
    } catch (e) {
      debugPrint('[Splash] Failed to precache splash logo: $e');
    }

    // Preload onboarding images to prevent white flash
    try {
      await ImagePreloader.instance.preloadSocialMediaShareImage(context);
    } catch (e) {
      debugPrint('[Splash] Failed to preload onboarding images: $e');
    }

    // Preload home CTA assets so first Home paint is immediate.
    try {
      await ImagePreloader.instance.preloadHomeAssets(context);
    } catch (e) {
      debugPrint('[Splash] Failed to preload home assets: $e');
    }

    // Wait for auth state to be ready (with minimum 0.5s splash time)
    // CRITICAL: Wait for actual auth state data, not just the provider to be available
    // This ensures Supabase session restoration from SharedPreferences completes
    try {
      await ref
          .read(authStateProvider.future)
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('[Splash] Auth state wait failed: $e');
    }

    // Keep a minimum splash duration for smoother transition.
    await Future.delayed(const Duration(milliseconds: 500));

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

    // Check if user came from share extension needing credits
    final needsCreditsFromShareExtension = await _checkNeedsCreditsFlag();

    // Determine the next page based on auth status and subscription status
    Widget nextPage;

    if (isAuthenticated) {
      final user = ref.read(authServiceProvider).currentUser;

      if (user == null) {
        // No user - go to login
        nextPage = const LoginPage();
      } else {
        try {
          await SubscriptionSyncService()
              .identify(user.id)
              .timeout(const Duration(seconds: 4));
          debugPrint('[Splash] Re-identified restored user with RevenueCat');
        } catch (e) {
          debugPrint('[Splash] Failed to re-identify restored user: $e');
        }

        // User is authenticated - check onboarding state
        final onboardingService = OnboardingStateService();

        try {
          // Determine where user should go based on onboarding completion
          final onboardingRoute =
              await onboardingService.determineOnboardingRoute(user.id);

          if (onboardingRoute == null) {
            // Onboarding complete - go to home
            debugPrint(
                '[Splash] User has completed onboarding - routing to home');
            await _bootstrapHistoryUiState();
            nextPage = const MainNavigation();
          } else if (onboardingRoute == 'welcome') {
            debugPrint(
                '[Splash] User has access but still needs to finish onboarding - routing to welcome');
            nextPage = const WelcomeFreeAnalysisPage();
          } else if (onboardingRoute == 'resubscribe_paywall') {
            debugPrint(
                '[Splash] User needs more access - routing to credits paywall');
            nextPage = PaywallPresentationPage(
              userId: user.id,
              placement: 'credits_paywall',
              dismissToHomeIfNoPurchase: true,
            );
          } else {
            // Product decision: incomplete onboarding sessions should not auto-resume
            // after relaunch. Sign the user out and require an explicit login.
            debugPrint(
                '[Splash] Incomplete onboarding route ($onboardingRoute) - signing out and routing to login');
            await _signOutIncompleteOnboardingSession();
            nextPage = const LoginPage();
          }
        } catch (e) {
          debugPrint('[Splash] Error determining onboarding route: $e');
          // On error, check if they can access home as fallback
          try {
            final canAccess = await onboardingService.canAccessHome(user.id);
            if (canAccess) {
              await _bootstrapHistoryUiState();
              nextPage = const MainNavigation();
            } else {
              final accessState = await SubscriptionSyncService()
                  .getUserAccessState(userId: user.id);
              if (accessState?.hasAccess == true) {
                debugPrint(
                    '[Splash] Error fallback found access for incomplete onboarding - routing to welcome');
                nextPage = const WelcomeFreeAnalysisPage();
              } else {
                await _signOutIncompleteOnboardingSession();
                nextPage = const LoginPage();
              }
            }
          } catch (e2) {
            debugPrint('[Splash] Error checking home access: $e2');
            await _signOutIncompleteOnboardingSession();
            nextPage = const LoginPage();
          }
        }
      }
    } else {
      // Not authenticated - go to login
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
    final bottomInset = MediaQuery.paddingOf(context).bottom;

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
        body: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: SizedBox(
                width: _logoWidth,
                child: Image.asset(
                  _assetPath,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomInset + _loaderBottomSpacing,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  CupertinoActivityIndicator(
                    radius: 12,
                    color: Colors.white,
                  ),
                  SizedBox(height: 9),
                  Text(
                    'Loading...',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _loaderTextColor,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _checkNeedsCreditsFlag() async {
    try {
      const platform = MethodChannel('snaplook/auth');
      final result = await platform.invokeMethod('getNeedsCreditsFlag');
      debugPrint('[Splash] Needs credits from share extension: $result');
      return result == true;
    } catch (e) {
      debugPrint('[Splash] Error checking needs credits flag: $e');
      return false;
    }
  }

  Future<void> _bootstrapHistoryUiState() async {
    try {
      final history = await ref
          .read(historyProvider.future)
          .timeout(const Duration(seconds: 4));
      ref.read(historyBootstrapProvider.notifier).state = history.isNotEmpty
          ? HistoryBootstrapState.hasHistory
          : HistoryBootstrapState.noHistory;
    } catch (e) {
      debugPrint('[Splash] Failed to bootstrap history UI state: $e');
      ref.read(historyBootstrapProvider.notifier).state =
          HistoryBootstrapState.unknown;
    }
  }
}
