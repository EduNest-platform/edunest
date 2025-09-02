import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/user_profile_service.dart';
import '../services/fcm_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import 'dart:async';
import 'dart:io';

class LoginController extends ChangeNotifier {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _userNotFound = false;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get userNotFound => _userNotFound;

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  void setUserNotFound(bool value) {
    _userNotFound = value;
    notifyListeners();
  }

  Future<LoginResult> loginWithEmail() async {
    setLoading(true);
    setError(null);
    setUserNotFound(false);
    try {
      final response = await AuthService.signInWithEmail(
        emailController.text.trim(),
        passwordController.text.trim(),
      );
      if (response.user != null) {
        // Save session tokens for persistence
        await SupabaseService.saveSessionTokens();
        
        // Store FCM token now that user is authenticated
        await FCMService().storePendingToken();
        
        // Fetch user profile
        final profile = await UserProfileService.getCurrentUserProfile();
        final needsProfileSetup = profile == null || !profile.isComplete();
        final hasCompletedAcademicPath =
            profile?.college != null &&
            profile?.branch != null &&
            profile?.semester != null;

        setLoading(false);
        return LoginResult(
          success: true,
          needsProfileSetup: needsProfileSetup,
          hasCompletedAcademicPath: hasCompletedAcademicPath,
        );
      } else {
        setLoading(false);
        return LoginResult(
          success: false,
          needsProfileSetup: false,
          hasCompletedAcademicPath: false,
        );
      }
    } on AuthException catch (e) {
      setLoading(false);
      setError(e.message);
      return LoginResult(
        success: false,
        needsProfileSetup: false,
        hasCompletedAcademicPath: false,
      );
    } on SocketException catch (_) {
      setLoading(false);
      setError(
        'No internet connection. Please check your network and try again.',
      );
      return LoginResult(
        success: false,
        needsProfileSetup: false,
        hasCompletedAcademicPath: false,
      );
    } on TimeoutException catch (_) {
      setLoading(false);
      setError(
        'No internet connection. Please check your network and try again.',
      );
      return LoginResult(
        success: false,
        needsProfileSetup: false,
        hasCompletedAcademicPath: false,
      );
    } catch (e) {
      setLoading(false);
      String errorMsg = 'An unexpected error occurred. Please try again.';
      final errorStr = e.toString();
      if (errorStr.contains('ClientException') ||
          errorStr.contains('SocketException') ||
          errorStr.contains('TimeoutException')) {
        errorMsg =
            'No internet connection. Please check your network and try again.';
      }
      setError(errorMsg);
      return LoginResult(
        success: false,
        needsProfileSetup: false,
        hasCompletedAcademicPath: false,
      );
    }
  }

  void disposeControllers() {
    emailController.dispose();
    passwordController.dispose();
  }
}

class LoginResult {
  final bool success;
  final bool needsProfileSetup;
  final bool hasCompletedAcademicPath;
  final String? accessToken;

  LoginResult({
    required this.success,
    required this.needsProfileSetup,
    required this.hasCompletedAcademicPath,
    this.accessToken,
  });
}
