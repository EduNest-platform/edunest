import 'dart:async';

class RateLimiterService {
  static final Map<String, List<DateTime>> _apiCallHistory = {};
  static final Map<String, int> _loginAttempts = {};
  static final Map<String, DateTime> _lockoutTimes = {};

  /// Check if API call is allowed (rate limiting)
  static Future<bool> isApiCallAllowed(
    String endpoint, {
    int maxCalls = 60,
    Duration window = const Duration(minutes: 1),
  }) async {
    final now = DateTime.now();
    final key = 'api_$endpoint';

    // Initialize history if not exists
    if (!_apiCallHistory.containsKey(key)) {
      _apiCallHistory[key] = [];
    }

    // Remove old entries outside the window
    _apiCallHistory[key]!.removeWhere((time) => now.difference(time) > window);

    // Check if limit exceeded
    if (_apiCallHistory[key]!.length >= maxCalls) {
      return false;
    }

    // Add current call
    _apiCallHistory[key]!.add(now);
    return true;
  }

  /// Check if login attempt is allowed
  static Future<bool> isLoginAllowed(String email) async {
    final now = DateTime.now();
    final key = 'login_$email';

    // Check if user is locked out
    if (_lockoutTimes.containsKey(key)) {
      final lockoutTime = _lockoutTimes[key]!;
      if (now.isBefore(lockoutTime)) {
        return false;
      } else {
        // Lockout expired, reset
        _lockoutTimes.remove(key);
        _loginAttempts.remove(key);
      }
    }

    return true;
  }

  /// Record a failed login attempt
  static Future<void> recordFailedLogin(String email) async {
    final key = 'login_$email';
    _loginAttempts[key] = (_loginAttempts[key] ?? 0) + 1;

    // Lock out after 5 failed attempts
    if (_loginAttempts[key]! >= 5) {
      _lockoutTimes[key] = DateTime.now().add(const Duration(minutes: 15));
    }
  }

  /// Record a successful login (reset attempts)
  static Future<void> recordSuccessfulLogin(String email) async {
    final key = 'login_$email';
    _loginAttempts.remove(key);
    _lockoutTimes.remove(key);
  }

  /// Get remaining login attempts
  static int getRemainingLoginAttempts(String email) {
    final key = 'login_$email';
    final attempts = _loginAttempts[key] ?? 0;
    return 5 - attempts;
  }

  /// Check if user is locked out
  static bool isUserLockedOut(String email) {
    final key = 'login_$email';
    if (!_lockoutTimes.containsKey(key)) return false;

    final now = DateTime.now();
    final lockoutTime = _lockoutTimes[key]!;

    if (now.isBefore(lockoutTime)) {
      return true;
    } else {
      // Lockout expired, clean up
      _lockoutTimes.remove(key);
      _loginAttempts.remove(key);
      return false;
    }
  }

  /// Get lockout remaining time
  static Duration? getLockoutRemainingTime(String email) {
    final key = 'login_$email';
    if (!_lockoutTimes.containsKey(key)) return null;

    final now = DateTime.now();
    final lockoutTime = _lockoutTimes[key]!;

    if (now.isBefore(lockoutTime)) {
      return lockoutTime.difference(now);
    } else {
      // Lockout expired, clean up
      _lockoutTimes.remove(key);
      _loginAttempts.remove(key);
      return null;
    }
  }

  /// Execute a function with rate limiting
  static Future<T> executeWithLimit<T>(
    Future<T> Function() operation, {
    String endpoint = 'default',
    int maxCalls = 60,
    Duration window = const Duration(minutes: 1),
  }) async {
    // Check if API call is allowed
    final isAllowed = await isApiCallAllowed(
      endpoint,
      maxCalls: maxCalls,
      window: window,
    );

    if (!isAllowed) {
      throw Exception('Rate limit exceeded for endpoint: $endpoint');
    }

    // Execute the operation
    return await operation();
  }

  /// Clear all rate limiting data (for testing or admin purposes)
  static void clearAllData() {
    _apiCallHistory.clear();
    _loginAttempts.clear();
    _lockoutTimes.clear();
  }
}
