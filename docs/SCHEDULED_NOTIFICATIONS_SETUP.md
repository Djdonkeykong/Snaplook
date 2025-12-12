# Scheduled Daily Notifications Setup Guide

## Overview
This guide explains how to send automated daily notifications to users for:
- Upload Reminders (if user hasn't uploaded in X days)
- Promotional notifications
- Any other scheduled notifications

## Prerequisites
- FCM tokens are being saved to `fcm_tokens` table
- User notification preferences are in `users` table:
  - `notification_enabled` (master toggle)
  - `upload_reminders_enabled`
  - `promotions_enabled`

---

## Option 1: Firebase Cloud Functions + Cloud Scheduler (Recommended)

**Best for:** Apps already using Firebase heavily

### Setup Steps:

1. **Install Firebase Admin SDK in Cloud Functions**
```bash
cd functions
npm install firebase-admin
```

2. **Create Scheduled Function** (`functions/src/index.ts`):
```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { createClient } from '@supabase/supabase-js';

admin.initializeApp();

const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_KEY!
);

// Runs every day at 10 AM
export const sendDailyReminders = functions.pubsub
  .schedule('0 10 * * *')
  .timeZone('America/New_York')
  .onRun(async (context) => {
    console.log('Starting daily notification job...');

    // Get users who should receive upload reminders
    const { data: users } = await supabase
      .from('users')
      .select('id, email, notification_enabled, upload_reminders_enabled')
      .eq('notification_enabled', true)
      .eq('upload_reminders_enabled', true);

    if (!users || users.length === 0) {
      console.log('No users to notify');
      return null;
    }

    // Get FCM tokens for these users
    const userIds = users.map(u => u.id);
    const { data: tokens } = await supabase
      .from('fcm_tokens')
      .select('user_id, token')
      .in('user_id', userIds);

    if (!tokens || tokens.length === 0) {
      console.log('No FCM tokens found');
      return null;
    }

    // Send notifications
    const messages = tokens.map(t => ({
      token: t.token,
      notification: {
        title: 'Upload Reminder',
        body: 'Haven\'t seen you in a while! Share your latest fashion finds.',
      },
      data: {
        type: 'upload_reminder',
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
    }));

    const response = await admin.messaging().sendEach(messages);
    console.log(`Sent ${response.successCount} notifications, ${response.failureCount} failures`);

    return null;
  });
```

3. **Deploy**:
```bash
firebase deploy --only functions
```

---

## Option 2: Supabase Edge Functions + pg_cron

**Best for:** Apps using Supabase Pro (pg_cron requires Pro plan)

### Setup Steps:

1. **Create Edge Function**:
```bash
supabase functions new send-daily-notifications
```

2. **Implement** (`supabase/functions/send-daily-notifications/index.ts`):
```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

serve(async (req) => {
  try {
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Get users who should receive notifications
    const { data: users } = await supabase
      .from('users')
      .select('id, notification_enabled, upload_reminders_enabled')
      .eq('notification_enabled', true)
      .eq('upload_reminders_enabled', true);

    if (!users || users.length === 0) {
      return new Response(JSON.stringify({ message: 'No users to notify' }), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // Get FCM tokens
    const userIds = users.map(u => u.id);
    const { data: tokens } = await supabase
      .from('fcm_tokens')
      .select('user_id, token')
      .in('user_id', userIds);

    if (!tokens || tokens.length === 0) {
      return new Response(JSON.stringify({ message: 'No tokens found' }), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // Send notifications via Firebase Admin SDK
    const FIREBASE_SERVER_KEY = Deno.env.get('FIREBASE_SERVER_KEY')!;

    const promises = tokens.map(async (t) => {
      const response = await fetch('https://fcm.googleapis.com/fcm/send', {
        method: 'POST',
        headers: {
          'Authorization': `key=${FIREBASE_SERVER_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          to: t.token,
          notification: {
            title: 'Upload Reminder',
            body: 'Haven\'t seen you in a while! Share your latest fashion finds.',
          },
          data: {
            type: 'upload_reminder',
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
          },
        }),
      });
      return response.json();
    });

    const results = await Promise.all(promises);
    const successCount = results.filter(r => r.success === 1).length;

    return new Response(
      JSON.stringify({
        message: `Sent ${successCount} notifications`,
        results
      }),
      { headers: { 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
```

3. **Deploy**:
```bash
supabase functions deploy send-daily-notifications
```

4. **Schedule with pg_cron** (in Supabase SQL Editor):
```sql
-- Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule daily at 10 AM
SELECT cron.schedule(
  'send-daily-notifications',
  '0 10 * * *',
  $$
  SELECT
    net.http_post(
      url := 'https://your-project-ref.supabase.co/functions/v1/send-daily-notifications',
      headers := '{"Authorization": "Bearer YOUR_ANON_KEY"}'::jsonb
    );
  $$
);
```

---

## Option 3: Simple Node.js Script + Cron Job (Easiest)

**Best for:** Quick setup, full control, easy debugging

### Setup Steps:

1. **Create Script** (`scripts/send-notifications.js`):
```javascript
const { createClient } = require('@supabase/supabase-js');
const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./firebase-service-account.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

// Initialize Supabase
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
);

async function sendDailyNotifications() {
  console.log('Starting notification job...');

  try {
    // Get users who should receive notifications
    const { data: users, error: usersError } = await supabase
      .from('users')
      .select('id, notification_enabled, upload_reminders_enabled')
      .eq('notification_enabled', true)
      .eq('upload_reminders_enabled', true);

    if (usersError) throw usersError;
    if (!users || users.length === 0) {
      console.log('No users to notify');
      return;
    }

    console.log(`Found ${users.length} users who want reminders`);

    // Get FCM tokens
    const userIds = users.map(u => u.id);
    const { data: tokens, error: tokensError } = await supabase
      .from('fcm_tokens')
      .select('user_id, token')
      .in('user_id', userIds);

    if (tokensError) throw tokensError;
    if (!tokens || tokens.length === 0) {
      console.log('No FCM tokens found');
      return;
    }

    console.log(`Found ${tokens.length} tokens`);

    // Send notifications
    const messages = tokens.map(t => ({
      token: t.token,
      notification: {
        title: 'Upload Reminder',
        body: 'Haven\'t seen you in a while! Share your latest fashion finds.',
      },
      data: {
        type: 'upload_reminder',
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
    }));

    const response = await admin.messaging().sendEach(messages);
    console.log(`✅ Success: ${response.successCount}`);
    console.log(`❌ Failures: ${response.failureCount}`);

    // Log failures for debugging
    response.responses.forEach((resp, idx) => {
      if (!resp.success) {
        console.error(`Failed to send to token ${tokens[idx].token}:`, resp.error);
      }
    });

  } catch (error) {
    console.error('Error sending notifications:', error);
  }
}

sendDailyNotifications();
```

2. **Install Dependencies**:
```bash
npm install @supabase/supabase-js firebase-admin dotenv
```

3. **Create `.env` File**:
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_KEY=your-service-key
```

4. **Get Firebase Service Account Key**:
   - Go to Firebase Console → Project Settings → Service Accounts
   - Click "Generate new private key"
   - Save as `firebase-service-account.json`

5. **Test Manually**:
```bash
node scripts/send-notifications.js
```

6. **Schedule with Cron**:

**On Linux/Mac**:
```bash
crontab -e
```
Add:
```cron
0 10 * * * cd /path/to/snaplook && node scripts/send-notifications.js >> logs/notifications.log 2>&1
```

**On Windows (Task Scheduler)**:
- Open Task Scheduler
- Create Basic Task
- Set trigger: Daily at 10:00 AM
- Action: Start a program
- Program: `node.exe`
- Arguments: `C:\path\to\snaplook\scripts\send-notifications.js`

**On Vercel (Serverless)**:
```json
// vercel.json
{
  "crons": [{
    "path": "/api/send-notifications",
    "schedule": "0 10 * * *"
  }]
}
```

---

## Advanced: Smart Upload Reminders

Only send reminders to users who haven't uploaded recently:

```javascript
// Add this query before sending notifications
const { data: recentUploads } = await supabase
  .from('user_searches')  // or whatever table tracks uploads
  .select('user_id')
  .gte('created_at', new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toIso8601String())
  .in('user_id', userIds);

const recentUploadUserIds = new Set(recentUploads?.map(u => u.user_id) || []);

// Filter out users who uploaded recently
const usersToNotify = users.filter(u => !recentUploadUserIds.has(u.id));
```

---

## Testing

Before going live, test with a single user:

```javascript
// Test with your own user ID
const { data: testToken } = await supabase
  .from('fcm_tokens')
  .select('token')
  .eq('user_id', 'YOUR_USER_ID')
  .single();

await admin.messaging().send({
  token: testToken.token,
  notification: {
    title: 'Test Notification',
    body: 'This is a test!',
  },
});
```

---

## Monitoring & Analytics

Track notification delivery:

1. **Create notifications_log table** in Supabase:
```sql
CREATE TABLE notifications_log (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  notification_type TEXT NOT NULL,
  sent_at TIMESTAMPTZ DEFAULT NOW(),
  success BOOLEAN NOT NULL,
  error_message TEXT
);
```

2. **Log each send**:
```javascript
const logs = response.responses.map((resp, idx) => ({
  user_id: tokens[idx].user_id,
  notification_type: 'upload_reminder',
  success: resp.success,
  error_message: resp.error?.message || null,
}));

await supabase.from('notifications_log').insert(logs);
```

---

## Cost Considerations

- **Firebase**: 1 million free messages/month, then $0.50 per 1,000 messages
- **Supabase Edge Functions**: 500K function invocations/month (free tier)
- **pg_cron**: Requires Supabase Pro ($25/month)
- **Vercel Cron**: Free tier includes 1 cron job

---

## Next Steps

1. Run the SQL migration to add notification columns (already created)
2. Choose which option fits your infrastructure
3. Set up the chosen solution
4. Test with your own account
5. Monitor delivery rates and adjust timing/content as needed
