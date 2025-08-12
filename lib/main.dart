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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Import for kReleaseMode and platform checks
import 'package:flutter/foundation.dart' show kReleaseMode, defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'dart:io' show Platform;

import 'package:window_manager/window_manager.dart';
import 'dart:async';

// Import Device Preview
import 'package:device_preview/device_preview.dart';


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

      // Only initialize window_manager on desktop platforms
      if (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        await windowManager.ensureInitialized();
      }

      // Initialize Firebase first!
      // Enable Crashlytics and set up error handling only on supported platforms
      final isCrashlyticsSupported =
          kIsWeb || (Platform.isAndroid || Platform.isIOS);
      print(
        'Crashlytics supported: '
            ' [33m$isCrashlyticsSupported [0m (kIsWeb: $kIsWeb, Platform: ${Platform.operatingSystem})',
      );
      // if (isCrashlyticsSupported) {
      //   await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      //     true,
      //   );
      //   FlutterError.onError =
      //       FirebaseCrashlytics.instance.recordFlutterFatalError;
      // }

      // // Initialize Firebase Performance
      // await FirebasePerformance.instance;

      // Now initialize other services
      await SupabaseService.init();
      NetworkService().initialize();

      // Wrap your app with DevicePreview
      runApp(
        DevicePreview(
          enabled: !kReleaseMode, // Disable in release builds
          builder: (context) => const MyApp(), // Wrap your app
        ),
      );
    },
        (error, stack) {
      final isCrashlyticsSupported =
          kIsWeb || (Platform.isAndroid || Platform.isIOS);
      // if (isCrashlyticsSupported) {
      //   FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      // } else {
      // Optionally print or handle errors differently on unsupported platforms
      print('Unhandled error: $error\n$stack');
      // }
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // --- Add these 3 lines for Device Preview ---
      useInheritedMediaQuery: true,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      // --------------------------------------------

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
        '/academic-info': (context) => const AcademicInfoScreen(subjectId: ''),
      },
    );
  }
}
