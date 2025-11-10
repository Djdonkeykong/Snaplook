import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// RevenueCat Customer Center
/// Provides a self-service UI for users to manage their subscriptions
/// including viewing subscription status, changing plans, and accessing support
///
/// Note: Customer Center UI is managed through RevenueCat's presentCustomerCenter method
class CustomerCenterPage extends StatefulWidget {
  const CustomerCenterPage({super.key});

  @override
  State<CustomerCenterPage> createState() => _CustomerCenterPageState();
}

class _CustomerCenterPageState extends State<CustomerCenterPage> {
  @override
  void initState() {
    super.initState();
    _showCustomerCenter();
  }

  Future<void> _showCustomerCenter() async {
    try {
      // Present the customer center using RevenueCat's native implementation
      // This will show a native UI for subscription management
      await Purchases.presentCustomerCenter();

      // Pop the page after customer center is dismissed
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error showing customer center: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to show subscription management: $e'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while customer center is being presented
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Management'),
      ),
      body: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

/// Show Customer Center as a modal
Future<void> showCustomerCenter(BuildContext context) async {
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => const CustomerCenterPage(),
      fullscreenDialog: true,
    ),
  );
}
