# RevenueCat Integration Guide for Snaplook

Complete implementation guide for RevenueCat in-app purchases with modern best practices.

## Table of Contents
- [Setup](#setup)
- [Configuration](#configuration)
- [Product Configuration](#product-configuration)
- [Usage Examples](#usage-examples)
- [Customer Center](#customer-center)
- [Testing](#testing)
- [Best Practices](#best-practices)

## Setup

### 1. Dependencies Installed ✅
```yaml
dependencies:
  purchases_flutter: ^8.2.3
  purchases_ui_flutter: ^8.2.3
```

### 2. API Key Configuration ✅
Test API Key configured in `lib/src/services/revenue_cat_service.dart`:
```dart
static const String _testApiKey = 'test_BwftAgotTKZWtqHYPcgoaqhbwbV';
```

**Important**: Before production release, replace with production keys:
- Apple: `sk_WBFENSAwHStcnHwASjgjkuCargpHt`
- Google: `sk_ElMqQMznRmlmeKxjkNMqSYgINEXOW`

### 3. Initialization ✅
RevenueCat is automatically initialized in `main.dart` before `runApp()`.

## Configuration

### RevenueCat Dashboard Setup

1. **Create Entitlement**
   - Go to https://app.revenuecat.com/
   - Navigate to: Entitlements
   - Create entitlement: `premium`
   - This unlocks all premium features

2. **Create Products**

   **Monthly Subscription:**
   - Product ID: `monthly`
   - Type: Auto-renewable subscription
   - Duration: 1 month
   - Price: $7.99/month
   - Trial: None

   **Yearly Subscription:**
   - Product ID: `yearly`
   - Type: Auto-renewable subscription
   - Duration: 1 year
   - Price: $59.99/year
   - Trial: 3 days

3. **Create Offering**
   - Name: `default`
   - Add packages:
     - `$rc_monthly` → monthly product
     - `$rc_annual` → yearly product

4. **Configure Paywall**
   - Go to: Paywalls → Create Paywall
   - Choose template or create custom
   - Assign to `default` offering
   - Customize colors, text, and layout in dashboard

## Product Configuration

### App Store Connect (iOS)

1. Go to App Store Connect → Your App → Features → In-App Purchases
2. Create subscription group: "Snaplook Premium"

**Monthly Subscription:**
```
Product ID: monthly (must match RevenueCat)
Reference Name: Snaplook Monthly Premium
Duration: 1 month
Price: $7.99 USD
```

**Yearly Subscription:**
```
Product ID: yearly (must match RevenueCat)
Reference Name: Snaplook Yearly Premium
Duration: 1 year
Price: $59.99 USD
Free Trial: 3 days
```

3. Submit for review and wait for approval

### Google Play Console (Android)

1. Go to Google Play Console → Your App → Monetize → Subscriptions

**Monthly Subscription:**
```
Product ID: monthly (must match RevenueCat)
Billing period: 1 month
Price: $7.99 USD
```

**Yearly Subscription:**
```
Product ID: yearly (must match RevenueCat)
Billing period: 1 year
Price: $59.99 USD
Free trial: 3 days
```

2. Activate both subscriptions

## Usage Examples

### Display RevenueCat Paywall

The modern way to show a paywall using RevenueCat's pre-built UI:

```dart
import 'package:snaplook/src/features/paywall/paywall.dart';

// Method 1: Show as modal
ElevatedButton(
  onPressed: () async {
    final purchased = await showRevenueCatPaywall(context);
    if (purchased == true) {
      // User completed purchase
      print('User subscribed!');
    }
  },
  child: Text('Subscribe'),
)

// Method 2: Navigate to page
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RevenueCatPaywallPage(),
      ),
    );
  },
  child: Text('View Plans'),
)

// Method 3: Show specific offering
ElevatedButton(
  onPressed: () async {
    await showRevenueCatPaywall(
      context,
      offering: 'special_offer', // Custom offering ID
    );
  },
  child: Text('Special Offer'),
)
```

### Check Subscription Status

```dart
import 'package:snaplook/src/services/revenue_cat_service.dart';

// Check if user has premium subscription
final hasPremium = await RevenueCatService().hasPremiumAccess();

if (hasPremium) {
  // Show premium content
} else {
  // Show paywall or free content
}

// Get customer info
final customerInfo = await RevenueCatService().getCustomerInfo();
final entitlements = customerInfo?.entitlements.active;

if (entitlements?['premium'] != null) {
  final expirationDate = entitlements!['premium']!.expirationDate;
  print('Premium expires: $expirationDate');
}
```

### Credit System Integration

```dart
import 'package:snaplook/src/features/paywall/paywall.dart';

// Wrap actions that require credits
CreditGatedButton(
  onPressed: () {
    // This will check credits before executing
    analyzeImage();
  },
  child: ElevatedButton(
    onPressed: null, // Disabled, CreditGatedButton handles tap
    child: Text('Analyze Image'),
  ),
)

// Manual credit check
ElevatedButton(
  onPressed: () async {
    final canProceed = await checkCreditsBeforeAction(
      context,
      ref,
      onProceed: () {
        // Consume credit
        ref.read(creditBalanceProvider.notifier).consumeCredit();
        analyzeImage();
      },
    );
  },
  child: Text('Analyze Image'),
)

// Display credit balance
AppBar(
  title: Text('Snaplook'),
  actions: [
    CreditBalanceDisplay(),
    SizedBox(width: 16),
  ],
)
```

## Customer Center

RevenueCat Customer Center provides self-service subscription management:

### Show Customer Center

```dart
import 'package:snaplook/src/features/paywall/paywall.dart';

// In settings or profile page
ListTile(
  leading: Icon(Icons.card_membership),
  title: Text('Manage Subscription'),
  subtitle: Text('View plans, cancel, or restore purchases'),
  onTap: () => showCustomerCenter(context),
)

// Or navigate directly
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => CustomerCenterPage(),
  ),
);
```

### Features
- View active subscription
- Change subscription plan
- Cancel subscription
- Restore purchases
- View billing history
- Contact support
- Request refund

## Testing

### iOS Testing

1. **StoreKit Configuration (Xcode)**
   ```
   - Open Xcode
   - Product → Scheme → Edit Scheme
   - Run → Options
   - Check "StoreKit Configuration"
   - Create StoreKit configuration file
   ```

2. **Sandbox Testing**
   ```
   - Create sandbox tester in App Store Connect
   - Sign in: Settings → App Store → Sandbox Account
   - Test purchases (won't charge real money)
   ```

3. **Trial Testing**
   - Trials are accelerated in sandbox
   - 3 days = 3 minutes in sandbox

### Android Testing

1. **Internal Testing**
   ```
   - Upload AAB to Play Console
   - Add test users to internal testing
   - Install from Play Store link
   ```

2. **License Testing**
   ```
   - Add test accounts in Play Console
   - Setup → License Testing
   - Set to "RESPOND_NORMALLY"
   ```

3. **Trial Testing**
   - Trials are accelerated
   - 3 days = 5 minutes in test mode

### Test Checklist

- [ ] Monthly subscription purchase works
- [ ] Yearly subscription purchase works
- [ ] 3-day trial works for yearly
- [ ] Credits granted after purchase
- [ ] Restore purchases works
- [ ] Paywall displays correctly
- [ ] Customer Center works
- [ ] Cancellation works
- [ ] Credit refill works monthly

## Best Practices

### 1. User Authentication

After user signs in:
```dart
import 'package:snaplook/src/features/paywall/paywall.dart';

// Associate purchases with user
await initializePaywallWithUser(userId);
```

After user signs out:
```dart
// Clear purchase data
await cleanupPaywallOnLogout();
```

### 2. Error Handling

```dart
try {
  final purchased = await showRevenueCatPaywall(context);
  if (purchased == true) {
    // Success
  }
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Purchase failed: $e')),
  );
}
```

### 3. Offline Support

RevenueCat caches subscription status:
```dart
// This works offline after first sync
final hasPremium = await RevenueCatService().hasPremiumAccess();
```

### 4. Analytics

Track important events:
```dart
// Purchase completed
onPurchaseCompleted: (customerInfo, transaction) {
  // Send to your analytics
  analytics.logPurchase(
    productId: transaction.productIdentifier,
    revenue: transaction.price,
  );
}

// Paywall displayed
analytics.logPaywallView();
```

### 5. A/B Testing

Use RevenueCat Experiments:
```dart
// Show different offerings to different users
final offering = await getExperimentOffering();
await showRevenueCatPaywall(context, offering: offering);
```

## Common Issues

### "No offerings available"
- Check products are approved in stores
- Verify API keys are correct
- Wait 15-30 minutes for sync
- Check RevenueCat dashboard sync status

### "Purchase failed"
- iOS: Use sandbox account or StoreKit config
- Android: Use internal testing or license testing
- Verify products are activated

### Credits not syncing
- Check RevenueCat webhook configuration
- Verify entitlements are correct
- Try `ref.invalidate(creditBalanceProvider)`

## Resources

- [RevenueCat Docs](https://docs.revenuecat.com/)
- [Paywall Configuration](https://www.revenuecat.com/docs/tools/paywalls)
- [Customer Center](https://www.revenuecat.com/docs/tools/customer-center)
- [Flutter SDK Docs](https://www.revenuecat.com/docs/getting-started/installation/flutter)

## Support

For RevenueCat issues:
- Dashboard: https://app.revenuecat.com/
- Status: https://status.revenuecat.com/
- Community: https://community.revenuecat.com/

## Production Checklist

Before releasing:

- [ ] Replace test API key with production keys
- [ ] All products approved in both stores
- [ ] RevenueCat connected to both stores
- [ ] Webhooks configured
- [ ] Privacy policy updated
- [ ] Terms mention auto-renewal
- [ ] Refund policy documented
- [ ] Tested on real devices
- [ ] Customer support email configured
