import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'user_load_tracker.dart';

/// Real global system monitoring using system_monitoring table
class GlobalSystemMonitor {
  // Use secondary Supabase account for system monitoring
  static const String supabaseUrl = 'https://pfuzvpihupvhjshxiofn.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBmdXp2cGlodXB2aGpzaHhpb2ZuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE1Mjg1MjIsImV4cCI6MjA2NzEwNDUyMn0.WAPJG6iaxuCAM75yCRu6UOcck37XuilVoDJK3uwyx-k';
  
  static final supabase = SupabaseClient(supabaseUrl, supabaseAnonKey);
  static Timer? _reportingTimer;
  static String? _deviceId;
  static String? _appVersion;
  static String? _platform;
  static DateTime _lastReport = DateTime.now();
  
  /// Initialize global monitoring
  static Future<void> initialize() async {
    if (_reportingTimer != null) return;
    
    // Get device info
    await _initializeDeviceInfo();
    
    
    // Production: Report every 5 minutes to reduce database load
    _reportingTimer = Timer.periodic(Duration(seconds: 300), (_) {
      // Non-blocking reporting for performance
      Future.microtask(() => _reportSystemStatus());
    });
    
    // Initial report
    await _reportSystemStatus();
    
    if (kDebugMode) {
      print('🌐 GlobalSystemMonitor: Initialized for $_platform $_appVersion');
    }
  }
  
  /// Initialize device and app information
  static Future<void> _initializeDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final packageInfo = await PackageInfo.fromPlatform();
      
      _appVersion = packageInfo.version;
      
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceId = androidInfo.id;
        _platform = 'Android ${androidInfo.version.release}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceId = iosInfo.identifierForVendor ?? 'unknown_ios';
        _platform = 'iOS ${iosInfo.systemVersion}';
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        _deviceId = windowsInfo.deviceId;
        _platform = 'Windows ${windowsInfo.displayVersion}';
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        _deviceId = macInfo.systemGUID;
        _platform = 'macOS ${macInfo.osRelease}';
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        _deviceId = linuxInfo.machineId;
        _platform = 'Linux ${linuxInfo.prettyName}';
      } else {
        _deviceId = 'unknown';
        _platform = 'Unknown';
      }
    } catch (e) {
      _deviceId = 'error';
      _platform = 'Unknown';
      _appVersion = '1.0.0';
    }
  }
  
  /// Report current system status - Production optimized
  static Future<void> _reportSystemStatus() async {
    try {
      // Remove authentication requirement - report regardless of user login status
      
      // Get app active status from UserLoadTracker
      final isAppActive = UserLoadTracker.isAppActive;
      if (!isAppActive) return; // Don't report if app is not active
      
      // Get cached stats for performance
      final stats = UserLoadTracker.getStats();
      final localUserCount = stats['current_users'] as int;
      final loadLevel = stats['load_level'] as String;
      
      // Get current global stats first
      final globalStats = await getGlobalSystemStats();
      
      // Set active connections based on app state (1 if active, 0 if background)
      final totalActiveConnections = isAppActive ? 1 : 0;
      final totalActiveUsers = globalStats['total_active_users'] ?? localUserCount;
      
      // Insert matching exact table schema
      await supabase.from('system_monitoring').insert({
        'active_connections': totalActiveConnections,
        'max_connections': 60,
        'queue_size': 0,
        'system_load': _calculateLocalLoad(),
        'crash_risk': _assessCrashRisk(totalActiveUsers),
        'peak_users': globalStats['peak_users'] ?? totalActiveUsers,
        'cache_hit_rate': 95.0,
        'cache_entries': 100,
        'exam_mode_active': false,
        'active_test_takers': 0,
        'active_exams': 0,
        'circuit_breaker_open': false,
        'app_version': _appVersion,
        'platform': _platform,
        'metadata': {
          'device_id': _deviceId,
          'timestamp': DateTime.now().toIso8601String(),
          'session_duration': DateTime.now().difference(_lastReport).inMinutes,
          'app_state': isAppActive ? 'active' : 'background',
          'local_user_count': localUserCount,
          'total_active_users': totalActiveUsers,
          'load_level': loadLevel,
        }
      });
      
      _lastReport = DateTime.now();
      
      if (kDebugMode) {
        print('🌐 GlobalSystemMonitor: Status reported successfully to system_monitoring table');
      }
    } catch (e) {
      if (kDebugMode) {
        print('🌐 GlobalSystemMonitor: Failed to report status: $e');
      }
    }
  }
  
  /// Get real global system statistics
  static Future<Map<String, dynamic>> getGlobalSystemStats() async {
    try {
      // Get stats from last 10 minutes (since we report every 3-4 minutes)
      final tenMinutesAgo = DateTime.now().subtract(Duration(minutes: 10));
      
      final response = await supabase
          .from('system_monitoring')
          .select()
          .gte('timestamp', tenMinutesAgo.toIso8601String())
          .order('timestamp', ascending: false)
          .limit(200);
      
      if ((response as List).isEmpty) {
        return {
          'active_users': 0,
          'peak_users': 0,
          'system_load': 0.0,
          'crash_risk': 'LOW',
          'is_low_load': true,
          'is_medium_load': false,
          'is_high_load': false,
        };
      }
      
      final records = response as List;
      
      // Count unique ACTIVE users (by device_id in metadata, only if is_active is true)
      final uniqueActiveDevices = <String>{};
      double totalLoad = 0.0;
      int maxPeakUsers = 0;
      
      for (final record in records) {
        final metadata = record['metadata'] as Map<String, dynamic>?;
        final isActive = record['is_active'] as bool? ?? true; // Default to true for backward compatibility
        final activeConnections = record['active_connections'] as int? ?? 0;
        
        // Only count devices that are actually active and have active connections
        if (metadata != null && metadata['device_id'] != null && isActive && activeConnections > 0) {
          uniqueActiveDevices.add(metadata['device_id']);
        }
        
        totalLoad += (record['system_load'] as num?)?.toDouble() ?? 0.0;
        maxPeakUsers = math.max(maxPeakUsers, record['peak_users'] as int? ?? 0);
      }
      
      final activeUsers = uniqueActiveDevices.length;
      final avgLoad = records.isNotEmpty ? totalLoad / records.length : 0.0;
      
      // Determine load levels based on real user count
      final isLowLoad = activeUsers < 20;
      final isMediumLoad = activeUsers >= 20 && activeUsers < 50;
      final isHighLoad = activeUsers >= 50;
      
      String crashRisk = 'LOW';
      if (activeUsers > 80) {
        crashRisk = 'HIGH';
      } else if (activeUsers > 50) {
        crashRisk = 'MEDIUM';
      }
      
      return {
        'active_users': activeUsers,
        'peak_users': math.max(activeUsers, maxPeakUsers),
        'system_load': avgLoad,
        'crash_risk': crashRisk,
        'is_low_load': isLowLoad,
        'is_medium_load': isMediumLoad,
        'is_high_load': isHighLoad,
        'total_connections': records.length,
      };
    } catch (e) {
      if (kDebugMode) {
        print('🌐 GlobalSystemMonitor: Failed to get global stats: $e');
      }
      return {
        'active_users': 1,
        'peak_users': 1,
        'system_load': 0.0,
        'crash_risk': 'LOW',
        'is_low_load': true,
        'is_medium_load': false,
        'is_high_load': false,
      };
    }
  }
  
  /// Calculate local system load (placeholder - could be enhanced)
  static double _calculateLocalLoad() {
    // Simple load calculation based on time of day and random factors
    final hour = DateTime.now().hour;
    double baseLoad = 0.0;
    
    // Peak hours: 9-11 AM, 2-4 PM, 7-9 PM
    if ((hour >= 9 && hour <= 11) || 
        (hour >= 14 && hour <= 16) || 
        (hour >= 19 && hour <= 21)) {
      baseLoad = 30.0;
    } else if (hour >= 8 && hour <= 22) {
      baseLoad = 15.0;
    } else {
      baseLoad = 5.0;
    }
    
    // Add some randomness
    return (baseLoad + (DateTime.now().millisecond % 20)).clamp(0.0, 100.0);
  }
  
  /// Assess crash risk based on user count
  static String _assessCrashRisk(int userCount) {
    if (userCount > 100) return 'CRITICAL';
    if (userCount > 80) return 'HIGH';
    if (userCount > 50) return 'MEDIUM';
    return 'LOW';
  }
  
  /// Get current global user count
  static Future<int> getCurrentActiveUsers() async {
    final stats = await getGlobalSystemStats();
    return stats['active_users'] as int;
  }
  
  /// Check if system is in low load mode
  static Future<bool> isLowLoadMode() async {
    final stats = await getGlobalSystemStats();
    return stats['is_low_load'] as bool;
  }
  
  /// Check if system is in medium load mode
  static Future<bool> isMediumLoadMode() async {
    final stats = await getGlobalSystemStats();
    return stats['is_medium_load'] as bool;
  }
  
  /// Check if system is in high load mode
  static Future<bool> isHighLoadMode() async {
    final stats = await getGlobalSystemStats();
    return stats['is_high_load'] as bool;
  }
  
  /// Mark user as inactive (call when app is closing or user logs out)
  static Future<void> markUserInactive() async {
    await _reportInactiveStatus();
  }
  
  /// Report inactive status to reduce active user count
  static Future<void> _reportInactiveStatus() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      
      await supabase.from('system_monitoring').insert({
        'active_connections': 0, // Mark as inactive
        'max_connections': 60,
        'queue_size': 0,
        'system_load': 0.0,
        'crash_risk': 'LOW',
        'peak_users': 0,
        'cache_hit_rate': 0.0,
        'cache_entries': 0,
        'exam_mode_active': false,
        'active_test_takers': 0,
        'active_exams': 0,
        'circuit_breaker_open': false,
        'app_version': _appVersion,
        'platform': _platform,
        'is_active': false,
        'metadata': {
          'device_id': _deviceId,
          'user_id': user.id,
          'timestamp': DateTime.now().toIso8601String(),
          'session_duration': 0,
          'app_state': 'inactive',
          'logout_event': true,
        }
      });
      
      if (kDebugMode) {
        print('🌐 GlobalSystemMonitor: Reported inactive status');
      }
    } catch (e) {
      if (kDebugMode) {
        print('🌐 GlobalSystemMonitor: Failed to report inactive status: $e');
      }
    }
  }
  
  /// Dispose of the monitor
  static void dispose() {
    _reportingTimer?.cancel();
    _reportingTimer = null;
    
    // Report inactive status before disposing
    _reportInactiveStatus();
    
    if (kDebugMode) {
      print('🌐 GlobalSystemMonitor: Disposed');
    }
  }
}
