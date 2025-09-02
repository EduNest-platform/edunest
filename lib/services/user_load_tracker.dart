import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Smart user load tracking for conditional service activation
class UserLoadTracker {
  static int _currentUsers = 0;
  static int _activeConnections = 0;
  static DateTime _lastUpdate = DateTime.now();
  static DateTime _lastActivity = DateTime.now();
  static bool _isAppActive = true;
  static _AppLifecycleObserver? _lifecycleObserver;
  static String? _currentSessionId;
  static String? _deviceId;
  static bool _hasIncrementedThisSession = false;
  static bool _isInitialized = false;
  static DateTime? _appStartTime;
  static int _sessionDurationMinutes = 0;

  /// Initialize user load tracking - Called once at app startup
  static Future<void> initialize() async {
    if (_isInitialized) return;

    await _loadPersistedUserCount();
    
    // Generate unique device ID and session ID
    _deviceId = await _getOrCreateDeviceId();
    _appStartTime = DateTime.now();
    _currentSessionId = '${_deviceId}_${_appStartTime!.millisecondsSinceEpoch}';

    // Set up app lifecycle monitoring
    _lifecycleObserver = _AppLifecycleObserver();
    WidgetsBinding.instance.addObserver(_lifecycleObserver!);

    // Start periodic cleanup - Optimized for performance
    Timer.periodic(const Duration(minutes: 10), (timer) {
      if (_isAppActive && _currentUsers > 5) { // Only run when needed
        Future.microtask(() {
          _cleanupInactiveUsers();
          _checkRealActivity();
        });
      }
    });

    _isInitialized = true;

    if (kDebugMode) {
      print('📊 UserLoadTracker: Initialized with ${_currentUsers} persisted users');
      print('📊 Device ID: $_deviceId, Session: $_currentSessionId');
    }
  }

  /// Load user count from persistent storage with realistic decay
  static Future<void> _loadPersistedUserCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final persistedCount = prefs.getInt('user_load_count') ?? 0;
      final lastUpdate = prefs.getString('user_load_last_update');
      final lastDeviceId = prefs.getString('last_device_id');
      
      // Reset count if different device (prevents cross-device inflation)
      if (lastDeviceId != null && lastDeviceId != _deviceId) {
        _currentUsers = 1; // Fresh start on new device
        await prefs.setString('last_device_id', _deviceId ?? '');
        _lastUpdate = DateTime.now();
        await _persistUserCount();
        return;
      }

      if (lastUpdate != null) {
        final lastUpdateTime = DateTime.parse(lastUpdate);
        final timeDiff = DateTime.now().difference(lastUpdateTime);

        // Realistic mobile app user retention patterns
        if (timeDiff.inHours > 24) {
          _currentUsers = 1; // After 24 hours, assume fresh start
        } else if (timeDiff.inHours > 6) {
          _currentUsers = (persistedCount * 0.05).round().clamp(1, persistedCount); // 5% retention after 6+ hours
        } else if (timeDiff.inHours > 2) {
          _currentUsers = (persistedCount * 0.15).round().clamp(1, persistedCount); // 15% retention after 2+ hours
        } else if (timeDiff.inMinutes > 30) {
          _currentUsers = (persistedCount * 0.4).round().clamp(1, persistedCount); // 40% retention after 30+ min
        } else if (timeDiff.inMinutes > 10) {
          _currentUsers = (persistedCount * 0.7).round().clamp(1, persistedCount); // 70% retention after 10+ min
        } else {
          _currentUsers = persistedCount; // Recent activity, keep count
        }
      } else {
        _currentUsers = 1; // Default to 1 user (current user)
      }

      _lastUpdate = DateTime.now();
      await _persistUserCount();
      await prefs.setString('last_device_id', _deviceId ?? '');
    } catch (e) {
      if (kDebugMode) {
        print('📊 UserLoadTracker: Error loading persisted count: $e');
      }
      _currentUsers = 1; // Safe fallback
    }
  }

  /// Persist user count to storage
  static Future<void> _persistUserCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('user_load_count', _currentUsers);
      await prefs.setString('user_load_last_update', DateTime.now().toIso8601String());
    } catch (e) {
      if (kDebugMode) {
        print('📊 UserLoadTracker: Error persisting count: $e');
      }
    }
  }

  /// Update current user count (for manual tracking) - With validation
  static Future<void> updateUserCount(int users) async {
    // Validate user count is realistic
    final validatedUsers = users.clamp(0, 200); // Cap at 200 max users

    if (validatedUsers != users && kDebugMode) {
      print('📊 UserLoadTracker: User count clamped from $users to $validatedUsers');
    }

    _currentUsers = validatedUsers;
    _lastUpdate = DateTime.now();
    await _persistUserCount();

    if (kDebugMode) {
      print('📊 UserLoadTracker: Updated to $validatedUsers users');
    }
  }

  /// Increment active user - Only once per app session (async but non-blocking)
  static void incrementActiveUser() {
    // Prevent multiple increments in the same session
    if (_hasIncrementedThisSession) {
      return; // Silent return for performance
    }
    
    // Run increment logic asynchronously to not block app startup
    _incrementActiveUserAsync();
  }
  
  /// Internal async increment logic with realistic validation
  static Future<void> _incrementActiveUserAsync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastIncrementTime = prefs.getString('last_user_increment');
      final lastSessionId = prefs.getString('last_session_id');
      final lastIncrementDevice = prefs.getString('last_increment_device');
      
      // Prevent same session increment
      if (lastSessionId == _currentSessionId) {
        return;
      }
      
      // Prevent same device rapid increments
      if (lastIncrementDevice == _deviceId && lastIncrementTime != null) {
        final lastIncrement = DateTime.parse(lastIncrementTime);
        final timeDiff = DateTime.now().difference(lastIncrement);
        
        // Realistic minimum time between increments from same device
        if (timeDiff.inMinutes < 5) {
          return;
        }
      }
      
      // Realistic user caps based on app type (educational app)
      final maxUsers = _getRealisticMaxUsers();
      if (_currentUsers >= maxUsers) {
        return;
      }
      
      // Calculate session duration for realistic increment
      _sessionDurationMinutes = _appStartTime != null 
          ? DateTime.now().difference(_appStartTime!).inMinutes 
          : 0;
      
      // Only increment if user has been active for reasonable time
      if (_sessionDurationMinutes < 1) {
        return; // Too quick, likely not a real user session
      }
      
      _currentUsers++;
      _lastUpdate = DateTime.now();
      _hasIncrementedThisSession = true;
      
      await _persistUserCount();
      await prefs.setString('last_user_increment', DateTime.now().toIso8601String());
      await prefs.setString('last_session_id', _currentSessionId ?? '');
      await prefs.setString('last_increment_device', _deviceId ?? '');
      await prefs.setInt('session_duration_minutes', _sessionDurationMinutes);
      
      if (kDebugMode) {
        print('📊 UserLoadTracker: User joined (${_currentUsers} active) - Device: $_deviceId, Duration: ${_sessionDurationMinutes}min');
      }
    } catch (e) {
      if (kDebugMode) {
        print('📊 UserLoadTracker: Error in increment: $e');
      }
    }
  }

  /// Decrement active user (async but non-blocking)
  static void decrementActiveUser() {
    if (_currentUsers > 0) {
      _currentUsers--;
      _lastUpdate = DateTime.now();
      // Run persistence asynchronously to not block app shutdown
      _persistUserCount().catchError((e) {
        // Silent error handling
        if (kDebugMode) {
          print('📊 UserLoadTracker: Error persisting decrement: $e');
        }
      });
    }
  }

  /// Track database connection
  static void trackConnection() {
    _activeConnections++;
  }

  /// Release database connection
  static void releaseConnection() {
    if (_activeConnections > 0) {
      _activeConnections--;
    }
  }

  /// Get current user count
  static int get currentUsers => _currentUsers;

  /// Get active connections
  static int get activeConnections => _activeConnections;

  /// Production-ready load thresholds - Only count ACTIVE users for performance decisions
  static bool get isLowLoadMode {
    final activeUsers = _getActiveUserCount();
    return activeUsers < 35;
  }

  /// Medium load: Balanced performance and optimization
  static bool get isMediumLoadMode {
    final activeUsers = _getActiveUserCount();
    return activeUsers >= 35 && activeUsers < 55;
  }

  /// High load: Maximum optimization and resource management
  static bool get isHighLoadMode {
    final activeUsers = _getActiveUserCount();
    return activeUsers >= 55;
  }
  
  /// Get count of truly active users (not background/paused apps)
  static int _getActiveUserCount() {
    if (!_isAppActive) {
      // If current app is not active, don't contribute to system load
      return (_currentUsers * 0.1).round(); // Minimal impact from background apps
    }
    
    // For active apps, use realistic active user estimation
    final timeSinceActivity = DateTime.now().difference(_lastActivity).inMinutes;
    if (timeSinceActivity > 5) {
      // Reduce impact if no recent activity
      return (_currentUsers * 0.6).round();
    }
    
    return _currentUsers;
  }

  /// Get load level as string
  static String get loadLevel {
    if (isLowLoadMode) return 'LOW';
    if (isMediumLoadMode) return 'MEDIUM';
    return 'HIGH';
  }

  /// Get load statistics (cached for performance)
  static Map<String, dynamic>? _cachedStats;
  static DateTime? _lastStatsUpdate;
  
  static Map<String, dynamic> getStats() {
    final now = DateTime.now();
    
    // Cache stats for 30 seconds to reduce computation
    if (_cachedStats == null || _lastStatsUpdate == null || 
        now.difference(_lastStatsUpdate!).inSeconds > 30) {
      _cachedStats = {
        'current_users': _currentUsers,
        'active_connections': _activeConnections,
        'load_level': loadLevel,
        'last_update': _lastUpdate.toIso8601String(),
        'is_low_load': isLowLoadMode,
        'is_medium_load': isMediumLoadMode,
        'is_high_load': isHighLoadMode,
        'is_app_active': _isAppActive,
        'max_supported_users': 150, // Production limit
        'performance_optimized': true,
      };
      _lastStatsUpdate = now;
    }
    
    return Map<String, dynamic>.from(_cachedStats!);
  }

  /// Cleanup inactive users with realistic educational app patterns
  static void _cleanupInactiveUsers() {
    final timeSinceLastUpdate = DateTime.now().difference(_lastUpdate).inMinutes;
    
    if (timeSinceLastUpdate > 3) { // Start cleanup after 3 minutes
      if (_currentUsers > 1) {
        // Educational app specific retention patterns
        double reductionFactor;
        if (timeSinceLastUpdate > 60) { // 1 hour
          reductionFactor = 0.02; // Keep only 2% after 1+ hour
        } else if (timeSinceLastUpdate > 30) { // 30 minutes
          reductionFactor = 0.08; // Keep only 8% after 30+ min
        } else if (timeSinceLastUpdate > 15) { // 15 minutes
          reductionFactor = 0.2; // Keep only 20% after 15+ min
        } else if (timeSinceLastUpdate > 10) { // 10 minutes
          reductionFactor = 0.35; // Keep only 35% after 10+ min
        } else if (timeSinceLastUpdate > 5) { // 5 minutes
          reductionFactor = 0.6; // Keep only 60% after 5+ min
        } else {
          reductionFactor = 0.8; // Keep only 80% after 3+ min
        }
        
        final oldCount = _currentUsers;
        _currentUsers = (_currentUsers * reductionFactor).round();
        
        // Always keep at least 1 user if app is still active
        if (_currentUsers < 1 && _isAppActive) {
          _currentUsers = 1;
        }
        
        // Educational apps typically have lower concurrent users
        if (_currentUsers > 75 && timeSinceLastUpdate > 10) {
          _currentUsers = (_currentUsers * 0.4).round(); // Aggressive reduction for unrealistic numbers
        }
        
        if (kDebugMode && oldCount != _currentUsers) {
          print('📊 UserLoadTracker: Cleaned up inactive users after ${timeSinceLastUpdate}min (${oldCount} → ${_currentUsers})');
        }
      }
    }
  }

  /// Record user activity (call this on any user interaction)
  static void recordActivity() {
    _lastActivity = DateTime.now();
  }

  /// Check real activity patterns for educational apps
  static void _checkRealActivity() {
    final timeSinceActivity = DateTime.now().difference(_lastActivity).inMinutes;
    
    // Educational app activity patterns
    if (timeSinceActivity > 8 && _currentUsers > 1) {
      // Students typically have focused study sessions
      double activityReduction;
      if (timeSinceActivity > 25) { // Long inactivity
        activityReduction = 0.1; // Keep only 10%
      } else if (timeSinceActivity > 15) { // Medium inactivity
        activityReduction = 0.3; // Keep only 30%
      } else {
        activityReduction = 0.6; // Keep only 60%
      }
      
      final oldCount = _currentUsers;
      _currentUsers = (_currentUsers * activityReduction).round().clamp(1, _currentUsers);
      
      if (kDebugMode && oldCount != _currentUsers) {
        print('📊 UserLoadTracker: No activity for ${timeSinceActivity}min, reduced from $oldCount to $_currentUsers users');
      }
    }
    
    // Reset unrealistic numbers for educational context
    if (_currentUsers > _getRealisticMaxUsers() && timeSinceActivity > 5) {
      _currentUsers = (_getRealisticMaxUsers() * 0.6).round().clamp(1, _getRealisticMaxUsers());
      if (kDebugMode) {
        print('📊 UserLoadTracker: Reset unrealistic user count to $_currentUsers');
      }
    }
  }

  /// Handle app lifecycle changes - Only count truly active users
  static void _handleAppLifecycleChange(AppLifecycleState state) {
    final wasActive = _isAppActive;

    switch (state) {
      case AppLifecycleState.resumed:
        _isAppActive = true;
        recordActivity();
        // Only increment if this is a fresh app resume (not just switching back)
        if (!wasActive && !_hasIncrementedThisSession) {
          incrementActiveUser(); // Non-blocking call
        }
        if (kDebugMode) {
          print('📊 UserLoadTracker: App resumed (wasActive: $wasActive)');
        }
        break;
      case AppLifecycleState.paused:
        _isAppActive = false;
        // Immediately reduce load calculation impact for backgrounded apps
        if (kDebugMode) {
          print('📊 UserLoadTracker: App paused - reducing load impact');
        }
        break;
      case AppLifecycleState.inactive:
        _isAppActive = false;
        if (kDebugMode) {
          print('📊 UserLoadTracker: App inactive');
        }
        break;
      case AppLifecycleState.detached:
        _isAppActive = false;
        // App is closing - decrement user count
        if (_hasIncrementedThisSession && _currentUsers > 0) {
          decrementActiveUser(); // Non-blocking call
          _hasIncrementedThisSession = false;
        }
        if (kDebugMode) {
          print('📊 UserLoadTracker: App detached/closing');
        }
        break;
      case AppLifecycleState.hidden:
        _isAppActive = false;
        if (kDebugMode) {
          print('📊 UserLoadTracker: App hidden');
        }
        break;
    }
  }

  /// Mark user as inactive when app closes (non-blocking)
  static void markUserInactive() {
    _isAppActive = false;
    _currentUsers = 0;
    _activeConnections = 0;
    // Run persistence asynchronously to not block app shutdown
    _persistUserCount().catchError((e) {
      // Silent error handling
      if (kDebugMode) {
        print('📊 UserLoadTracker: Error persisting inactive state: $e');
      }
    });
  }

  /// Get app active status
  static bool get isAppActive => _isAppActive;

  /// Dispose resources - Called when app is closing
  static void dispose() {
    if (_lifecycleObserver != null) {
      WidgetsBinding.instance.removeObserver(_lifecycleObserver!);
      _lifecycleObserver = null;
    }

    // Decrement user count if we incremented this session
    if (_hasIncrementedThisSession && _currentUsers > 0) {
      decrementActiveUser(); // Non-blocking call
      _hasIncrementedThisSession = false;
    }

    // Mark user as inactive when disposing
    markUserInactive(); // Non-blocking call

    _isInitialized = false;

    if (kDebugMode) {
      print('📊 UserLoadTracker: Disposed - Session: $_currentSessionId');
    }
  }
  
  /// Generate or retrieve unique device ID
  static Future<String> _getOrCreateDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString('unique_device_id');
      
      if (deviceId == null) {
        final deviceInfo = DeviceInfoPlugin();
        String identifier = '';
        
        if (Platform.isAndroid) {
          final androidInfo = await deviceInfo.androidInfo;
          identifier = '${androidInfo.model}_${androidInfo.id}_${androidInfo.fingerprint}';
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfo.iosInfo;
          identifier = '${iosInfo.model}_${iosInfo.identifierForVendor}_${iosInfo.systemVersion}';
        } else if (Platform.isWindows) {
          final windowsInfo = await deviceInfo.windowsInfo;
          identifier = '${windowsInfo.computerName}_${windowsInfo.userName}_${windowsInfo.systemMemoryInMegabytes}';
        } else if (Platform.isMacOS) {
          final macInfo = await deviceInfo.macOsInfo;
          identifier = '${macInfo.computerName}_${macInfo.hostName}_${macInfo.systemGUID}';
        } else if (Platform.isLinux) {
          final linuxInfo = await deviceInfo.linuxInfo;
          identifier = '${linuxInfo.name}_${linuxInfo.id}_${linuxInfo.machineId}';
        } else {
          identifier = 'unknown_${DateTime.now().millisecondsSinceEpoch}';
        }
        
        // Create hash for privacy and consistency
        final bytes = utf8.encode(identifier);
        final digest = sha256.convert(bytes);
        deviceId = digest.toString().substring(0, 16); // Use first 16 chars
        
        await prefs.setString('unique_device_id', deviceId);
      }
      
      return deviceId;
    } catch (e) {
      // Fallback to timestamp-based ID
      final fallbackId = 'fallback_${DateTime.now().millisecondsSinceEpoch}';
      if (kDebugMode) {
        print('📊 UserLoadTracker: Error generating device ID, using fallback: $e');
      }
      return fallbackId;
    }
  }
  
  /// Get realistic maximum users for educational app context
  static int _getRealisticMaxUsers() {
    final hour = DateTime.now().hour;
    
    // Educational apps have peak usage during study hours
    if (hour >= 9 && hour <= 11) { // Morning study peak
      return 80;
    } else if (hour >= 14 && hour <= 17) { // Afternoon study peak
      return 100;
    } else if (hour >= 19 && hour <= 22) { // Evening study peak
      return 120;
    } else if (hour >= 6 && hour <= 23) { // Regular study hours
      return 60;
    } else { // Late night/early morning
      return 25;
    }
  }
}

/// App lifecycle observer for UserLoadTracker
class _AppLifecycleObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    UserLoadTracker._handleAppLifecycleChange(state);
  }
}