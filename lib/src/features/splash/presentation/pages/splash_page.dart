import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    // Determine the next page based on auth status
    Widget nextPage;

    if (isAuthenticated) {
      // User has account → go to main app
      nextPage = const MainNavigation();
    } else {
      // No account → go to login/tutorials flow
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
          child: Builder(
            builder: (context) {
              // Slightly smaller than launch icon: ~22% of screen width.
              final logoWidth = MediaQuery.of(context).size.width * 0.22;
              return SizedBox(
                width: logoWidth,
                child: Image.asset(
                  _assetPath,
                  fit: BoxFit.contain,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
