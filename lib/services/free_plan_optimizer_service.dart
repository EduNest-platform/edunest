import 'dart:async';
import 'package:flutter/foundation.dart';
import 'connection_queue_service.dart';
import 'free_optimized_cache_service.dart';
import 'load_balancing_service.dart';
import 'performance_optimization_service.dart';

/// Master service that combines all free plan optimizations
class FreePlanOptimizerService {
  static bool _isInitialized = false;
  static Timer? _cleanupTimer;

  /// Initialize all optimization services
  static Future<void> initialize() async {
    if (_isInitialized) return;

    // Start periodic cleanup
    _cleanupTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => _performMaintenance(),
    );

    // Preload critical data during initialization
    final user = await _getCurrentUser();
    if (user != null) {
      await FreeOptimizedCacheService.preloadCriticalData(user);
    }

    _isInitialized = true;
    if (kDebugMode) print('✅ Free Plan Optimizer initialized');
  }

  /// Execute database operation with all optimizations
  static Future<T> optimizedDatabaseOperation<T>(
    String operationName,
    Future<T> Function() operation, {
    Duration? cacheDuration,
    bool useCache = true,
    bool canDefer = true,
    int priority = 1,
  }) async {
    // 1. Check cache first (if enabled)
    if (useCache) {
      final cacheKey = 'db_$operationName';
      final cached = await FreeOptimizedCacheService.getCachedData<T>(cacheKey);
      if (cached != null) {
        return cached;
      }
    }

    // 2. Use connection queue to manage concurrent connections
    return ConnectionQueueService.executeWithQueue(
      operationName,
      () async {
        // 3. Apply load balancing
        return LoadBalancingService.executeWithLoadBalancing(
          operationName,
          () async {
            // 4. Track performance
            return PerformanceOptimizationService.trackOperation(
              operationName,
              () async {
                // 5. Execute with timeout
                final result = await PerformanceOptimizationService.executeWithTimeout(
                  operation(),
                  timeout: const Duration(seconds: 8), // Shorter timeout for free plan
                  operationName: operationName,
                );

                // 6. Cache the result
                if (useCache) {
                  final cacheKey = 'db_$operationName';
                  await FreeOptimizedCacheService.cacheData(
                    cacheKey,
                    result,
                    customDuration: cacheDuration,
                  );
                }

                return result;
              },
            );
          },
          priority: priority,
          canDefer: canDefer,
        );
      },
    );
  }

  /// Get comprehensive system status for free plan
  static Map<String, dynamic> getSystemStatus() {
    final connectionStats = ConnectionQueueService.getStats();
    final loadStats = LoadBalancingService.getLoadStats();
    final cacheStats = FreeOptimizedCacheService.getCacheStats();
    final performanceStats = PerformanceOptimizationService.getPerformanceStats();

    return {
      'connection_usage': connectionStats['active_connections'],
      'connection_limit': connectionStats['max_connections'],
      'queue_size': connectionStats['queued_operations'],
      'system_load': loadStats['current_load'],
      'is_peak_time': loadStats['is_peak_time'],
      'cache_hit_rate': cacheStats['cache_hit_potential'],
      'cache_entries': cacheStats['valid_entries'],
      'slow_operations': PerformanceOptimizationService.getSlowOperations().length,
      'status': _getOverallStatus(connectionStats, loadStats),
      'recommendations': _getRecommendations(connectionStats, loadStats),
    };
  }

  /// Get user-friendly status message
  static String getStatusMessage() {
    final status = getSystemStatus();
    final connectionUsage = (status['connection_usage'] as int);
    final connectionLimit = (status['connection_limit'] as int);
    final usagePercent = (connectionUsage / connectionLimit * 100).round();

    if (usagePercent >= 90) {
      return '🚨 High traffic - some features may be slower';
    } else if (usagePercent >= 70) {
      return '⚠️ Moderate traffic - optimizing performance';
    } else if (status['is_peak_time'] as bool) {
      return '📊 Peak hours - enhanced optimizations active';
    } else {
      return '✅ All systems running smoothly';
    }
  }

  /// Execute critical operations (always high priority)
  static Future<T> executeCriticalOperation<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    return optimizedDatabaseOperation(
      operationName,
      operation,
      useCache: false, // Critical operations should be fresh
      canDefer: false, // Never defer critical operations
      priority: 3, // Highest priority
    );
  }

  /// Execute background operations (can be deferred)
  static Future<T> executeBackgroundOperation<T>(
    String operationName,
    Future<T> Function() operation, {
    Duration? cacheDuration,
  }) async {
    return optimizedDatabaseOperation(
      operationName,
      operation,
      cacheDuration: cacheDuration ?? const Duration(hours: 1),
      canDefer: true,
      priority: 1, // Lowest priority
    );
  }

  /// Force refresh data (bypass cache)
  static Future<T> forceRefresh<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    // Clear related cache entries
    await FreeOptimizedCacheService.clearAllCache();
    
    return optimizedDatabaseOperation(
      operationName,
      operation,
      useCache: false,
      priority: 2, // Medium priority for refresh
    );
  }

  /// Cleanup and maintenance
  static Future<void> _performMaintenance() async {
    try {
      await FreeOptimizedCacheService.cleanExpiredCache();
      PerformanceOptimizationService.clearStats();
      
      if (kDebugMode) {
        final status = getSystemStatus();
        print('🔧 Maintenance complete. Status: ${status['status']}');
      }
    } catch (e) {
      if (kDebugMode) print('Maintenance error: $e');
    }
  }

  static String _getOverallStatus(Map<String, int> connectionStats, Map<String, dynamic> loadStats) {
    final connectionUsage = connectionStats['active_connections']! / connectionStats['max_connections']!;
    final systemLoad = loadStats['current_load'] as int;

    if (connectionUsage >= 0.9 || systemLoad >= 90) return 'CRITICAL';
    if (connectionUsage >= 0.7 || systemLoad >= 70) return 'HIGH';
    if (connectionUsage >= 0.5 || systemLoad >= 50) return 'MODERATE';
    return 'NORMAL';
  }

  static List<String> _getRecommendations(Map<String, int> connectionStats, Map<String, dynamic> loadStats) {
    final recommendations = <String>[];
    final connectionUsage = connectionStats['active_connections']! / connectionStats['max_connections']!;
    final systemLoad = loadStats['current_load'] as int;

    if (connectionUsage >= 0.8) {
      recommendations.add('Consider upgrading to Pro plan for unlimited connections');
    }
    
    if (systemLoad >= 80) {
      recommendations.add('Reduce background operations during peak hours');
    }
    
    if (loadStats['is_peak_time'] as bool) {
      recommendations.add('Some operations may be queued during peak hours');
    }

    return recommendations;
  }

  static Future<String?> _getCurrentUser() async {
    try {
      // This would get current user ID
      return 'current_user_id'; // Placeholder
    } catch (e) {
      return null;
    }
  }

  /// Dispose resources
  static void dispose() {
    _cleanupTimer?.cancel();
    _isInitialized = false;
  }
}
