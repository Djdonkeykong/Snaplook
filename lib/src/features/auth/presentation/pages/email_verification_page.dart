import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../domain/providers/auth_provider.dart';
import '../../../onboarding/presentation/pages/welcome_free_analysis_page.dart';
import '../../../onboarding/presentation/pages/how_it_works_page.dart';
import '../../../../../shared/navigation/main_navigation.dart'
    show MainNavigation, selectedIndexProvider, scrollToTopTriggerProvider, isAtHomeRootProvider;
import '../../../../shared/widgets/snaplook_back_button.dart';
import '../../../../services/onboarding_state_service.dart';
import '../../../../services/subscription_sync_service.dart';

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
            // Refresh subscription data in case purchase happened pre-signup
            try {
              await SubscriptionSyncService().syncSubscriptionToSupabase();
            } catch (syncError) {
              print('[EmailVerification] Subscription sync error (ignored): $syncError');
            }

            // Check if user has completed onboarding
            final supabase = Supabase.instance.client;
            final userResponse = await supabase
                .from('users')
                .select('onboarding_state, subscription_status')
                .eq('id', userId)
                .maybeSingle();

            print('[EmailVerification] User record found: ${userResponse != null}');

            // Check if user has completed onboarding
            final hasCompletedOnboarding = userResponse != null && userResponse['onboarding_state'] == 'completed';
            final subscriptionStatus = userResponse != null ? userResponse['subscription_status'] as String? : null;
            final hasActiveSubscription = subscriptionStatus == 'active';
            final paymentCompleteState = userResponse != null && userResponse['onboarding_state'] == 'payment_complete';
            print('[EmailVerification] Has completed onboarding: $hasCompletedOnboarding');
            print('[EmailVerification] Subscription status: $subscriptionStatus');

            if (hasCompletedOnboarding) {
              // Existing user who completed onboarding - go to main app
              print('[EmailVerification] Existing user - navigating to main app');
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
            } else {
              // New user. If they already purchased, mark payment complete and jump to welcome; otherwise start from How It Works.
              final shouldJumpToWelcome = hasActiveSubscription || paymentCompleteState;

              if (shouldJumpToWelcome) {
                try {
                  await OnboardingStateService().markPaymentComplete(userId);
                } catch (e) {
                  print('[EmailVerification] Error marking payment complete: $e');
                }
              }

              print('[EmailVerification] New user - navigating to ${shouldJumpToWelcome ? 'welcome' : 'onboarding intro'}');
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) =>
                      shouldJumpToWelcome ? const WelcomeFreeAnalysisPage() : const HowItWorksPage(),
                ),
                (route) => false,
              );
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

            SizedBox(height: spacing.m),

            // Subtitle
            RichText(
              text: TextSpan(
                text: 'Please enter the 6-digit code we\'ve just sent to ',
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF6B7280),
                  fontFamily: 'PlusJakartaSans',
                  height: 1.5,
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

            SizedBox(height: spacing.xl),

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
