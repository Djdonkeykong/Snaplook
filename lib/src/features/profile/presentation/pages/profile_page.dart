import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../shared/navigation/main_navigation.dart';
import '../../../auth/domain/providers/auth_provider.dart';
import '../../../auth/presentation/pages/login_page.dart';

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
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
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
            MaterialPageRoute(
              builder: (context) => const LoginPage(),
            ),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error logging out: ${e.toString()}'),
              backgroundColor: Colors.red,
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
          child: Padding(
            padding: EdgeInsets.all(spacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                const Text(
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

                SizedBox(height: spacing.xl),

                // Account Section
                _SectionCard(
                  title: 'Account',
                  children: [
                    _SettingItem(
                      icon: Icons.person_outline,
                      title: 'Profile',
                      subtitle: 'Enter your name',
                      trailing: const Text(
                        '30 years old',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      onTap: () {},
                    ),
                    _SettingItem(
                      icon: Icons.workspace_premium_outlined,
                      title: 'Premium',
                      subtitle: 'Upgrade to unlock all features',
                      onTap: () {},
                    ),
                  ],
                ),

                SizedBox(height: spacing.l),

                // Preferences Section
                _SectionCard(
                  title: 'Preferences',
                  children: [
                    _SettingItem(
                      icon: Icons.palette_outlined,
                      title: 'Appearance',
                      subtitle: 'Choose light, dark, or system appearance',
                      trailing: const Text(
                        'Light',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      onTap: () {},
                    ),
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
                    _SettingItem(
                      icon: Icons.language_outlined,
                      title: 'Language',
                      subtitle: 'Select your preferred language',
                      trailing: const Text(
                        'English',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      onTap: () {},
                    ),
                  ],
                ),

                SizedBox(height: spacing.l),

                // Fashion Preferences Section
                _SectionCard(
                  title: 'Fashion Preferences',
                  children: [
                    _SettingItem(
                      icon: Icons.style_outlined,
                      title: 'Style preferences',
                      subtitle: 'Casual, formal, streetwear',
                      onTap: () {},
                    ),
                    _SettingItem(
                      icon: Icons.straighten_outlined,
                      title: 'Size preferences',
                      subtitle: 'Save your sizes for quick reference',
                      onTap: () {},
                    ),
                    _SettingItem(
                      icon: Icons.attach_money_outlined,
                      title: 'Budget range',
                      subtitle: 'Filter products by price',
                      onTap: () {},
                    ),
                  ],
                ),

                SizedBox(height: spacing.l),

                // Data & Privacy Section
                _SectionCard(
                  title: 'Data & Privacy',
                  children: [
                    _SettingItem(
                      icon: Icons.history_outlined,
                      title: 'Clear search history',
                      subtitle: 'Remove all search data',
                      onTap: () {},
                    ),
                    _SettingItem(
                      icon: Icons.favorite_outline,
                      title: 'Clear favorites',
                      subtitle: 'Remove all saved items',
                      onTap: () {},
                    ),
                    _SettingItem(
                      icon: Icons.download_outlined,
                      title: 'Export data',
                      subtitle: 'Download your personal data',
                      onTap: () {},
                    ),
                    _SettingItem(
                      icon: Icons.shield_outlined,
                      title: 'Privacy Policy',
                      onTap: () {},
                    ),
                    _SettingItem(
                      icon: Icons.description_outlined,
                      title: 'Terms and Conditions',
                      onTap: () {},
                    ),
                  ],
                ),

                SizedBox(height: spacing.l),

                // Support Section
                _SectionCard(
                  title: 'Support',
                  children: [
                    _SettingItem(
                      icon: Icons.help_outline,
                      title: 'Help & FAQ',
                      onTap: () {},
                    ),
                    _SettingItem(
                      icon: Icons.email_outlined,
                      title: 'Support Email',
                      onTap: () {},
                    ),
                    _SettingItem(
                      icon: Icons.bug_report_outlined,
                      title: 'Report a bug',
                      onTap: () {},
                    ),
                    _SettingItem(
                      icon: Icons.school_outlined,
                      title: 'Tutorial',
                      subtitle: 'Learn how to use the app',
                      onTap: () {},
                    ),
                  ],
                ),

                SizedBox(height: spacing.l),

                // Social Section
                _SectionCard(
                  title: 'Social',
                  children: [
                    _SettingItem(
                      icon: Icons.share_outlined,
                      title: 'Share app',
                      subtitle: 'Tell your friends about Snaplook',
                      onTap: () {},
                    ),
                    _SettingItem(
                      icon: Icons.star_outline,
                      title: 'Rate the app',
                      onTap: () {},
                    ),
                    _SettingItem(
                      icon: Icons.sync_outlined,
                      title: 'Sync Data',
                      trailing: const Text(
                        'Last Synced: 1:35 PM',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      onTap: () {},
                    ),
                  ],
                ),

                SizedBox(height: spacing.l),

                // Account Actions Section
                _SectionCard(
                  children: [
                    _SettingItem(
                      icon: Icons.logout_outlined,
                      title: 'Logout',
                      titleColor: AppColors.secondary,
                      onTap: _handleLogout,
                    ),
                    _SettingItem(
                      icon: Icons.person_remove_outlined,
                      title: 'Delete Account',
                      titleColor: Colors.red.shade600,
                      onTap: () {},
                    ),
                  ],
                ),

                SizedBox(height: spacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String? title;
  final List<Widget> children;

  const _SectionCard({
    this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Padding(
            padding: EdgeInsets.only(left: spacing.m, bottom: spacing.sm),
            child: Text(
              title!,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ],
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE5E7EB),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: const Color(0xFFF3F4F6),
                    indent: 60,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;

  const _SettingItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all(spacing.m),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFFF9F9F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 18,
                color: Colors.black87,
              ),
            ),
            SizedBox(width: spacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: titleColor ?? Colors.black,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              const Icon(
                Icons.chevron_right,
                color: Color(0xFF9CA3AF),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
