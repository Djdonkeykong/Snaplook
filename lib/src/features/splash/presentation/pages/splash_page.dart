import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../shared/navigation/main_navigation.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../auth/domain/providers/auth_provider.dart';
import '../../../onboarding/presentation/pages/account_creation_page.dart';
import '../../../paywall/providers/credit_provider.dart';
import '../../../../services/subscription_sync_service.dart';
import 'dart:ui';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheAndNavigate();
  }

  Future<void> _precacheAndNavigate() async {
    // Precache the logo image first
    await precacheImage(
      const AssetImage('assets/images/splash_logo.png'),
      context,
    );

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

    // Check if user has active subscription (RevenueCat)
    final hasActiveSubscription = ref.read(hasActiveSubscriptionProvider);

    // Ensure share extension receives the latest auth state via AuthService.
    // This avoids racing MethodChannel calls that might send a null userId.
    if (mounted) {
      final authService = ref.read(authServiceProvider);
      await authService.syncAuthState();

      // If user is authenticated, sync subscription data from RevenueCat to Supabase
      // This ensures data stays in sync across devices and after restores
      if (isAuthenticated) {
        await SubscriptionSyncService().syncSubscriptionToSupabase();
      }
    }

    // Determine the next page based on auth + subscription status
    Widget nextPage;

    if (isAuthenticated) {
      // User has account → go to main app
      nextPage = const MainNavigation();
    } else if (hasActiveSubscription) {
      // User paid but no account → go to account creation
      nextPage = const AccountCreationPage();
    } else {
      // No payment, no account → go to login/tutorials flow
      nextPage = const LoginPage();
    }

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
    return Scaffold(
      backgroundColor: const Color(0xFFF2003C),
      body: Center(
        child: SizedBox(
          width: 180,
          child: Image.asset(
            'assets/images/splash_logo.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
