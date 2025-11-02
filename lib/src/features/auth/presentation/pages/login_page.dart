import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:video_player/video_player.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../shared/navigation/main_navigation.dart';
import '../../../../../src/shared/services/video_preloader.dart';
import '../../../onboarding/presentation/pages/gender_selection_page.dart';
import '../../domain/providers/auth_provider.dart';
import 'email_sign_in_page.dart';
import '../../../home/domain/providers/inspiration_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  VideoPlayerController? get _controller => VideoPreloader.instance.loginVideoController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await VideoPreloader.instance.preloadLoginVideo();
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    VideoPreloader.instance.pauseLoginVideo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Calculate video height based on available space
    // Reserve space for: text (90px), button (56px), sign-in (50px), spacings (100px)
    final reservedBottomSpace = 360.0; // Space needed for bottom content
    final topSpacing = 24.0; // spacing.l
    final spacingBelowVideo = 16.0; // spacing.m
    final availableVideoSpace = screenHeight - reservedBottomSpace - topSpacing - spacingBelowVideo;
    final videoHeight = availableVideoSpace.clamp(280.0, availableVideoSpace);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: spacing.l),

              if (_controller != null && VideoPreloader.instance.isLoginVideoInitialized)
                Container(
                  height: videoHeight,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio,
                        child: VideoPlayer(_controller!),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  height: videoHeight,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),

              SizedBox(height: spacing.xl),

              const Text(
                'Snap the look\nin seconds.',
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

              const Spacer(),

              SizedBox(height: spacing.m),

              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const GenderSelectionPage(),
                      ),
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
                    'Get Started',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'PlusJakartaSans',
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),

              SizedBox(height: spacing.m),

              TextButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  _showSignInBottomSheet(context);
                },
                child: RichText(
                  textAlign: TextAlign.center,
                  text: const TextSpan(
                    text: 'Already have an account? ',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.2,
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

              SizedBox(height: spacing.l),
            ],
          ),
        ),
      ),
    );
  }

  void _showSignInBottomSheet(BuildContext context) {
    final spacing = context.spacing;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(spacing.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                margin: EdgeInsets.only(bottom: spacing.m),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title with close button
              Stack(
                children: [
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
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.black,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: spacing.xxl),

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
                      Navigator.pop(context);
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
                      Navigator.pop(context);
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
                      Navigator.pop(context);
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
                      Navigator.pop(context);
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
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const EmailSignInPage(),
                    ),
                  );
                },
              ),

              SizedBox(height: spacing.l),

              // Terms and Privacy Policy
              Padding(
                padding: EdgeInsets.symmetric(horizontal: spacing.m),
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

              SizedBox(height: MediaQuery.of(context).padding.bottom + spacing.m),
            ],
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
