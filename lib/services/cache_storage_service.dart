import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../services/files_service.dart';
import 'user_load_tracker.dart';

class CacheEntry<T> {
  final T data;
  final DateTime timestamp;
  final DateTime? expiresAt;
  final int size;

  CacheEntry({
    required this.data,
    required this.timestamp,
    this.expiresAt,
    this.size = 0,
  });

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  Map<String, dynamic> toJson() {
    return {
      'data': data is List<FileResource>
          ? (data as List<FileResource>).map((e) => e.toJson()).toList()
          : (data is FileResource ? (data as FileResource).toJson() : data),
      'timestamp': timestamp.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'size': size,
    };
  }

  static CacheEntry<T> fromJson<T>(Map<String, dynamic> json, T Function(dynamic) parser) {
    return CacheEntry<T>(
      data: parser(json['data']),
      timestamp: DateTime.parse(json['timestamp']),
      expiresAt: json['expiresAt'] != null ? DateTime.parse(json['expiresAt']) : null,
      size: json['size'] ?? 0,
    );
  }
}

class CacheStorageService {
  static CacheStorageService? _instance;
  static CacheStorageService get instance => _instance ??= CacheStorageService._();
  
  CacheStorageService._();

  // Memory cache
  final Map<String, CacheEntry> _memoryCache = {};
  
  // Cache configuration
  static const int maxMemoryCacheSize = 50 * 1024 * 1024; // 50MB
  static const int maxDiskCacheSize = 200 * 1024 * 1024; // 200MB
  static const Duration defaultExpiration = Duration(minutes: 30);
  static const Duration longTermExpiration = Duration(hours: 24);
  
  int _currentMemorySize = 0;
  late SharedPreferences _prefs;
  late Directory _cacheDir;
  bool _initialized = false;

  /// Initialize the cache service
  Future<void> initialize() async {
    if (_initialized) return;
    
    _prefs = await SharedPreferences.getInstance();
    _cacheDir = await getTemporaryDirectory();
    
    // Create cache subdirectory
    final cacheSubDir = Directory('${_cacheDir.path}/edunest_cache');
    if (!cacheSubDir.existsSync()) {
      cacheSubDir.createSync(recursive: true);
    }
    _cacheDir = cacheSubDir;
    
    // Clean expired cache on startup
    await _cleanExpiredCache();
    
    _initialized = true;
  }

  /// Generate cache key
  String _generateKey(String prefix, Map<String, dynamic> params) {
    final sortedParams = Map.fromEntries(
      params.entries.toList()..sort((a, b) => a.key.compareTo(b.key))
    );
    final paramString = sortedParams.toString();
    return '${prefix}_${paramString.hashCode}';
  }

  /// Get data from cache (memory first, then disk)
  Future<T?> get<T>(String key, T Function(dynamic) parser) async {
    await initialize();
    
    // Check memory cache first
    final memoryEntry = _memoryCache[key];
    if (memoryEntry != null && !memoryEntry.isExpired) {
      return memoryEntry.data as T;
    }

    // Check disk cache
    final diskEntry = await _getDiskCache<T>(key, parser);
    if (diskEntry != null && !diskEntry.isExpired) {
      // Move to memory cache for faster access
      _setMemoryCache(key, diskEntry);
      return diskEntry.data;
    }

    return null;
  }

  /// Set data in cache (both memory and disk)
  Future<void> set<T>(String key, T data, {Duration? expiration}) async {
    await initialize();
    
    final exp = expiration ?? defaultExpiration;
    final expiresAt = DateTime.now().add(exp);
    final size = _calculateSize(data);
    
    final entry = CacheEntry<T>(
      data: data,
      timestamp: DateTime.now(),
      expiresAt: expiresAt,
      size: size,
    );

    // Set in memory cache
    _setMemoryCache(key, entry);
    
    // Set in disk cache
    await _setDiskCache(key, entry);
  }

  /// Set data in memory cache with smart size management
  void _setMemoryCache(String key, CacheEntry entry) {
    // Remove existing entry if present
    final existingEntry = _memoryCache[key];
    if (existingEntry != null) {
      _currentMemorySize -= existingEntry.size;
    }

    // 🚀 SMART CACHE MANAGEMENT based on user load
    if (UserLoadTracker.isLowLoadMode) {
      // Low load: Simple cache, no strict memory limits
      _memoryCache[key] = entry;
      _currentMemorySize += entry.size;
      
      // Simple cleanup every 100 entries
      if (_memoryCache.length > 100) {
        _simpleCleanup();
      }
    } else if (UserLoadTracker.isMediumLoadMode) {
      // Medium load: Moderate memory management
      _memoryCache[key] = entry;
      _currentMemorySize += entry.size;
      
      // Non-blocking cleanup if needed
      if (_currentMemorySize > maxMemoryCacheSize) {
        Future.microtask(() => _smartEviction());
      }
    } else {
      // High load: Full sophisticated memory management
      // Check if we need to evict entries (but limit iterations)
      int evictionAttempts = 0;
      const maxEvictions = 10; // Prevent infinite loops
      
      while (_currentMemorySize + entry.size > maxMemoryCacheSize && 
             _memoryCache.isNotEmpty && 
             evictionAttempts < maxEvictions) {
        _evictOldestMemoryEntry();
        evictionAttempts++;
      }

      _memoryCache[key] = entry;
      _currentMemorySize += entry.size;
    }
  }
  
  /// Simple cleanup for low load mode
  void _simpleCleanup() {
    if (_memoryCache.length <= 100) return;
    
    // Remove oldest 20 entries
    final oldKeys = _memoryCache.keys.take(20).toList();
    for (final oldKey in oldKeys) {
      final removedEntry = _memoryCache.remove(oldKey);
      if (removedEntry != null) {
        _currentMemorySize -= removedEntry.size;
      }
    }
    
    if (kDebugMode) {
      print('🧹 Cache: Simple cleanup completed (${_memoryCache.length} entries remaining)');
    }
  }
  
  /// Smart eviction for medium load mode (non-blocking)
  void _smartEviction() {
    if (_memoryCache.isEmpty) return;
    
    // Remove expired entries first
    final expiredKeys = <String>[];
    for (final entry in _memoryCache.entries) {
      if (entry.value.isExpired) {
        expiredKeys.add(entry.key);
      }
    }
    
    for (final key in expiredKeys) {
      final removedEntry = _memoryCache.remove(key);
      if (removedEntry != null) {
        _currentMemorySize -= removedEntry.size;
      }
    }
    
    // If still over limit, remove oldest entries
    if (_currentMemorySize > maxMemoryCacheSize) {
      final sortedEntries = _memoryCache.entries.toList()
        ..sort((a, b) => a.value.timestamp.compareTo(b.value.timestamp));
      
      final toRemove = (sortedEntries.length * 0.2).round(); // Remove 20%
      for (int i = 0; i < toRemove && i < sortedEntries.length; i++) {
        final key = sortedEntries[i].key;
        final removedEntry = _memoryCache.remove(key);
        if (removedEntry != null) {
          _currentMemorySize -= removedEntry.size;
        }
      }
    }
    
    if (kDebugMode) {
      print('🧹 Cache: Smart eviction completed (${_memoryCache.length} entries, ${(_currentMemorySize / 1024 / 1024).toStringAsFixed(1)}MB)');
    }
  }

  /// Evict oldest entry from memory cache
  void _evictOldestMemoryEntry() {
    if (_memoryCache.isEmpty) return;
    
    String oldestKey = _memoryCache.keys.first;
    DateTime oldestTime = _memoryCache[oldestKey]!.timestamp;
    
    for (final entry in _memoryCache.entries) {
      if (entry.value.timestamp.isBefore(oldestTime)) {
        oldestKey = entry.key;
        oldestTime = entry.value.timestamp;
      }
    }
    
    final removedEntry = _memoryCache.remove(oldestKey);
    if (removedEntry != null) {
      _currentMemorySize -= removedEntry.size;
    }
  }

  /// Get data from disk cache
  Future<CacheEntry<T>?> _getDiskCache<T>(String key, T Function(dynamic) parser) async {
    try {
      final file = File('${_cacheDir.path}/$key.json');
      if (!file.existsSync()) return null;

      final jsonString = await file.readAsString();
      final json = jsonDecode(jsonString);
      
      return CacheEntry.fromJson<T>(json, parser);
    } catch (e) {
      return null;
    }
  }

  /// Set data in disk cache
  Future<void> _setDiskCache(String key, CacheEntry entry) async {
    try {
      final file = File('${_cacheDir.path}/$key.json');
      final json = jsonEncode(entry.toJson());
      await file.writeAsString(json);
    } catch (e) {
      // Ignore disk cache errors
    }
  }

  /// Calculate approximate size of data
  int _calculateSize(dynamic data) {
    try {
      if (data is String) return data.length * 2;
      if (data is List) return data.length * 1024; // Approximate
      if (data is Map) return jsonEncode(data).length * 2;
      return 1024; // Default size
    } catch (e) {
      return 1024;
    }
  }

  /// Remove specific key from cache
  Future<void> remove(String key) async {
    await initialize();
    
    // Remove from memory
    final memoryEntry = _memoryCache.remove(key);
    if (memoryEntry != null) {
      _currentMemorySize -= memoryEntry.size;
    }
    
    // Remove from disk
    try {
      final file = File('${_cacheDir.path}/$key.json');
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (e) {
      // Ignore errors
    }
  }

  /// Clear all cache
  Future<void> clear() async {
    await initialize();
    
    // Clear memory cache
    _memoryCache.clear();
    _currentMemorySize = 0;
    
    // Clear disk cache
    try {
      final files = _cacheDir.listSync();
      for (final file in files) {
        if (file is File && file.path.endsWith('.json')) {
          await file.delete();
        }
      }
    } catch (e) {
      // Ignore errors
    }
  }

  /// Clean expired cache entries
  Future<void> _cleanExpiredCache() async {
    final now = DateTime.now();
    
    // Clean memory cache
    final expiredMemoryKeys = <String>[];
    for (final entry in _memoryCache.entries) {
      if (entry.value.isExpired) {
        expiredMemoryKeys.add(entry.key);
      }
    }
    
    for (final key in expiredMemoryKeys) {
      final entry = _memoryCache.remove(key);
      if (entry != null) {
        _currentMemorySize -= entry.size;
      }
    }
    
    // Clean disk cache
    try {
      final files = _cacheDir.listSync();
      for (final file in files) {
        if (file is File && file.path.endsWith('.json')) {
          try {
            final content = await file.readAsString();
            final json = jsonDecode(content);
            final expiresAtStr = json['expiresAt'];
            
            if (expiresAtStr != null) {
              final expiresAt = DateTime.parse(expiresAtStr);
              if (now.isAfter(expiresAt)) {
                await file.delete();
              }
            }
          } catch (e) {
            // Delete corrupted files
            await file.delete();
          }
        }
      }
    } catch (e) {
      // Ignore errors
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getStats() {
    return {
      'memoryEntries': _memoryCache.length,
      'memorySize': _currentMemorySize,
      'memoryUsagePercent': (_currentMemorySize / maxMemoryCacheSize * 100).toStringAsFixed(1),
    };
  }

  /// Generate cache key for file lists
  String getFileListKey(String subjectId, String fileType, {int? page, int? limit}) {
    return _generateKey('files_list', {
      'subjectId': subjectId,
      'fileType': fileType,
      'page': page ?? 0,
      'limit': limit ?? 20,
    });
  }

  /// Generate cache key for file details
  String getFileDetailsKey(String fileId) {
    return _generateKey('file_details', {'fileId': fileId});
  }

  /// Generate cache key for search results
  String getSearchKey(String subjectId, String query, {int? page}) {
    return _generateKey('search_results', {
      'subjectId': subjectId,
      'query': query,
      'page': page ?? 0,
    });
  }

  /// Generate cache key for file stats
  String getFileStatsKey(String subjectId) {
    return _generateKey('file_stats', {'subjectId': subjectId});
  }
}
