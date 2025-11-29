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

      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
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

              // Subscription Status Card
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(spacing.l),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(context.radius.large),
                  border: Border.all(
                    color: colorScheme.outlineVariant,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Plan',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'PlusJakartaSans',
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: spacing.xs),
                    Row(
                      children: [
                        Text(
                          displayStatus,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'PlusJakartaSans',
                            color: isSubscribed
                                ? AppColors.secondary
                                : colorScheme.onSurface,
                            letterSpacing: -0.3,
                          ),
                        ),
                        if (isSubscribed) ...[
                          SizedBox(width: spacing.s),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: spacing.s,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Active',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'PlusJakartaSans',
                                color: AppColors.secondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: spacing.xl),

              // Manage Subscription Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: () => _openSubscriptionManagement(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.secondary,
                    side: const BorderSide(
                      color: AppColors.secondary,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: Text(
                    Platform.isIOS
                        ? 'Manage in App Store'
                        : 'Manage in Google Play',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'PlusJakartaSans',
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),

              SizedBox(height: spacing.m),

              // Restore Purchases Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: () => _restorePurchases(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.onSurface,
                    side: BorderSide(
                      color: colorScheme.outlineVariant,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    'Restore Purchases',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'PlusJakartaSans',
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),

              SizedBox(height: spacing.xl),

              // Info text
              Text(
                'To cancel or modify your subscription, use the ${Platform.isIOS ? 'App Store' : 'Google Play'} subscription management. Changes will take effect at the end of your current billing period.',
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'PlusJakartaSans',
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
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
