# RevenueCat In-App Purchase Setup Guide for Snaplook

This guide walks you through setting up in-app purchases for Snaplook using RevenueCat on both iOS (App Store) and Android (Google Play).

## Table of Contents
1. [RevenueCat Setup](#1-revenuecat-setup)
2. [iOS App Store Setup](#2-ios-app-store-setup)
3. [Android Google Play Setup](#3-android-google-play-setup)
4. [Code Integration](#4-code-integration)
5. [Testing](#5-testing)
6. [Troubleshooting](#6-troubleshooting)

---

## 1. RevenueCat Setup

### Step 1: Create RevenueCat Account
1. Go to [RevenueCat](https://www.revenuecat.com/)
2. Sign up for a free account
3. Create a new project named "Snaplook"

### Step 2: Get API Keys
1. In RevenueCat dashboard, go to **Project Settings** → **API Keys**
2. Copy your:
   - **Apple App Store API Key** (for iOS)
   - **Google Play API Key** (for Android)
3. Update these keys in `/lib/src/services/revenue_cat_service.dart`:

```dart
static const String _appleApiKey = 'YOUR_APPLE_API_KEY';
static const String _googleApiKey = 'YOUR_GOOGLE_API_KEY';
```

### Step 3: Configure Entitlements
1. Go to **Entitlements** in RevenueCat dashboard
2. Create a new entitlement called `premium`
3. This will unlock all premium features for subscribers

### Step 4: Create Products
Create two subscription products in RevenueCat:

#### Monthly Subscription
- **Identifier**: `snaplook_monthly_subscription`
- **Type**: Auto-renewable subscription
- **Duration**: 1 month
- **Price**: $7.99/month
- **No trial period**

#### Yearly Subscription
- **Identifier**: `snaplook_yearly_subscription`
- **Type**: Auto-renewable subscription
- **Duration**: 1 year
- **Price**: $59.99/year ($4.99/month)
- **Free trial**: 3 days

### Step 5: Create Offering
1. Go to **Offerings** in RevenueCat
2. Create a new offering called "default"
3. Add both products to this offering:
   - Set yearly as `$rc_annual` package
   - Set monthly as `$rc_monthly` package

---

## 2. iOS App Store Setup

### Step 1: App Store Connect Setup
1. Log in to [App Store Connect](https://appstoreconnect.apple.com/)
2. Select your Snaplook app
3. Go to **Features** → **In-App Purchases**

### Step 2: Create Subscription Group
1. Click **Manage** under Subscriptions
2. Create a new subscription group: "Snaplook Premium"
3. Set display name and reference name

### Step 3: Create Monthly Subscription
1. Click **+** to add new subscription
2. Configure:
   - **Product ID**: `snaplook_monthly_subscription` (must match RevenueCat)
   - **Reference Name**: Snaplook Monthly Premium
   - **Subscription Duration**: 1 month
   - **Price**: $7.99 USD (set for all territories)
   - **Localization**: Add English (US)
     - **Subscription Display Name**: Monthly Premium
     - **Description**: Unlimited fashion analysis with 100 monthly credits

### Step 4: Create Yearly Subscription
1. Click **+** to add new subscription
2. Configure:
   - **Product ID**: `snaplook_yearly_subscription` (must match RevenueCat)
   - **Reference Name**: Snaplook Yearly Premium
   - **Subscription Duration**: 1 year
   - **Price**: $59.99 USD (set for all territories)
   - **Free Trial**: 3 days
   - **Localization**: Add English (US)
     - **Subscription Display Name**: Yearly Premium
     - **Description**: Best value! Unlimited fashion analysis with 100 monthly credits. Includes 3-day free trial.

### Step 5: Submit for Review
1. Add screenshots (required for App Store review)
2. Submit each in-app purchase for review
3. Wait for Apple approval (usually 24-48 hours)

### Step 6: Connect RevenueCat to App Store
1. In RevenueCat dashboard, go to **Apple App Store**
2. Follow instructions to upload:
   - **App Store Connect API Key** (.p8 file)
   - **Issuer ID**
   - **Key ID**
3. RevenueCat will automatically sync your products

### Step 7: Configure iOS App
Add to `ios/Runner/Info.plist`:

```xml
<key>SKAdNetworkItems</key>
<array>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>cstr6suwn9.skadnetwork</string>
    </dict>
</array>
```

---

## 3. Android Google Play Setup

### Step 1: Google Play Console Setup
1. Log in to [Google Play Console](https://play.google.com/console/)
2. Select your Snaplook app
3. Go to **Monetize** → **Subscriptions**

### Step 2: Create Monthly Subscription
1. Click **Create subscription**
2. Configure:
   - **Product ID**: `snaplook_monthly_subscription` (must match RevenueCat)
   - **Name**: Monthly Premium
   - **Description**: Unlimited fashion analysis with 100 monthly credits
   - **Billing period**: 1 month
   - **Price**: $7.99 USD
   - **Free trial**: None
   - **Grace period**: 3 days (recommended)

### Step 3: Create Yearly Subscription
1. Click **Create subscription**
2. Configure:
   - **Product ID**: `snaplook_yearly_subscription` (must match RevenueCat)
   - **Name**: Yearly Premium
   - **Description**: Best value! Unlimited fashion analysis with 100 monthly credits. Includes 3-day free trial.
   - **Billing period**: 1 year
   - **Price**: $59.99 USD
   - **Free trial**: 3 days
   - **Grace period**: 3 days (recommended)

### Step 4: Activate Subscriptions
1. Review both subscriptions
2. Click **Activate** for each

### Step 5: Connect RevenueCat to Google Play
1. In RevenueCat dashboard, go to **Google Play Store**
2. Follow instructions to:
   - Create a service account in Google Cloud Console
   - Download JSON key file
   - Upload to RevenueCat
   - Grant necessary permissions in Google Play Console

### Step 6: Configure Android App
Add to `android/app/build.gradle`:

```gradle
dependencies {
    // RevenueCat billing client
    implementation 'com.android.billingclient:billing:6.0.1'
}
```

Update `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="com.android.vending.BILLING" />
```

---

## 4. Code Integration

### Step 1: Install Dependencies
Run:
```bash
flutter pub get
```

### Step 2: Update main.dart
Add initialization to your `main.dart`:

```dart
import 'package:snaplook/src/features/paywall/initialization/paywall_initialization.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize RevenueCat (do this before runApp)
  await initializePaywallSystem();

  runApp(const ProviderScope(child: MyApp()));
}
```

### Step 3: Initialize After User Login
When a user logs in or signs up, call:

```dart
import 'package:snaplook/src/features/paywall/initialization/paywall_initialization.dart';

// After successful login
await initializePaywallWithUser(userId);
```

### Step 4: Handle Logout
When a user logs out:

```dart
import 'package:snaplook/src/features/paywall/initialization/paywall_initialization.dart';

await cleanupPaywallOnLogout();
```

### Step 5: Add Credit Checks to Image Analysis
Wrap your image analysis button with credit check:

```dart
import 'package:snaplook/src/features/paywall/presentation/widgets/credit_check_widget.dart';

// Option 1: Use CreditGatedButton widget
CreditGatedButton(
  onPressed: () {
    // Perform image analysis
    _analyzeImage();
  },
  child: YourAnalysisButton(),
)

// Option 2: Manual check
ElevatedButton(
  onPressed: () async {
    final canProceed = await checkCreditsBeforeAction(
      context,
      ref,
      onProceed: () {
        // Consume credit and proceed
        ref.read(creditBalanceProvider.notifier).consumeCredit();
        _analyzeImage();
      },
    );
  },
  child: Text('Analyze Image'),
)
```

### Step 6: Display Credit Balance
Add credit display to your app bar:

```dart
import 'package:snaplook/src/features/paywall/presentation/widgets/credit_check_widget.dart';

AppBar(
  title: Text('Snaplook'),
  actions: [
    CreditBalanceDisplay(),
    SizedBox(width: 16),
  ],
)
```

### Step 7: Add Subscription Management
Add to profile or settings page:

```dart
import 'package:snaplook/src/features/paywall/presentation/pages/subscription_management_page.dart';

ListTile(
  leading: Icon(Icons.card_membership),
  title: Text('Subscription'),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubscriptionManagementPage(),
      ),
    );
  },
)
```

---

## 5. Testing

### iOS Testing

#### Sandbox Testing
1. In Xcode, go to **Product** → **Scheme** → **Edit Scheme**
2. Under **Run** → **Options**, check **StoreKit Configuration**
3. Create a StoreKit configuration file for local testing

#### TestFlight Testing
1. Upload build to TestFlight
2. Add test users in App Store Connect
3. Enable sandbox account:
   - Go to Settings → App Store → Sandbox Account
   - Sign in with test account
4. Test purchases (they won't charge real money)

#### Testing 3-Day Trial
- Trials are accelerated in sandbox: 3 days = 3 minutes
- You can cancel and resubscribe multiple times

### Android Testing

#### Internal Testing
1. Upload AAB to Google Play Console
2. Create internal testing track
3. Add test users
4. Install from Play Store internal testing link

#### License Testing
1. In Google Play Console, go to **Setup** → **License Testing**
2. Add test Gmail accounts
3. Set license response to "RESPOND_NORMALLY"
4. Test purchases won't charge real money

#### Testing 3-Day Trial
- Trials are accelerated in test mode: 3 days = 5 minutes
- Use "License Testing" to test different scenarios

### Testing Checklist
- [ ] Monthly subscription purchase works
- [ ] Yearly subscription purchase works
- [ ] 3-day free trial starts correctly
- [ ] Credits are granted after purchase
- [ ] Credits refill monthly
- [ ] Restore purchases works
- [ ] Free trial (1 free analysis) works for new users
- [ ] Paywall appears when credits run out
- [ ] Subscription management UI shows correct info
- [ ] Cancellation works properly

---

## 6. Troubleshooting

### Common Issues

#### "No offerings available"
- **Cause**: Products not synced from stores to RevenueCat
- **Fix**:
  1. Check products are approved in App Store/Play Store
  2. Verify API keys are correct in RevenueCat
  3. Wait 15-30 minutes for sync
  4. Check RevenueCat dashboard for sync status

#### "Purchase failed" on iOS
- **Cause**: Not using sandbox account or StoreKit configuration
- **Fix**:
  1. Sign in with sandbox account in Settings
  2. Or enable StoreKit configuration in Xcode
  3. Make sure products are approved

#### "Item not available for purchase" on Android
- **Cause**: App not signed with release key or products not activated
- **Fix**:
  1. Make sure products are activated in Play Console
  2. Upload APK with correct signing key
  3. Add your account to internal testing

#### Credits not syncing
- **Cause**: RevenueCat webhook not configured
- **Fix**:
  1. Check webhook logs in RevenueCat dashboard
  2. Verify entitlements are set up correctly
  3. Try calling `syncWithSubscription()` manually

#### User can purchase multiple times
- **Cause**: Not checking active subscriptions before purchase
- **Fix**: The code already handles this via RevenueCat SDK

---

## Support

### Resources
- [RevenueCat Documentation](https://docs.revenuecat.com/)
- [Apple In-App Purchase Guide](https://developer.apple.com/in-app-purchase/)
- [Google Play Billing Guide](https://developer.android.com/google/play/billing)

### RevenueCat Dashboard URLs
- Production: https://app.revenuecat.com/
- Documentation: https://docs.revenuecat.com/
- Status: https://status.revenuecat.com/

### Testing Accounts
- Create sandbox accounts in:
  - iOS: App Store Connect → Users and Access → Sandbox Testers
  - Android: Google Play Console → Setup → License Testing

---

## Production Checklist

Before releasing to production:
- [ ] Replace `YOUR_APPLE_API_KEY` and `YOUR_GOOGLE_API_KEY` in code
- [ ] All in-app purchases approved in App Store
- [ ] All subscriptions activated in Google Play
- [ ] RevenueCat connected to both stores
- [ ] Webhooks configured in RevenueCat
- [ ] Tested on real devices with test accounts
- [ ] Privacy policy updated to mention subscriptions
- [ ] Terms of service mention auto-renewal
- [ ] Refund policy documented
- [ ] Customer support email configured

---

## Notes

### Credit System
- **Free users**: 1 free analysis
- **Monthly subscribers**: 100 credits/month
- **Yearly subscribers**: 100 credits/month (refills monthly)
- Credits refill on the same day each month

### Pricing
- Monthly: $7.99/month
- Yearly: $59.99/year ($4.99/month, 38% savings)
- Yearly includes 3-day free trial

### Update Product IDs
If you want different product IDs, update them in:
1. `/lib/src/features/paywall/models/subscription_plan.dart`
2. RevenueCat dashboard
3. App Store Connect
4. Google Play Console

All identifiers must match across all platforms!

---

## Questions?

If you encounter issues, check:
1. RevenueCat dashboard logs
2. Xcode console for iOS errors
3. Android Studio logcat for Android errors
4. RevenueCat debug logs (enabled in debug mode)

Good luck with your launch! 🚀
