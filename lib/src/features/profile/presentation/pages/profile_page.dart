import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_cupertino_navigation_bar/super_cupertino_navigation_bar.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
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
    final metadata = user?.userMetadata ?? <String, dynamic>{};
    final membershipValue = metadata['membership'];
    final membershipLabel = _formatMembershipLabel(membershipValue);
    final isPremiumMembership = _isPremiumMembership(membershipValue);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SuperScaffold(
        scrollController: _scrollController,
        appBar: SuperAppBar(
          title: const Text(
            'Settings',
            style: TextStyle(
              fontSize: 17,
              fontFamily: 'PlusJakartaSans',
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          backgroundColor: Colors.white,
          searchBar: SuperSearchBar(enabled: false),
          largeTitle: SuperLargeTitle(
            largeTitle: 'Settings',
            textStyle: const TextStyle(
              fontSize: 30,
              fontFamily: 'PlusJakartaSans',
              letterSpacing: -1.0,
              fontWeight: FontWeight.bold,
              color: Colors.black,
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
                  color: Colors.white,
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
                                    color: AppColors.textSecondary,
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
                              color: Colors.grey.shade400),
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
                Center(
                  child: Text(
                    'Version 1.0.0',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textTertiary,
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
            color: AppColors.textSecondary,
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
    final backgroundColor =
        isPremium ? AppColors.secondary.withOpacity(0.1) : Colors.grey.shade100;
    final textColor = isPremium ? AppColors.secondary : AppColors.textSecondary;
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
          color: isPremium ? AppColors.secondary : Colors.grey.shade300,
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
