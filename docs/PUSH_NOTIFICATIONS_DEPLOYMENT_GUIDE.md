# Push Notifications Deployment Guide

This guide covers deploying the backend infrastructure for push notifications.

## Prerequisites

- Completed Firebase setup (see `FIREBASE_SETUP_GUIDE.md`)
- Supabase CLI installed: `npm install -g supabase`
- Firebase Service Account JSON key (downloaded from Firebase Console)

---

## Step 1: Set Firebase Service Account in Supabase

1. Go to your Supabase Dashboard
2. Navigate to **Project Settings** > **Edge Functions** > **Secrets**
3. Click **Add new secret**
4. Name: `FIREBASE_SERVICE_ACCOUNT`
5. Value: Paste the **entire contents** of your Firebase service account JSON file
   - The file is named something like `snaplook-app-main-firebase-adminsdk-xxxxx.json`
   - Copy and paste the entire JSON object, including the curly braces
   - Example format:
   ```json
   {"type":"service_account","project_id":"your-project-id","private_key_id":"...","private_key":"-----BEGIN PRIVATE KEY-----\n...","client_email":"...","client_id":"...","auth_uri":"...","token_uri":"...","auth_provider_x509_cert_url":"...","client_x509_cert_url":"...","universe_domain":"googleapis.com"}
   ```
6. Click **Save**

**Note:** The Edge Function uses FCM V1 API (the modern, recommended API) instead of the legacy API.

---

## Step 2: Deploy Edge Functions

### Deploy send-push-notification function

```bash
cd D:\Snaplook
supabase functions deploy send-push-notification
```

### Deploy send-reengagement-notifications function

```bash
supabase functions deploy send-reengagement-notifications
```

---

## Step 3: Set Up Cron Job for Re-engagement Notifications

### Option A: Using Supabase Cron (Recommended)

1. Go to Supabase Dashboard > **Database** > **Cron Jobs**
2. Click **Create a new cron job**
3. **Name**: `send-reengagement-notifications`
4. **Schedule**: `0 10 * * *` (Daily at 10 AM UTC)
   - Customize as needed:
     - `0 10 * * *` - Daily at 10 AM
     - `0 18 * * *` - Daily at 6 PM
     - `0 10 * * 1` - Every Monday at 10 AM
5. **Command**:
   ```sql
   SELECT net.http_post(
     url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-reengagement-notifications',
     headers := '{"Content-Type": "application/json", "Authorization": "Bearer YOUR_SERVICE_ROLE_KEY"}'::jsonb
   );
   ```
   Replace:
   - `YOUR_PROJECT_REF` with your Supabase project reference
   - `YOUR_SERVICE_ROLE_KEY` with your service role key

6. Click **Create cron job**

### Option B: Using External Cron Service (e.g., cron-job.org)

1. Sign up for a free cron service like [cron-job.org](https://cron-job.org)
2. Create a new cron job
3. **URL**: `https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-reengagement-notifications`
4. **Method**: POST
5. **Headers**:
   ```
   Authorization: Bearer YOUR_SERVICE_ROLE_KEY
   Content-Type: application/json
   ```
6. **Schedule**: Daily at desired time
7. Save

---

## Step 4: Test the Push Notification System

### Test sending a notification manually

```bash
curl -X POST \
  'https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-push-notification' \
  -H 'Authorization: Bearer YOUR_SERVICE_ROLE_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "user_id": "YOUR_USER_ID",
    "title": "Test Notification",
    "body": "This is a test push notification!",
    "data": {
      "type": "test"
    }
  }'
```

Replace:
- `YOUR_PROJECT_REF` - Your Supabase project reference
- `YOUR_SERVICE_ROLE_KEY` - Your Supabase service role key
- `YOUR_USER_ID` - A test user ID from your database

### Test re-engagement function

```bash
curl -X POST \
  'https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-reengagement-notifications' \
  -H 'Authorization: Bearer YOUR_SERVICE_ROLE_KEY' \
  -H 'Content-Type: application/json'
```

---

## Step 5: Monitor Edge Function Logs

1. Go to Supabase Dashboard > **Edge Functions**
2. Click on the function name (e.g., `send-push-notification`)
3. Click **Logs** tab
4. You'll see real-time logs of function executions

---

## Notification Types Implemented

### 1. Re-engagement Notifications
- **Trigger**: Daily cron job
- **Target**: Users who haven't uploaded in 7+ days
- **Respects**: User notification preferences
- **Message**: "Haven't uploaded in a while? Discover new fashion items today!"

### Future Notification Types (Ready to Implement)

#### 2. Social Notifications
When you add social features:
```typescript
// Example: Send notification when someone follows you
await fetch('https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-push-notification', {
  method: 'POST',
  headers: {
    'Authorization': 'Bearer SERVICE_KEY',
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    user_id: followedUserId,
    title: 'New Follower',
    body: `${followerName} started following you!`,
    data: { type: 'new_follower', follower_id: followerId }
  })
})
```

#### 3. Search Complete Notifications
```typescript
// Send when search analysis is complete
await fetch('https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-push-notification', {
  method: 'POST',
  headers: {
    'Authorization': 'Bearer SERVICE_KEY',
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    user_id: userId,
    title: 'Your search is ready!',
    body: 'We found 24 similar fashion items for you.',
    data: { type: 'search_complete', search_id: searchId }
  })
})
```

---

## Troubleshooting

### Edge Function Errors

**"FIREBASE_SERVICE_ACCOUNT not configured"**
- Make sure you added the secret in Supabase Dashboard
- Verify you pasted the entire JSON contents (including curly braces)
- Redeploy the function after adding the secret

**"No FCM tokens found"**
- User hasn't granted notification permission
- FCM token not registered (check app logs)
- Check `fcm_tokens` table in database

**"Unauthorized" errors**
- Check that you're using the Service Role Key (not anon key)
- Verify the Authorization header format

### Cron Job Not Running

**Supabase Cron:**
- Check cron job status in Dashboard > Database > Cron Jobs
- View logs to see if it's executing
- Make sure `pg_cron` extension is enabled

**External Cron:**
- Check service dashboard for execution logs
- Verify URL is correct
- Check headers are properly set

### Notifications Not Received

**iOS:**
- Make sure APNs certificate is uploaded to Firebase
- Check that `GoogleService-Info.plist` is in Xcode project
- Verify app is not in Do Not Disturb mode

**Android:**
- Make sure `google-services.json` is in `android/app/`
- Check that Google Services plugin is applied
- Verify notification permission is granted (Android 13+)

---

## Security Best Practices

1. **Never expose Service Role Key** - Only use it in backend/Edge Functions
2. **Respect user preferences** - Always check notification settings before sending
3. **Rate limiting** - Don't spam users with too many notifications
4. **Test with real devices** - Simulators may not receive notifications properly
5. **Monitor logs** - Check Edge Function logs regularly for errors

---

## Customization

### Adjust Re-engagement Schedule

Edit the cron schedule:
- `0 10 * * *` - Daily at 10 AM
- `0 */6 * * *` - Every 6 hours
- `0 10 * * 1,4` - Monday and Thursday at 10 AM

### Adjust Inactivity Period

In `send-reengagement-notifications/index.ts`, change:
```typescript
// From 7 days:
sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7)

// To 3 days:
sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 3)
```

### Customize Notification Messages

Edit the notification payload in the Edge Function:
```typescript
const notificationPayload = {
  user_ids: eligibleUserIds,
  title: 'Your custom title',
  body: 'Your custom message',
  data: {
    type: 'your_custom_type',
  }
}
```

---

## Next Steps

1. Run `flutter pub get` to install the new dependencies
2. Follow `FIREBASE_SETUP_GUIDE.md` to configure Firebase
3. Deploy the Edge Functions using the commands above
4. Set up the cron job
5. Test notifications on a real device

Congratulations! Your push notification system is now live.
