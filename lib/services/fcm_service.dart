import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  FirebaseMessaging? _messaging;
  FlutterLocalNotificationsPlugin? _localNotifications;
  bool _isInitialized = false;
  String? _pendingToken;

  /// Initialize FCM service - Only on mobile platforms
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Only initialize FCM on mobile platforms
    if (!Platform.isAndroid && !Platform.isIOS) {
      if (kDebugMode) {
        print('🖥️ FCM Service: Skipping initialization on desktop platform (${Platform.operatingSystem})');
      }
      return;
    }

    try {
      _messaging = FirebaseMessaging.instance;

      // Initialize Local Notifications
      await _initializeLocalNotifications();

      // Request notification permissions
      await _requestPermissions();

      // Get and store FCM token
      await _handleTokenRefresh();

      // Set up message handlers
      _setupMessageHandlers();

      _isInitialized = true;
      if (kDebugMode) {
        print('✅ FCM Service initialized successfully on ${Platform.operatingSystem}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ FCM Service initialization failed: $e');
      }
    }
  }

  /// Initialize Local Notifications
  Future<void> _initializeLocalNotifications() async {
    _localNotifications = FlutterLocalNotificationsPlugin();
    
    const androidSettings = AndroidInitializationSettings('@drawable/ic_notification');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications!.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    // Create notification channels for Android
    if (Platform.isAndroid) {
      await _createNotificationChannels();
    }
  }
  
  /// Create Android notification channels
  Future<void> _createNotificationChannels() async {
    const marksChannel = AndroidNotificationChannel(
      'edunest_marks',
      'Grade Notifications', 
      description: 'Notifications for assignment and mid-semester marks',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
    );
    
    await _localNotifications!.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(marksChannel);
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    // Request FCM permissions
    NotificationSettings settings = await _messaging!.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    // Request local notification permissions for Android 13+
    if (Platform.isAndroid) {
      await _localNotifications!.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    // FCM Permission status: ${settings.authorizationStatus}
  }

  /// Handle FCM token refresh and storage
  Future<void> _handleTokenRefresh() async {
    try {
      // Get current token
      String? token = await _messaging!.getToken();
      if (token != null) {
        await _storeTokenInDatabase(token);
      }

      // Listen for token refresh
      _messaging!.onTokenRefresh.listen((String token) {
        _storeTokenInDatabase(token);
      });
    } catch (e) {
      // Error handling FCM token: $e
    }
  }

  /// Store FCM token in Supabase database
  Future<void> _storeTokenInDatabase(String token) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        print('FCM: No authenticated user, storing token as pending');
        // Store token temporarily for later storage after login
        _pendingToken = token;
        return;
      }

      // Get device information
      final deviceInfo = await _getDeviceInfo();
      
      print('FCM: Attempting to store token for user ${user.id}');
      print('FCM: Device info: $deviceInfo');
      print('FCM: Token: ${token.substring(0, 20)}...');

      // Upsert token in database
      final response = await Supabase.instance.client
          .from('user_fcm_tokens')
          .upsert({
            'user_id': user.id,
            'fcm_token': token,
            'device_type': deviceInfo['type'],
            'device_info': deviceInfo,
            'is_active': true,
            'updated_at': DateTime.now().toIso8601String(),
          }, onConflict: 'user_id,fcm_token');

      print('FCM: Token stored successfully for ${deviceInfo['type']} device');
      _pendingToken = null; // Clear pending token after successful storage
    } catch (e) {
      print('FCM: Error storing token: $e');
      print('FCM: Error type: ${e.runtimeType}');
      if (e is PostgrestException) {
        print('FCM: Postgrest error code: ${e.code}');
        print('FCM: Postgrest error message: ${e.message}');
        print('FCM: Postgrest error details: ${e.details}');
      }
    }
  }

  /// Store pending token after user login
  Future<void> storePendingToken() async {
    if (_pendingToken != null) {
      // Storing pending FCM token after login
      await _storeTokenInDatabase(_pendingToken!);
    }
  }

  /// Force refresh and store FCM token for existing authenticated sessions
  /// This is useful when app is updated and user session persists
  Future<void> refreshAndStoreToken() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        // No authenticated user for FCM token refresh
        return;
      }

      // Get current FCM token
      String? token = await _messaging?.getToken();
      if (token != null) {
        // Force refreshing FCM token for existing session
        await _storeTokenInDatabase(token);
      } else {
        // Could not get FCM token for refresh
      }
    } catch (e) {
      // Error refreshing FCM token: $e
    }
  }

  /// Get device information
  Future<Map<String, dynamic>> _getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    Map<String, dynamic> info = {};

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        info = {
          'type': 'android',
          'model': androidInfo.model,
          'manufacturer': androidInfo.manufacturer,
          'version': androidInfo.version.release,
          'sdk': androidInfo.version.sdkInt,
        };
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        info = {
          'type': 'ios',
          'model': iosInfo.model,
          'name': iosInfo.name,
          'version': iosInfo.systemVersion,
        };
      } else {
        info = {'type': 'unknown'};
      }
    } catch (e) {
      info = {'type': 'unknown', 'error': e.toString()};
    }

    return info;
  }

  /// Set up FCM message handlers
  void _setupMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Received foreground message: ${message.messageId}
      _handleForegroundMessage(message);
    });

    // Handle background message taps
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // App opened from background message: ${message.messageId}
      _handleMessageTap(message);
    });

    // Handle app launch from terminated state
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        // App launched from terminated state: ${message.messageId}
        _handleMessageTap(message);
      }
    });
  }

  /// Handle foreground messages by showing local notification
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    try {
      // FOREGROUND MESSAGE RECEIVED
      // Title: ${message.notification?.title}
      // Body: ${message.notification?.body}
      // Data: ${message.data}
      
      final notification = message.notification;
      final data = message.data;

      if (notification != null && (data['type'] == 'assignment_marks' || data['type'] == 'midsem_marks')) {
        // Only handle assignment marks and midsem marks notifications
        const String channelKey = 'edunest_marks';

        final androidDetails = AndroidNotificationDetails(
          channelKey,
          'Grade Notifications',
          channelDescription: 'Notifications for assignment and mid-semester marks',
          importance: Importance.max,
          priority: Priority.high,
          enableVibration: true,
          playSound: true,
          // Enhanced customizations for grade notifications
          color: const Color(0xFF2563eb), // Blue to match EduNest theme
          ledColor: const Color(0xFF2563eb),
          ledOnMs: 1000,
          ledOffMs: 500,
          enableLights: true,
          icon: '@drawable/ic_notification',
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
          styleInformation: BigTextStyleInformation(
            notification.body ?? '',
            htmlFormatBigText: true,
            contentTitle: notification.title ?? 'EduNest',
            htmlFormatContentTitle: true,
          ),
          // Double vibration pattern for grade notifications
          vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
          ticker: 'EduNest Grade Notification',
          autoCancel: true,
        );
        
        const iosDetails = DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );
        
        final notificationDetails = NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        );
        
        await _localNotifications!.show(
          DateTime.now().millisecondsSinceEpoch.remainder(100000),
          notification.title ?? 'EduNest',
          notification.body ?? '',
          notificationDetails,
          payload: data.isNotEmpty ? data.toString() : null,
        );
        
        // Local notification shown successfully
        // Title: ${notification.title}
        // Body: ${notification.body}
      }
    } catch (e) {
      // Error handling foreground message: $e
    }
  }

  /// Handle message tap navigation
  void _handleMessageTap(RemoteMessage message) {
    final data = message.data;
    // Handling message tap with data: $data
    
    // Only handle assignment marks and midsem marks navigation
    if (data['type'] == 'assignment_marks' || data['type'] == 'midsem_marks') {
      // Navigate to marks/grades screen
      // You can implement navigation logic here
      // Navigating to grades screen for: ${data['type']}
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    // Notification tapped: ${response.payload}
    
    if (response.payload != null) {
      // Parse payload and handle navigation
      // You can implement navigation logic here based on payload
    }
  }

  /// Schedule a local notification (for grade-related reminders only)
  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledDate,
    Map<String, String?>? payload,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'edunest_marks',
        'Grade Notifications',
        channelDescription: 'Notifications for assignment and mid-semester marks',
        importance: Importance.max,
        priority: Priority.high,
      );
      
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      await _localNotifications!.zonedSchedule(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        notificationDetails,
        payload: payload?.toString(),
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      // Local notification scheduled for: $scheduledDate
    } catch (e) {
      // Error scheduling notification: $e
    }
  }

  /// Cancel all scheduled notifications
  Future<void> cancelAllNotifications() async {
    await _localNotifications?.cancelAll();
  }

  /// Cancel notification by ID
  Future<void> cancelNotification(int id) async {
    await _localNotifications?.cancel(id);
  }

  /// Get current FCM token
  Future<String?> getCurrentToken() async {
    return await _messaging?.getToken();
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      return await _localNotifications!.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.areNotificationsEnabled() ?? false;
    }
    return true; // iOS handles this through system settings
  }

  /// Deactivate current device token (on logout)
  Future<void> deactivateCurrentToken() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final token = await getCurrentToken();
      
      if (user != null && token != null) {
        await Supabase.instance.client
            .from('user_fcm_tokens')
            .update({'is_active': false})
            .eq('user_id', user.id)
            .eq('fcm_token', token);
        
        // FCM token deactivated
      }
    } catch (e) {
      // Error deactivating FCM token: $e
    }
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background message received: ${message.messageId}
  // Handle background messages if needed
}
