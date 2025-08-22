import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

class LoadBalancingService {
  static int _currentUserLoad = 0;
  static DateTime _lastResetTime = DateTime.now();
  static final List<String> _deferredOperations = [];
  
  // Peak hours: 8-10 AM, 2-4 PM, 7-9 PM
  static const List<int> _peakHours = [8, 9, 14, 15, 19, 20];
  
  /// Check if current time is peak usage
  static bool isPeakTime() {
    final now = DateTime.now();
    return _peakHours.contains(now.hour);
  }

  /// Get current system load (0-100%)
  static int getCurrentLoad() {
    // Reset load counter every hour
    if (DateTime.now().difference(_lastResetTime).inHours >= 1) {
      _currentUserLoad = 0;
      _lastResetTime = DateTime.now();
    }
    
    // Estimate load based on concurrent operations
    return (_currentUserLoad * 2).clamp(0, 100);
  }

  /// Execute operation with load balancing
  static Future<T> executeWithLoadBalancing<T>(
    String operationName,
    Future<T> Function() operation, {
    int priority = 1, // 1 = low, 2 = medium, 3 = high
    bool canDefer = true,
  }) async {
    _currentUserLoad++;
    
    try {
      final load = getCurrentLoad();
      
      // If system is overloaded and operation can be deferred
      if (load > 80 && canDefer && priority < 3) {
        return _deferOperation<T>(operationName, operation, priority);
      }
      
      // Add artificial delay during peak times for non-critical operations
      if (isPeakTime() && priority == 1) {
        await Future.delayed(Duration(milliseconds: Random().nextInt(1000) + 500));
      }
      
      return await operation();
    } finally {
      _currentUserLoad--;
    }
  }

  /// Defer operation to execute later
  static Future<T> _deferOperation<T>(
    String operationName,
    Future<T> Function() operation,
    int priority,
  ) async {
    if (kDebugMode) {
      print('⏸️ Deferring operation: $operationName (load: ${getCurrentLoad()}%)');
    }
    
    // Wait for load to decrease
    while (getCurrentLoad() > 60) {
      await Future.delayed(const Duration(seconds: 2));
    }
    
    if (kDebugMode) {
      print('▶️ Executing deferred operation: $operationName');
    }
    
    return await operation();
  }

  /// Batch multiple operations to reduce connection overhead
  static Future<List<T>> batchOperations<T>(
    List<Future<T> Function()> operations,
    {int batchSize = 3}
  ) async {
    final results = <T>[];
    
    for (int i = 0; i < operations.length; i += batchSize) {
      final batch = operations.skip(i).take(batchSize).toList();
      final batchResults = await Future.wait(
        batch.map((op) => op()),
      );
      results.addAll(batchResults);
      
      // Small delay between batches to prevent overwhelming
      if (i + batchSize < operations.length) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
    
    return results;
  }

  /// Get recommended operation timing
  static Duration getRecommendedDelay() {
    final load = getCurrentLoad();
    final isPeak = isPeakTime();
    
    if (load > 90) return const Duration(seconds: 5);
    if (load > 70) return const Duration(seconds: 2);
    if (isPeak) return const Duration(milliseconds: 500);
    
    return Duration.zero;
  }

  /// Schedule operation for off-peak time
  static Future<T> scheduleForOffPeak<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    if (!isPeakTime()) {
      return await operation();
    }
    
    if (kDebugMode) {
      print('📅 Scheduling for off-peak: $operationName');
    }
    
    // Wait until we're out of peak hours or load decreases significantly
    while (isPeakTime() && getCurrentLoad() > 50) {
      await Future.delayed(const Duration(minutes: 5));
    }
    
    return await operation();
  }

  /// Get load balancing statistics
  static Map<String, dynamic> getLoadStats() {
    return {
      'current_load': getCurrentLoad(),
      'is_peak_time': isPeakTime(),
      'active_operations': _currentUserLoad,
      'deferred_operations': _deferredOperations.length,
      'recommended_delay_ms': getRecommendedDelay().inMilliseconds,
      'next_off_peak_hour': _getNextOffPeakHour(),
    };
  }

  static int _getNextOffPeakHour() {
    final now = DateTime.now();
    for (int hour = now.hour + 1; hour < 24; hour++) {
      if (!_peakHours.contains(hour)) {
        return hour;
      }
    }
    // Next day
    for (int hour = 0; hour < now.hour; hour++) {
      if (!_peakHours.contains(hour)) {
        return hour;
      }
    }
    return now.hour; // Fallback
  }
}
