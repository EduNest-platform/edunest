import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

/// Enhanced connection management for 200-300 users
class ScalableConnectionService {
  static final List<_PriorityOperation> _operationQueue = [];
  static int _activeConnections = 0;
  static int _totalUsers = 0;
  static int _peakConcurrentUsers = 0;
  static DateTime _lastStatsReset = DateTime.now();
  
  // Dynamic connection limits based on usage
  static int _maxConnections = 45; // Start conservative
  static const int _absoluteMaxConnections = 55; // Never exceed this
  static const int _emergencyMaxConnections = 58; // Last resort
  
  // Circuit breaker pattern
  static bool _circuitBreakerOpen = false;
  static int _failureCount = 0;
  static const int _maxFailures = 5;
  static const Duration _circuitBreakerTimeout = Duration(minutes: 2);

  /// Enhanced queue execution with priority and circuit breaker
  static Future<T> executeWithAdvancedQueue<T>(
    String operationName,
    Future<T> Function() operation, {
    int priority = 1, // 1=low, 2=medium, 3=high, 4=critical
    bool bypassQueue = false,
    Duration? customTimeout,
  }) async {
    // Update user statistics
    _updateUserStats();
    
    // Check circuit breaker
    if (_circuitBreakerOpen && priority < 4) {
      throw Exception('System temporarily unavailable. Please try again in a few minutes.');
    }

    // Dynamic connection limit adjustment
    _adjustConnectionLimits();

    // Critical operations bypass queue
    if (bypassQueue || priority >= 4) {
      return _executeDirectly(operationName, operation, customTimeout);
    }

    // Check if we can execute immediately
    if (_activeConnections < _maxConnections) {
      return _executeDirectly(operationName, operation, customTimeout);
    }

    // Add to priority queue
    final completer = Completer<T>();
    final queuedOp = _PriorityOperation<T>(
      name: operationName,
      operation: operation,
      completer: completer,
      priority: priority,
      timeout: customTimeout ?? Duration(seconds: 10),
      queueTime: DateTime.now(),
    );

    _operationQueue.add(queuedOp);
    _operationQueue.sort(); // Sort by priority

    if (kDebugMode) {
      print('⏳ Queued: $operationName (P$priority, ${_operationQueue.length} in queue)');
    }

    _processQueue();
    return completer.future;
  }

  /// Execute operation directly with circuit breaker protection
  static Future<T> _executeDirectly<T>(
    String operationName,
    Future<T> Function() operation,
    Duration? customTimeout,
  ) async {
    _activeConnections++;
    
    if (kDebugMode) {
      print('🔗 Executing: $operationName ($_activeConnections/$_maxConnections active)');
    }

    try {
      final result = await operation().timeout(
        customTimeout ?? Duration(seconds: 8),
      );
      
      // Reset failure count on success
      _failureCount = 0;
      return result;
    } catch (e) {
      _handleFailure(e);
      rethrow;
    } finally {
      _activeConnections--;
      _processQueue();
    }
  }

  /// Handle failures and circuit breaker logic
  static void _handleFailure(dynamic error) {
    _failureCount++;

    if (_failureCount >= _maxFailures) {
      _circuitBreakerOpen = true;
      if (kDebugMode) {
        print('🚨 Circuit breaker OPEN - too many failures');
      }
      
      // Auto-reset circuit breaker after timeout
      Timer(_circuitBreakerTimeout, () {
        _circuitBreakerOpen = false;
        _failureCount = 0;
        if (kDebugMode) print('✅ Circuit breaker RESET');
      });
    }
  }

  /// Dynamic connection limit adjustment based on current load
  static void _adjustConnectionLimits() {
    final queueSize = _operationQueue.length;
    
    // Increase limit if queue is building up and we're under absolute max
    if (queueSize > 10 && _maxConnections < _absoluteMaxConnections) {
      _maxConnections = min(_maxConnections + 2, _absoluteMaxConnections);
      if (kDebugMode) {
        print('📈 Increased connection limit to $_maxConnections');
      }
    }
    
    // Emergency increase if queue is really long
    if (queueSize > 20 && _maxConnections < _emergencyMaxConnections) {
      _maxConnections = _emergencyMaxConnections;
      if (kDebugMode) {
        print('🚨 EMERGENCY: Connection limit increased to $_maxConnections');
      }
    }
    
    // Decrease limit if load is low
    if (queueSize == 0 && _activeConnections < _maxConnections * 0.5) {
      _maxConnections = max(45, _maxConnections - 1);
    }
  }

  /// Process queue with priority ordering
  static Future<void> _processQueue() async {
    while (_operationQueue.isNotEmpty && _activeConnections < _maxConnections) {
      final queuedOp = _operationQueue.removeAt(0); // Remove first (highest priority)
      
      // Check if operation has timed out in queue
      final waitTime = DateTime.now().difference(queuedOp.queueTime);
      if (waitTime > Duration(seconds: 30)) {
        queuedOp.completer.completeError(
          TimeoutException('Operation timed out in queue', waitTime)
        );
        continue;
      }
      
      // Execute the queued operation
      try {
        final result = await _executeDirectly(
          queuedOp.name, 
          queuedOp.operation,
          queuedOp.timeout,
        );
        queuedOp.completer.complete(result);
      } catch (e) {
        queuedOp.completer.completeError(e);
      }
    }
  }

  /// Update user statistics for load analysis
  static void _updateUserStats() {
    _totalUsers++;
    if (_activeConnections > _peakConcurrentUsers) {
      _peakConcurrentUsers = _activeConnections;
    }
    
    // Reset stats daily
    if (DateTime.now().difference(_lastStatsReset).inDays >= 1) {
      _lastStatsReset = DateTime.now();
      _peakConcurrentUsers = 0;
      _totalUsers = 0;
    }
  }

  /// Get comprehensive system status
  static Map<String, dynamic> getAdvancedStats() {
    final queueSize = _operationQueue.length;
    final avgQueuePriority = _operationQueue.isEmpty 
        ? 0.0
        : _operationQueue.fold<int>(0, (sum, op) => sum + op.priority) / _operationQueue.length;
    
    return {
      'active_connections': _activeConnections,
      'max_connections': _maxConnections,
      'absolute_max': _absoluteMaxConnections,
      'queue_size': queueSize,
      'avg_queue_priority': avgQueuePriority.toStringAsFixed(1),
      'circuit_breaker_open': _circuitBreakerOpen,
      'failure_count': _failureCount,
      'peak_concurrent_users': _peakConcurrentUsers,
      'total_operations_today': _totalUsers,
      'system_status': _getSystemStatus(),
      'estimated_max_users': _getEstimatedMaxUsers(),
      'crash_risk': _getCrashRisk(),
    };
  }

  /// Estimate maximum supportable users
  static int _getEstimatedMaxUsers() {
    // Assume 30% peak concurrency, 3 operations per user per session
    final maxConcurrentOps = _maxConnections;
    final maxConcurrentUsers = (maxConcurrentOps / 3).floor();
    return (maxConcurrentUsers / 0.3).floor(); // Total user base
  }

  /// Calculate crash risk percentage
  static String _getCrashRisk() {
    final usage = _activeConnections / _maxConnections;
    final queuePressure = _operationQueue.length / 20.0; // Queue pressure factor
    
    final risk = ((usage + queuePressure) * 100).clamp(0, 100);
    
    if (risk >= 90) return 'CRITICAL (${risk.toInt()}%)';
    if (risk >= 70) return 'HIGH (${risk.toInt()}%)';
    if (risk >= 50) return 'MEDIUM (${risk.toInt()}%)';
    return 'LOW (${risk.toInt()}%)';
  }

  static String _getSystemStatus() {
    if (_circuitBreakerOpen) return 'CIRCUIT_BREAKER_OPEN';
    
    final usage = _activeConnections / _maxConnections;
    final queueSize = _operationQueue.length;
    
    if (usage >= 0.95 || queueSize > 25) return 'CRITICAL_OVERLOAD';
    if (usage >= 0.8 || queueSize > 15) return 'HIGH_LOAD';
    if (usage >= 0.6 || queueSize > 5) return 'MODERATE_LOAD';
    return 'NORMAL';
  }

  /// Emergency methods for crash prevention
  static void emergencyThrottle() {
    _maxConnections = max(30, _maxConnections - 10);
    if (kDebugMode) {
      print('🚨 EMERGENCY THROTTLE: Reduced to $_maxConnections connections');
    }
  }

  static void clearQueue() {
    while (_operationQueue.isNotEmpty) {
      final op = _operationQueue.removeAt(0);
      op.completer.completeError(Exception('Queue cleared due to system overload'));
    }
    if (kDebugMode) print('🧹 Emergency queue clear completed');
  }
}

/// Priority operation for queue management
class _PriorityOperation<T> implements Comparable<_PriorityOperation<T>> {
  final String name;
  final Future<T> Function() operation;
  final Completer<T> completer;
  final int priority;
  final Duration timeout;
  final DateTime queueTime;

  _PriorityOperation({
    required this.name,
    required this.operation,
    required this.completer,
    required this.priority,
    required this.timeout,
    required this.queueTime,
  });

  @override
  int compareTo(_PriorityOperation<T> other) {
    // Higher priority first (4 > 3 > 2 > 1)
    final priorityCompare = other.priority.compareTo(priority);
    if (priorityCompare != 0) return priorityCompare;
    
    // Then by queue time (earlier first)
    return queueTime.compareTo(other.queueTime);
  }
}
