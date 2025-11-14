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

  Future<void> _requestNotificationPermission() async {
    if (_isRequesting) return;

    setState(() {
      _isRequesting = true;
    });

    try {
      // Request notification permission
      final status = await Permission.notification.request();

      if (mounted) {
        // Navigate to account creation regardless of permission status
        // User can always enable notifications later in settings
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const AccountCreationPage(),
          ),
        );
      }
    } catch (e) {
      print('[NotificationPermission] Error requesting permission: $e');
      if (mounted) {
        // Even if there's an error, still navigate forward
        Navigator.of(context).pushReplacement(
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

  void _skipNotifications() {
    HapticFeedback.lightImpact();
    Navigator.of(context).pushReplacement(
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
              const Spacer(flex: 2),

              // Title
              const Text(
                'Stay updated with\nnotifications',
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

              // Subtitle
              const Text(
                'Get notified when new fashion trends\nand styles match your preferences',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF6B7280),
                  fontFamily: 'PlusJakartaSans',
                  height: 1.5,
                ),
              ),

              const Spacer(flex: 1),

              // Illustration container
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(spacing.xl),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F9F9),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFE5E7EB),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    // Bell icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFf2003c).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_active_outlined,
                        size: 40,
                        color: Color(0xFFf2003c),
                      ),
                    ),
                    SizedBox(height: spacing.l),

                    // Benefits list
                    _BenefitItem(
                      icon: Icons.favorite_outline,
                      text: 'New items matching your style',
                    ),
                    SizedBox(height: spacing.m),
                    _BenefitItem(
                      icon: Icons.local_offer_outlined,
                      text: 'Exclusive deals and discounts',
                    ),
                    SizedBox(height: spacing.m),
                    _BenefitItem(
                      icon: Icons.auto_awesome_outlined,
                      text: 'Personalized fashion insights',
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 2),

              // Enable notifications button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isRequesting ? null : _requestNotificationPermission,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFf2003c),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    disabledBackgroundColor: const Color(0xFFf2003c).withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: _isRequesting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Enable Notifications',
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

              // Skip button
              TextButton(
                onPressed: _skipNotifications,
                child: const Text(
                  'Maybe later',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF6B7280),
                    fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.w600,
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
}

class _BenefitItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BenefitItem({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: const Color(0xFFf2003c),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black,
              fontFamily: 'PlusJakartaSans',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
