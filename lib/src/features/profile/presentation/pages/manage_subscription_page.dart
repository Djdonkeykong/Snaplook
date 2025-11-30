import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../auth/domain/providers/auth_provider.dart';
import '../../../../shared/widgets/snaplook_back_button.dart';

class ManageSubscriptionPage extends ConsumerWidget {
  const ManageSubscriptionPage({super.key});

  Future<void> _openSubscriptionManagement(BuildContext context) async {
    try {
      Uri? uri;

      if (Platform.isIOS) {
        // iOS subscription management
        uri = Uri.parse('https://apps.apple.com/account/subscriptions');
      } else if (Platform.isAndroid) {
        // Android subscription management
        uri = Uri.parse('https://play.google.com/store/account/subscriptions');
      }

      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not open subscription management',
              style: context.snackTextStyle(
                merge: const TextStyle(fontFamily: 'PlusJakartaSans'),
              ),
            ),
            duration: const Duration(milliseconds: 2000),
          ),
        );
      }
    }
  }

  Future<void> _restorePurchases(BuildContext context) async {
    // TODO: Implement Superwall restore purchases
    // This will call Superwall's restore purchases method
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Restoring purchases...',
          style: context.snackTextStyle(
            merge: const TextStyle(fontFamily: 'PlusJakartaSans'),
          ),
        ),
        duration: const Duration(milliseconds: 2000),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final spacing = context.spacing;

    final user = ref.watch(currentUserProvider);
    final metadata = user?.userMetadata ?? <String, dynamic>{};
    final membershipValue = metadata['membership'];
    final membership = (membershipValue is String
            ? membershipValue
            : membershipValue?.toString() ?? 'free')
        .trim()
        .toLowerCase();

    final isSubscribed = membership != 'free' && membership.isNotEmpty;
    final displayStatus = isSubscribed ? _formatMembership(membership) : 'Free';

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
          'Manage Subscription',
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

              _SettingsCard(
                children: [
                  _SettingsRow.value(
                    label: 'Current Plan',
                    value: displayStatus,
                    valueColor:
                        isSubscribed ? AppColors.secondary : colorScheme.onSurface,
                  ),
                ],
              ),

              SizedBox(height: spacing.l),

              _SettingsCard(
                children: [
                  _SettingsRow.disclosure(
                    label: Platform.isIOS
                        ? 'Manage in App Store'
                        : 'Manage in Google Play',
                    onTap: () => _openSubscriptionManagement(context),
                  ),
                  _Divider(),
                  _SettingsRow.disclosure(
                    label: 'Restore Purchases',
                    onTap: () => _restorePurchases(context),
                  ),
                ],
              ),

              SizedBox(height: spacing.l),

              _SettingsCard(
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Text(
                      'To cancel or modify your subscription, use the ${Platform.isIOS ? 'App Store' : 'Google Play'} subscription management. Changes take effect at the end of your billing period.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: colorScheme.onSurfaceVariant,
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatMembership(String raw) {
    final cleaned = raw.trim();
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

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      color: Color(0xFFECECEC),
      indent: 16,
      endIndent: 16,
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final String label;
  final String? value;
  final Color? valueColor;
  final VoidCallback? onTap;
  final _RowType type;

  const _SettingsRow.value({
    required this.label,
    this.value,
    this.valueColor,
  })  : onTap = null,
        type = _RowType.value;

  const _SettingsRow.disclosure({
    required this.label,
    required this.onTap,
    this.value,
    this.valueColor,
  }) : type = _RowType.disclosure;

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      fontFamily: 'PlusJakartaSans',
      color: Colors.black,
    );
    final valueStyle = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      fontFamily: 'PlusJakartaSans',
      color: valueColor ?? Colors.black.withOpacity(0.6),
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: textStyle,
              ),
            ),
            if (value != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  value!,
                  style: valueStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (type == _RowType.disclosure)
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: Color(0xFF8E8E93),
              ),
          ],
        ),
      ),
    );
  }
}

enum _RowType { value, disclosure }
