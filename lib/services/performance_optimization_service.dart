import 'dart:async';
import 'package:flutter/foundation.dart';

class PerformanceOptimizationService {
  static final Map<String, DateTime> _operationStartTimes = {};
  static final Map<String, Duration> _operationDurations = {};

  /// Start tracking an operation's performance
  static void startOperation(String operationName) {
    _operationStartTimes[operationName] = DateTime.now();
    if (kDebugMode) {
      print('🚀 Started operation: $operationName');
    }
  }

  /// End tracking an operation and log its duration
  static void endOperation(String operationName) {
    final startTime = _operationStartTimes[operationName];
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime);
      _operationDurations[operationName] = duration;
      _operationStartTimes.remove(operationName);
      
      if (kDebugMode) {
        if (duration.inMilliseconds > 2000) {
          print('⚠️ SLOW operation: $operationName took ${duration.inMilliseconds}ms');
        } else if (duration.inMilliseconds > 1000) {
          print('⏰ Moderate operation: $operationName took ${duration.inMilliseconds}ms');
        } else {
          print('✅ Fast operation: $operationName took ${duration.inMilliseconds}ms');
        }
      }
    }
  }

  /// Execute a function with performance tracking
  static Future<T> trackOperation<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    startOperation(operationName);
    try {
      final result = await operation();
      endOperation(operationName);
      return result;
    } catch (e) {
      endOperation(operationName);
      rethrow;
    }
  }

  /// Get performance statistics
  static Map<String, Duration> getPerformanceStats() {
    return Map.unmodifiable(_operationDurations);
  }

  /// Clear performance data
  static void clearStats() {
    _operationStartTimes.clear();
    _operationDurations.clear();
  }

  /// Check if any operations are taking too long
  static List<String> getSlowOperations() {
    return _operationDurations.entries
        .where((entry) => entry.value.inMilliseconds > 2000)
        .map((entry) => '${entry.key}: ${entry.value.inMilliseconds}ms')
        .toList();
  }

  /// Execute with timeout to prevent hanging
  static Future<T> executeWithTimeout<T>(
    Future<T> operation, {
    Duration timeout = const Duration(seconds: 10),
    String? operationName,
  }) async {
    if (operationName != null) startOperation(operationName);
    
    try {
      final result = await operation.timeout(timeout);
      if (operationName != null) endOperation(operationName);
      return result;
    } on TimeoutException {
      if (operationName != null) endOperation(operationName);
      if (kDebugMode) {
        print('⏰ TIMEOUT: ${operationName ?? 'Operation'} timed out after ${timeout.inSeconds}s');
      }
      rethrow;
    } catch (e) {
      if (operationName != null) endOperation(operationName);
      rethrow;
    }
  }
}
