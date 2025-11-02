import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../shared/navigation/main_navigation.dart';
import '../../../auth/domain/providers/auth_provider.dart';
import '../../../auth/presentation/pages/email_sign_in_page.dart';
import '../../../home/domain/providers/inspiration_provider.dart';
import '../widgets/progress_indicator.dart';

class AccountCreationPage extends ConsumerWidget {
  const AccountCreationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_back,
              color: Colors.black,
              size: 20,
            ),
          ),
        ),
        centerTitle: true,
        title: const OnboardingProgressIndicator(
          currentStep: 5,
          totalSteps: 5,
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
                    'Create an account',
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
                          // Apple button
                          _AuthButton(
                            icon: Icons.apple,
                            iconSize: 32,
                            label: 'Continue with Apple',
                            backgroundColor: Colors.black,
                            textColor: Colors.white,
                            onPressed: () async {
                              try {
                                final authService = ref.read(authServiceProvider);
                                await authService.signInWithApple();

                                if (context.mounted) {
                                  // Reset tab to home and refresh providers
                                  ref.read(selectedIndexProvider.notifier).state = 0;
                                  ref.invalidate(inspirationProvider);
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(
                                      builder: (context) => const MainNavigation(),
                                    ),
                                    (route) => false,
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error signing in with Apple: ${e.toString()}'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                          ),

                          SizedBox(height: spacing.m),

                          // Google button
                          _AuthButtonWithSvg(
                            svgAsset: 'assets/icons/google_logo.svg',
                            iconSize: 22,
                            label: 'Continue with Google',
                            backgroundColor: Colors.white,
                            textColor: Colors.black,
                            borderColor: const Color(0xFFE5E7EB),
                            onPressed: () async {
                              try {
                                final authService = ref.read(authServiceProvider);
                                await authService.signInWithGoogle();

                                if (context.mounted) {
                                  // Reset tab to home and refresh providers
                                  ref.read(selectedIndexProvider.notifier).state = 0;
                                  ref.invalidate(inspirationProvider);
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(
                                      builder: (context) => const MainNavigation(),
                                    ),
                                    (route) => false,
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error signing in with Google: ${e.toString()}'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
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
                                // TODO: Open Terms of Conditions
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
                                // TODO: Open Privacy Policy
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
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(widget.textColor),
                ),
              )
            else
              Transform.translate(
                offset: widget.icon == Icons.apple ? const Offset(0, -2) : Offset.zero,
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
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(widget.textColor),
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
