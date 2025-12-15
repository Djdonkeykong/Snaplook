import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../auth/domain/providers/auth_provider.dart';
import '../../../auth/domain/services/auth_service.dart';
import '../../../auth/presentation/pages/email_sign_in_page.dart';
import '../../../profile/presentation/widgets/profile_webview_bottom_sheet.dart';
import '../../../home/domain/providers/inspiration_provider.dart';
import '../widgets/progress_indicator.dart';
import 'welcome_free_analysis_page.dart';
import 'gender_selection_page.dart';
import 'user_goals_page.dart';
import 'notification_permission_page.dart';
import '../../../../../shared/navigation/main_navigation.dart'
    show
        MainNavigation,
        selectedIndexProvider,
        scrollToTopTriggerProvider,
        isAtHomeRootProvider;
import '../../../../shared/widgets/snaplook_back_button.dart';
import '../../../../shared/widgets/bottom_sheet_handle.dart';
import '../../../../shared/widgets/snaplook_circular_icon_button.dart';
import '../../../../services/subscription_sync_service.dart';
import '../../../../services/fraud_prevention_service.dart';
import '../../../../services/onboarding_state_service.dart';

class AccountCreationPage extends ConsumerStatefulWidget {
  const AccountCreationPage({super.key});

  /// Opens the legal document bottom sheet used across auth flows.
  static Future<void> openLegalSheet({
    required BuildContext context,
    required String title,
    required String url,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      useRootNavigator: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.95,
          child: ProfileWebViewBottomSheet(
            title: title,
            initialUrl: url,
          ),
        );
      },
    );
  }

  @override
  ConsumerState<AccountCreationPage> createState() =>
      _AccountCreationPageState();
}

class _AccountCreationPageState extends ConsumerState<AccountCreationPage> {
  Future<void> _openLegalDocument({
    required String title,
    required String url,
  }) async {
    if (!mounted) return;

    await AccountCreationPage.openLegalSheet(
      context: context,
      title: title,
      url: url,
    );
  }

  Future<void> _handlePostSignInNavigation(BuildContext context) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) return;

    final userResponse = await supabase
        .from('users')
        .select('onboarding_state')
        .eq('id', userId)
        .maybeSingle();

    final hasCompletedOnboarding =
        userResponse != null && userResponse['onboarding_state'] == 'completed';

    if (!mounted) return;

    if (hasCompletedOnboarding) {
      // Reset to home tab and refresh providers
      ref.read(selectedIndexProvider.notifier).state = 0;
      ref.invalidate(selectedIndexProvider);
      ref.invalidate(scrollToTopTriggerProvider);
      ref.invalidate(isAtHomeRootProvider);
      ref.invalidate(inspirationProvider);

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const MainNavigation(
            key: ValueKey('fresh-main-nav'),
          ),
        ),
        (route) => false,
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const UserGoalsPage(),
        ),
      );
    }
  }

  Future<void> _showSignInBottomSheet(BuildContext context) async {
    final spacing = context.spacing;
    final platform = Theme.of(context).platform;
    final isAppleSignInAvailable =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.all(spacing.l),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BottomSheetHandle(
                        margin: EdgeInsets.only(bottom: spacing.m),
                      ),
                      const Center(
                        child: Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            fontFamily: 'PlusJakartaSans',
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      SizedBox(height: spacing.xxl),
                      if (isAppleSignInAvailable) ...[
                        _AuthButton(
                          icon: Icons.apple,
                          iconSize: 32,
                          label: 'Continue with Apple',
                          backgroundColor: Colors.black,
                          textColor: Colors.white,
                          onPressed: () async {
                            final authService = ref.read(authServiceProvider);
                            try {
                              await authService.signInWithApple();
                              if (mounted) {
                                Navigator.pop(context);
                                await _handlePostSignInNavigation(context);
                              }
                            } catch (e) {
                              if (mounted && e != AuthService.authCancelledException) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).clearSnackBars();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      e.toString(),
                                      style: context.snackTextStyle(
                                        merge: const TextStyle(fontFamily: 'PlusJakartaSans'),
                                      ),
                                    ),
                                    duration: const Duration(milliseconds: 2500),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                        SizedBox(height: spacing.m),
                      ],
                      _AuthButtonWithSvg(
                        svgAsset: 'assets/icons/google_logo.svg',
                        iconSize: 22,
                        label: 'Continue with Google',
                        backgroundColor: Colors.white,
                        textColor: Colors.black,
                        borderColor: const Color(0xFFE5E7EB),
                        onPressed: () async {
                          final authService = ref.read(authServiceProvider);
                          try {
                            await authService.signInWithGoogle();
                            if (mounted) {
                              Navigator.pop(context);
                              await _handlePostSignInNavigation(context);
                            }
                          } catch (e) {
                            if (mounted && e != AuthService.authCancelledException) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).clearSnackBars();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    e.toString(),
                                    style: context.snackTextStyle(
                                      merge: const TextStyle(fontFamily: 'PlusJakartaSans'),
                                    ),
                                  ),
                                  duration: const Duration(milliseconds: 2500),
                                ),
                              );
                            }
                          }
                        },
                      ),
                      SizedBox(height: spacing.m),
                      _AuthButton(
                        icon: Icons.email_outlined,
                        iconSize: 24,
                        label: 'Continue with email',
                        backgroundColor: Colors.white,
                        textColor: Colors.black,
                        borderColor: const Color(0xFFE5E7EB),
                        onPressed: () async {
                          Navigator.pop(context);
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const EmailSignInPage(),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: spacing.xl),
                    ],
                  ),
                ),
                Positioned(
                  top: spacing.l,
                  right: spacing.l,
                  child: SnaplookCircularIconButton(
                    icon: Icons.close,
                    iconSize: 18,
                    size: 32,
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Close',
                    semanticLabel: 'Close',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Link Superwall subscription to newly created account
  Future<bool> _linkSubscriptionToAccount(String userId) async {
    try {
      debugPrint('[AccountCreation] Linking subscription for user $userId via Superwall');

      await SubscriptionSyncService().identifyWithSuperwall(userId);

      // Update device fingerprint for fraud prevention
      await FraudPreventionService.updateUserDeviceFingerprint(userId);

      // Calculate fraud score
      final authService = ref.read(authServiceProvider);
      final email = authService.currentUser?.email;
      if (email != null) {
        await FraudPreventionService.calculateFraudScore(
          userId,
          email: email,
        );
      }

      debugPrint('[AccountCreation] Subscription linked successfully');
      return true;
    } catch (e) {
      debugPrint('[AccountCreation] Error linking subscription: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error linking subscription. Please try again.',
              style: context.snackTextStyle(
                merge: const TextStyle(fontFamily: 'PlusJakartaSans'),
              ),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  void _showSubscriptionConflictDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Subscription Already Exists',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'This account already has an active subscription.\n\n'
          'Your recent purchase will be refunded within 24 hours.\n\n'
          'Please use the existing subscription or create a new account.',
          style: TextStyle(fontFamily: 'PlusJakartaSans'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Go back to paywall
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.secondary,
              textStyle: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final targetPlatform = Theme.of(context).platform;
    final isAppleSignInAvailable = targetPlatform == TargetPlatform.iOS ||
        targetPlatform == TargetPlatform.macOS;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const SnaplookBackButton(),
        centerTitle: true,
        title: const OnboardingProgressIndicator(
          currentStep: 19,
          totalSteps: 20,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: spacing.l),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom -
                  kToolbarHeight,
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: spacing.l),

                  // Title
                  const Text(
                    'Create your account',
                    style: TextStyle(
                      fontSize: 34,
                      fontFamily: 'PlusJakartaSans',
                      letterSpacing: -1.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      height: 1.3,
                    ),
                  ),

                  // Spacer to push buttons to center
                  const Spacer(),

                  // Centered auth buttons
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                        children: [
                          if (isAppleSignInAvailable) ...[
                            // Apple button
                            _AuthButton(
                              icon: Icons.apple,
                              iconSize: 32,
                              label: 'Continue with Apple',
                              backgroundColor: Colors.black,
                              textColor: Colors.white,
                              onPressed: () async {
                                final authService =
                                    ref.read(authServiceProvider);

                                try {
                                  await authService.signInWithApple();
                                } catch (e) {
                                  print(
                                      '[AccountCreation] Apple sign in error: $e');
                                  // Check if auth actually succeeded despite the error
                                  if (authService.currentUser == null &&
                                      context.mounted) {
                                    ScaffoldMessenger.of(context)
                                        .clearSnackBars();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Error signing in with Apple: ${e.toString()}',
                                          style: context.snackTextStyle(
                                            merge: const TextStyle(
                                                fontFamily: 'PlusJakartaSans'),
                                          ),
                                        ),
                                        duration:
                                            const Duration(milliseconds: 2500),
                                      ),
                                    );
                                    return;
                                  }
                                }

                                // Wait briefly for auth state to fully propagate
                                await Future.delayed(
                                    const Duration(milliseconds: 500));

                                // Check if auth succeeded
                                if (context.mounted) {
                                  final userId = authService.currentUser?.id;
                                  print(
                                      '[AccountCreation] Apple - User ID after sign in: $userId');
                                  if (userId != null) {
                                    // Update checkpoint to 'account' to mark account creation
                                    print('[AccountCreation] Apple - Updating checkpoint to account...');
                                    try {
                                      await OnboardingStateService().updateCheckpoint(
                                        userId,
                                        OnboardingCheckpoint.account,
                                      );
                                      print('[AccountCreation] Apple - Checkpoint updated to account');
                                    } catch (checkpointError) {
                                      print('[AccountCreation] Apple - Error updating checkpoint: $checkpointError');
                                      // Non-critical - continue
                                    }

                                    // CRITICAL: Link subscription to new account
                                    // This transfers any anonymous purchases to the identified user
                                    final linkSuccess =
                                        await _linkSubscriptionToAccount(userId);
                                    if (!linkSuccess) {
                                      // Subscription conflict - dialog already shown
                                      return;
                                    }

                                    // First check if user went through onboarding already (providers have values)
                                    final selectedGender =
                                        ref.read(selectedGenderProvider);
                                    print(
                                        '[AccountCreation] Apple - Gender from provider: ${selectedGender?.name}');

                                    if (selectedGender != null) {
                                      // User went through onboarding BEFORE creating account
                                      // Go to welcome page which will save preferences and initialize credits
                                      print(
                                          '[AccountCreation] Apple - User completed onboarding, going to welcome page');
                                      Navigator.of(context).pushAndRemoveUntil(
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const WelcomeFreeAnalysisPage(),
                                        ),
                                        (route) => false,
                                      );
                                    } else {
                                      // No provider values, check database to see if returning user
                                      try {
                                        final supabase =
                                            Supabase.instance.client;
                                        final userResponse = await supabase
                                            .from('users')
                                            .select('onboarding_state')
                                            .eq('id', userId)
                                            .maybeSingle();

                                        print(
                                            '[AccountCreation] Apple - User record found: ${userResponse != null}');

                                        // Check if user has completed onboarding
                                        final hasCompletedOnboarding =
                                            userResponse != null &&
                                                userResponse['onboarding_state'] == 'completed';
                                        print(
                                            '[AccountCreation] Apple - Has completed onboarding in DB: $hasCompletedOnboarding');

                                        if (hasCompletedOnboarding) {
                                          // Existing user who completed onboarding - go to main app
                                          print(
                                              '[AccountCreation] Apple - Existing user - navigating to main app');
                                          // Reset to home tab
                                          ref
                                              .read(selectedIndexProvider
                                                  .notifier)
                                              .state = 0;
                                          // Invalidate all providers to refresh state
                                          ref.invalidate(selectedIndexProvider);
                                          ref.invalidate(
                                              scrollToTopTriggerProvider);
                                          ref.invalidate(isAtHomeRootProvider);
                                          Navigator.of(context)
                                              .pushAndRemoveUntil(
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const MainNavigation(
                                                      key: ValueKey(
                                                          'fresh-main-nav')),
                                            ),
                                            (route) => false,
                                          );
                                        } else {
                                          // New user - start onboarding from gender selection
                                          print(
                                              '[AccountCreation] Apple - New user - navigating to gender selection');
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const GenderSelectionPage(),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        // If check fails, assume new user
                                        print(
                                            '[AccountCreation] Apple - Check error, assuming new user: $e');
                                        if (context.mounted) {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const GenderSelectionPage(),
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  }
                                }
                              },
                            ),
                            SizedBox(height: spacing.m),
                          ],

                          // Google button
                          _AuthButtonWithSvg(
                            svgAsset: 'assets/icons/google_logo.svg',
                            iconSize: 22,
                            label: 'Continue with Google',
                            backgroundColor: Colors.white,
                            textColor: Colors.black,
                            borderColor: const Color(0xFFE5E7EB),
                            onPressed: () async {
                              final authService = ref.read(authServiceProvider);

                              try {
                                await authService.signInWithGoogle();
                              } catch (e) {
                                print('[AccountCreation] Sign in error: $e');
                                // Check if auth actually succeeded despite the error
                                if (authService.currentUser == null &&
                                    context.mounted) {
                                  ScaffoldMessenger.of(context)
                                      .clearSnackBars();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Error signing in with Google: ${e.toString()}',
                                        style: context.snackTextStyle(
                                          merge: const TextStyle(
                                              fontFamily: 'PlusJakartaSans'),
                                        ),
                                      ),
                                      duration:
                                          const Duration(milliseconds: 2500),
                                    ),
                                  );
                                  return;
                                }
                              }

                              // Wait briefly for auth state to fully propagate
                              await Future.delayed(
                                  const Duration(milliseconds: 500));

                              // Check if auth succeeded
                              if (context.mounted) {
                                final userId = authService.currentUser?.id;
                                print(
                                    '[AccountCreation] Google - User ID after sign in: $userId');
                                if (userId != null) {
                                  // Update checkpoint to 'account' to mark account creation
                                  print('[AccountCreation] Google - Updating checkpoint to account...');
                                  try {
                                    await OnboardingStateService().updateCheckpoint(
                                      userId,
                                      OnboardingCheckpoint.account,
                                    );
                                    print('[AccountCreation] Google - Checkpoint updated to account');
                                  } catch (checkpointError) {
                                    print('[AccountCreation] Google - Error updating checkpoint: $checkpointError');
                                    // Non-critical - continue
                                  }

                                  // CRITICAL: Link subscription to new account
                                  // This transfers any anonymous purchases to the identified user
                                  final linkSuccess =
                                      await _linkSubscriptionToAccount(userId);
                                  if (!linkSuccess) {
                                    // Subscription conflict - dialog already shown
                                    return;
                                  }

                                  // First check if user went through onboarding already (providers have values)
                                  final selectedGender =
                                      ref.read(selectedGenderProvider);
                                  print(
                                      '[AccountCreation] Google - Gender from provider: ${selectedGender?.name}');

                                  if (selectedGender != null) {
                                    // User went through onboarding BEFORE creating account
                                    // Go to welcome page which will save preferences and initialize credits
                                    print(
                                        '[AccountCreation] Google - User completed onboarding, going to welcome page');
                                    Navigator.of(context).pushAndRemoveUntil(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const WelcomeFreeAnalysisPage(),
                                      ),
                                      (route) => false,
                                    );
                                  } else {
                                    // No provider values, check database to see if returning user
                                    try {
                                      final supabase = Supabase.instance.client;
                                      final userResponse = await supabase
                                          .from('users')
                                          .select('onboarding_state')
                                          .eq('id', userId)
                                          .maybeSingle();

                                      print(
                                          '[AccountCreation] Google - User record found: ${userResponse != null}');

                                      // Check if user has completed onboarding
                                      final hasCompletedOnboarding =
                                          userResponse != null &&
                                              userResponse['onboarding_state'] == 'completed';
                                      print(
                                          '[AccountCreation] Google - Has completed onboarding in DB: $hasCompletedOnboarding');

                                      if (hasCompletedOnboarding) {
                                        // Existing user who completed onboarding - go to main app
                                        print(
                                            '[AccountCreation] Google - Existing user - navigating to main app');
                                        // Reset to home tab
                                        ref
                                            .read(
                                                selectedIndexProvider.notifier)
                                            .state = 0;
                                        // Invalidate all providers to refresh state
                                        ref.invalidate(selectedIndexProvider);
                                        ref.invalidate(
                                            scrollToTopTriggerProvider);
                                        ref.invalidate(isAtHomeRootProvider);
                                        Navigator.of(context)
                                            .pushAndRemoveUntil(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const MainNavigation(
                                                    key: ValueKey(
                                                        'fresh-main-nav')),
                                          ),
                                          (route) => false,
                                        );
                                      } else {
                                        // New user - start onboarding from gender selection
                                        print(
                                            '[AccountCreation] Google - New user - navigating to gender selection');
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const GenderSelectionPage(),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      // If check fails, assume new user
                                      print(
                                          '[AccountCreation] Google - Check error, assuming new user: $e');
                                      if (context.mounted) {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const GenderSelectionPage(),
                                          ),
                                        );
                                      }
                                    }
                                  }
                                }
                              }
                            },
                          ),

                          SizedBox(height: spacing.m),

                          // Email button
                          _AuthButton(
                            icon: Icons.email_outlined,
                            iconSize: 26,
                            label: 'Continue with Email',
                            backgroundColor: Colors.white,
                            textColor: Colors.black,
                            borderColor: const Color(0xFFE5E7EB),
                            onPressed: () async {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const EmailSignInPage(),
                                ),
                              );
                            },
                          ),

                          SizedBox(height: spacing.m),
                          TextButton(
                            onPressed: () async {
                              HapticFeedback.mediumImpact();
                              await _showSignInBottomSheet(context);
                            },
                            child: RichText(
                              textAlign: TextAlign.center,
                              text: const TextSpan(
                                text: 'Already have an account? ',
                                style: TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 14,
                                  fontFamily: 'PlusJakartaSans',
                                  fontWeight: FontWeight.w400,
                                  height: 1.5,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Sign In',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'PlusJakartaSans',
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Terms and Privacy Policy
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: spacing.xl),
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        text: 'By continuing you agree to Snaplook\'s ',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                          fontFamily: 'PlusJakartaSans',
                          height: 1.5,
                        ),
                        children: [
                          TextSpan(
                            text: 'Terms of Conditions',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black,
                              fontFamily: 'PlusJakartaSans',
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.black,
                              decorationThickness: 1.5,
                              height: 1.5,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                HapticFeedback.selectionClick();
                                _openLegalDocument(
                                  title: 'Terms of Service',
                                  url:
                                      'https://truefindr.com/terms-of-service/',
                                );
                              },
                          ),
                          const TextSpan(
                            text: ' and ',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                              fontFamily: 'PlusJakartaSans',
                              height: 1.5,
                            ),
                          ),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black,
                              fontFamily: 'PlusJakartaSans',
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.black,
                              decorationThickness: 1.5,
                              height: 1.5,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                HapticFeedback.selectionClick();
                                _openLegalDocument(
                                  title: 'Privacy Policy',
                                  url: 'https://truefindr.com/privacy-policy/',
                                );
                              },
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: spacing.xl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthButton extends StatefulWidget {
  final IconData icon;
  final double iconSize;
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;
  final Future<void> Function() onPressed;

  const _AuthButton({
    required this.icon,
    this.iconSize = 24,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.borderColor,
    required this.onPressed,
  });

  @override
  State<_AuthButton> createState() => _AuthButtonState();
}

class _AuthButtonState extends State<_AuthButton> {
  bool _isLoading = false;

  Future<void> _handlePress() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      await widget.onPressed();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(28),
        border: widget.borderColor != null
            ? Border.all(color: widget.borderColor!, width: 1.5)
            : null,
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handlePress,
        style: ElevatedButton.styleFrom(
          backgroundColor: widget.backgroundColor,
          foregroundColor: widget.textColor,
          elevation: 0,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: widget.backgroundColor,
          disabledForegroundColor: widget.textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoading)
              SizedBox(
                width: widget.iconSize,
                height: widget.iconSize,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
                ),
              )
            else
              Transform.translate(
                offset: widget.icon == Icons.apple
                    ? const Offset(0, -2)
                    : Offset.zero,
                child: Icon(widget.icon, size: widget.iconSize),
              ),
            const SizedBox(width: 12),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'PlusJakartaSans',
                letterSpacing: -0.2,
                color: widget.textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthButtonWithSvg extends StatefulWidget {
  final String svgAsset;
  final double iconSize;
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;
  final Future<void> Function() onPressed;

  const _AuthButtonWithSvg({
    required this.svgAsset,
    this.iconSize = 24,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.borderColor,
    required this.onPressed,
  });

  @override
  State<_AuthButtonWithSvg> createState() => _AuthButtonWithSvgState();
}

class _AuthButtonWithSvgState extends State<_AuthButtonWithSvg> {
  bool _isLoading = false;

  Future<void> _handlePress() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      await widget.onPressed();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(28),
        border: widget.borderColor != null
            ? Border.all(color: widget.borderColor!, width: 1.5)
            : null,
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handlePress,
        style: ElevatedButton.styleFrom(
          backgroundColor: widget.backgroundColor,
          foregroundColor: widget.textColor,
          elevation: 0,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: widget.backgroundColor,
          disabledForegroundColor: widget.textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoading)
              SizedBox(
                width: widget.iconSize,
                height: widget.iconSize,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
                ),
              )
            else
              SvgPicture.asset(
                widget.svgAsset,
                width: widget.iconSize,
                height: widget.iconSize,
              ),
            const SizedBox(width: 12),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'PlusJakartaSans',
                letterSpacing: -0.2,
                color: widget.textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
