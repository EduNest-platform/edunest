import 'package:supabase_flutter/supabase_flutter.dart';
import 'config_service.dart';
import 'secure_storage_service.dart';

class SupabaseService {
  static Future<void> init() async {
    await Supabase.initialize(
      url: ConfigService.supabaseUrl,
      anonKey: ConfigService.supabaseAnonKey,
      debug: false, // Disable debug in production
    );
    // Manual session restoration for hot restart/app restart
    if (Supabase.instance.client.auth.currentUser == null) {
      final refreshToken = await SecureStorageService.getRefreshToken();
      if (refreshToken != null) {
        try {
          await Supabase.instance.client.auth.refreshSession();
        } catch (e) {
          // Optionally handle error
        }
      }
    }
  }

  static SupabaseClient get client => Supabase.instance.client;

  // Helper method to check if user is logged in
  static bool get isLoggedIn => client.auth.currentUser != null;

  // Helper method to get current user
  static User? get currentUser => client.auth.currentUser;

  // Helper method to get current session
  static Session? get currentSession => client.auth.currentSession;

  // Call this after successful login
  static Future<void> saveSessionTokens() async {
    final session = client.auth.currentSession;
    if (session != null) {
      await SecureStorageService.storeAccessToken(session.accessToken);
      await SecureStorageService.storeRefreshToken(session.refreshToken!);
    }
  }

  // Call this on logout
  static Future<void> clearSessionTokens() async {
    await SecureStorageService.clearTokens();
  }
  
  // Add query optimization helper
  static Future<T?> executeWithRetry<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration delay = const Duration(milliseconds: 500),
  }) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        return await operation();
      } catch (e) {
        if (i == maxRetries - 1) rethrow;
        await Future.delayed(delay * (i + 1));
      }
    }
    return null;
  }
}
