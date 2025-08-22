import 'dart:async';
import 'package:flutter/foundation.dart';

class ConnectionMonitorService {
  static int _activeConnections = 0;
  static int _peakConnections = 0;
  static final List<String> _connectionHistory = [];
  static Timer? _monitoringTimer;

  /// Start monitoring connection usage
  static void startMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _logConnectionStats(),
    );
  }

  /// Stop monitoring
  static void stopMonitoring() {
    _monitoringTimer?.cancel();
  }

  /// Track when a connection is opened
  static void onConnectionOpened(String operation) {
    _activeConnections++;
    if (_activeConnections > _peakConnections) {
      _peakConnections = _activeConnections;
    }
    
    _connectionHistory.add('${DateTime.now().toIso8601String()}: +$operation ($_activeConnections active)');
    
    if (kDebugMode) {
      print('🔗 Connection opened for $operation. Active: $_activeConnections');
      
      // WARNING: Approaching limit
      if (_activeConnections >= 45) {
        print('⚠️ WARNING: $_activeConnections/60 connections used (${(_activeConnections/60*100).toInt()}%)');
      }
      
      // CRITICAL: Very close to limit
      if (_activeConnections >= 55) {
        print('🚨 CRITICAL: $_activeConnections/60 connections used! Risk of exceeding limit!');
      }
    }
  }

  /// Track when a connection is closed
  static void onConnectionClosed(String operation) {
    if (_activeConnections > 0) {
      _activeConnections--;
    }
    
    _connectionHistory.add('${DateTime.now().toIso8601String()}: -$operation ($_activeConnections active)');
    
    if (kDebugMode) {
      print('🔌 Connection closed for $operation. Active: $_activeConnections');
    }
  }

  /// Get current connection statistics
  static Map<String, dynamic> getConnectionStats() {
    return {
      'active_connections': _activeConnections,
      'peak_connections': _peakConnections,
      'free_plan_limit': 60,
      'usage_percentage': (_activeConnections / 60 * 100).toInt(),
      'connections_remaining': 60 - _activeConnections,
      'is_near_limit': _activeConnections >= 45,
      'is_critical': _activeConnections >= 55,
    };
  }

  /// Get connection history (last 50 entries)
  static List<String> getConnectionHistory() {
    return _connectionHistory.length > 50 
        ? _connectionHistory.sublist(_connectionHistory.length - 50)
        : List.from(_connectionHistory);
  }

  /// Execute operation with connection tracking
  static Future<T> trackConnection<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    onConnectionOpened(operationName);
    try {
      final result = await operation();
      return result;
    } finally {
      onConnectionClosed(operationName);
    }
  }

  /// Check if it's safe to open new connections
  static bool isSafeToConnect() {
    return _activeConnections < 55; // Keep 5 connection buffer
  }

  /// Get recommendation for upgrade
  static String getUpgradeRecommendation() {
    final stats = getConnectionStats();
    final usagePercent = stats['usage_percentage'] as int;
    
    if (usagePercent >= 90) {
      return '🚨 URGENT: Upgrade to Pro immediately! Risk of service disruption.';
    } else if (usagePercent >= 75) {
      return '⚠️ HIGH: Consider upgrading to Pro soon. Approaching limits.';
    } else if (usagePercent >= 50) {
      return '💡 MEDIUM: Monitor usage. Pro upgrade recommended for growth.';
    } else {
      return '✅ LOW: Current usage within safe limits.';
    }
  }

  static void _logConnectionStats() {
    final stats = getConnectionStats();
    if (kDebugMode) {
      print('📊 Connection Stats: ${stats['active_connections']}/60 (${stats['usage_percentage']}%)');
      if (stats['is_critical'] as bool) {
        print('🚨 ${getUpgradeRecommendation()}');
      }
    }
  }

  /// Reset statistics (for testing)
  static void reset() {
    _activeConnections = 0;
    _peakConnections = 0;
    _connectionHistory.clear();
  }
}
