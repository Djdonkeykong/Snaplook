# Quick Integration Guide

## Step 1: Update main.dart

Add RevenueCat initialization to your `main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snaplook/src/features/paywall/paywall.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize RevenueCat before app starts
  await initializePaywallSystem();

  runApp(const ProviderScope(child: MyApp()));
}
```

## Step 2: Update Revenue Cat API Keys

Open `/lib/src/services/revenue_cat_service.dart` and replace:

```dart
static const String _appleApiKey = 'YOUR_APPLE_API_KEY';
static const String _googleApiKey = 'YOUR_GOOGLE_API_KEY';
```

Get your keys from: https://app.revenuecat.com/settings/api-keys

## Step 3: Add Credit Display to App Bar

```dart
import 'package:snaplook/src/features/paywall/paywall.dart';

AppBar(
  title: const Text('Snaplook'),
  actions: [
    // Shows credit balance
    const CreditBalanceDisplay(),
    const SizedBox(width: 16),

    // Shows "FREE TRIAL" badge for new users
    const FreeTrialBadge(),
    const SizedBox(width: 8),
  ],
)
```

## Step 4: Add Credit Check Before Image Analysis

### Option A: Using CreditGatedButton (Recommended)

```dart
import 'package:snaplook/src/features/paywall/paywall.dart';

CreditGatedButton(
  consumeCredit: true, // Automatically consumes 1 credit
  onPressed: () {
    // This only runs if user has credits
    _performImageAnalysis();
  },
  child: ElevatedButton(
    onPressed: null, // Disable - CreditGatedButton handles taps
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFFf2003c),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
    ),
    child: const Text('Analyze Fashion'),
  ),
)
```

### Option B: Manual Credit Check

```dart
import 'package:snaplook/src/features/paywall/paywall.dart';

ElevatedButton(
  onPressed: () async {
    // Check if user has credits
    final canProceed = await checkCreditsBeforeAction(
      context,
      ref,
      onProceed: () async {
        // Consume credit
        await ref.read(creditBalanceProvider.notifier).consumeCredit();

        // Perform analysis
        await _performImageAnalysis();
      },
    );

    if (!canProceed) {
      // User was redirected to paywall
      print('User needs to subscribe');
    }
  },
  child: const Text('Analyze Fashion'),
)
```

## Step 5: Add Subscription Management to Profile

```dart
import 'package:snaplook/src/features/paywall/paywall.dart';

// In your profile/settings page
ListTile(
  leading: const Icon(Icons.card_membership),
  title: const Text('Subscription & Credits'),
  trailing: const Icon(Icons.chevron_right),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SubscriptionManagementPage(),
      ),
    );
  },
)
```

## Step 6: Handle User Authentication

### After Login/Signup

```dart
import 'package:snaplook/src/features/paywall/paywall.dart';

Future<void> onUserLogin(String userId) async {
  // Link RevenueCat to user account
  await initializePaywallWithUser(userId);

  // Credits will now sync across devices
}
```

### After Logout

```dart
import 'package:snaplook/src/features/paywall/paywall.dart';

Future<void> onUserLogout() async {
  // Clean up RevenueCat session
  await cleanupPaywallOnLogout();
}
```

## Step 7: Show Paywall for New Users

```dart
import 'package:snaplook/src/features/paywall/paywall.dart';

// Show paywall after onboarding or when user tries to use app without credits
void showPaywallIfNeeded() {
  final shouldShow = ref.read(shouldShowPaywallProvider);

  if (shouldShow) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PaywallPage(),
        fullscreenDialog: true,
      ),
    );
  }
}
```

## Complete Example: Detection Flow

Here's a complete example showing credit check in an image detection flow:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snaplook/src/features/paywall/paywall.dart';

class DetectionPage extends ConsumerStatefulWidget {
  const DetectionPage({super.key});

  @override
  ConsumerState<DetectionPage> createState() => _DetectionPageState();
}

class _DetectionPageState extends ConsumerState<DetectionPage> {
  bool _isAnalyzing = false;

  @override
  Widget build(BuildContext context) {
    final creditBalance = ref.watch(creditBalanceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fashion Detection'),
        actions: [
          // Show credits in app bar
          const CreditBalanceDisplay(),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Show free trial badge if applicable
          const FreeTrialBadge(),

          // Your image display here
          Expanded(
            child: Center(
              child: Text('Your image preview'),
            ),
          ),

          // Analysis button with credit check
          Padding(
            padding: const EdgeInsets.all(24),
            child: CreditGatedButton(
              consumeCredit: true,
              onPressed: _isAnalyzing ? () {} : _analyzeImage,
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: null, // CreditGatedButton handles taps
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFf2003c),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: _isAnalyzing
                      ? const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        )
                      : const Text(
                          'Analyze Fashion',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ),

          // Show credit info
          creditBalance.when(
            data: (balance) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                balance.availableCredits > 0
                    ? '${balance.availableCredits} credits remaining'
                    : 'No credits available',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12,
                  color: balance.availableCredits > 0
                      ? Colors.green
                      : Colors.red,
                ),
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Future<void> _analyzeImage() async {
    setState(() => _isAnalyzing = true);

    try {
      // Your image analysis logic here
      await Future.delayed(const Duration(seconds: 2));

      // Navigate to results
      if (mounted) {
        Navigator.pushNamed(context, '/results');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Analysis failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }
}
```

## Testing Locally

1. **Run pub get**:
   ```bash
   flutter pub get
   ```

2. **Test without real purchases** (will show errors for now):
   ```bash
   flutter run
   ```

3. **Set up RevenueCat** (follow `REVENUECAT_SETUP.md`):
   - Create account
   - Get API keys
   - Update code with keys
   - Create products in App Store/Play Store
   - Test with sandbox accounts

## Useful Providers

```dart
// Check if user can perform action
final canPerformAction = ref.watch(canPerformActionProvider);

// Check if paywall should be shown
final shouldShowPaywall = ref.watch(shouldShowPaywallProvider);

// Check if user has active subscription
final hasSubscription = ref.watch(hasActiveSubscriptionProvider);

// Check if user is in trial period
final isInTrial = ref.watch(isInTrialPeriodProvider);

// Get credit balance
final credits = ref.watch(creditBalanceProvider);

// Get subscription status
final status = ref.watch(subscriptionStatusProvider);
```

## Next Steps

1. ✅ Install dependencies: `flutter pub get`
2. ✅ Update API keys in `revenue_cat_service.dart`
3. ✅ Add initialization to `main.dart`
4. ✅ Add credit checks to image analysis
5. ✅ Add subscription management to profile
6. ✅ Follow `REVENUECAT_SETUP.md` for store setup
7. ✅ Test with sandbox accounts

**Need help?** Check `REVENUECAT_SETUP.md` for detailed setup instructions!
