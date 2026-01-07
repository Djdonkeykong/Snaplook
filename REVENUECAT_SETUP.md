# RevenueCat Integration Setup Guide

This guide walks you through setting up the RevenueCat webhook integration to keep your subscription data in sync with Supabase.

## What Was Fixed

### Problem
Users with expired trials weren't getting their credits reset at the start of the month because:
1. The `is_trial` flag wasn't being updated when trials expired
2. The monthly credit reset only runs for users with `is_trial = false`
3. The app only synced subscription data client-side (when users opened the app)

### Solution (3-Layer Approach)

#### Layer 1: RevenueCat Webhook (Real-time)
A Supabase Edge Function that receives webhook events from RevenueCat and immediately updates subscription status, trial status, and expiration dates.

**Events handled:**
- `INITIAL_PURCHASE` - New subscription started
- `RENEWAL` - Subscription renewed
- `CANCELLATION` - Subscription cancelled (but still active until expiration)
- `EXPIRATION` - Subscription expired
- `BILLING_ISSUE` - Payment failed
- `PRODUCT_CHANGE` - User changed subscription tier

#### Layer 2: Daily Trial Expiration Sync (Backup)
A pg_cron job that runs daily at 2:00 AM UTC to catch any missed trial-to-paid conversions.

**Function:** `sync_expired_trials()`
**Schedule:** `0 2 * * *` (Daily at 2 AM UTC)

#### Layer 3: Improved Monthly Credit Reset (Safety Net)
Enhanced the existing monthly credit reset to be more robust by checking expiration dates.

**Function:** `reset_paid_credits_monthly()`
**Schedule:** `0 0 1 * *` (1st of each month at midnight UTC)

## Setup Instructions

### Step 1: Get Your Supabase Edge Function URL

Your webhook URL is:
```
https://YOUR_SUPABASE_PROJECT_REF.supabase.co/functions/v1/handle-revenuecat-webhook
```

Replace `YOUR_SUPABASE_PROJECT_REF` with your actual Supabase project reference.

### Step 2: Configure RevenueCat Webhook

1. Go to your [RevenueCat Dashboard](https://app.revenuecat.com/)
2. Navigate to your project
3. Go to **Integrations** > **Webhooks**
4. Click **+ New** to add a webhook
5. Enter your Supabase Edge Function URL
6. Select the following events (or select "All Events"):
   - Initial Purchase
   - Renewal
   - Cancellation
   - Expiration
   - Billing Issue
   - Product Change
7. Click **Add Webhook**
8. Copy the **Webhook Authorization Secret**

### Step 3: Add Webhook Secret to Supabase

1. Go to your Supabase Dashboard
2. Navigate to **Project Settings** > **Edge Functions** > **Secrets**
3. Add a new secret:
   - **Name:** `REVENUECAT_WEBHOOK_SECRET`
   - **Value:** Paste the webhook secret from RevenueCat
4. Click **Save**

### Step 4: Test the Webhook

1. In RevenueCat Dashboard, go to the webhook you just created
2. Click **Send Test Event**
3. Check your Supabase Edge Function logs:
   - Go to **Edge Functions** > **handle-revenuecat-webhook** > **Logs**
   - You should see the webhook event being processed

### Step 5: Verify Cron Jobs

Run this SQL in Supabase SQL Editor to verify cron jobs are scheduled:

```sql
SELECT
  jobid,
  jobname,
  schedule,
  command,
  active
FROM cron.job
WHERE jobname IN ('reset-paid-credits-monthly', 'sync-expired-trials-daily');
```

Expected output:
- `reset-paid-credits-monthly` - Schedule: `0 0 1 * *` (Monthly on 1st at midnight)
- `sync-expired-trials-daily` - Schedule: `0 2 * * *` (Daily at 2 AM)

## Immediate Fix Applied

The following users were updated immediately:
- **bestkid9292@gmail.com** - Trial expired, marked as paid, granted 100 credits
- **thomose@gmail.com** - Trial expired, marked as paid, granted 100 credits

Both users now have:
- `is_trial = false`
- `paid_credits_remaining = 100`
- `credits_reset_date = 2026-02-01` (next reset)

## How It Works Together

### Scenario 1: User Trial Converts to Paid (Normal Flow)
1. User starts trial in app
2. Trial period ends and converts to paid subscription
3. **RevenueCat webhook fires** `RENEWAL` event
4. Edge function updates: `is_trial = false`
5. Database trigger grants 100 credits (via `apply_paid_credits_on_activation`)
6. User is now eligible for monthly credit resets

### Scenario 2: Webhook Missed (Backup Flow)
1. Webhook fails or user doesn't open app
2. **Daily cron job runs** at 2:00 AM UTC
3. `sync_expired_trials()` finds users with expired trials
4. Updates `is_trial = false` for converted subscriptions
5. Next monthly reset will include these users

### Scenario 3: Monthly Credit Reset
1. **Monthly cron job runs** on 1st of month at midnight UTC
2. `reset_paid_credits_monthly()` finds eligible users:
   - `subscription_status = 'active'`
   - `is_trial = false` (paid users only)
   - `subscription_expires_at > now()` (not expired)
3. Resets credits to 100 for all eligible users

## Monitoring

### Check Edge Function Logs
```
Supabase Dashboard > Edge Functions > handle-revenuecat-webhook > Logs
```

Look for:
- `[RevenueCat Webhook] Received event: RENEWAL for user ...`
- `[RevenueCat Webhook] Updated user ... to active subscription (trial: false)`

### Check Cron Job Execution
```sql
-- Check if jobs have run recently
SELECT * FROM cron.job_run_details
WHERE jobid IN (
  SELECT jobid FROM cron.job
  WHERE jobname IN ('reset-paid-credits-monthly', 'sync-expired-trials-daily')
)
ORDER BY start_time DESC
LIMIT 10;
```

### Manually Trigger Functions (For Testing)
```sql
-- Test daily trial sync
SELECT public.sync_expired_trials();

-- Test monthly credit reset
SELECT public.reset_paid_credits_monthly();
```

## Troubleshooting

### Webhook Not Firing
1. Check RevenueCat Dashboard webhook logs
2. Verify webhook URL is correct
3. Ensure Edge Function is deployed and active
4. Check if webhook secret is configured in Supabase

### Credits Not Resetting
1. Verify user has `is_trial = false`
2. Check `subscription_expires_at` is in the future
3. Verify `credits_reset_date` is in the past or null
4. Check cron job logs for errors

### Edge Function Errors
1. Go to Edge Function logs in Supabase Dashboard
2. Look for error messages
3. Common issues:
   - Missing `REVENUECAT_WEBHOOK_SECRET` environment variable
   - Invalid webhook signature
   - Supabase service role key not configured

## Files Created/Modified

### New Files
- `supabase/functions/handle-revenuecat-webhook/index.ts` - Edge function for webhooks
- `supabase/migrations/20260104000000_add_daily_trial_expiration_sync.sql` - Daily sync migration
- `supabase/migrations/20260104000001_improve_monthly_credit_reset.sql` - Improved reset logic
- `REVENUECAT_SETUP.md` - This setup guide

### Database Functions
- `sync_expired_trials()` - Daily trial expiration sync
- `reset_paid_credits_monthly()` - Monthly credit reset (improved)

### Cron Jobs
- `sync-expired-trials-daily` - Runs daily at 2:00 AM UTC
- `reset-paid-credits-monthly` - Runs monthly on 1st at midnight UTC

## Support

If you encounter issues:
1. Check Edge Function logs
2. Check cron job execution history
3. Verify webhook is configured correctly in RevenueCat
4. Test webhook manually from RevenueCat Dashboard
