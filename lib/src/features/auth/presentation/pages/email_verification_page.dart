import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../domain/providers/auth_provider.dart';
import '../../domain/services/auth_service.dart';
import '../../../onboarding/presentation/pages/how_it_works_page.dart';
import '../../../onboarding/presentation/pages/notification_permission_page.dart';
import '../../../onboarding/presentation/pages/welcome_free_analysis_page.dart';
import '../../../../services/paywall_helper.dart';
import '../../../../../shared/navigation/main_navigation.dart'
    show
        MainNavigation,
        selectedIndexProvider,
        scrollToTopTriggerProvider,
        isAtHomeRootProvider;
import '../../../../shared/widgets/snaplook_back_button.dart';
import '../../../../services/onboarding_state_service.dart';
import '../../../../services/subscription_sync_service.dart';
import '../../../../services/fraud_prevention_service.dart';
import '../../../onboarding/domain/providers/gender_provider.dart';
import '../../../onboarding/domain/providers/onboarding_preferences_provider.dart';
import '../../../onboarding/presentation/pages/discovery_source_page.dart';

class EmailVerificationPage extends ConsumerStatefulWidget {
  final String email;

  const EmailVerificationPage({
    super.key,
    required this.email,
  });

  @override
  ConsumerState<EmailVerificationPage> createState() =>
      _EmailVerificationPageState();
}

class _EmailVerificationPageState extends ConsumerState<EmailVerificationPage>
    with SingleTickerProviderStateMixin {
  static const int _otpLength = 6;
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();
  bool _isVerifying = false;
  bool _isResending = false;
  late final AnimationController _cursorBlinkController;

  @override
  void initState() {
    super.initState();
    _cursorBlinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
    _otpController.addListener(_onOtpChanged);
    _otpFocusNode.addListener(_onOtpFocusChanged);

    // Auto-focus first code input field after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        FocusScope.of(context).requestFocus(_otpFocusNode);
      }
    });
  }

  @override
  void dispose() {
    _cursorBlinkController.dispose();
    _otpController
      ..removeListener(_onOtpChanged)
      ..dispose();
    _otpFocusNode
      ..removeListener(_onOtpFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _onOtpFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onOtpChanged() {
    if (!mounted) return;

    final sanitized = _sanitizeOtp(_otpController.text);
    if (sanitized != _otpController.text) {
      _otpController.value = TextEditingValue(
        text: sanitized,
        selection: TextSelection.collapsed(offset: sanitized.length),
      );
      return;
    }

    setState(() {});

    if (!_isVerifying && sanitized.length == _otpLength) {
      unawaited(_submitOtpIfReady(sanitized));
    }
  }

  String _sanitizeOtp(String raw) {
    final digitsOnly = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length <= _otpLength) return digitsOnly;
    return digitsOnly.substring(0, _otpLength);
  }

  Future<void> _submitOtpIfReady(String code) async {
    if (!mounted || _isVerifying || code.length != _otpLength) return;
    if (_otpController.text != code) return;

    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    await _verifyCode(code);
  }

  void _focusOtpInput() {
    if (!mounted) return;
    FocusScope.of(context).requestFocus(_otpFocusNode);
    _otpController.selection =
        TextSelection.collapsed(offset: _otpController.text.length);
  }

  Future<void> _verifyCode(String code) async {
    if (_isVerifying) return;
    setState(() => _isVerifying = true);

    try {
      final authService = ref.read(authServiceProvider);
      await authService.verifyOtp(
        email: widget.email,
        token: code,
      );

      // Wait briefly for auth state to fully propagate
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        final normalizedEmail = widget.email.trim().toLowerCase();
        if (AuthService.reviewerEmails.contains(normalizedEmail)) {
          print(
              '[EmailVerification] Reviewer account detected - navigating directly to home');
          ref.read(selectedIndexProvider.notifier).state = 0;
          ref.invalidate(selectedIndexProvider);
          ref.invalidate(scrollToTopTriggerProvider);
          ref.invalidate(isAtHomeRootProvider);
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) =>
                  const MainNavigation(key: ValueKey('fresh-main-nav')),
            ),
            (route) => false,
          );
          return;
        }

        // Check if this is a new user or existing user
        final userId = authService.currentUser?.id;
        print('[EmailVerification] User ID after OTP verification: $userId');

        if (userId != null) {
          try {
            // Update checkpoint to 'account' to mark account creation
            print('[EmailVerification] Updating checkpoint to account...');
            try {
              await OnboardingStateService().updateCheckpoint(
                userId,
                OnboardingCheckpoint.account,
              );
              print('[EmailVerification] Checkpoint updated to account');
            } catch (checkpointError) {
              print(
                  '[EmailVerification] Error updating checkpoint: $checkpointError');
            }

            // CRITICAL: Identify user with RevenueCat to link any anonymous purchases
            // This must happen BEFORE checking subscription status
            print(
                '[EmailVerification] Linking RevenueCat subscription to account...');
            try {
              await SubscriptionSyncService().identify(userId);
              print(
                  '[EmailVerification] RevenueCat subscription linked and synced');
            } catch (linkError) {
              print(
                  '[EmailVerification] Error linking RevenueCat subscription: $linkError');
            }

            // Update device fingerprint for fraud prevention
            await FraudPreventionService.updateUserDeviceFingerprint(userId);

            // Calculate fraud score
            try {
              await FraudPreventionService.calculateFraudScore(
                userId,
                email: widget.email,
              );
            } catch (fraudError) {
              print(
                  '[EmailVerification] Error calculating fraud score: $fraudError');
            }

            // Persist ALL onboarding selections if they exist in providers
            final selectedGender = ref.read(selectedGenderProvider);
            final notificationGranted =
                ref.read(notificationPermissionGrantedProvider);
            final styleDirection = ref.read(styleDirectionProvider);
            final whatYouWant = ref.read(whatYouWantProvider);
            final budget = ref.read(budgetProvider);
            final discoverySource = ref.read(selectedDiscoverySourceProvider);

            print(
                '[EmailVerification] Gender from provider: ${selectedGender?.name}');
            print(
                '[EmailVerification] Notification permission from provider: $notificationGranted');
            print(
                '[EmailVerification] Style direction from provider: $styleDirection');
            print(
                '[EmailVerification] What you want from provider: $whatYouWant');
            print('[EmailVerification] Budget from provider: $budget');
            print(
                '[EmailVerification] Discovery source from provider: ${discoverySource?.name}');

            // Map Gender enum to preferred_gender_filter
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

            // Map DiscoverySource enum to string
            String? discoverySourceString;
            if (discoverySource != null) {
              discoverySourceString = discoverySource.name;
            }

            // Save ALL preferences to database
            try {
              await OnboardingStateService().saveUserPreferences(
                userId: userId,
                preferredGenderFilter: preferredGenderFilter,
                notificationEnabled: notificationGranted,
                styleDirection:
                    styleDirection.isNotEmpty ? styleDirection : null,
                whatYouWant: whatYouWant.isNotEmpty ? whatYouWant : null,
                budget: budget,
                discoverySource: discoverySourceString,
              );
              print('[EmailVerification] All onboarding preferences persisted');
            } catch (prefError) {
              print(
                  '[EmailVerification] Error persisting preferences: $prefError');
            }

            // Check if user has completed onboarding from database
            final supabase = Supabase.instance.client;
            final userResponse = await supabase
                .from('users')
                .select('onboarding_state')
                .eq('id', userId)
                .maybeSingle();

            print(
                '[EmailVerification] User record found: ${userResponse != null}');

            final hasCompletedOnboarding = userResponse != null &&
                userResponse['onboarding_state'] == 'completed';
            print(
                '[EmailVerification] Has completed onboarding: $hasCompletedOnboarding');

            final accessState = await SubscriptionSyncService()
                .getUserAccessState(userId: userId);
            final hasActiveSubscription =
                accessState?.hasActiveSubscription ?? false;
            final hasCredits = accessState?.hasCredits ?? false;
            final hasAccess = accessState?.hasAccess ?? false;

            print(
                '[EmailVerification] Access state: hasAccess=$hasAccess '
                'hasActiveSubscription=$hasActiveSubscription '
                'hasCredits=$hasCredits '
                'credits=${accessState?.paidCreditsRemaining}');

            if (hasCompletedOnboarding && hasAccess) {
              // Existing user who completed onboarding and already has access - go to main app
              print(
                  '[EmailVerification] Existing user with access - navigating to main app');
              // Reset to home tab
              ref.read(selectedIndexProvider.notifier).state = 0;
              // Invalidate all providers to refresh state
              ref.invalidate(selectedIndexProvider);
              ref.invalidate(scrollToTopTriggerProvider);
              ref.invalidate(isAtHomeRootProvider);
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) =>
                      const MainNavigation(key: ValueKey('fresh-main-nav')),
                ),
                (route) => false,
              );
            } else if (hasCompletedOnboarding && !hasAccess) {
              // Existing user who completed onboarding but has no access - present paywall
              print(
                  '[EmailVerification] Existing user without access - presenting Superwall paywall');
              await PaywallHelper.presentPaywallAndNavigate(
                context: context,
                userId: userId,
                placement: 'credits_paywall',
              );
            } else {
              // New user - check onboarding progress
              final hasOnboardingData = discoverySource != null;

              if (hasAccess) {
                // User already has access, but onboarding still needs to finish.
                print(
                    '[EmailVerification] New user with access - navigating to welcome');
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) =>
                        const WelcomeFreeAnalysisPage(),
                  ),
                  (route) => false,
                );
              } else if (hasOnboardingData) {
                // User went through onboarding but has no access - present paywall
                print(
                    '[EmailVerification] New user with onboarding data but no access - presenting Superwall paywall');
                await PaywallHelper.presentPaywallAndNavigate(
                  context: context,
                  userId: userId,
                );
              } else {
                // New user without onboarding data - start from beginning
                print(
                    '[EmailVerification] New user without onboarding data - navigating to HowItWorksPage');
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const HowItWorksPage(),
                  ),
                  (route) => false,
                );
              }
            }
          } catch (e) {
            // If check fails, assume new user and route into onboarding entry
            print('[EmailVerification] Check error, assuming new user: $e');
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const HowItWorksPage(),
                ),
                (route) => false,
              );
            }
          }
        }
      }
    } catch (e) {
      print('[EmailVerification] OTP verification error: $e');
      if (mounted) {
        // Clear OTP field on error
        _otpController.clear();
        _focusOtpInput();

        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Invalid verification code. Please try again.',
              style: context.snackTextStyle(
                merge: const TextStyle(fontFamily: 'PlusJakartaSans'),
              ),
            ),
            duration: const Duration(milliseconds: 2500),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;

    final username = parts[0];
    final domain = parts[1];

    if (username.length <= 2) {
      return '${username[0]}${'*' * (username.length - 1)}@$domain';
    }

    final visibleStart = username.substring(0, 2);
    final masked = '*' * (username.length - 2);
    return '$visibleStart$masked@$domain';
  }

  Future<void> _handleResend() async {
    if (_isResending || _isVerifying) return;
    HapticFeedback.mediumImpact();
    setState(() => _isResending = true);

    try {
      final authService = ref.read(authServiceProvider);
      await authService.signInWithOtp(widget.email);

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Verification code resent',
              style: context.snackTextStyle(
                merge: const TextStyle(fontFamily: 'PlusJakartaSans'),
              ),
            ),
            duration: const Duration(milliseconds: 2500),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error resending code: ${e.toString()}',
              style: context.snackTextStyle(
                merge: const TextStyle(fontFamily: 'PlusJakartaSans'),
              ),
            ),
            duration: const Duration(milliseconds: 2500),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: const SnaplookBackButton(),
          ),
          body: Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: spacing.l),

                // Title
                const Text(
                  'Confirm your email',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    fontFamily: 'PlusJakartaSans',
                    letterSpacing: -1.0,
                    height: 1.3,
                  ),
                ),

                SizedBox(height: spacing.xs),

                // Subtitle
                RichText(
                  text: TextSpan(
                    text: 'Please enter the 6-digit code we\'ve just sent to ',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'PlusJakartaSans',
                    ),
                    children: [
                      TextSpan(
                        text: _maskEmail(widget.email),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black,
                          fontFamily: 'PlusJakartaSans',
                          fontWeight: FontWeight.bold,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: spacing.l),

                // Code input boxes
                Stack(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _focusOtpInput,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(_otpLength, (index) {
                          final value = _otpController.text;
                          final digit =
                              index < value.length ? value[index] : '';
                          final isActive = _otpFocusNode.hasFocus &&
                              value.length < _otpLength &&
                              index == value.length;

                          return Container(
                            width: 56,
                            height: 76,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isActive
                                    ? AppColors.secondary
                                    : Colors.black,
                                width: isActive ? 2.4 : 2,
                              ),
                            ),
                            child: digit.isNotEmpty
                                ? Text(
                                    digit,
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'PlusJakartaSans',
                                      color: Colors.black,
                                    ),
                                  )
                                : isActive
                                    ? FadeTransition(
                                        opacity: Tween<double>(
                                          begin: 1,
                                          end: 0.15,
                                        ).animate(_cursorBlinkController),
                                        child: Container(
                                          width: 3,
                                          height: 34,
                                          decoration: BoxDecoration(
                                            color: AppColors.secondary,
                                            borderRadius:
                                                BorderRadius.circular(2),
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                          );
                        }),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 0,
                      child: SizedBox(
                        width: 1,
                        height: 1,
                        child: TextField(
                          controller: _otpController,
                          focusNode: _otpFocusNode,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          showCursor: false,
                          cursorColor: Colors.transparent,
                          style: const TextStyle(
                            fontSize: 1,
                            color: Colors.transparent,
                          ),
                          enableSuggestions: false,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isCollapsed: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(_otpLength),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: spacing.xl),

                // Resend code
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Didn\'t receive the code? ',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                    GestureDetector(
                      onTap: _handleResend,
                      child: const Text(
                        'Resend',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black,
                          fontFamily: 'PlusJakartaSans',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                SizedBox(height: spacing.xxl),
              ],
            ),
          ),
        ),
        if (_isVerifying || _isResending)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          color: AppColors.secondary,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
