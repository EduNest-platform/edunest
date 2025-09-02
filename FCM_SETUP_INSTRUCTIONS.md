# FCM Notification Setup Instructions

## Overview
This guide will help you set up Firebase Cloud Messaging (FCM) notifications for assignment marks and midsem marks in EduNest.

## Prerequisites
- Firebase project with FCM enabled
- Supabase project with Edge Functions enabled
- Admin access to your database

## Step-by-Step Setup

### 1. Firebase Setup

#### A. Create Firebase Project (if not already done)
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or select existing project
3. Enable Cloud Messaging in the project settings

#### B. Get Firebase Configuration
1. In Firebase Console, go to Project Settings > General
2. Add your Android/iOS apps if not already added
3. Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
4. Place these files in the appropriate directories:
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`

#### C. Get Firebase Service Account Key
1. In Firebase Console, go to Project Settings > Service Accounts
2. Click "Generate new private key" to download the service account JSON file
3. Keep this file secure - you'll need its contents for Supabase

### 2. Database Setup

#### A. Run Database Migrations
Execute these SQL files in your Supabase SQL editor:

1. **Create FCM tokens table:**
```bash
# Run the contents of: database/migrations/create_fcm_tokens_table.sql
```

2. **Create notification triggers:**
```bash
# Run the contents of: database/migrations/create_marks_notification_triggers.sql
```

**IMPORTANT:** Before running the triggers file, update these values:
- Replace `https://your-project-id.supabase.co` with your actual Supabase URL
- Replace `your-service-role-key` with your actual Supabase service role key

### 3. Supabase Edge Function Setup

#### A. Deploy the Edge Function
1. Install Supabase CLI if not already installed:
```bash
npm install -g supabase
```

2. Login to Supabase:
```bash
supabase login
```

3. Link your project:
```bash
cd "Super Admin/supabase"
supabase link --project-ref your-project-id
```

4. Deploy the function:
```bash
supabase functions deploy send-fcm-notification
```

#### B. Set Environment Variables
In your Supabase dashboard, go to Settings > Edge Functions and add:
- `FIREBASE_PROJECT_ID`: Your Firebase project ID (found in Firebase Console > Project Settings)
- `FIREBASE_SERVICE_ACCOUNT`: The entire contents of your service account JSON file from step 1C (paste as a single line JSON string)

### 4. Flutter App Setup

#### A. Install Dependencies
Run in your project root:
```bash
flutter pub get
```

#### B. Android Configuration
1. Ensure `google-services.json` is in `android/app/`
2. Add to `android/app/build.gradle`:
```gradle
plugins {
    id 'com.google.gms.google-services'
}
```

3. Add to `android/build.gradle`:
```gradle
dependencies {
    classpath 'com.google.gms:google-services:4.3.15'
}
```

4. Add notification icon to `android/app/src/main/res/drawable/ic_notification.xml`:
```xml
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24"
    android:tint="?attr/colorOnPrimary">
  <path
      android:fillColor="@android:color/white"
      android:pathData="M12,2C6.48,2 2,6.48 2,12s4.48,10 10,10 10,-4.48 10,-10S17.52,2 12,2zM13,17h-2v-6h2v6zM13,9h-2L11,7h2v2z"/>
</vector>
```

#### C. iOS Configuration (if targeting iOS)
1. Ensure `GoogleService-Info.plist` is in `ios/Runner/`
2. Add to `ios/Runner/Info.plist`:
```xml
<key>FirebaseMessagingAutoInitEnabled</key>
<true/>
```

### 5. Testing the Setup

#### A. Test FCM Token Registration
1. Run the app and login as a student
2. Check the `user_fcm_tokens` table in Supabase - you should see a token entry

#### B. Test Notifications
1. Login to admin panel
2. Go to Assignment Marks or Midsem Marks
3. Add marks for a student who has the app installed
4. The student should receive a notification

#### C. Debug Issues
Check these if notifications aren't working:
1. Supabase Edge Function logs
2. Database trigger logs (check for NOTICE/WARNING messages)
3. Flutter app logs for FCM token registration
4. Firebase Console for delivery reports

## Notification Types

The system supports these notification types:

### Assignment Marks
- **Trigger:** When assignment marks are saved/updated
- **Title:** "New Assignment Grade 📝"
- **Body:** "You received X/Y marks in [Assignment Name]"

### Midsem Marks
- **Trigger:** When midsem marks are saved/updated
- **Title:** "Midsem Results Available 🎯"
- **Body:** "You scored X/Y in [Exam Name]"

## Troubleshooting

### Common Issues

1. **No notifications received:**
   - Check if FCM token is stored in database
   - Verify Firebase server key in Supabase environment variables
   - Check Edge Function logs

2. **Notifications not showing on Android:**
   - Ensure notification permissions are granted
   - Check if app is in battery optimization whitelist

3. **Database triggers not firing:**
   - Verify triggers are created correctly
   - Check if Supabase URL and service key are correct in trigger functions

4. **Edge Function errors:**
   - Check function logs in Supabase dashboard
   - Verify environment variables are set

## Security Notes

- FCM server key should be kept secure and only stored in Supabase environment variables
- Database triggers use service role key - ensure it has proper permissions
- FCM tokens are automatically cleaned up when they become invalid

## Future Enhancements

You can extend this system to add:
- Attendance alerts (when attendance drops below 75%)
- Test assignment notifications
- Deadline reminders
- Custom notification scheduling
