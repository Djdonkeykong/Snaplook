import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:io' show Platform;
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../shared/widgets/snaplook_back_button.dart';
import '../widgets/progress_indicator.dart';
import 'account_creation_page.dart';
import 'welcome_free_analysis_page.dart';
import 'trial_intro_page.dart';
import '../../../auth/domain/providers/auth_provider.dart';
import '../../../../services/onboarding_state_service.dart';
import '../../../../services/notification_service.dart';

// Provider to store notification permission choice
final notificationPermissionGrantedProvider =
    StateProvider<bool?>((ref) => null);

class NotificationPermissionPage extends ConsumerStatefulWidget {
  const NotificationPermissionPage({
    super.key,
    this.continueToTrialFlow = false,
  });

  final bool continueToTrialFlow;

  @override
  ConsumerState<NotificationPermissionPage> createState() =>
      _NotificationPermissionPageState();
}

class _NotificationPermissionPageState
    extends ConsumerState<NotificationPermissionPage> {
  bool _isRequesting = false;

  /// Save notification preference to database if user is authenticated
  Future<void> _saveNotificationPreference(bool granted) async {
    try {
      final user = ref.read(authServiceProvider).currentUser;
      if (user == null) {
        debugPrint('[NotificationPermission] No authenticated user - preference will be saved later');
        return;
      }

      debugPrint('[NotificationPermission] Saving notification preference: $granted');

      // Save notification preference to database
      await OnboardingStateService().saveUserPreferences(
        userId: user.id,
        notificationEnabled: granted,
      );

      debugPrint('[NotificationPermission] Notification preference saved successfully');
    } catch (e) {
      debugPrint('[NotificationPermission] Error saving notification preference: $e');
      // Non-critical error - allow user to continue
    }
  }

  Future<void> _handleAllow() async {
    if (_isRequesting) return;

    setState(() {
      _isRequesting = true;
    });

    HapticFeedback.mediumImpact();

    try {
      // Check if Firebase is initialized
      bool firebaseReady = false;
      try {
        Firebase.app();
        firebaseReady = true;
      } catch (e) {
        debugPrint('[NotificationPermission] Firebase not initialized: $e');
      }

      bool granted = false;

      if (firebaseReady) {
        // Request notification permission using Firebase Messaging (shows native iOS dialog)
        final settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );

        granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;

        debugPrint('[NotificationPermission] Permission requested, granted: $granted');
        debugPrint('[NotificationPermission] Authorization status: ${settings.authorizationStatus}');

        // CRITICAL: Explicitly register for remote notifications with iOS
        // When FirebaseAppDelegateProxyEnabled is false, we must manually trigger this
        if (granted && Platform.isIOS) {
          debugPrint('[NotificationPermission] Explicitly registering for remote notifications on iOS...');
          try {
            const platform = MethodChannel('snaplook/notifications');
            await platform.invokeMethod('registerForRemoteNotifications');
            debugPrint('[NotificationPermission] Remote notification registration triggered');

            // Give iOS a moment to generate APNS token, then try to get FCM token
            await Future.delayed(const Duration(milliseconds: 500));

            final token = await FirebaseMessaging.instance.getToken();
            if (token != null) {
              debugPrint('[NotificationPermission] Got FCM token: $token');
            } else {
              debugPrint('[NotificationPermission] FCM token is null - APNS token may not be available yet');
            }
          } catch (e) {
            debugPrint('[NotificationPermission] Error during notification registration: $e');
            // Token will be registered later when APNS token becomes available
          }
        }
      } else {
        debugPrint('[NotificationPermission] Skipping permission request - Firebase not ready');
      }

      // Store permission result in provider
      ref.read(notificationPermissionGrantedProvider.notifier).state = granted;

      // Save preference to database if user is authenticated
      await _saveNotificationPreference(granted);

      // Initialize FCM and register token if permission granted
      if (granted && firebaseReady) {
        try {
          await NotificationService().initialize();
          debugPrint('[NotificationPermission] FCM initialized and token registered');
        } catch (e) {
          debugPrint('[NotificationPermission] Error initializing FCM: $e');
        }
      }

      _navigateToNextStep();
    } catch (e, stackTrace) {
      debugPrint('[NotificationPermission] Error requesting permission: $e');
      debugPrint('[NotificationPermission] Stack trace: $stackTrace');
      // Default to false on error
      ref.read(notificationPermissionGrantedProvider.notifier).state = false;

      _navigateToNextStep();
    } finally {
      if (mounted) {
        setState(() {
          _isRequesting = false;
        });
      }
    }
  }

  Future<void> _handleDontAllow() async {
    HapticFeedback.mediumImpact();

    print('[NotificationPermission] User declined permission');

    // Store that permission was denied
    ref.read(notificationPermissionGrantedProvider.notifier).state = false;

    // Save preference to database if user is authenticated
    await _saveNotificationPreference(false);

    _navigateToNextStep();
  }

  void _navigateToNextStep() {
    if (!mounted) return;

    if (widget.continueToTrialFlow) {
      // Navigate to trial intro page (which leads to reminder, then paywall)
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const TrialIntroPage(),
        ),
      );
      return;
    }

    // Not in trial flow - go directly to account creation or welcome
    final authService = ref.read(authServiceProvider);
    final isAuthenticated = authService.currentUser != null;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => isAuthenticated
            ? const WelcomeFreeAnalysisPage()
            : const AccountCreationPage(),
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
        leading: const SnaplookBackButton(),
        centerTitle: true,
        title: OnboardingProgressIndicator(
          currentStep: widget.continueToTrialFlow ? 6 : 5,
          totalSteps: widget.continueToTrialFlow ? 10 : 6,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.l),
          child: Column(
            children: [
              SizedBox(height: spacing.l),
              Align(
                alignment: Alignment.centerLeft,
                child: const Text(
                  'Get reminders to find\nyour next look',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    fontFamily: 'PlusJakartaSans',
                    letterSpacing: -1.0,
                    height: 1.3,
                  ),
                ),
              ),
              SizedBox(height: spacing.l),
              const Spacer(flex: 2),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D1D6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 32, horizontal: 24),
                        child: Text(
                          'Snaplook Would Like To\nSend You Notifications',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                            fontFamily: 'SF Pro Display',
                            height: 1.3,
                          ),
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        height: 1,
                        color: const Color(0xFFB5B5B5),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _DialogButton(
                              text: "Don't Allow",
                              isPrimary: false,
                              onTap: _handleDontAllow,
                            ),
                          ),
                          Expanded(
                            child: _DialogButton(
                              text: 'Allow',
                              isPrimary: true,
                              onTap: _handleAllow,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
  final VoidCallback onTap;

  const _DialogButton({
    required this.text,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isPrimary ? const Color(0xFFf2003c) : const Color(0xFFD1D1D6),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: isPrimary ? Colors.white : Colors.black,
            fontFamily: 'SF Pro Text',
          ),
        ),
      ),
    );
  }
}
