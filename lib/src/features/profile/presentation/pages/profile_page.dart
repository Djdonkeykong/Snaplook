import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../shared/navigation/main_navigation.dart';
import '../../../auth/domain/providers/auth_provider.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../paywall/providers/credit_provider.dart';
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
              foregroundColor: AppColors.secondary,
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
    final user = ref.watch(currentUserProvider);
    final userEmail = user?.email ?? 'user@example.com';
    final initials = userEmail.isNotEmpty ? userEmail[0].toUpperCase() : 'U';

    // Get subscription status from RevenueCat
    final subscriptionStatusAsync = ref.watch(subscriptionStatusProvider);
    final membershipLabel = subscriptionStatusAsync.when(
      data: (status) {
        if (status.isInTrialPeriod) return 'Trial';
        if (status.isActive) return 'Premium';
        return 'Free';
      },
      loading: () => 'Free',
      error: (_, __) => 'Free',
    );
    final isPremiumMembership = subscriptionStatusAsync.when(
      data: (status) => status.isActive || status.isInTrialPeriod,
      loading: () => false,
      error: (_, __) => false,
    );

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          'Settings',
          style: TextStyle(
            fontSize: 22,
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
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
                                Row(
                                  children: [
                                    _MembershipBadge(
                                      label: membershipLabel,
                                      isPremium: isPremiumMembership,
                                    ),
                                    SizedBox(width: spacing.xs),
                                    // Show trial days or expiration info
                                    subscriptionStatusAsync.when(
                                      data: (status) {
                                        if (status.isInTrialPeriod && status.daysRemainingInTrial != null) {
                                          final days = status.daysRemainingInTrial!;
                                          return Text(
                                            '$days ${days == 1 ? "day" : "days"} left',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontFamily: 'PlusJakartaSans',
                                              color: colorScheme.onSurfaceVariant,
                                            ),
                                          );
                                        }
                                        return const SizedBox.shrink();
                                      },
                                      loading: () => const SizedBox.shrink(),
                                      error: (_, __) => const SizedBox.shrink(),
                                    ),
                                  ],
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

                // Subscription Section
                _SectionHeader(title: 'Subscription'),
                _SimpleSettingItem(
                  title: 'Manage Subscription',
                  onTap: () async {
                    final purchaseController = ref.read(purchaseControllerProvider);
                    await purchaseController.showManagementUI();
                  },
                ),

                SizedBox(height: spacing.l),

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
