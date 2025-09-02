import 'package:flutter/material.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/profile_setup_screen.dart';
import 'screens/auth/academic_path_review_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/home/Subject Screen/subject_view_screen.dart';
import 'screens/home/attendance/attendance_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/search/search_screen.dart';
import 'screens/practice_tests/practice_tests_screen.dart';
import 'screens/practice_tests/test_results_list_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/security/security_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/help/help_support_screen.dart';
import 'screens/about/about_screen.dart';
import 'screens/home/academic_info_screen.dart';
import 'services/supabase_service.dart';
import 'services/network_service.dart';
import 'services/free_plan_optimizer_service.dart';
import 'services/user_load_tracker.dart';
import 'services/fcm_service.dart';
import 'services/ad_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart'
    show kReleaseMode, kDebugMode, defaultTargetPlatform, TargetPlatform;
import 'package:window_manager/window_manager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';
// ignore: depend_on_referenced_packages
import 'package:device_preview/device_preview.dart';
import 'package:app_links/app_links.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> clearAllAppData() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  const secureStorage = FlutterSecureStorage();
  await secureStorage.deleteAll();
}

void main() {
  runZonedGuarded(
        () async {
      WidgetsFlutterBinding.ensureInitialized();

      if (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        await windowManager.ensureInitialized();
      }

      // Initialize Firebase only for mobile platforms (not Windows/Desktop)
      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        await Firebase.initializeApp();
        
        // Set up background message handler
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      }

      await SupabaseService.init();
      NetworkService().initialize();
      
      // Initialize FCM Service only for mobile platforms
      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        FCMService().initialize().catchError((e) {
          if (kDebugMode) {
            print('FCM Service init error: $e');
          }
        });
      }
      
      // 🚀 Initialize user tracking first (must be before other services)
      // Non-blocking initialization to not delay app startup
      UserLoadTracker.initialize().catchError((e) {
        // Silent error handling - app should still work without tracking
        if (kDebugMode) {
          print('UserLoadTracker init error: $e');
        }
      });
      
      
      
      // 🚀 Initialize monitoring and optimization services
      try {
        await FreePlanOptimizerService.initialize();
      } catch (e) {
        // Continue without optimizer - app should still work
      }
      
      // 🎯 Initialize Unity Ads (non-blocking)
      AdService.initialize().catchError((e) {
        if (kDebugMode) {
          print('AdService init error: $e');
        }
      });

      runApp(
        DevicePreview(
          enabled: !kReleaseMode,
          builder: (context) => const MyApp(),
        ),
      );
    },
        (error, stack) {
      // Handle silently in production
    },
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _handleInitialLink();
    _handleIncomingLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleInitialLink() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _processLink(initialUri);
      }
    } catch (e) {
      // Handle silently in production
    }
  }

  void _handleIncomingLinks() {
    _linkSubscription = _appLinks.uriLinkStream.listen((Uri uri) {
      _processLink(uri);
    }, onError: (err) {
      // Handle silently in production
    });
  }

  void _processLink(Uri uri) {
    if (uri.host == 'login-callback') {
      navigatorKey.currentState
          ?.pushNamedAndRemoveUntil('/login-callback', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      useInheritedMediaQuery: true,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      navigatorKey: navigatorKey,
      title: 'EduNest',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login-callback': (context) => const LoginScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/profile-setup': (context) => const ProfileSetupScreen(),
        '/academic-path-review': (context) => const AcademicPathReviewScreen(),
        '/home': (context) => const HomeScreen(),
        '/subjects': (context) => const SubjectViewScreen(),
        '/attendance': (context) => const AttendanceScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/search': (context) => const SearchWidget(),
        '/practice-tests': (context) => const PracticeTestsScreen(),
        '/test-results': (context) => const TestResultsListScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/security': (context) => const SecurityScreen(),
        '/notifications': (context) => const NotificationsScreen(),
        '/help-support': (context) => const HelpSupportScreen(),
        '/about': (context) => const AboutScreen(),
        '/academic-info': (context) => const AcademicInfoScreen(),
      },
    );
  }
}