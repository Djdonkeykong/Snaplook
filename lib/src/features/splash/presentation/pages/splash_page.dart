import 'package:flutter/material.dart';
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

    // Wait for auth state to be ready (with minimum 1.5s splash time)
    final authStateAsync = ref.read(authStateProvider);

    await Future.wait([
      Future.delayed(const Duration(milliseconds: 1500)),
      authStateAsync.when(
        data: (_) => Future.value(),
        loading: () => Future.value(),
        error: (_, __) => Future.value(),
      ),
    ]);

    if (!mounted) return;

    // Now check if user is authenticated
    final isAuthenticated = ref.read(isAuthenticatedProvider);
    final nextPage = isAuthenticated ? const MainNavigation() : const LoginPage();

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
      backgroundColor: const Color(0xFFf2003c),
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
