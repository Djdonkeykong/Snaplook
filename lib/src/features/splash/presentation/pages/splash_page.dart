import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../../../../shared/navigation/main_navigation.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../auth/domain/providers/auth_provider.dart';
import '../../../../services/subscription_sync_service.dart';
import '../../../onboarding/presentation/pages/how_it_works_page.dart';

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

    // Determine the next page based on auth status, subscription status, and onboarding state
    Widget nextPage;

    if (isAuthenticated) {
      // Trust the Supabase session; avoid signing out on onboarding fetch issues.
      final user = ref.read(authServiceProvider).currentUser;

      if (user == null) {
        nextPage = const LoginPage();
      } else {
        // Check subscription status from RevenueCat and onboarding state from Supabase
        try {
          // Get subscription status from RevenueCat
          final customerInfo = await Purchases.getCustomerInfo().timeout(
            const Duration(seconds: 10),
          );
          final hasActiveSubscription = customerInfo.entitlements.active.isNotEmpty;

          // Get onboarding status from Supabase
          final supabase = Supabase.instance.client;
          final userResponse = await supabase
              .from('users')
              .select('onboarding_state, subscription_status, is_trial')
              .eq('id', user.id)
              .maybeSingle()
              .timeout(const Duration(seconds: 10));

          final hasCompletedOnboarding = userResponse?['onboarding_state'] == 'completed';

          // Sync subscription status if there's a mismatch
          final dbSubscriptionStatus = userResponse?['subscription_status'] ?? 'free';
          final dbIsTrial = userResponse?['is_trial'] == true;
          final dbHasActiveSubscription = dbSubscriptionStatus == 'active' || dbIsTrial;

          if (hasActiveSubscription != dbHasActiveSubscription) {
            // Subscription status mismatch - sync from RevenueCat to Supabase
            debugPrint('[Splash] Subscription status mismatch - syncing from RevenueCat to Supabase');
            await SubscriptionSyncService().syncSubscriptionToSupabase();
          }

          // Route based on onboarding completion and subscription status
          if (hasCompletedOnboarding && hasActiveSubscription) {
            nextPage = const MainNavigation(); // Home
          } else if (hasCompletedOnboarding && !hasActiveSubscription) {
            nextPage = const LoginPage(); // Subscription expired/free - send to login so they can renew or switch accounts
          } else {
            nextPage = const HowItWorksPage(); // Continue onboarding from where they left off
          }
        } catch (e) {
          debugPrint('[Splash] Error checking subscription status: $e');
          // On error, default to safe navigation (show login to avoid unauthorized access)
          nextPage = const LoginPage();
        }
      }
    } else {
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
