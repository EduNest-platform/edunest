import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'user_load_tracker.dart';

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

  /// Get current system load (0-100%) - Performance optimized
  static int? _cachedLoad;
  static DateTime? _lastLoadCalculation;
  
  static int getCurrentLoad() {
    final now = DateTime.now();
    
    // Cache load calculation for 5 seconds to reduce CPU usage
    if (_cachedLoad == null || _lastLoadCalculation == null ||
        now.difference(_lastLoadCalculation!).inSeconds > 5) {
      
      // Reset load counter every hour
      if (now.difference(_lastResetTime).inHours >= 1) {
        _currentUserLoad = 0;
        _lastResetTime = now;
      }
      
      // Optimized load calculation for 100+ users
      final userCount = UserLoadTracker.currentUsers;
      final activeConnections = UserLoadTracker.activeConnections;
      
      // Production-ready calculation for educational apps
      final baseLoad = (userCount * 0.6).round(); // Reduced impact for scalability
      final connectionLoad = (activeConnections * 1.2).round(); // Balanced connection weight
      final operationLoad = (_currentUserLoad * 0.8).round(); // Reduced operation weight
      
      _cachedLoad = (baseLoad + connectionLoad + operationLoad).clamp(0, 100);
      _lastLoadCalculation = now;
    }
    
    return _cachedLoad!;
  }

  /// Execute operation with smart load balancing
  static Future<T> executeWithLoadBalancing<T>(
    String operationName,
    Future<T> Function() operation, {
    int priority = 1, // 1 = low, 2 = medium, 3 = high
    bool canDefer = true,
  }) async {
    _currentUserLoad++;
    
    try {
      // 🚀 SMART MODE: Check user load level
      if (UserLoadTracker.isLowLoadMode) {
        // Low load: Execute immediately, no delays or balancing
        if (kDebugMode) {
          print('🚀 LoadBalancer: Fast execution (${UserLoadTracker.currentUsers} users)');
        }
        return await operation();
      }
      
      if (UserLoadTracker.isMediumLoadMode) {
        // Medium load: Light optimization, minimal delays
        final load = getCurrentLoad();
        if (load > 70 && canDefer && priority < 3) {
          // Short delay only if really needed
          await Future.delayed(Duration(milliseconds: 100));
        }
        return await operation();
      }
      
      // High load: Full sophisticated load balancing
      final load = getCurrentLoad();
      
      // If system is overloaded and operation can be deferred
      if (load > 80 && canDefer && priority < 3) {
        return _deferOperation<T>(operationName, operation, priority);
      }
      
      // Minimal delay for 100+ user production environment
      if (isPeakTime() && priority == 1 && UserLoadTracker.currentUsers > 100) {
        // Production: Very short delays only for extreme load
        final delayMs = Random().nextInt(100) + 25; // 25-125ms delay
        await Future.delayed(Duration(milliseconds: delayMs));
      }
      
      return await operation();
    } finally {
      _currentUserLoad--;
    }
  }

  /// Defer operation to execute later (non-blocking)
  static Future<T> _deferOperation<T>(
    String operationName,
    Future<T> Function() operation,
    int priority,
  ) async {
    if (kDebugMode) {
      print('⏸️ Deferring operation: $operationName (load: ${getCurrentLoad()}%)');
    }
    
    // 🚀 SMART: Non-blocking wait with timeout
    int attempts = 0;
    const maxAttempts = 5; // Maximum 10 seconds wait
    
    while (getCurrentLoad() > 60 && attempts < maxAttempts) {
      await Future.delayed(const Duration(seconds: 2));
      attempts++;
    }
    
    if (attempts >= maxAttempts) {
      if (kDebugMode) {
        print('⚠️ Executing despite high load: $operationName (timeout reached)');
      }
    } else if (kDebugMode) {
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

  /// Schedule operation for off-peak time (non-blocking)
  static Future<T> scheduleForOffPeak<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    // 🚀 SMART: Only defer for high load scenarios
    if (!isPeakTime() || UserLoadTracker.isLowLoadMode) {
      return await operation();
    }
    
    if (kDebugMode) {
      print('📅 Scheduling for off-peak: $operationName');
    }
    
    // 🚀 SMART: Non-blocking wait with reasonable timeout
    int attempts = 0;
    const maxAttempts = 3; // Maximum 15 minutes wait
    
    while (isPeakTime() && getCurrentLoad() > 50 && attempts < maxAttempts && UserLoadTracker.isHighLoadMode) {
      await Future.delayed(const Duration(minutes: 5));
      attempts++;
    }
    
    if (attempts >= maxAttempts) {
      if (kDebugMode) {
        print('⚠️ Executing despite peak time: $operationName (timeout reached)');
      }
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
