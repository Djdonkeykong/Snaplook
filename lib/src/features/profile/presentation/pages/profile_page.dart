import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_cupertino_navigation_bar/super_cupertino_navigation_bar.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/theme/theme_mode_notifier.dart';
import '../../../../../shared/navigation/main_navigation.dart';
import '../../../auth/domain/providers/auth_provider.dart';
import '../../../auth/presentation/pages/login_page.dart';
import 'edit_profile_page.dart';
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
        backgroundColor: Theme.of(context).colorScheme.surface,
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
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              textStyle: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : AppColors.secondary,
              textStyle: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('Logout'),
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
  }

  Future<void> _showThemeModeSheet() async {
    final currentMode = ref.read(themeModeProvider);
    final selectedMode = await showModalBottomSheet<ThemeMode>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => _ThemeModeBottomSheet(currentMode: currentMode),
    );
    if (selectedMode != null) {
      await ref.read(themeModeProvider.notifier).setThemeMode(selectedMode);
    }
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
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

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final spacing = context.spacing;
    final themeMode = ref.watch(themeModeProvider);
    final user = ref.watch(currentUserProvider);
    final userEmail = user?.email ?? 'user@example.com';
    final initials = userEmail.isNotEmpty ? userEmail[0].toUpperCase() : 'U';
    final metadata = user?.userMetadata ?? <String, dynamic>{};
    final membershipValue = metadata['membership'];
    final membershipLabel = _formatMembershipLabel(membershipValue);
    final isPremiumMembership = _isPremiumMembership(membershipValue);

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: SuperScaffold(
        scrollController: _scrollController,
        appBar: SuperAppBar(
          title: Text(
            'Settings',
            style: TextStyle(
              fontSize: 17,
              fontFamily: 'PlusJakartaSans',
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          backgroundColor: colorScheme.surface,
          searchBar: SuperSearchBar(enabled: false),
          largeTitle: SuperLargeTitle(
            largeTitle: 'Settings',
            textStyle: TextStyle(
              fontSize: 30,
              fontFamily: 'PlusJakartaSans',
              letterSpacing: -1.0,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
              height: 1.3,
            ),
            padding: EdgeInsets.symmetric(horizontal: spacing.l),
          ),
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(top: spacing.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Section
                Material(
                  color: colorScheme.surface,
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const EditProfilePage()),
                      );
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
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'PlusJakartaSans',
                                color: colorScheme.onSurface,
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
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'PlusJakartaSans',
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  userEmail,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontFamily: 'PlusJakartaSans',
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                SizedBox(height: spacing.xs),
                                _MembershipBadge(
                                  label: membershipLabel,
                                  isPremium: isPremiumMembership,
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right,
                              color: colorScheme.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: spacing.m),

                // Settings Section
                _SectionHeader(title: 'Settings'),
                _SimpleSettingItem(
                  title: 'Notifications',
                  onTap: () {},
                ),
                _SimpleSettingItem(
                  title: 'Appearance',
                  trailingText: _themeModeLabel(themeMode),
                  onTap: _showThemeModeSheet,
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
                      MaterialPageRoute(
                          builder: (_) => const ContactSupportPage()),
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
                      MaterialPageRoute(
                          builder: (_) => const PrivacyPolicyPage()),
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
                  textColor: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : AppColors.secondary,
                  onTap: _handleLogout,
                ),
                _SimpleSettingItem(
                  title: 'Delete Account',
                  textColor: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : AppColors.secondary,
                  onTap: () {},
                ),

                SizedBox(height: spacing.xl),

                // Version info
                Center(
                  child: Text(
                    'Version 1.0.0',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurfaceVariant,
                      fontFamily: 'PlusJakartaSans',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                SizedBox(height: spacing.xl),
              ],
            ),
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
            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
  final String? trailingText;

  const _SimpleSettingItem({
    required this.title,
    this.onTap,
    this.textColor,
    this.trailingText,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surface,
      child: InkWell(
        onTap: onTap,
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
                    color: textColor ?? colorScheme.onSurface,
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
              ),
              if (trailingText != null)
                Padding(
                  padding: EdgeInsets.only(right: spacing.xs),
                  child: Text(
                    trailingText!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurfaceVariant,
                      fontFamily: 'PlusJakartaSans',
                    ),
                  ),
                ),
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeModeBottomSheet extends StatelessWidget {
  final ThemeMode currentMode;

  const _ThemeModeBottomSheet({required this.currentMode});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = context.radius.large;

    const options = [
      _ThemeModeOption(
        mode: ThemeMode.system,
        title: 'Use system setting',
        description: 'Automatically follow your device appearance.',
        icon: Icons.auto_mode_outlined,
      ),
      _ThemeModeOption(
        mode: ThemeMode.light,
        title: 'Light',
        description: 'Bright background with dark text.',
        icon: Icons.light_mode_outlined,
      ),
      _ThemeModeOption(
        mode: ThemeMode.dark,
        title: 'Dark',
        description: 'Dim background with light text.',
        icon: Icons.dark_mode_outlined,
      ),
    ];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: spacing.l,
          right: spacing.l,
          top: spacing.m,
          bottom: spacing.l + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            SizedBox(height: spacing.m),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Appearance',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'PlusJakartaSans',
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            SizedBox(height: spacing.s),
            ...options.map(
              (option) => Padding(
                padding: EdgeInsets.only(bottom: spacing.s),
                child: _ThemeModeOptionTile(
                  option: option,
                  isSelected: option.mode == currentMode,
                  borderRadius: radius,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeModeOptionTile extends StatelessWidget {
  final _ThemeModeOption option;
  final bool isSelected;
  final double borderRadius;

  const _ThemeModeOptionTile({
    required this.option,
    required this.isSelected,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(borderRadius),
      onTap: () => Navigator.of(context).pop(option.mode),
      child: Container(
        padding: EdgeInsets.all(spacing.m),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.secondary.withOpacity(0.12)
              : colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color:
                isSelected ? colorScheme.secondary : colorScheme.outlineVariant,
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              option.icon,
              size: 24,
              color:
                  isSelected ? colorScheme.secondary : colorScheme.onSurface,
            ),
            SizedBox(width: spacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          option.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'PlusJakartaSans',
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle,
                          size: 20,
                          color: colorScheme.secondary,
                        ),
                    ],
                  ),
                  SizedBox(height: spacing.xs),
                  Text(
                    option.description,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'PlusJakartaSans',
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeModeOption {
  final ThemeMode mode;
  final String title;
  final String description;
  final IconData icon;

  const _ThemeModeOption({
    required this.mode,
    required this.title,
    required this.description,
    required this.icon,
  });
}

class _MembershipBadge extends StatelessWidget {
  final String label;
  final bool isPremium;

  const _MembershipBadge({
    required this.label,
    required this.isPremium,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = isPremium
        ? colorScheme.secondary.withOpacity(0.12)
        : colorScheme.surfaceVariant;
    final textColor =
        isPremium ? colorScheme.secondary : colorScheme.onSurfaceVariant;
    final borderColor =
        isPremium ? colorScheme.secondary : colorScheme.outlineVariant;
    final radius = context.radius.medium;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.s,
        vertical: spacing.xs,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium_outlined,
            size: 14,
            color: textColor,
          ),
          SizedBox(width: spacing.xs),
          Text(
            '$label member',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'PlusJakartaSans',
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatMembershipLabel(dynamic membershipValue) {
  final raw = (membershipValue is String
          ? membershipValue
          : membershipValue?.toString() ?? '')
      .trim();
  if (raw.isEmpty) {
    return 'Free';
  }
  final normalized = raw.replaceAll(RegExp(r'[_-]+'), ' ').trim();
  final segments = normalized
      .split(RegExp(r'\s+'))
      .where((segment) => segment.isNotEmpty)
      .map(
        (segment) =>
            segment[0].toUpperCase() + segment.substring(1).toLowerCase(),
      )
      .toList();
  return segments.isEmpty ? 'Free' : segments.join(' ');
}

bool _isPremiumMembership(dynamic membershipValue) {
  final raw = (membershipValue is String
          ? membershipValue
          : membershipValue?.toString() ?? '')
      .toLowerCase();
  return raw.contains('premium') || raw.contains('pro');
}
