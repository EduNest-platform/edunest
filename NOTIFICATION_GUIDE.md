# EduNest Notification System Guide

## What Are Local Notifications?

**Local notifications** are actual system notifications that appear on your device - they are NOT banners or in-app popups. They are the same type of notifications you see from WhatsApp, Gmail, or any other app on your phone.

### Key Points:
- ✅ **Real System Notifications**: They appear in your device's notification tray/center
- ✅ **Work When App is Closed**: You'll receive them even if EduNest is completely closed
- ✅ **Native Experience**: They look and behave exactly like other app notifications
- ✅ **Interactive**: You can tap them to open the app or dismiss them

## How Our Notification System Works

### Dual Architecture: FCM + Local Notifications

```
Server → FCM (Firebase) → Your Device → Local Notification Display
```

1. **FCM (Firebase Cloud Messaging)**: Delivers the notification from our server to your device
2. **flutter_local_notifications**: Takes the FCM data and creates a beautiful, customized notification

## Notification Types & Appearance

### 🎓 Grade Notifications (Only Notification Type)
**When you receive new assignment marks or mid-semester marks:**

**Visual Appearance:**
- **Color**: Green accent (`#10b981`)
- **Priority**: Maximum (appears as heads-up notification)
- **Vibration**: Double pulse pattern (500ms, pause, 500ms)
- **LED Light**: Green (on supported devices)
- **Icon**: EduNest app logo
- **Style**: Expanded text showing full grade details

**Supported Notification Types:**
- `assignment_marks` - New assignment grades
- `midsem_marks` - Mid-semester exam results

**Example:**
```
🏫 EduNest
New Marks for Mathematics
You scored 85/100 in Assignment 3. Great work! 
Your current average is 82%.
```

**Behavior:**
- Appears immediately on screen (heads-up)
- Stays in notification tray until dismissed
- Tapping opens the app to grades section

## Notification States & Behavior

### 📱 When App is Open (Foreground)
- Notification appears as a system notification
- App continues running normally
- You can tap the notification or continue using the app

### 🔄 When App is in Background
- Notification appears immediately
- Tapping brings the app back to foreground
- App resumes from where you left off

### ❌ When App is Completely Closed
- Notification still appears (this is the power of FCM!)
- Tapping launches the app
- App opens to the relevant screen based on notification type

### 💀 When App is Terminated/Force Closed
- Notifications still work perfectly
- FCM wakes up the notification system
- Full functionality maintained

## Customization Features

### 🎨 Visual Customizations
- **App Logo**: Your EduNest icon appears on every notification
- **Colors**: Different colors for different notification types
- **Expanded Text**: Full message content visible without opening
- **LED Lights**: Colored LED indicators (Android devices)

### 🔊 Audio & Haptic Feedback
- **Sounds**: System notification sounds
- **Vibration Patterns**: Custom patterns for different types
- **Silent Mode**: Respects your device's silent/do-not-disturb settings

### 🎯 Smart Targeting
- **Personalized**: Only you receive notifications meant for you
- **Context-Aware**: Different styles for different types of updates
- **Multi-Device**: Works across all your devices where EduNest is installed

## Technical Implementation

### Notification Channels (Android)
We create separate channels for better organization:

1. **`edunest_notifications`**: General updates and announcements
2. **`edunest_marks`**: Grade and assignment notifications

### Permissions
The app automatically requests:
- **FCM Permissions**: For receiving push notifications
- **Local Notification Permissions**: For displaying notifications (Android 13+)
- **Sound & Vibration**: For audio and haptic feedback

### Data Flow
```
1. Admin updates grades in admin panel
2. Database trigger fires
3. Supabase Edge Function sends FCM message
4. FCM delivers to your device
5. EduNest app receives FCM data
6. flutter_local_notifications creates beautiful notification
7. You see the notification on your screen
```

## Notification Examples

### Grade Notification (Expanded View)
```
┌─────────────────────────────────────┐
│ 🏫 EduNest                    [🔔] │
│ New Marks for Computer Science      │
│                                     │
│ Excellent work! You scored 92/100   │
│ in Mid-Semester Exam. This brings   │
│ your overall average to 88.5%.      │
│ Keep up the great work!             │
│                                     │
│ 📊 View Details    ❌ Dismiss       │
└─────────────────────────────────────┘
```

### General Notification (Standard View)
```
┌─────────────────────────────────────┐
│ 🏫 EduNest                    [🔔] │
│ Assignment Reminder                 │
│ Physics Lab Report due tomorrow     │
│ at 11:59 PM                        │
└─────────────────────────────────────┘
```

## Troubleshooting

### If Notifications Aren't Working:

1. **Check App Permissions**:
   - Go to Settings > Apps > EduNest > Notifications
   - Ensure all notification permissions are enabled

2. **Check Device Settings**:
   - Ensure "Do Not Disturb" isn't blocking notifications
   - Check battery optimization settings

3. **Check FCM Token**:
   - The app automatically manages this
   - Logout and login again to refresh token

### Testing Notifications:
- Ask your teacher to update a grade
- Check if you receive the notification within 30 seconds
- Try with app open, closed, and in background

## Privacy & Security

- **Secure Delivery**: All notifications are encrypted in transit
- **Personal Data**: Only you receive your notifications
- **Token Management**: FCM tokens are securely stored and managed
- **Logout Protection**: Tokens are deactivated when you logout

---

**Need Help?** Contact your system administrator or check the app's help section for more information.
