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

    _nameController = TextEditingController(text: fullName)
      ..addListener(_handleProfileFieldsChanged);
    _usernameController = TextEditingController(text: username)
      ..addListener(_handleProfileFieldsChanged);
    _membershipType = _formatMembershipLabel(normalizedMembership);
    _isPremiumMember = loweredMembership.contains('premium') ||
        loweredMembership.contains('pro');
  }

  @override
  void dispose() {
    _nameController.removeListener(_handleProfileFieldsChanged);
    _usernameController.removeListener(_handleProfileFieldsChanged);
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final spacing = context.spacing;
    final user = ref.watch(currentUserProvider);
    final displayUsername = _usernameController.text.isNotEmpty
        ? _usernameController.text
        : (user?.email?.split('@').first ?? 'User');
    final circleLabel =
        displayUsername.isNotEmpty ? displayUsername[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        leadingWidth: 56,
        leading: SnaplookBackButton(
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Profile',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: 'PlusJakartaSans',
            color: colorScheme.onSurface,
            letterSpacing: -0.3,
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
                        color: Color(0xFFF2003C),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        circleLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'PlusJakartaSans',
                          color: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(height: spacing.s),
                    Text(
                      displayUsername,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'PlusJakartaSans',
                        color: colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: spacing.xs),
                    Text(
                      'Membership: $_membershipType',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'PlusJakartaSans',
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: spacing.m),
                    TextButton(
                      onPressed: () {
                        // TODO: Implement avatar editing
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: spacing.l,
                          vertical: spacing.xs,
                        ),
                        backgroundColor: colorScheme.surfaceVariant,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        'Edit profile',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontFamily: 'PlusJakartaSans',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(height: spacing.l),
                  ],
                ),
              ),
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

  void _handleProfileFieldsChanged() {
    if (mounted) {
      setState(() {});
    }
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
              borderSide: const BorderSide(
                  color: AppColors.secondary,
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

