import 'package:flutter/material.dart';
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error logging out: ${e.toString()}'),
              backgroundColor: Colors.black,
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

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.all(spacing.l),
                child: const Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 38,
                    fontFamily: 'PlusJakartaSans',
                    letterSpacing: -1.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    height: 1.3,
                  ),
                ),
              ),

              SizedBox(height: spacing.m),

              // Account Section
              Padding(
                padding: EdgeInsets.symmetric(horizontal: spacing.l),
                child: _SectionTitle(title: 'Account'),
              ),
              SizedBox(height: spacing.m),
              _SettingItem(
                  icon: Icons.workspace_premium_outlined,
                  title: 'Premium',
                  subtitle: 'Unlock all features',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PremiumPage()),
                    );
                  },
                ),

              SizedBox(height: spacing.xl),

              // Notifications Section
              Padding(
                padding: EdgeInsets.symmetric(horizontal: spacing.l),
                child: _SectionTitle(title: 'Preferences'),
              ),
              SizedBox(height: spacing.m),
              _SettingItem(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: 'Product updates and new features',
                trailing: Switch(
                  value: true,
                  onChanged: (value) {},
                  activeColor: AppColors.secondary,
                ),
                onTap: null,
              ),

              SizedBox(height: spacing.xl),

              // Support Section
              Padding(
                padding: EdgeInsets.symmetric(horizontal: spacing.l),
                child: _SectionTitle(title: 'Support & Legal'),
              ),
              SizedBox(height: spacing.m),
              _SettingItem(
                icon: Icons.help_outline,
                title: 'Help & FAQ',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HelpFaqPage()),
                  );
                },
              ),
              Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
              _SettingItem(
                icon: Icons.email_outlined,
                title: 'Contact Support',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ContactSupportPage()),
                  );
                },
              ),
              Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
              _SettingItem(
                icon: Icons.shield_outlined,
                title: 'Privacy Policy',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
                  );
                },
              ),
              Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
              _SettingItem(
                icon: Icons.description_outlined,
                title: 'Terms and Conditions',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TermsPage()),
                  );
                },
              ),

              SizedBox(height: spacing.xl),

              // Logout Button
              Padding(
                padding: EdgeInsets.symmetric(horizontal: spacing.l),
                child: GestureDetector(
                  onTap: _handleLogout,
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Center(
                      child: Text(
                        'Logout',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'PlusJakartaSans',
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: spacing.m),

              // Delete Account Button
              Padding(
                padding: EdgeInsets.symmetric(horizontal: spacing.l),
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: AppColors.secondary, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        'Delete Account',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'PlusJakartaSans',
                          color: AppColors.secondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: spacing.xxl),

              // Version info
              Center(
                child: Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                    fontFamily: 'PlusJakartaSans',
                  ),
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

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.black,
        fontFamily: 'PlusJakartaSans',
      ),
    );
  }
}

class _SettingItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 68),
          padding: EdgeInsets.symmetric(vertical: spacing.m, horizontal: spacing.l),
          child: Row(
            children: [
              Icon(icon, size: 22, color: Colors.black),
              SizedBox(width: spacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontFamily: 'PlusJakartaSans',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (onTap != null)
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
