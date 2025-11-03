import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../shared/navigation/main_navigation.dart';
import '../../../auth/domain/providers/auth_provider.dart';
import '../../../auth/presentation/pages/login_page.dart';
import 'premium_page.dart';
import 'help_faq_page.dart';
import 'contact_support_page.dart';
import 'privacy_policy_page.dart';
import 'terms_page.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Logout',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(fontFamily: 'PlusJakartaSans'),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Colors.black,
                fontFamily: 'PlusJakartaSans',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Logout',
              style: TextStyle(
                color: AppColors.secondary,
                fontFamily: 'PlusJakartaSans',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final authService = ref.read(authServiceProvider);
        await authService.signOut();

        if (mounted) {
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error logging out: ${e.toString()}',
                style: const TextStyle(fontFamily: 'PlusJakartaSans'),
              ),
              backgroundColor: Colors.black,
              duration: const Duration(milliseconds: 2500),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to scroll to top trigger for profile tab (index 2)
    ref.listen(scrollToTopTriggerProvider, (previous, next) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    final spacing = context.spacing;
    final user = ref.watch(currentUserProvider);
    final userEmail = user?.email ?? 'user@example.com';
    final initials = userEmail.isNotEmpty ? userEmail[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            children: [
              // Centered Header
              Padding(
                padding: EdgeInsets.symmetric(vertical: spacing.l),
                child: const Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // Profile Section
              Material(
                color: Colors.white,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    // TODO: Navigate to profile edit page
                  },
                  child: Padding(
                    padding: EdgeInsets.all(spacing.l),
                    child: Row(
                      children: [
                        // Circular Avatar
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: const Color(0xFFB4E5D4),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              initials,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'PlusJakartaSans',
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: spacing.m),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userEmail.split('@').first,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'PlusJakartaSans',
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                userEmail,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontFamily: 'PlusJakartaSans',
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: Colors.grey.shade400),
                      ],
                    ),
                  ),
                ),
              ),

              SizedBox(height: spacing.m),

              // Settings Section
              _SectionHeader(title: 'Settings'),
              _SimpleSettingItem(
                title: 'Premium',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PremiumPage()),
                  );
                },
              ),
              _SimpleSettingItem(
                title: 'Notifications',
                onTap: () {},
              ),

              SizedBox(height: spacing.l),

              // Support Section
              _SectionHeader(title: 'Support'),
              _SimpleSettingItem(
                title: 'Help & FAQ',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HelpFaqPage()),
                  );
                },
              ),
              _SimpleSettingItem(
                title: 'Contact Support',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ContactSupportPage()),
                  );
                },
              ),

              SizedBox(height: spacing.l),

              // Legal Section
              _SectionHeader(title: 'Legal'),
              _SimpleSettingItem(
                title: 'Privacy Policy',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
                  );
                },
              ),
              _SimpleSettingItem(
                title: 'Terms and Conditions',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TermsPage()),
                  );
                },
              ),

              SizedBox(height: spacing.l),

              // Account Section
              _SectionHeader(title: 'Account'),
              _SimpleSettingItem(
                title: 'Logout',
                textColor: AppColors.secondary,
                onTap: _handleLogout,
              ),
              _SimpleSettingItem(
                title: 'Delete Account',
                textColor: AppColors.secondary,
                onTap: () {},
              ),

              SizedBox(height: spacing.xl),

              // Version info
              Text(
                'Version 1.0.0',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade400,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),

              SizedBox(height: spacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Padding(
      padding: EdgeInsets.only(
        left: spacing.l,
        right: spacing.l,
        bottom: spacing.sm,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
            fontFamily: 'PlusJakartaSans',
          ),
        ),
      ),
    );
  }
}

class _SimpleSettingItem extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;
  final Color? textColor;

  const _SimpleSettingItem({
    required this.title,
    this.onTap,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap != null
            ? () {
                HapticFeedback.mediumImpact();
                onTap!();
              }
            : null,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.l,
            vertical: spacing.sm + 4,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: textColor ?? Colors.black,
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
