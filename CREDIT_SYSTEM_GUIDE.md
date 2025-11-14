# Credit System Implementation Guide

## Overview
Snaplook uses a credit-based system to manage user access to fashion analysis features.

### For Free Users:
- Get **1 free analysis** after creating an account
- This single analysis can include any number of garments (1-5+)
- Behind the scenes, this may consume multiple backend credits, but users only see "1 free analysis"
- After using their free analysis, users must upgrade to continue

### For Paid Users (Monthly/Yearly):
- Get **100 credits per month**
- 1 credit = 1 garment search result
- If they analyze an image with 5 garments, it costs 5 credits
- Credits reset monthly

## Database Schema

```sql
-- profiles table columns:
- free_analyses_remaining (INTEGER, default 1)
- paid_credits_remaining (INTEGER, default 0)
- subscription_tier (TEXT: 'free' | 'monthly' | 'yearly', default 'free')
- credits_reset_date (TIMESTAMP, nullable)
- total_analyses_performed (INTEGER, default 0)
```

## Onboarding Flow (Option A - Implemented)

1. **Login/Welcome Page** → User clicks "Get Started"
2. **Gender Selection** (Step 1/5)
3. **Discovery Source Selection** (Step 2/5)
4. **Tutorial Walkthrough** (Steps 3-4/5)
5. **Account Creation** (Step 5/5) → User creates account
6. **🆕 Welcome & Credits Page** → "You get 1 free analysis!"
7. **Main App** → User can now use the app

## Integration Points

### 1. Before Performing Analysis

```dart
// In detection_page.dart or wherever analysis is triggered
import 'package:snaplook/src/features/credits/providers/credit_provider.dart';

Future<void> _handleAnalyze() async {
  final creditService = ref.read(creditServiceProvider);
  final canAnalyze = await creditService.canPerformAnalysis();

  if (!canAnalyze) {
    // Show paywall
    _showPaywall();
    return;
  }

  // Perform analysis
  final results = await performDetection(...);

  // After successful analysis, consume credits
  final garmentCount = results.length;
  await creditService.consumeCreditsForAnalysis(garmentCount);

  // Refresh credit status UI
  ref.invalidate(creditStatusProvider);

  // Show results to user
  _showResults(results);
}
```

### 2. Displaying Credit Status in UI

```dart
// In profile_page.dart or any page header
final creditMessage = ref.watch(creditDisplayMessageProvider);

Text(creditMessage) // Shows: "1 free analysis remaining" or "87 credits remaining"
```

### 3. Checking if User Has Credits

```dart
// Quick boolean check
final hasCredits = ref.watch(hasCreditsProvider);

if (!hasCredits) {
  // Show upgrade CTA
}
```

## Service Methods

### CreditService

```dart
// Initialize new user with 1 free analysis
await creditService.initializeNewUser(userId);

// Check if user can perform an analysis
bool canAnalyze = await creditService.canPerformAnalysis();

// Get detailed credit status
CreditStatus status = await creditService.getCreditStatus();

// Consume credits after analysis
await creditService.consumeCreditsForAnalysis(garmentCount);

// Add credits when user subscribes
await creditService.addPaidCredits(userId, 100);

// Reset monthly credits (for paid users)
await creditService.resetMonthlyCreditsIfNeeded();
```

### CreditStatus Model

```dart
class CreditStatus {
  String subscriptionTier;     // 'free', 'monthly', 'yearly'
  int freeAnalysesRemaining;   // For free users
  int paidCreditsRemaining;    // For paid users

  bool get isFreeUser;
  bool get isPaidUser;
  bool get hasCredits;
  String get displayMessage;   // User-friendly message
}
```

## Next Steps: Adding Paywall

When you're ready to add the paywall back:

1. Create a new paywall page that shows:
   - Current credit status
   - Subscription options (Monthly: $7.99, Yearly: $59.99)
   - "Get 100 credits/month" messaging

2. When user subscribes:
```dart
await creditService.addPaidCredits(userId, 100);
// Update subscription_tier in Supabase via RevenueCat webhook
```

3. Add monthly credit reset:
   - Set up a cron job (or check on app launch)
   - Call `creditService.resetMonthlyCreditsIfNeeded()`

## Files Created/Modified

### New Files:
- `lib/src/features/onboarding/presentation/pages/welcome_free_analysis_page.dart`
- `lib/src/services/credit_service.dart`
- `lib/src/features/credits/providers/credit_provider.dart`
- `supabase/migrations/20250114000000_add_credit_system.sql`
- `CREDIT_SYSTEM_GUIDE.md` (this file)

### Modified Files:
- `lib/src/features/onboarding/presentation/pages/account_creation_page.dart`
- `lib/src/features/auth/presentation/pages/email_verification_page.dart`

## Testing Checklist

- [ ] New user creates account → sees welcome page with "1 free analysis"
- [ ] User performs first analysis with 3 garments → sees results, analysis count decrements
- [ ] User tries second analysis → hits paywall
- [ ] Paid user subscribes → gets 100 credits
- [ ] Paid user analyzes image with 5 garments → 5 credits deducted
- [ ] Paid user's credits reset monthly

## UI/UX Recommendations

1. **Subtle Credit Counter**: Show remaining credits in app header or profile
2. **Pre-Analysis Warning**: If user has 1 analysis/few credits left, show gentle reminder
3. **Post-Analysis Celebration**: "You just discovered 5 amazing fashion items!"
4. **Upgrade CTAs**: When credits run out, emphasize value: "Get 100 more searches for just $7.99/month"
