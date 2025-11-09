import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../providers/credit_provider.dart';
import 'paywall_page.dart';

/// Page for managing subscription and viewing credit balance
class SubscriptionManagementPage extends ConsumerWidget {
  const SubscriptionManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final creditBalance = ref.watch(creditBalanceProvider);
    final subscriptionStatus = ref.watch(subscriptionStatusProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_back,
              color: Colors.black,
              size: 20,
            ),
          ),
        ),
        title: const Text(
          'Subscription',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(creditBalanceProvider.notifier).refresh();
          await ref.read(subscriptionStatusProvider.notifier).refresh();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(spacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Credit balance card
              creditBalance.when(
                data: (balance) => _CreditBalanceCard(balance: balance),
                loading: () => const _LoadingCard(),
                error: (error, _) => _ErrorCard(message: error.toString()),
              ),

              SizedBox(height: spacing.l),

              // Subscription status card
              subscriptionStatus.when(
                data: (status) => _SubscriptionStatusCard(status: status),
                loading: () => const _LoadingCard(),
                error: (error, _) => _ErrorCard(message: error.toString()),
              ),

              SizedBox(height: spacing.l),

              // Action buttons
              creditBalance.when(
                data: (balance) {
                  if (!balance.hasActiveSubscription) {
                    return _UpgradeButton(
                      onTap: () => _navigateToPaywall(context),
                    );
                  }
                  return Column(
                    children: [
                      _ManageSubscriptionButton(
                        onTap: () => _handleManageSubscription(context, ref),
                      ),
                      SizedBox(height: spacing.m),
                      _RestorePurchasesButton(
                        onTap: () => _handleRestore(context, ref),
                      ),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              SizedBox(height: spacing.xl),

              // Info text
              const _InfoSection(),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToPaywall(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const PaywallPage(),
      ),
    );
  }

  Future<void> _handleManageSubscription(BuildContext context, WidgetRef ref) async {
    try {
      HapticFeedback.mediumImpact();
      final purchaseController = ref.read(purchaseControllerProvider);
      await purchaseController.showManagementUI();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not open subscription management',
              style: const TextStyle(fontFamily: 'PlusJakartaSans'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleRestore(BuildContext context, WidgetRef ref) async {
    try {
      HapticFeedback.mediumImpact();

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFf2003c)),
          ),
        ),
      );

      final purchaseController = ref.read(purchaseControllerProvider);
      final success = await purchaseController.restorePurchases();

      if (context.mounted) {
        Navigator.of(context).pop(); // Dismiss loading

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Purchases restored successfully!',
                style: TextStyle(fontFamily: 'PlusJakartaSans'),
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'No purchases found to restore',
                style: TextStyle(fontFamily: 'PlusJakartaSans'),
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Failed to restore purchases',
              style: TextStyle(fontFamily: 'PlusJakartaSans'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _CreditBalanceCard extends StatelessWidget {
  final dynamic balance;

  const _CreditBalanceCard({required this.balance});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(spacing.l),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFf2003c), Color(0xFFd00030)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFf2003c).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Available Credits',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          SizedBox(height: spacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${balance.availableCredits}',
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'scans',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
          if (balance.hasActiveSubscription && balance.nextRefillDate != null) ...[
            SizedBox(height: spacing.m),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Refills on ${DateFormat('MMM d, yyyy').format(balance.nextRefillDate)}',
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SubscriptionStatusCard extends StatelessWidget {
  final dynamic status;

  const _SubscriptionStatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(spacing.l),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                status.isActive ? Icons.check_circle : Icons.cancel,
                color: status.isActive ? Colors.green : Colors.grey,
                size: 24,
              ),
              SizedBox(width: spacing.sm),
              Text(
                status.isActive ? 'Active Subscription' : 'No Active Subscription',
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          if (status.isActive) ...[
            SizedBox(height: spacing.m),
            if (status.isInTrialPeriod) ...[
              _StatusRow(
                icon: Icons.timelapse,
                label: 'Trial Period',
                value: '${status.daysRemainingInTrial} days remaining',
              ),
              SizedBox(height: spacing.sm),
            ],
            if (status.productIdentifier != null)
              _StatusRow(
                icon: Icons.card_membership,
                label: 'Plan',
                value: status.productIdentifier!.contains('yearly') ? 'Yearly' : 'Monthly',
              ),
            if (status.expirationDate != null) ...[
              SizedBox(height: spacing.sm),
              _StatusRow(
                icon: Icons.calendar_today,
                label: 'Renews on',
                value: DateFormat('MMM d, yyyy').format(status.expirationDate!),
              ),
            ],
          ] else ...[
            SizedBox(height: spacing.sm),
            const Text(
              'Subscribe to get monthly credits and unlimited access',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatusRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF6B7280)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 14,
            color: Color(0xFF6B7280),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}

class _UpgradeButton extends StatelessWidget {
  final VoidCallback onTap;

  const _UpgradeButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFf2003c),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: const Text(
          'Upgrade to Premium',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _ManageSubscriptionButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ManageSubscriptionButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black,
          side: BorderSide(color: Colors.grey.shade300, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: const Text(
          'Manage Subscription',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _RestorePurchasesButton extends StatelessWidget {
  final VoidCallback onTap;

  const _RestorePurchasesButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: onTap,
        child: const Text(
          'Restore Purchases',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 14,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFf2003c)),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 32),
          const SizedBox(height: 8),
          Text(
            'Error loading data',
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'How it works',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        _InfoItem(
          icon: Icons.image_search,
          text: 'Use credits to analyze fashion items and find similar styles',
        ),
        const SizedBox(height: 12),
        _InfoItem(
          icon: Icons.refresh,
          text: 'Credits automatically refill every month for subscribers',
        ),
        const SizedBox(height: 12),
        _InfoItem(
          icon: Icons.star,
          text: 'Free users get 1 complimentary scan to try the app',
        ),
      ],
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFFf2003c)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 14,
              color: Color(0xFF6B7280),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
