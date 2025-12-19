import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../../../../shared/navigation/main_navigation.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../auth/domain/providers/auth_provider.dart';

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
        // User is authenticated - check subscription status
        try {
          // Get subscription status from RevenueCat
          final customerInfo = await Purchases.getCustomerInfo().timeout(
            const Duration(seconds: 10),
          );
          final hasActiveSubscription = customerInfo.entitlements.active.isNotEmpty;

          debugPrint('[Splash] User authenticated. Has active subscription: $hasActiveSubscription');

          // Check if user needs credits from share extension
          if (needsCreditsFromShareExtension) {
            // User came from share extension with no credits - send to login page
            nextPage = const LoginPage();
          } else if (hasActiveSubscription) {
            // Logged in + active subscription -> Home
            nextPage = const MainNavigation();
          } else {
            // Logged in + NO subscription -> Login page
            nextPage = const LoginPage();
          }
        } catch (e) {
          debugPrint('[Splash] Error checking subscription status: $e');
          // On error, default to login page
          nextPage = const LoginPage();
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
}
