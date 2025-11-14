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

class WelcomeFreeAnalysisPage extends ConsumerStatefulWidget {
  const WelcomeFreeAnalysisPage({super.key});

  @override
  ConsumerState<WelcomeFreeAnalysisPage> createState() => _WelcomeFreeAnalysisPageState();
}

class _WelcomeFreeAnalysisPageState extends ConsumerState<WelcomeFreeAnalysisPage> {
  @override
  void initState() {
    super.initState();
    // Initialize user's free analysis in the background
    _initializeFreeAnalysis();
  }

  Future<void> _initializeFreeAnalysis() async {
    try {
      final userId = ref.read(authServiceProvider).currentUser?.id;
      if (userId != null) {
        final creditService = ref.read(creditServiceProvider);
        await creditService.initializeNewUser(userId);
        // Invalidate credit status to refresh UI
        ref.invalidate(creditStatusProvider);
      }
    } catch (e) {
      print('[WelcomePage] Error initializing free analysis: $e');
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
              const Spacer(flex: 2),

              // Success animation
              Lottie.asset(
                'assets/animations/success.json',
                width: 200,
                height: 200,
                repeat: false,
              ),

              SizedBox(height: spacing.xl),

              // Welcome message
              const Text(
                'Welcome to Snaplook!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontFamily: 'PlusJakartaSans',
                  letterSpacing: -1.0,
                  height: 1.3,
                ),
              ),

              SizedBox(height: spacing.m),

              // Free analysis message
              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  text: 'You get ',
                  style: TextStyle(
                    fontSize: 18,
                    color: Color(0xFF6B7280),
                    fontFamily: 'PlusJakartaSans',
                    height: 1.5,
                  ),
                  children: [
                    TextSpan(
                      text: '1 free analysis',
                      style: TextStyle(
                        fontSize: 18,
                        color: Color(0xFFf2003c),
                        fontFamily: 'PlusJakartaSans',
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                    TextSpan(
                      text: ' to discover amazing fashion finds!',
                      style: TextStyle(
                        fontSize: 18,
                        color: Color(0xFF6B7280),
                        fontFamily: 'PlusJakartaSans',
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: spacing.l),

              // Visual representation
              Container(
                padding: EdgeInsets.all(spacing.l),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F9F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE5E7EB),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.camera_alt_outlined,
                      size: 48,
                      color: Color(0xFFf2003c),
                    ),
                    SizedBox(height: spacing.m),
                    const Text(
                      'Upload any photo and discover\nall the fashion items in it',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                        fontFamily: 'PlusJakartaSans',
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 3),

              // Continue button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    // Reset to home tab and navigate to main app
                    ref.read(selectedIndexProvider.notifier).state = 0;
                    ref.invalidate(inspirationProvider);
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const MainNavigation(),
                      ),
                      (route) => false,
                    );
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

              SizedBox(height: spacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
