# Snaplook Onboarding Flow - Complete Scenario Analysis

## Overview
This document provides a comprehensive analysis of ALL possible scenarios in the Snaplook onboarding flow, including how authentication, subscription status, and user state are handled at every decision point.

## Updated Onboarding Flow

```
1. LoginPage (with login sheet option)
2. HowItWorksPage
3. AwesomeIntroPage
4. GenderSelectionPage
5. DiscoverySourcePage
6. StyleDirectionPage
7. WhatYouWantPage
8. PriceRangePage
9. BudgetPage
10. AgeRangePage
11. PreferredRetailersPage
12. StylePreferencesPage
13. ShoppingFrequencyPage
14. CategoryInterestsPage
15. AddFirstStylePage
16. TutorialImageAnalysisPage
17. NotificationPermissionPage
18. **SaveProgressPage** (NEW)
19. RevenueCatPaywallPage
20. AccountCreationPage (conditional)
21. WelcomeFreeAnalysisPage
22. ... rest of onboarding
```

---

## Critical Decision Points

### 1. LoginPage
**Decision:** Is user authenticated?

- **Authenticated + Onboarding Complete** → MainNavigation (Home)
- **Authenticated + Onboarding Incomplete** → HowItWorksPage (resume onboarding)
- **Not Authenticated** → User can tap "Get Started" to begin OR use login sheet to authenticate first

---

### 2. NotificationPermissionPage
**Navigation:** Always goes to SaveProgressPage

**Actions:**
- Requests notification permission (Allow/Don't Allow)
- Saves preference to database if user is authenticated
- Initializes FCM if permission granted

---

### 3. SaveProgressPage (NEW)
**Decision Points:**

#### On Init:
- **If authenticated** → Skip page entirely, check subscription status immediately

#### If Not Authenticated - User has 4 options:
1. Sign in with Apple
2. Sign in with Google
3. Sign in with Email
4. Skip (Continue without account)

#### After Authentication Success:
1. Sync user to RevenueCat (`SubscriptionSyncService.identify()`)
2. Check RevenueCat subscription status
3. Update device fingerprint for fraud prevention
4. Persist onboarding selections to database

**Routing Logic:**
- **Has Active Subscription** → WelcomeFreeAnalysisPage (skip paywall AND AccountCreationPage)
- **No Subscription** → RevenueCatPaywallPage
- **Skipped (No Auth)** → RevenueCatPaywallPage

---

### 4. RevenueCatPaywallPage
**Decision Points:**

#### On Init:
- **If authenticated AND has active subscription** → Skip to WelcomeFreeAnalysisPage

#### Purchase Flow:
- User selects plan (Monthly or Yearly with trial)
- Taps "Continue for free" (trial) or "Subscribe now"
- Purchase processed via RevenueCat

#### After Purchase Success:
- **If authenticated:**
  - Sync subscription to Supabase
  - Mark payment complete in onboarding state
  - Navigate to WelcomeFreeAnalysisPage
- **If not authenticated:**
  - Navigate to AccountCreationPage (anonymous purchase will be linked)

#### Restore Purchases:
- Fetches RevenueCat customer info
- **If has subscription:**
  - **Authenticated:** Sync to Supabase → WelcomeFreeAnalysisPage
  - **Not authenticated:** Show message → AccountCreationPage
- **No subscription:** Show "No purchases to restore"

---

### 5. AccountCreationPage
**Appears ONLY if:**
- User is not authenticated
- User completed paywall (or skipped it)

**Critical Logic - Subscription Conflict Detection:**

When user authenticates (Apple/Google/Email):

1. **Check if account already exists in Supabase**
2. **Get existing subscription status** (subscription_status, is_trial)
3. **Check for anonymous purchase** (RevenueCat customerInfo before identify)

**Scenario Handling:**

#### A. Existing Account WITH Active Subscription + Anonymous Purchase
- **CONFLICT DETECTED**
- Show dialog: "Subscription Already Exists"
- Message: "Your recent purchase will be refunded within 24 hours"
- User sent back to paywall
- **NO LINKING OCCURS**

#### B. Existing Account WITH Active Subscription + NO Anonymous Purchase
- Link account to RevenueCat
- Sync subscription to Supabase
- Mark payment complete
- Navigate to WelcomeFreeAnalysisPage

#### C. Existing Account WITHOUT Subscription + Anonymous Purchase
- Link anonymous purchase to account
- Sync subscription to Supabase
- Mark payment complete
- Navigate to WelcomeFreeAnalysisPage

#### D. New Account + Anonymous Purchase
- Create user record
- Link anonymous purchase
- Sync subscription to Supabase
- Mark payment complete
- Navigate to WelcomeFreeAnalysisPage

#### E. Existing Account (Returning User - Completed Onboarding Before)
- Link account
- Reset to home tab
- Navigate to MainNavigation

---

## Complete Scenario Breakdown

### Scenario 1: Fresh User - No Account Until End
**Flow:**
1. Start at LoginPage → Tap "Get Started" (no login)
2. Go through preferences pages
3. NotificationPermissionPage → Allow/Deny
4. SaveProgressPage → **Tap "Continue without account"**
5. RevenueCatPaywallPage → **Purchase subscription (anonymous)**
6. AccountCreationPage → **Create new account (Apple/Google/Email)**
7. Anonymous purchase linked to new account
8. WelcomeFreeAnalysisPage → Continue onboarding

**Result:** ✅ Account created with subscription linked

---

### Scenario 2: User Logs In at LoginPage
**Flow:**
1. Start at LoginPage → **Use login sheet to authenticate**
2. Check onboarding status:
   - If completed → MainNavigation
   - If incomplete → Resume from checkpoint
3. Go through preferences (authenticated)
4. NotificationPermissionPage → Preference saved to DB
5. SaveProgressPage → **Skipped automatically (already auth)**
6. RevenueCatPaywallPage:
   - If has subscription → Skip to WelcomeFreeAnalysisPage
   - If no subscription → Show paywall
7. If purchase → Sync immediately, go to WelcomeFreeAnalysisPage
8. AccountCreationPage → **Skipped (already auth)**

**Result:** ✅ Seamless authenticated flow

---

### Scenario 3: User Logs In at SaveProgressPage - WITH Subscription
**Flow:**
1. Start at LoginPage → Tap "Get Started" (no login)
2. Go through preferences (unauthenticated)
3. NotificationPermissionPage
4. SaveProgressPage → **Sign in with Apple/Google/Email**
5. Auth successful → Check subscription via RevenueCat
6. **Has active subscription detected**
7. Sync subscription to Supabase
8. Mark payment complete
9. **Navigate directly to WelcomeFreeAnalysisPage**
10. RevenueCatPaywallPage → **SKIPPED**
11. AccountCreationPage → **SKIPPED**

**Result:** ✅ User with existing subscription bypasses paywall and account creation

---

### Scenario 4: User Logs In at SaveProgressPage - NO Subscription
**Flow:**
1. Start at LoginPage → Tap "Get Started" (no login)
2. Go through preferences (unauthenticated)
3. NotificationPermissionPage
4. SaveProgressPage → **Sign in with Apple/Google/Email**
5. Auth successful → Check subscription via RevenueCat
6. **No active subscription detected**
7. Sync user to RevenueCat (identify)
8. Persist onboarding preferences to database
9. **Navigate to RevenueCatPaywallPage**
10. User can purchase or skip
11. After purchase → Sync to Supabase
12. **Navigate to WelcomeFreeAnalysisPage** (skip AccountCreationPage - already auth)

**Result:** ✅ User sees paywall but skips account creation since already authenticated

---

### Scenario 5: User Skips SaveProgressPage → Purchases → Logs Into EXISTING Account at AccountCreationPage
**Flow:**
1. Start at LoginPage → Tap "Get Started" (no login)
2. Go through preferences (unauthenticated)
3. NotificationPermissionPage
4. SaveProgressPage → **Tap "Continue without account"**
5. RevenueCatPaywallPage → **Purchase subscription (anonymous)**
6. AccountCreationPage → **Tap "Already have an account? Sign In"**
7. **Sign into EXISTING account**

**Critical Check:**
- Check if existing account has active subscription in Supabase
- Check if there's an anonymous purchase waiting to link

**Scenarios:**

#### 5A. Existing Account HAS Subscription
- **CONFLICT:** Dialog shown
- "Subscription Already Exists - Recent purchase will be refunded"
- User returns to paywall
- **Anonymous purchase NOT linked**

**Result:** ✅ Conflict handled gracefully, prevents double subscription

#### 5B. Existing Account NO Subscription
- Link anonymous purchase to existing account
- Sync subscription to Supabase
- Check if onboarding was completed before:
  - If yes → MainNavigation
  - If no → WelcomeFreeAnalysisPage

**Result:** ✅ Anonymous purchase successfully transferred to existing account

---

### Scenario 6: User With Expired Subscription
**Flow:**
1. User authenticates (any entry point)
2. Check subscription status → **Expired**
3. Navigate to RevenueCatPaywallPage
4. User can:
   - **Restore Purchases** (if subscription was from different device)
   - **Purchase new subscription**
   - **Upgrade/renew**

**Result:** ✅ Expired users directed to paywall for renewal

---

### Scenario 7: User Restores Purchases - Authenticated
**Flow:**
1. At RevenueCatPaywallPage (authenticated)
2. Tap **"Restore"** button
3. RevenueCat fetches customer info
4. **If has active subscription:**
   - Sync to Supabase
   - Mark payment complete
   - Navigate to WelcomeFreeAnalysisPage
5. **If no subscription:**
   - Show "No purchases to restore"

**Result:** ✅ Restored subscription synced and user proceeds

---

### Scenario 8: User Restores Purchases - Not Authenticated
**Flow:**
1. At RevenueCatPaywallPage (not authenticated)
2. Tap **"Restore"** button
3. RevenueCat fetches customer info
4. **If has active subscription:**
   - Show message: "Purchases restored! Please create an account to continue"
   - Navigate to AccountCreationPage
   - User creates/signs into account
   - Subscription linked via identify()
5. **If no subscription:**
   - Show "No purchases to restore"

**Result:** ✅ User creates account to link restored subscription

---

### Scenario 9: User Authenticated With Active Trial
**Flow:**
1. User authenticates (any point)
2. Check RevenueCat → **Active trial detected**
3. Sync trial status to Supabase
4. Mark is_trial = true in database
5. Record trial start time (fraud prevention)
6. User proceeds through onboarding
7. Trial reminder shown later in flow

**Result:** ✅ Trial status tracked correctly

---

### Scenario 10: Fraud Prevention - Multiple Trial Attempts
**Flow:**
1. User completes trial on Account A
2. Creates Account B (different email)
3. Attempts to start trial
4. **FraudPreventionService checks:**
   - Device fingerprint
   - Email patterns
   - Previous trial records
5. **Trial eligibility = FALSE**
6. At RevenueCatPaywallPage:
   - No "3-day FREE" badge shown
   - Button says "Subscribe now" instead of "Continue for free"
   - User must pay immediately

**Result:** ✅ Trial abuse prevented via device fingerprinting

---

### Scenario 11: Network Failure During Purchase
**Flow:**
1. User at RevenueCatPaywallPage
2. Selects plan → Taps purchase
3. **Network failure during RevenueCat.purchasePackage()**
4. Error caught and logged
5. User shown error message
6. **Purchase state not marked complete**
7. User can:
   - Retry purchase
   - Use "Restore Purchases" if payment went through on backend

**Error Handling:**
- Timeout: 10 seconds for RevenueCat calls
- Retry mechanism: 3 attempts for critical calls
- Graceful fallback: Navigate to next step even on non-critical failures

**Result:** ✅ Network failures handled gracefully with retries

---

### Scenario 12: Network Failure During Authentication
**Flow:**
1. User at SaveProgressPage or AccountCreationPage
2. Taps Apple/Google/Email sign in
3. **Network failure during auth**
4. Error caught by AuthService
5. User shown error message
6. **Auth state NOT changed**
7. User remains on current page
8. Can retry authentication

**Error Handling:**
- Apple/Google: Native error handling
- Email: Timeout after 10 seconds
- Error messages shown via SnackBar

**Result:** ✅ Auth failures don't break flow

---

### Scenario 13: User Denies Notification Permission
**Flow:**
1. At NotificationPermissionPage
2. User taps **"Don't Allow"**
3. Permission status stored: notification_granted = false
4. Saved to database if authenticated
5. **User proceeds normally to SaveProgressPage**
6. No impact on subscription or onboarding

**Result:** ✅ Notification denial doesn't block onboarding

---

### Scenario 14: User Logs Out Mid-Onboarding
**Flow:**
1. User authenticated, mid-onboarding
2. User logs out (via profile or settings)
3. Auth state cleared
4. **Next app launch:**
   - Check onboarding_state in database
   - If in_progress → Reset to not_started
   - User must start from beginning

**Result:** ✅ Incomplete onboarding resets on logout

---

### Scenario 15: Returning User - Completed Onboarding Previously
**Flow:**
1. User launches app
2. Check auth status → **Authenticated**
3. Check onboarding_state → **"completed"**
4. Check subscription_status:
   - **Active or Trial** → MainNavigation (Home)
   - **Expired** → RevenueCatPaywallPage

**Result:** ✅ Returning users go straight to app or renewal flow

---

## Backend Data Flow

### Supabase Database Updates

**users table fields updated during onboarding:**

| Field | Updated At | Value |
|-------|-----------|-------|
| `onboarding_state` | Start, Payment, Complete | 'not_started', 'in_progress', 'payment_complete', 'completed' |
| `onboarding_checkpoint` | Each major step | 'gender', 'discovery', 'tutorial', 'save_progress', 'paywall', 'account', 'welcome' |
| `onboarding_started_at` | OnboardingStateService.startOnboarding() | Timestamp |
| `payment_completed_at` | OnboardingStateService.markPaymentComplete() | Timestamp |
| `onboarding_completed_at` | OnboardingStateService.completeOnboarding() | Timestamp |
| `preferred_gender_filter` | SaveUserPreferences() | 'men', 'women', 'all' |
| `notification_enabled` | NotificationPermissionPage, SaveProgressPage | Boolean |
| `style_direction` | SaveUserPreferences() | JSON array |
| `what_you_want` | SaveUserPreferences() | JSON array |
| `budget` | SaveUserPreferences() | String |
| `discovery_source` | SaveUserPreferences() | String |
| `subscription_status` | SubscriptionSyncService.syncSubscriptionToSupabase() | 'free', 'active', 'expired' |
| `is_trial` | OnboardingStateService.markPaymentComplete() | Boolean |

### RevenueCat Integration Points

1. **Initialize** (main.dart startup)
   - Platform-specific API keys
   - Anonymous ID or user ID

2. **Identify** (SaveProgressPage, AccountCreationPage)
   - Links anonymous purchases to user account
   - Merges purchase history

3. **Purchase** (RevenueCatPaywallPage)
   - Processes subscription purchase
   - Returns CustomerInfo

4. **Restore** (RevenueCatPaywallPage)
   - Fetches previous purchases
   - Syncs to current account

5. **Get Customer Info** (Multiple pages)
   - Checks active entitlements
   - Determines subscription status

### Fraud Prevention Flow

1. **Device Fingerprint** generated at:
   - SaveProgressPage (on auth)
   - AccountCreationPage (on auth)

2. **Trial Eligibility Check**:
   - Checks device_fingerprints table
   - Counts previous trials for device
   - Returns true/false

3. **Fraud Score Calculation**:
   - Email pattern analysis
   - Device history
   - Trial abuse detection

---

## Error Handling Summary

### Retry Mechanisms
- **RevenueCat API calls:** 3 retries with exponential backoff
- **Timeout:** 10 seconds for network calls
- **Fallback:** Continue to next step on non-critical failures

### User-Facing Error Messages
- Network failures: "Network error checking subscription"
- Auth failures: "Error signing in with [provider]"
- Purchase failures: Error from RevenueCat SDK
- Subscription conflicts: Custom dialog with clear explanation

### Logging
- All major actions logged with `[PageName]` prefix
- Error stack traces captured
- Critical decision points logged

---

## Testing Checklist

### Core Flows
- [ ] Fresh user - no account until end
- [ ] User logs in at LoginPage
- [ ] User logs in at SaveProgressPage with subscription
- [ ] User logs in at SaveProgressPage without subscription
- [ ] User skips SaveProgressPage, purchases, logs into existing account

### Edge Cases
- [ ] Network failure during purchase
- [ ] Network failure during authentication
- [ ] Subscription conflict (existing + new purchase)
- [ ] Restore purchases while authenticated
- [ ] Restore purchases while not authenticated
- [ ] Trial eligibility check works
- [ ] Fraud prevention blocks multiple trials
- [ ] Notification permission denied
- [ ] User logs out mid-onboarding

### Data Integrity
- [ ] Preferences saved correctly when authenticated
- [ ] Preferences saved after authentication at SaveProgressPage
- [ ] Anonymous purchase linked correctly
- [ ] Subscription synced to Supabase
- [ ] Device fingerprint updated
- [ ] Fraud score calculated
- [ ] Onboarding checkpoints saved

---

## Key Files

| File | Purpose |
|------|---------|
| `save_progress_page.dart` | NEW page between notifications and paywall |
| `notification_permission_page.dart` | Updated to navigate to SaveProgressPage |
| `revenuecat_paywall_page.dart` | Enhanced subscription check and restore logic |
| `account_creation_page.dart` | Improved conflict detection and linking logic |
| `onboarding_state_service.dart` | Added saveProgress checkpoint |
| `subscription_sync_service.dart` | Syncs RevenueCat to Supabase |
| `fraud_prevention_service.dart` | Device fingerprinting and trial tracking |

---

## Progress Indicators

**Updated Step Numbers:**
- NotificationPermissionPage: Step 13/14
- SaveProgressPage: Step 14/20
- RevenueCatPaywallPage: Step 14/14 (legacy, should be updated to 15/20)
- AccountCreationPage: Step 19/20

**Note:** Progress indicators need to be updated throughout onboarding flow to reflect new SaveProgressPage.
