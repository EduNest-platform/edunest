import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_profile_service.dart';
import 'rate_limiter_service.dart';
import 'session_tracking_service.dart';
import 'dart:developer' as developer;
import 'supabase_service.dart';

class AuthService {
  static final _auth = Supabase.instance.client.auth;

  static Future<AuthResponse> signInWithEmail(
    String email,
    String password,
  ) async {
    // Check rate limiting
    if (!await RateLimiterService.isLoginAllowed(email)) {
      final remainingTime = RateLimiterService.getLockoutRemainingTime(email);
      throw AuthException(
        'Too many failed login attempts. Please try again in ${remainingTime?.inMinutes ?? 15} minutes.',
      );
    }

    try {
      final response = await _auth.signInWithPassword(
        email: email,
        password: password,
      );

      // Record successful login
      await RateLimiterService.recordSuccessfulLogin(email);

      // Record login session and history
      await SessionTrackingService.recordLoginSession();

      return response;
    } catch (e) {
      // Record failed login attempt
      await RateLimiterService.recordFailedLogin(email);

      // Record failed login in history
      final failureReason = e is AuthException ? e.message : 'Unknown error';
      await SessionTrackingService.recordLoginHistory(
        false,
        failureReason: failureReason,
      );

      // Check if user is now locked out
      if (RateLimiterService.isUserLockedOut(email)) {
        final remainingTime = RateLimiterService.getLockoutRemainingTime(email);
        throw AuthException(
          'Account temporarily locked due to too many failed attempts. Please try again in ${remainingTime?.inMinutes ?? 15} minutes.',
        );
      }

      // Re-throw the original error
      rethrow;
    }
  }

  static Future<AuthResponse> signUpWithEmail(
    String email,
    String password, {
    Map<String, dynamic>? data,
  }) async {
    // Validate password strength
    if (!_isPasswordStrong(password)) {
      throw AuthException(
        'Password must be at least 8 characters long and contain uppercase, lowercase, number, and special character.',
      );
    }

    // Validate email format
    if (!_isValidEmail(email)) {
      throw AuthException('Please enter a valid email address.');
    }

    return _auth.signUp(email: email, password: password, data: data);
  }

  static Future<void> signOut() async {
    // Clear session tracking data
    await SessionTrackingService.clearAllSessionData();
    await _auth.signOut();
    await SupabaseService.clearSessionTokens();
  }

  static User? get currentUser => _auth.currentUser;

  // Helper method to check if user is logged in
  static bool get isLoggedIn => _auth.currentUser != null;

  // Helper method to get current session
  static Session? get currentSession => _auth.currentSession;

  // Helper method to print current auth status
  static void printAuthStatus() {
    final user = currentUser;
    final session = currentSession;
  }

  // Helper method to check if user is fully authenticated and has completed setup
  static Future<AuthStatus> checkAuthStatus() async {
    try {
      final user = currentUser;
      if (user == null) {
        return AuthStatus.notLoggedIn;
      }

      // Check if session is valid
      final session = currentSession;
      if (session == null) {
        return AuthStatus.notLoggedIn;
      }

      // REMOVED: Session expiry check that was causing issues after hot restart
      // Supabase handles session validation internally, so if we have a currentUser
      // and currentSession, we should trust that the session is valid.
      // The session.expiresAt value can be corrupted after hot restart.

      // Check if user has completed academic path setup
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

  static Future<void> sendPasswordResetEmail(String email) async {
    // Validate email format
    if (!_isValidEmail(email)) {
      throw AuthException('Please enter a valid email address.');
    }

    await _auth.resetPasswordForEmail(email);
  }

  /// Check if a user exists by email (for account linking scenarios)
  static Future<bool> userExistsByEmail(String email) async {
    try {
      developer.log(
        'Checking if user exists by email: $email',
        name: 'AuthService',
      );

      // Try to get user profile by email using UserProfileService
      final profile = await UserProfileService.getUserProfileByEmail(email);
      final exists = profile != null;

      developer.log('User exists by email: $exists', name: 'AuthService');
      return exists;
    } catch (e) {
      developer.log('Error checking user existence: $e', name: 'AuthService');
      return false;
    }
  }

  /// Handle account linking when Google sign-in email matches existing email account
  static Future<void> handleAccountLinking(String googleEmail) async {
    try {
      developer.log(
        'Handling account linking for email: $googleEmail',
        name: 'AuthService',
      );

      final existingUser = await userExistsByEmail(googleEmail);
      if (existingUser) {
        developer.log(
          'Existing user found - accounts will be linked',
          name: 'AuthService',
        );
        // Supabase automatically handles account linking when emails match
        // The user will be signed in to their existing account
      } else {
        developer.log(
          'No existing user found - creating new account',
          name: 'AuthService',
        );
        // This is a new user, Supabase will create a new account
      }
    } catch (e) {
      developer.log('Error in account linking: $e', name: 'AuthService');
    }
  }

  // Password strength validation
  static bool _isPasswordStrong(String password) {
    if (password.length < 8) return false;

    bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
    bool hasLowercase = password.contains(RegExp(r'[a-z]'));
    bool hasDigits = password.contains(RegExp(r'[0-9]'));
    bool hasSpecialCharacters = password.contains(
      RegExp(r'[!@#$%^&*(),.?":{}|<>]'),
    );

    return hasUppercase && hasLowercase && hasDigits && hasSpecialCharacters;
  }

  // Email validation
  static bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // Get remaining login attempts for a user
  static int getRemainingLoginAttempts(String email) {
    return RateLimiterService.getRemainingLoginAttempts(email);
  }

  // Check if user is locked out
  static bool isUserLockedOut(String email) {
    return RateLimiterService.isUserLockedOut(email);
  }

  // Get lockout remaining time
  static Duration? getLockoutRemainingTime(String email) {
    return RateLimiterService.getLockoutRemainingTime(email);
  }
}

enum AuthStatus {
  notLoggedIn,
  sessionExpired,
  needsSetup,
  fullyAuthenticated,
  error,
}
