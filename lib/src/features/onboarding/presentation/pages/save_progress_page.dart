import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../auth/domain/providers/auth_provider.dart';
import '../../../auth/domain/services/auth_service.dart';
import '../../../auth/presentation/pages/email_sign_in_page.dart';
import '../../../profile/presentation/widgets/profile_webview_bottom_sheet.dart';
import '../widgets/progress_indicator.dart';
import '../widgets/onboarding_bottom_bar.dart';
import 'revenuecat_paywall_page.dart';
import 'welcome_free_analysis_page.dart';
import '../../../../../shared/navigation/main_navigation.dart';
import '../../../../shared/widgets/snaplook_back_button.dart';
import '../../../../services/subscription_sync_service.dart';
import '../../../../services/fraud_prevention_service.dart';
import '../../../../services/onboarding_state_service.dart';
import '../../../../services/revenuecat_service.dart';
import '../../domain/providers/gender_provider.dart';
import '../../domain/providers/onboarding_preferences_provider.dart';
import 'notification_permission_page.dart';
import 'discovery_source_page.dart';

class SaveProgressPage extends ConsumerStatefulWidget {
  const SaveProgressPage({super.key});

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
  ConsumerState<SaveProgressPage> createState() => _SaveProgressPageState();
}

class _SaveProgressPageState extends ConsumerState<SaveProgressPage> {
  bool _isCheckingAuth = true;

  @override
  void initState() {
    super.initState();
    _checkIfShouldSkip();
  }

  Future<void> _checkIfShouldSkip() async {
    final authService = ref.read(authServiceProvider);
    final isAuthenticated = authService.currentUser != null;

    if (isAuthenticated) {
      debugPrint('[SaveProgress] User already authenticated, skipping to next step');
      // Don't set _isCheckingAuth to false, just navigate
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateBasedOnSubscriptionStatus();
      });
    } else {
      // User is not authenticated, show the page
      if (mounted) {
        setState(() {
          _isCheckingAuth = false;
        });
      }
    }
  }

  Future<void> _openLegalDocument({
    required String title,
    required String url,
  }) async {
    if (!mounted) return;

    await SaveProgressPage.openLegalSheet(
      context: context,
      title: title,
      url: url,
    );
  }

  Future<void> _navigateBasedOnSubscriptionStatus() async {
    if (!mounted) return;

    final authService = ref.read(authServiceProvider);
    final userId = authService.currentUser?.id;

    if (userId == null) {
      debugPrint('[SaveProgress] No user found, navigating to paywall');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const RevenueCatPaywallPage()),
      );
      return;
    }

    try {
      debugPrint('[SaveProgress] Checking subscription status for user $userId');

      CustomerInfo? customerInfo;
      int retryCount = 0;
      const maxRetries = 3;

      while (retryCount < maxRetries) {
        try {
          customerInfo = RevenueCatService().currentCustomerInfo ??
              await Purchases.getCustomerInfo()
                  .timeout(const Duration(seconds: 10));
          break;
        } catch (e) {
          retryCount++;
          debugPrint(
              '[SaveProgress] Error fetching customer info (attempt $retryCount/$maxRetries): $e');

          if (retryCount >= maxRetries) {
            debugPrint(
                '[SaveProgress] Max retries reached, continuing without subscription check');

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Network error checking subscription. Continuing to paywall.',
                  ),
                  duration: Duration(seconds: 3),
                ),
              );
            }
            break;
          }

          await Future.delayed(Duration(seconds: retryCount));
        }
      }

      final activeEntitlements = customerInfo?.entitlements.active.values;
      final hasActiveSubscription =
          activeEntitlements != null && activeEntitlements.isNotEmpty;

      debugPrint(
          '[SaveProgress] Has active subscription: $hasActiveSubscription');

      if (hasActiveSubscription) {
        debugPrint(
            '[SaveProgress] User has active subscription, syncing and checking onboarding status');

        try {
          await SubscriptionSyncService()
              .syncSubscriptionToSupabase()
              .timeout(const Duration(seconds: 10));
          await OnboardingStateService()
              .markPaymentComplete(userId)
              .timeout(const Duration(seconds: 10));
        } catch (e) {
          debugPrint('[SaveProgress] Error syncing subscription: $e');
        }

        if (mounted) {
          // Check if user has completed onboarding before
          try {
            final supabase = Supabase.instance.client;
            final userResponse = await supabase
                .from('users')
                .select('onboarding_state')
                .eq('id', userId)
                .maybeSingle();

            final hasCompletedOnboarding = userResponse != null &&
                userResponse['onboarding_state'] == 'completed';

            if (hasCompletedOnboarding) {
              // User already completed onboarding - go to home
              debugPrint('[SaveProgress] User completed onboarding previously - going to home');
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const MainNavigation(
                    key: ValueKey('fresh-main-nav'),
                  ),
                ),
                (route) => false,
              );
            } else {
              // User hasn't completed onboarding - continue the flow
              debugPrint('[SaveProgress] User hasn\'t completed onboarding - going to welcome');
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                    builder: (context) => const WelcomeFreeAnalysisPage()),
              );
            }
          } catch (e) {
            debugPrint('[SaveProgress] Error checking onboarding status: $e');
            // Default to continuing onboarding
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                  builder: (context) => const WelcomeFreeAnalysisPage()),
            );
          }
        }
      } else {
        debugPrint(
            '[SaveProgress] No active subscription, navigating to paywall');
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
                builder: (context) => const RevenueCatPaywallPage()),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[SaveProgress] Error checking subscription status: $e');
      debugPrint('[SaveProgress] Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );

        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const RevenueCatPaywallPage()),
        );
      }
    }
  }

  Future<void> _handleSkip() async {
    HapticFeedback.mediumImpact();
    debugPrint('[SaveProgress] User skipped account creation');
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const RevenueCatPaywallPage()),
    );
  }

  Future<void> _persistOnboardingSelections(String userId) async {
    try {
      final selectedGender = ref.read(selectedGenderProvider);
      final notificationGranted = ref.read(notificationPermissionGrantedProvider);
      final styleDirection = ref.read(styleDirectionProvider);
      final whatYouWant = ref.read(whatYouWantProvider);
      final budget = ref.read(budgetProvider);
      final discoverySource = ref.read(selectedDiscoverySourceProvider);

      String? preferredGenderFilter;
      if (selectedGender != null) {
        switch (selectedGender) {
          case Gender.male:
            preferredGenderFilter = 'men';
            break;
          case Gender.female:
            preferredGenderFilter = 'women';
            break;
          case Gender.other:
            preferredGenderFilter = 'all';
            break;
        }
      }

      String? discoverySourceString;
      if (discoverySource != null) {
        discoverySourceString = discoverySource.name;
      }

      await OnboardingStateService().saveUserPreferences(
        userId: userId,
        preferredGenderFilter: preferredGenderFilter,
        notificationEnabled: notificationGranted,
        styleDirection: styleDirection.isNotEmpty ? styleDirection : null,
        whatYouWant: whatYouWant.isNotEmpty ? whatYouWant : null,
        budget: budget,
        discoverySource: discoverySourceString,
      );

      debugPrint(
          '[SaveProgress] All onboarding selections persisted successfully');
    } catch (e) {
      debugPrint('[SaveProgress] Error persisting onboarding selections: $e');
    }
  }

  Future<void> _handleAuthSuccess(BuildContext context) async {
    final authService = ref.read(authServiceProvider);
    final userId = authService.currentUser?.id;

    if (userId == null) {
      debugPrint('[SaveProgress] No user ID after auth');
      return;
    }

    debugPrint('[SaveProgress] Auth successful for user $userId');

    try {
      await OnboardingStateService().updateCheckpoint(
        userId,
        OnboardingCheckpoint.saveProgress,
      );
    } catch (e) {
      debugPrint('[SaveProgress] Error updating checkpoint: $e');
    }

    try {
      await SubscriptionSyncService().identify(userId);
      await FraudPreventionService.updateUserDeviceFingerprint(userId);

      final email = authService.currentUser?.email;
      if (email != null) {
        await FraudPreventionService.calculateFraudScore(
          userId,
          email: email,
        );
      }
    } catch (e) {
      debugPrint('[SaveProgress] Error syncing subscription data: $e');
    }

    await _persistOnboardingSelections(userId);

    await _navigateBasedOnSubscriptionStatus();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while checking authentication
    if (_isCheckingAuth) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
          ),
        ),
      );
    }

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
          currentStep: 14,
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

                  const Text(
                    'Save your progress',
                    style: TextStyle(
                      fontSize: 34,
                      fontFamily: 'PlusJakartaSans',
                      letterSpacing: -1.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      height: 1.3,
                    ),
                  ),

                  const Spacer(),

                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                        children: [
                          if (isAppleSignInAvailable) ...[
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
                                  debugPrint(
                                      '[SaveProgress] Apple sign in error: $e');
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

                                await Future.delayed(
                                    const Duration(milliseconds: 500));

                                if (context.mounted) {
                                  await _handleAuthSuccess(context);
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
                              } catch (e) {
                                debugPrint('[SaveProgress] Sign in error: $e');
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

                              await Future.delayed(
                                  const Duration(milliseconds: 500));

                              if (context.mounted) {
                                await _handleAuthSuccess(context);
                              }
                            },
                          ),

                          SizedBox(height: spacing.m),

                          _AuthButton(
                            icon: Icons.email_outlined,
                            iconSize: 26,
                            label: 'Continue with Email',
                            backgroundColor: Colors.white,
                            textColor: Colors.black,
                            borderColor: const Color(0xFFE5E7EB),
                            onPressed: () async {
                              final result = await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const EmailSignInPage(),
                                ),
                              );

                              if (result == true && context.mounted) {
                                await Future.delayed(
                                    const Duration(milliseconds: 500));
                                await _handleAuthSuccess(context);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Add bottom spacing to account for bottom navigation bar
                  SizedBox(height: spacing.xxl * 3),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: OnboardingBottomBar(
        primaryButton: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _handleSkip,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFf2003c),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: const Text(
              'Continue',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'PlusJakartaSans',
                letterSpacing: -0.2,
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
                child: Center(
                  child: SizedBox(
                    width: widget.icon == Icons.apple ? 22 : widget.iconSize,
                    height: widget.icon == Icons.apple ? 22 : widget.iconSize,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.secondary),
                    ),
                  ),
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
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.secondary),
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
