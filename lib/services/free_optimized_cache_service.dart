import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class FreeOptimizedCacheService {
  static final Map<String, dynamic> _memoryCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  
  // Cache durations for different data types
  static const Duration _profileCacheDuration = Duration(hours: 2);
  static const Duration _subjectsCacheDuration = Duration(hours: 1);
  static const Duration _attendanceCacheDuration = Duration(minutes: 15);
  static const Duration _staticDataCacheDuration = Duration(days: 1);

  /// Cache data with automatic expiration
  static Future<void> cacheData(
    String key,
    dynamic data, {
    Duration? customDuration,
  }) async {
    // Store in memory for immediate access
    _memoryCache[key] = data;
    _cacheTimestamps[key] = DateTime.now();

    // Also store in persistent storage for app restarts
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'data': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'duration': (customDuration ?? _getDefaultDuration(key)).inMilliseconds,
      };
      await prefs.setString(key, jsonEncode(cacheData));
    } catch (e) {
      if (kDebugMode) print('Cache storage error: $e');
    }
  }

  /// Get cached data if still valid
  static Future<T?> getCachedData<T>(String key) async {
    // Check memory cache first
    if (_memoryCache.containsKey(key) && _isCacheValid(key)) {
      if (kDebugMode) print('📱 Memory cache hit: $key');
      return _memoryCache[key] as T?;
    }

    // Check persistent storage
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedString = prefs.getString(key);
      
      if (cachedString != null) {
        final cacheData = jsonDecode(cachedString) as Map<String, dynamic>;
        final timestamp = DateTime.fromMillisecondsSinceEpoch(cacheData['timestamp']);
        final duration = Duration(milliseconds: cacheData['duration']);
        
        if (DateTime.now().difference(timestamp) < duration) {
          final data = cacheData['data'];
          // Update memory cache
          _memoryCache[key] = data;
          _cacheTimestamps[key] = timestamp;
          
          if (kDebugMode) print('💾 Persistent cache hit: $key');
          return data as T?;
        } else {
          // Remove expired data
          await prefs.remove(key);
        }
      }
    } catch (e) {
      if (kDebugMode) print('Cache retrieval error: $e');
    }

    return null;
  }

  /// Execute operation with caching
  static Future<T> cacheOrExecute<T>(
    String key,
    Future<T> Function() operation, {
    Duration? cacheDuration,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = await getCachedData<T>(key);
      if (cached != null) {
        return cached;
      }
    }

    if (kDebugMode) print('🔄 Cache miss, executing: $key');
    final result = await operation();
    await cacheData(key, result, customDuration: cacheDuration);
    return result;
  }

  /// Alias for cacheOrExecute to maintain compatibility
  static Future<T> getCachedOrExecute<T>(
    String key,
    Future<T> Function() operation, {
    Duration? duration,
    bool forceRefresh = false,
  }) async {
    return cacheOrExecute<T>(
      key,
      operation,
      cacheDuration: duration,
      forceRefresh: forceRefresh,
    );
  }

  /// Preload critical data during low usage
  static Future<void> preloadCriticalData(String userId) async {
    try {
      // This runs in background, doesn't block UI
      final futures = <Future>[];
      
      // Preload user profile
      futures.add(_preloadUserProfile(userId));
      
      // Preload subjects list
      futures.add(_preloadSubjects(userId));
      
      // Wait for all preloading to complete
      await Future.wait(futures);
      
      if (kDebugMode) print('✅ Critical data preloaded');
    } catch (e) {
      if (kDebugMode) print('Preload error: $e');
    }
  }

  static Future<void> _preloadUserProfile(String userId) async {
    // Implementation would go here
    // This is just a placeholder
  }

  static Future<void> _preloadSubjects(String userId) async {
    // Implementation would go here
    // This is just a placeholder
  }

  /// Clear expired cache entries
  static Future<void> cleanExpiredCache() async {
    final keysToRemove = <String>[];
    
    for (final entry in _cacheTimestamps.entries) {
      if (!_isCacheValid(entry.key)) {
        keysToRemove.add(entry.key);
      }
    }

    for (final key in keysToRemove) {
      _memoryCache.remove(key);
      _cacheTimestamps.remove(key);
    }

    // Also clean persistent storage
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in keysToRemove) {
        await prefs.remove(key);
      }
    } catch (e) {
      if (kDebugMode) print('Cache cleanup error: $e');
    }

    if (kDebugMode && keysToRemove.isNotEmpty) {
      print('🧹 Cleaned ${keysToRemove.length} expired cache entries');
    }
  }

  /// Get cache statistics
  static Map<String, dynamic> getCacheStats() {
    final validEntries = _cacheTimestamps.entries.where((e) => _isCacheValid(e.key)).length;
    
    return {
      'memory_entries': _memoryCache.length,
      'valid_entries': validEntries,
      'expired_entries': _memoryCache.length - validEntries,
      'cache_hit_potential': validEntries > 0 ? (validEntries / _memoryCache.length * 100).round() : 0,
    };
  }

  static bool _isCacheValid(String key) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return false;
    
    final age = DateTime.now().difference(timestamp);
    final maxAge = _getDefaultDuration(key);
    
    return age < maxAge;
  }

  static Duration _getDefaultDuration(String key) {
    if (key.contains('profile')) return _profileCacheDuration;
    if (key.contains('subjects')) return _subjectsCacheDuration;
    if (key.contains('attendance')) return _attendanceCacheDuration;
    return _staticDataCacheDuration;
  }

  /// Clear all cache (for logout)
  static Future<void> clearAllCache() async {
    _memoryCache.clear();
    _cacheTimestamps.clear();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      if (kDebugMode) print('Cache clear error: $e');
    }
  }
}
