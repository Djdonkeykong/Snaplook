import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../widgets/progress_indicator.dart';
import 'account_creation_page.dart';

class NotificationPermissionPage extends ConsumerStatefulWidget {
  const NotificationPermissionPage({super.key});

  @override
  ConsumerState<NotificationPermissionPage> createState() =>
      _NotificationPermissionPageState();
}

class _NotificationPermissionPageState
    extends ConsumerState<NotificationPermissionPage> {
  bool _isRequesting = false;

  Future<void> _handleAllow() async {
    if (_isRequesting) return;

    setState(() {
      _isRequesting = true;
    });

    HapticFeedback.lightImpact();

    try {
      // Request notification permission
      await Permission.notification.request();

      if (mounted) {
        // Navigate to account creation
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const AccountCreationPage(),
          ),
        );
      }
    } catch (e) {
      print('[NotificationPermission] Error requesting permission: $e');
      if (mounted) {
        // Even if there's an error, still navigate forward
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const AccountCreationPage(),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRequesting = false;
        });
      }
    }
  }

  void _handleDontAllow() {
    HapticFeedback.lightImpact();
    // User declined, navigate to account creation anyway
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AccountCreationPage(),
      ),
    );
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
          currentStep: 4,
          totalSteps: 5,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.l),
          child: Column(
            children: [
              const Spacer(flex: 1),

              // Title
              const Text(
                'Reach your goals with\nnotifications',
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

              const Spacer(flex: 2),

              // Mock iOS notification dialog
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D1D6),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      child: Column(
                        children: [
                          const Text(
                            'Snaplook would like to send you\nNotifications',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                              fontFamily: 'PlusJakartaSans',
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Divider(
                            color: Color(0xFFACACAC),
                            height: 1,
                            thickness: 0.5,
                          ),
                          const SizedBox(height: 1),
                          Row(
                            children: [
                              Expanded(
                                child: _DialogButton(
                                  text: "Don't Allow",
                                  isPrimary: false,
                                  onTap: _isRequesting ? null : _handleDontAllow,
                                ),
                              ),
                              const SizedBox(
                                width: 1,
                                height: 44,
                                child: ColoredBox(
                                  color: Color(0xFFACACAC),
                                ),
                              ),
                              Expanded(
                                child: _DialogButton(
                                  text: 'Allow',
                                  isPrimary: true,
                                  onTap: _isRequesting ? null : _handleAllow,
                                  isLoading: _isRequesting,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '👆',
                      style: TextStyle(fontSize: 48),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  final String text;
  final bool isPrimary;
  final VoidCallback? onTap;
  final bool isLoading;

  const _DialogButton({
    required this.text,
    required this.isPrimary,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isPrimary ? const Color(0xFF007AFF) : Colors.transparent,
          borderRadius: isPrimary
              ? const BorderRadius.only(
                  bottomRight: Radius.circular(12),
                )
              : const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                text,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: isPrimary ? Colors.white : const Color(0xFF007AFF),
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
      ),
    );
  }
}
