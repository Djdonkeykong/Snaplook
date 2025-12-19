import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../domain/providers/auth_provider.dart';
import '../../../onboarding/presentation/pages/welcome_free_analysis_page.dart';
import '../../../onboarding/presentation/pages/how_it_works_page.dart';
import '../../../onboarding/presentation/pages/notification_permission_page.dart';
import '../../../paywall/presentation/pages/paywall_page.dart';
import '../../../../../shared/navigation/main_navigation.dart'
    show MainNavigation, selectedIndexProvider, scrollToTopTriggerProvider, isAtHomeRootProvider;
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

class _EmailVerificationPageState extends ConsumerState<EmailVerificationPage> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  @override
  void initState() {
    super.initState();

    // Add keyboard event listeners to each focus node
    for (int i = 0; i < 6; i++) {
      final index = i; // Capture index for closure
      _focusNodes[i].onKeyEvent = (node, event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.backspace ||
              key == LogicalKeyboardKey.delete) {
            final handled = _handleBackspaceKey(index);
            return handled ? KeyEventResult.handled : KeyEventResult.ignored;
          }
        }
        return KeyEventResult.ignored;
      };
    }

    // Auto-focus first code input field after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _focusNodes[0].requestFocus();
      }
    });
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _handleCodeInput(int index, String value) async {
    if (value.length > 1) {
      // If user pastes or types multiple digits, take only the first one
      _controllers[index].text = value[0];
      _controllers[index].selection = TextSelection.fromPosition(
        TextPosition(offset: 1),
      );
      value = value[0];
    }

    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }

    // Check if all fields are filled
    bool allFilled = _controllers.every((c) => c.text.isNotEmpty);
    if (allFilled) {
      String code = _controllers.map((c) => c.text).join();
      await _verifyCode(code);
    }
  }

  Future<void> _verifyCode(String code) async {
    try {
      final authService = ref.read(authServiceProvider);
      await authService.verifyOtp(
        email: widget.email,
        token: code,
      );

      // Wait briefly for auth state to fully propagate
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
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
              print('[EmailVerification] Error updating checkpoint: $checkpointError');
            }

            // CRITICAL: Identify user with RevenueCat to link any anonymous purchases
            // This must happen BEFORE checking subscription status
            print('[EmailVerification] Linking RevenueCat subscription to account...');
            try {
              await SubscriptionSyncService().identify(userId);
              print('[EmailVerification] RevenueCat subscription linked and synced');
            } catch (linkError) {
              print('[EmailVerification] Error linking RevenueCat subscription: $linkError');
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
              print('[EmailVerification] Error calculating fraud score: $fraudError');
            }

            // Persist ALL onboarding selections if they exist in providers
            final selectedGender = ref.read(selectedGenderProvider);
            final notificationGranted = ref.read(notificationPermissionGrantedProvider);
            final styleDirection = ref.read(styleDirectionProvider);
            final whatYouWant = ref.read(whatYouWantProvider);
            final budget = ref.read(budgetProvider);
            final discoverySource = ref.read(selectedDiscoverySourceProvider);

            print('[EmailVerification] Gender from provider: ${selectedGender?.name}');
            print('[EmailVerification] Notification permission from provider: $notificationGranted');
            print('[EmailVerification] Style direction from provider: $styleDirection');
            print('[EmailVerification] What you want from provider: $whatYouWant');
            print('[EmailVerification] Budget from provider: $budget');
            print('[EmailVerification] Discovery source from provider: ${discoverySource?.name}');

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
                styleDirection: styleDirection.isNotEmpty ? styleDirection : null,
                whatYouWant: whatYouWant.isNotEmpty ? whatYouWant : null,
                budget: budget,
                discoverySource: discoverySourceString,
              );
              print('[EmailVerification] All onboarding preferences persisted');
            } catch (prefError) {
              print('[EmailVerification] Error persisting preferences: $prefError');
            }

            // Check if user has completed onboarding
            final supabase = Supabase.instance.client;
            final userResponse = await supabase
                .from('users')
                .select('onboarding_state, subscription_status, is_trial')
                .eq('id', userId)
                .maybeSingle();

            print('[EmailVerification] User record found: ${userResponse != null}');

            // Check if user has completed onboarding
            final hasCompletedOnboarding = userResponse != null && userResponse['onboarding_state'] == 'completed';
            final subscriptionStatus = userResponse != null ? userResponse['subscription_status'] as String? : null;
            final isTrial = userResponse != null && userResponse['is_trial'] == true;
            final hasActiveSubscription = subscriptionStatus == 'active' || isTrial;
            print('[EmailVerification] Has completed onboarding: $hasCompletedOnboarding');
            print('[EmailVerification] Subscription status: $subscriptionStatus');
            print('[EmailVerification] Is trial: $isTrial');
            print('[EmailVerification] Has active subscription: $hasActiveSubscription');

            if (hasCompletedOnboarding && hasActiveSubscription) {
              // Existing user who completed onboarding and has active subscription - go to main app
              print('[EmailVerification] Existing user with subscription - navigating to main app');
              // Reset to home tab
              ref.read(selectedIndexProvider.notifier).state = 0;
              // Invalidate all providers to refresh state
              ref.invalidate(selectedIndexProvider);
              ref.invalidate(scrollToTopTriggerProvider);
              ref.invalidate(isAtHomeRootProvider);
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const MainNavigation(key: ValueKey('fresh-main-nav')),
                ),
                (route) => false,
              );
            } else if (hasCompletedOnboarding && !hasActiveSubscription) {
              // Existing user who completed onboarding but NO subscription - go to paywall
              print('[EmailVerification] Existing user without subscription - navigating to paywall');
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const PaywallPage(),
                ),
                (route) => false,
              );
            } else {
              // New user - check onboarding progress
              final hasOnboardingData = selectedGender != null;

              if (hasActiveSubscription) {
                // User purchased subscription - go straight to home
                print('[EmailVerification] New user with subscription - navigating to home');
                ref.read(selectedIndexProvider.notifier).state = 0;
                ref.invalidate(selectedIndexProvider);
                ref.invalidate(scrollToTopTriggerProvider);
                ref.invalidate(isAtHomeRootProvider);
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const MainNavigation(key: ValueKey('fresh-main-nav')),
                  ),
                  (route) => false,
                );
              } else if (hasOnboardingData) {
                // User went through onboarding but no subscription - go to paywall
                print('[EmailVerification] New user with onboarding data but no subscription - navigating to paywall');
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const PaywallPage(),
                  ),
                  (route) => false,
                );
              } else {
                // New user without onboarding data - start from beginning
                print('[EmailVerification] New user without onboarding data - navigating to HowItWorksPage');
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
        // Clear all fields on error
        for (var controller in _controllers) {
          controller.clear();
        }
        _focusNodes[0].requestFocus();

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
    }
  }

  bool _handleBackspaceKey(int index) {
    final controller = _controllers[index];
    if (controller.text.isNotEmpty) {
      // Current field has content - clear it
      controller.clear();
      controller.selection = const TextSelection.collapsed(offset: 0);
      return true;
    }

    if (index > 0) {
      // Current field is empty - go to previous field and clear it
      final previousController = _controllers[index - 1];
      _focusNodes[index - 1].requestFocus();
      previousController.clear();
      previousController.selection = const TextSelection.collapsed(offset: 0);
      return true;
    }

    return false;
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Scaffold(
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (index) {
                return SizedBox(
                  width: 56,
                  height: 76,
                  child: TextField(
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    showCursor: true,
                    cursorColor: Colors.black,
                    cursorWidth: 2,
                    cursorHeight: 32,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'PlusJakartaSans',
                      color: Colors.black,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 0,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.black,
                          width: 2,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.black,
                          width: 2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.black,
                          width: 2,
                        ),
                      ),
                    ),
                    onChanged: (value) {
                      _handleCodeInput(index, value);
                    },
                    onTap: () {
                      _controllers[index].selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: _controllers[index].text.length,
                      );
                    },
                  ),
                );
              }),
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
    );
  }
}
