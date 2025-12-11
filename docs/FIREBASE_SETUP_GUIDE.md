# Firebase Push Notifications Setup Guide

This guide will walk you through setting up Firebase Cloud Messaging (FCM) for both iOS and Android in your Snaplook app.

## Prerequisites

- Firebase account (free)
- iOS: Apple Developer Account (for APNs certificate)
- Android: None required

---

## Step 1: Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project"
3. Name it "Snaplook" (or any name)
4. Follow the setup wizard (disable Google Analytics if you don't need it)
5. Click "Create project"

---

## Step 2: Add iOS App to Firebase

1. In Firebase Console, click the iOS icon
2. **iOS bundle ID**: Enter your app's bundle ID (find it in Xcode: `Runner` > `General` > `Bundle Identifier`)
   - Example: `com.snaplook.app`
3. **App nickname**: "Snaplook iOS" (optional)
4. **App Store ID**: Leave blank for now
5. Click "Register app"
6. **Download `GoogleService-Info.plist`**
7. Add the file to your Xcode project:
   - Open Xcode
   - Right-click on `Runner` folder
   - Select "Add Files to Runner"
   - Select `GoogleService-Info.plist`
   - ✅ Check "Copy items if needed"
   - ✅ Check target "Runner"
   - Click "Add"

### iOS APNs Certificate Setup

1. In Firebase Console > Project Settings > Cloud Messaging tab
2. Under "Apple app configuration", click "Upload" for APNs Authentication Key
3. **Get APNs Key from Apple Developer Portal:**
   - Go to [Apple Developer Portal](https://developer.apple.com/account/resources/authkeys/list)
   - Click the "+" button to create a new key
   - Check "Apple Push Notifications service (APNs)"
   - Click "Continue" then "Register"
   - Download the `.p8` file
   - Note the **Key ID** (shown on the download page)
4. **Upload to Firebase:**
   - Upload the `.p8` file
   - Enter the Key ID
   - Enter your **Team ID** (find it in Apple Developer Portal > Membership)
   - Click "Upload"

---

## Step 3: Add Android App to Firebase

1. In Firebase Console, click the Android icon
2. **Android package name**: Enter your app's package name
   - Find it in `android/app/build.gradle` under `applicationId`
   - Example: `com.snaplook.app`
3. **App nickname**: "Snaplook Android" (optional)
4. **Debug SHA-1**: Leave blank for now (not needed for FCM)
5. Click "Register app"
6. **Download `google-services.json`**
7. Place the file in `android/app/` directory
   ```
   android/
     app/
       google-services.json  <-- Place here
       build.gradle
   ```

### Android Configuration

1. Open `android/build.gradle` (project-level)
2. Add Google Services plugin (should already be there, but verify):
   ```gradle
   dependencies {
       classpath 'com.google.gms:google-services:4.4.0'
   }
   ```

3. Open `android/app/build.gradle`
4. Add plugin at the bottom:
   ```gradle
   apply plugin: 'com.google.gms.google-services'
   ```

---

## Step 4: Get Firebase Server Key (for Supabase Edge Functions)

1. In Firebase Console > Project Settings > Cloud Messaging tab
2. Scroll to "Cloud Messaging API (Legacy)"
3. If not enabled, click "Enable" (you may need to enable it in Google Cloud Console)
4. Copy the **Server key**
5. Save this for the next section (Supabase Edge Function setup)

---

## Step 5: Test the Setup

### Option A: Test with Firebase Console

1. Build and run your app on a device/simulator
2. Go through the onboarding flow and allow notifications
3. Check the logs for FCM token:
   ```
   [NotificationService] FCM Token: <your-token>
   ```
4. In Firebase Console > Cloud Messaging > Send test message
5. Paste the FCM token
6. Send the notification
7. You should receive it!

### Option B: Test with Supabase Edge Function

After setting up the Edge Functions (next section), you can trigger notifications programmatically.

---

## Next Steps

Once Firebase is configured, proceed to:
1. **Configure Supabase Edge Functions** to send notifications
2. **Set up the cron job** for re-engagement notifications

See `SUPABASE_EDGE_FUNCTIONS_GUIDE.md` for backend setup.

---

## Troubleshooting

### iOS
- **No token received**: Make sure you have APNs key uploaded to Firebase
- **Permission denied**: Check that you're requesting permission correctly
- **App crashes**: Make sure `GoogleService-Info.plist` is in the Xcode project target

### Android
- **No token received**: Check that `google-services.json` is in `android/app/`
- **Build errors**: Make sure you applied the Google Services plugin in `build.gradle`
- **Permission denied**: Android 13+ requires runtime permission (handled in code)

### General
- **Token not saving to database**: Check RLS policies on `fcm_tokens` table
- **Background notifications not working**: Make sure `firebase_options.dart` is generated
- **Foreground notifications not showing**: Check the logs - they should show in a SnackBar

---

## Security Notes

- Never commit `GoogleService-Info.plist` or `google-services.json` to public repos
- The Firebase Server Key should be stored as a Supabase secret
- Only authenticated users can register FCM tokens (enforced by RLS)
