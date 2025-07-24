import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_profile_service.dart';
import 'session_tracking_service.dart';
import 'dart:developer' as developer;

class SupabaseAuthService {
  static final _auth = Supabase.instance.client.auth;

  /// Sign in with email and password
  static Future<AuthResponse> signInWithEmail(
    String email,
    String password,
  ) async {
    try {
      final response = await _auth.signInWithPassword(
        email: email,
        password: password,
      );
      await SessionTrackingService.recordLoginSession();
      await SessionTrackingService.recordLoginHistory(true);
      return response;
    } catch (e) {
      await SessionTrackingService.recordLoginHistory(
        false,
        failureReason: e.toString(),
      );
      rethrow;
    }
  }

  /// Sign out from Supabase
  static Future<void> signOut() async {
    try {
      await _auth.signOut();
      await SessionTrackingService.clearAllSessionData();
      developer.log('Signed out from Supabase', name: 'SupabaseAuthService');
    } catch (e) {
      developer.log('Error during sign out: $e', name: 'SupabaseAuthService');
      rethrow;
    }
  }

  /// Check if user is logged in
  static bool get isLoggedIn => _auth.currentUser != null;

  /// Get current user
  static User? get currentUser => _auth.currentUser;

  /// Check auth status
  static Future<AuthStatus> checkAuthStatus() async {
    try {
      final user = currentUser;
      if (user == null) return AuthStatus.notLoggedIn;
      final session = _auth.currentSession;
      if (session == null) return AuthStatus.notLoggedIn;
      if (session.expiresAt != null) {
        final expiresAt = DateTime.fromMillisecondsSinceEpoch(
          session.expiresAt!,
        );
        if (DateTime.now().isAfter(expiresAt)) return AuthStatus.sessionExpired;
      }
      final profile = await UserProfileService.getCurrentUserProfile();
      if (profile?.college != null &&
          profile?.branch != null &&
          profile?.semester != null) {
        return AuthStatus.fullyAuthenticated;
      } else {
        return AuthStatus.needsSetup;
      }
    } catch (e) {
      return AuthStatus.error;
    }
  }
}

enum AuthStatus {
  notLoggedIn,
  sessionExpired,
  needsSetup,
  fullyAuthenticated,
  error,
}
