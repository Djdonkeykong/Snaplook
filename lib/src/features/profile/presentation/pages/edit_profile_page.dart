import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../auth/domain/providers/auth_provider.dart';
import '../../../../shared/widgets/snaplook_back_button.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final String _membershipType;
  late final bool _isPremiumMember;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    final email = user?.email ?? 'user@example.com';
    final metadata = user?.userMetadata ?? <String, dynamic>{};
    final fullName = metadata['full_name'] as String? ?? email.split('@').first;
    final username = metadata['username'] as String? ?? email.split('@').first;
    final membershipValue = metadata['membership'];
    final normalizedMembership = (membershipValue is String
            ? membershipValue
            : membershipValue?.toString() ?? '')
        .trim();
    final loweredMembership = normalizedMembership.toLowerCase();

    _nameController = TextEditingController(text: fullName);
    _usernameController = TextEditingController(text: username);
    _membershipType = _formatMembershipLabel(normalizedMembership);
    _isPremiumMember = loweredMembership.contains('premium') ||
        loweredMembership.contains('pro');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final spacing = context.spacing;
    final user = ref.watch(currentUserProvider);
    final initials = _initialsFromName(_nameController.text, user?.email);

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        automaticallyImplyLeading: false,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: SnaplookBackButton(
            onPressed: () => Navigator.of(context).pop(),
            showBackground: false,
          ),
        ),
        titleSpacing: 0,
        centerTitle: true,
        title: Text(
          'Profile',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: spacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: spacing.l),
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: const BoxDecoration(
                        color: Color(0xFFB4E5D4),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'PlusJakartaSans',
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: spacing.m),
                    TextButton(
                      onPressed: () {
                        // TODO: Implement avatar editing
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: spacing.m,
                          vertical: spacing.xs,
                        ),
                        backgroundColor: colorScheme.surfaceVariant,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        'Edit',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontFamily: 'PlusJakartaSans',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: spacing.l),
              _MembershipStatusCard(
                membershipType: _membershipType,
                isPremium: _isPremiumMember,
              ),
              SizedBox(height: spacing.l),
              _RoundedField(
                  controller: _nameController,
                  title: 'Name',
                  hintText: 'Add your name'),
              SizedBox(height: spacing.xl),
              _RoundedField(
                  controller: _usernameController,
                  title: 'Username',
                  hintText: 'Choose a username'),
              SizedBox(height: spacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  String _initialsFromName(String name, String? email) {
    if (name.trim().isNotEmpty) {
      final parts = name.trim().split(' ');
      if (parts.length == 1) {
        return parts.first[0].toUpperCase();
      }
      return (parts.first[0] + parts.last[0]).toUpperCase();
    }
    final source = email ?? 'U';
    return source[0].toUpperCase();
  }

  String _formatMembershipLabel(String raw) {
    final cleaned = raw.trim();
    if (cleaned.isEmpty) {
      return 'Free';
    }
    final normalized = cleaned.replaceAll(RegExp(r'[_-]+'), ' ').trim();
    final segments =
        normalized.split(RegExp(r'\s+')).where((segment) => segment.isNotEmpty);
    if (segments.isEmpty) {
      return 'Free';
    }
    return segments
        .map(
          (segment) =>
              segment[0].toUpperCase() + segment.substring(1).toLowerCase(),
        )
        .join(' ');
  }
}

class _RoundedField extends StatelessWidget {
  final TextEditingController controller;
  final String title;
  final String hintText;

  const _RoundedField({
    required this.controller,
    required this.title,
    required this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    final radius = context.radius.large;
    final spacing = context.spacing;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: 'PlusJakartaSans',
            color: colorScheme.onSurface,
          ),
        ),
        SizedBox(height: spacing.s),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              fontFamily: 'PlusJakartaSans',
              color: colorScheme.onSurfaceVariant,
            ),
            filled: true,
            fillColor: colorScheme.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radius),
              borderSide:
                  BorderSide(color: colorScheme.outlineVariant, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radius),
              borderSide: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : AppColors.secondary,
                  width: 1.5),
            ),
          ),
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 16,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _MembershipStatusCard extends StatelessWidget {
  final String membershipType;
  final bool isPremium;

  const _MembershipStatusCard({
    required this.membershipType,
    required this.isPremium,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final radius = context.radius.large;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isPremium
        ? (isDark ? Colors.white.withOpacity(0.12) : AppColors.secondary.withOpacity(0.12))
        : colorScheme.surfaceVariant;
    final borderColor = isPremium
        ? (isDark ? Colors.white : AppColors.secondary)
        : colorScheme.outlineVariant;
    final iconColor = isPremium
        ? (isDark ? Colors.white : AppColors.secondary)
        : colorScheme.onSurfaceVariant;
    final descriptionColor = colorScheme.onSurfaceVariant;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(spacing.m),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isPremium
                  ? (isDark ? Colors.white.withOpacity(0.1) : AppColors.secondary.withOpacity(0.1))
                  : colorScheme.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.workspace_premium_outlined,
              color: iconColor,
            ),
          ),
          SizedBox(width: spacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Membership',
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: spacing.xs),
                Text(
                  membershipType,
                  style: TextStyle(
                    fontSize: 18,
                    fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: spacing.xs),
                Text(
                  isPremium
                      ? 'You have access to all premium features.'
                      : 'Enjoy core features on the current plan.',
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'PlusJakartaSans',
                    color: descriptionColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
