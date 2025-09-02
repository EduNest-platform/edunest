import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service.dart';
import '../../services/fcm_service.dart';
import 'package:edunest/services/global_system_monitor.dart';
import 'package:flutter/foundation.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateAfterSplash();
  }

  Future<void> _navigateAfterSplash() async {
    await Future.delayed(const Duration(seconds: 2));

    // Wait a bit more for Supabase to initialize
    await Future.delayed(const Duration(milliseconds: 500));

    final user = SupabaseService.client.auth.currentUser;

    if (!mounted) return;

    if (user == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    // Initialize global system monitoring only if authenticated
    if (user != null) {
      await GlobalSystemMonitor.initialize();
      
      // Refresh FCM token for existing authenticated sessions
      // This ensures FCM token is updated when users install new APK without logging out
      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        try {
          await FCMService().refreshAndStoreToken();
          print('📱 FCM token refreshed for existing session');
        } catch (e) {
          print('⚠️ FCM token refresh failed: $e');
        }
      }
    }

    // Use AuthService.checkAuthStatus() for consistent navigation logic
    final authStatus = await AuthService.checkAuthStatus();

    if (!mounted) return;

    switch (authStatus) {
      case AuthStatus.fullyAuthenticated:
        Navigator.pushReplacementNamed(context, '/academic-path-review');
        break;
      case AuthStatus.needsSetup:
        Navigator.pushReplacementNamed(context, '/profile-setup');
        break;
      case AuthStatus.notLoggedIn:
      case AuthStatus.sessionExpired:
      case AuthStatus.error:
        Navigator.pushReplacementNamed(context, '/login');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primaryBlue, AppTheme.primaryLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.school,
                  size: 80,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(height: 32),
              // App Name
              Text(
                'EduNest',
                style: GoogleFonts.poppins(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your Academic Resource Nest',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 48),
              // Loading indicator
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
