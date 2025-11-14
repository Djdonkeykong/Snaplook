import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/credit_provider.dart';
import '../pages/paywall_page.dart';

/// Dev mode flag - bypass all credit checks when true
final devModeProvider = StateProvider<bool>((ref) => false);

/// Helper function to check credits before performing an action
/// Returns true if action can proceed, false if blocked
Future<bool> checkCreditsBeforeAction(
  BuildContext context,
  WidgetRef ref, {
  required VoidCallback onProceed,
}) async {
  // Dev mode bypass
  final devMode = ref.read(devModeProvider);
  if (devMode) {
    onProceed();
    return true;
  }

  final creditBalance = ref.read(creditBalanceProvider);

  return creditBalance.when(
    data: (balance) {
      if (balance.canPerformAction) {
        // User has credits - proceed with action
        onProceed();
        return true;
      } else {
        // No credits - show paywall
        _showPaywall(context);
        return false;
      }
    },
    loading: () {
      // Still loading - don't proceed
      return false;
    },
    error: (_, __) {
      // Error - show paywall as fallback
      _showPaywall(context);
      return false;
    },
  );
}

/// Show paywall modal
void _showPaywall(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => const PaywallPage(),
      fullscreenDialog: true,
    ),
  );
}

/// Widget that wraps a button and handles credit checks
class CreditGatedButton extends ConsumerWidget {
  final Widget child;
  final VoidCallback onPressed;
  final bool consumeCredit;
  final String? insufficientCreditsMessage;

  const CreditGatedButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.consumeCredit = true,
    this.insufficientCreditsMessage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _handleTap(context, ref),
      child: child,
    );
  }

  Future<void> _handleTap(BuildContext context, WidgetRef ref) async {
    // Dev mode bypass
    final devMode = ref.read(devModeProvider);
    if (devMode) {
      onPressed();
      return;
    }

    final creditBalance = ref.read(creditBalanceProvider);

    await creditBalance.when(
      data: (balance) async {
        if (balance.canPerformAction) {
          // User has credits
          if (consumeCredit) {
            // Consume credit first
            final success = await ref.read(creditBalanceProvider.notifier).consumeCredit();
            if (success) {
              onPressed();
            } else {
              // Credit consumption failed
              if (context.mounted) {
                _showInsufficientCreditsDialog(context);
              }
            }
          } else {
            // Don't consume credit, just proceed
            onPressed();
          }
        } else {
          // No credits available
          if (context.mounted) {
            _showPaywall(context);
          }
        }
      },
      loading: () {
        // Still loading
      },
      error: (error, _) {
        // Error - show paywall as fallback
        if (context.mounted) {
          _showPaywall(context);
        }
      },
    );
  }

  void _showInsufficientCreditsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'No Credits Available',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          insufficientCreditsMessage ??
              'You don\'t have enough credits to perform this action. Subscribe to get monthly credits.',
          style: const TextStyle(fontFamily: 'PlusJakartaSans'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showPaywall(context);
            },
            child: const Text(
              'Get Credits',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                color: Color(0xFFf2003c),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Credit balance display widget
class CreditBalanceDisplay extends ConsumerWidget {
  final bool showLabel;

  const CreditBalanceDisplay({
    super.key,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creditBalance = ref.watch(creditBalanceProvider);

    return creditBalance.when(
      data: (balance) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: balance.availableCredits > 0
              ? const Color(0xFFf2003c).withOpacity(0.1)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: balance.availableCredits > 0
                ? const Color(0xFFf2003c).withOpacity(0.3)
                : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bolt,
              size: 16,
              color: balance.availableCredits > 0
                  ? const Color(0xFFf2003c)
                  : Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(
              '${balance.availableCredits}',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: balance.availableCredits > 0
                    ? const Color(0xFFf2003c)
                    : Colors.grey,
              ),
            ),
            if (showLabel) ...[
              const SizedBox(width: 4),
              Text(
                'credits',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12,
                  color: balance.availableCredits > 0
                      ? const Color(0xFFf2003c)
                      : Colors.grey,
                ),
              ),
            ],
          ],
        ),
      ),
      loading: () => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Badge that shows when user is in free trial
class FreeTrialBadge extends ConsumerWidget {
  const FreeTrialBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creditBalance = ref.watch(creditBalanceProvider);

    return creditBalance.maybeWhen(
      data: (balance) {
        if (balance.isInFreeTrial) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star, size: 12, color: Colors.green.shade700),
                const SizedBox(width: 4),
                Text(
                  'FREE TRIAL',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
