import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../services/files_service.dart';
import '../services/cache_storage_service.dart';
import '../services/batch_api_service.dart';

enum FileResourceType {
  notes('notes'),
  assignments('assignments'),
  code('code'),
  payScreen('pay_screen'),
  pyq('pyq'),
  documents('documents'),
  videos('videos'),
  images('images'),
  others('others');

  const FileResourceType(this.value);
  final String value;
}

class PaginatedFileResult {
  final List<FileResource> files;
  final bool hasMore;
  final int currentPage;
  final int totalCount;
  final DateTime lastUpdated;

  PaginatedFileResult({
    required this.files,
    required this.hasMore,
    required this.currentPage,
    required this.totalCount,
    required this.lastUpdated,
  });

  PaginatedFileResult copyWith({
    List<FileResource>? files,
    bool? hasMore,
    int? currentPage,
    int? totalCount,
    DateTime? lastUpdated,
  }) {
    return PaginatedFileResult(
      files: files ?? this.files,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      totalCount: totalCount ?? this.totalCount,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class SearchResult {
  final List<FileResource> files;
  final String query;
  final DateTime timestamp;
  final bool fromCache;

  SearchResult({
    required this.files,
    required this.query,
    required this.timestamp,
    this.fromCache = false,
  });
}

class CachedFileResourceService extends ChangeNotifier {
  static CachedFileResourceService? _instance;
  static CachedFileResourceService get instance => _instance ??= CachedFileResourceService._();
  
  CachedFileResourceService._();

  final CacheStorageService _cache = CacheStorageService.instance;
  final BatchApiService _batch = BatchApiService.instance;

  // Configuration
  static const int defaultPageSize = 20;
  static const int maxCachedPages = 5;
  static const Duration searchDebounceDelay = Duration(milliseconds: 300);

  // State management
  final Map<String, PaginatedFileResult> _paginatedCache = {};
  final Map<String, FileResource> _fileDetailsCache = {};
  final Map<String, Timer> _searchTimers = {};
  final Map<String, bool> _loadingStates = {};

  // File list management
  final Map<String, StreamController<PaginatedFileResult>> _fileStreamControllers = {};
  final Map<String, StreamController<SearchResult>> _searchStreamControllers = {};

  bool _initialized = false;

  /// Initialize the service
  Future<void> initialize() async {
    if (_initialized) return;
    
    await _cache.initialize();
    _initialized = true;
  }

  /// Get paginated files for a subject and type with caching
  Future<PaginatedFileResult> getFiles({
    required String subjectId,
    required FileResourceType type,
    int page = 0,
    int pageSize = defaultPageSize,
    bool forceRefresh = false,
  }) async {
    await initialize();

    final cacheKey = _cache.getFileListKey(subjectId, type.value, page: page, limit: pageSize);
    
    // Return cached data if available and not forcing refresh
    if (!forceRefresh) {
      final cachedResult = await _cache.get<List<FileResource>>(
        cacheKey, 
        (data) => (data as List).map((item) => FileResource.fromJson(item)).toList(),
      );
      
      if (cachedResult != null) {
        final result = PaginatedFileResult(
          files: cachedResult,
          hasMore: cachedResult.length == pageSize,
          currentPage: page,
          totalCount: -1, // Unknown from cache
          lastUpdated: DateTime.now(),
        );
        
        _paginatedCache[cacheKey] = result;
        return result;
      }
    }

    // Mark as loading
    _setLoadingState(cacheKey, true);

    try {
      // Use batch API for optimization
      final files = await _batch.addToBatch<List<FileResource>>('getFiles', {
        'subjectId': subjectId,
        'fileType': type.value,
        'limit': pageSize,
        'offset': page * pageSize,
      });

      // Cache the result
      await _cache.set(cacheKey, files);

      final result = PaginatedFileResult(
        files: files,
        hasMore: files.length == pageSize,
        currentPage: page,
        totalCount: -1, // Would need separate API call to get total
        lastUpdated: DateTime.now(),
      );

      _paginatedCache[cacheKey] = result;
      return result;

    } catch (e) {
      // Return cached data as fallback if available
      final cachedResult = await _cache.get<List<FileResource>>(
        cacheKey,
        (data) => (data as List).map((item) => FileResource.fromJson(item)).toList(),
      );

      if (cachedResult != null) {
        return PaginatedFileResult(
          files: cachedResult,
          hasMore: false,
          currentPage: page,
          totalCount: -1,
          lastUpdated: DateTime.now(),
        );
      }

      rethrow;
    } finally {
      _setLoadingState(cacheKey, false);
    }
  }

  /// Get file stream for reactive UI updates
  Stream<PaginatedFileResult> getFileStream({
    required String subjectId,
    required FileResourceType type,
    int page = 0,
    int pageSize = defaultPageSize,
  }) {
    final streamKey = '${subjectId}_${type.value}_${page}_$pageSize';
    
    if (!_fileStreamControllers.containsKey(streamKey)) {
      _fileStreamControllers[streamKey] = StreamController<PaginatedFileResult>.broadcast();
      
      // Initialize with cached data then fetch fresh data
      _initializeFileStream(subjectId, type, page, pageSize, streamKey);
    }

    return _fileStreamControllers[streamKey]!.stream;
  }

  /// Initialize file stream with cached data then fresh data
  void _initializeFileStream(
    String subjectId, 
    FileResourceType type, 
    int page, 
    int pageSize, 
    String streamKey
  ) async {
    try {
      // First, emit cached data if available
      final cachedResult = await getFiles(
        subjectId: subjectId,
        type: type,
        page: page,
        pageSize: pageSize,
        forceRefresh: false,
      );
      
      _fileStreamControllers[streamKey]?.add(cachedResult);

      // Then fetch fresh data
      final freshResult = await getFiles(
        subjectId: subjectId,
        type: type,
        page: page,
        pageSize: pageSize,
        forceRefresh: true,
      );
      
      _fileStreamControllers[streamKey]?.add(freshResult);
    } catch (e) {
      _fileStreamControllers[streamKey]?.addError(e);
    }
  }

  /// Refresh files (pull-to-refresh functionality)
  Future<PaginatedFileResult> refreshFiles({
    required String subjectId,
    required FileResourceType type,
    int page = 0,
    int pageSize = defaultPageSize,
  }) async {
    // Clear cache for this specific query
    final cacheKey = _cache.getFileListKey(subjectId, type.value, page: page, limit: pageSize);
    await _cache.remove(cacheKey);

    // Fetch fresh data
    final result = await getFiles(
      subjectId: subjectId,
      type: type,
      page: page,
      pageSize: pageSize,
      forceRefresh: true,
    );

    // Notify stream listeners
    final streamKey = '${subjectId}_${type.value}_${page}_$pageSize';
    _fileStreamControllers[streamKey]?.add(result);

    return result;
  }

  /// Load next page of files
  Future<PaginatedFileResult> loadNextPage({
    required String subjectId,
    required FileResourceType type,
    required int currentPage,
    int pageSize = defaultPageSize,
  }) async {
    return getFiles(
      subjectId: subjectId,
      type: type,
      page: currentPage + 1,
      pageSize: pageSize,
    );
  }

  /// Get file details with lazy loading
  Future<FileResource?> getFileDetails(String fileId, {bool forceRefresh = false}) async {
    await initialize();

    // Check memory cache first
    if (!forceRefresh && _fileDetailsCache.containsKey(fileId)) {
      return _fileDetailsCache[fileId];
    }

    // Check disk cache
    final cacheKey = _cache.getFileDetailsKey(fileId);
    if (!forceRefresh) {
      final cachedFile = await _cache.get<FileResource>(
        cacheKey,
        (data) => FileResource.fromJson(data),
      );
      
      if (cachedFile != null) {
        _fileDetailsCache[fileId] = cachedFile;
        return cachedFile;
      }
    }

    try {
      // Use batch API
      final file = await _batch.addToBatch<FileResource?>('getFileDetails', {
        'fileId': fileId,
      });

      if (file != null) {
        // Cache in both memory and disk
        _fileDetailsCache[fileId] = file;
        await _cache.set(cacheKey, file);
      }

      return file;
    } catch (e) {
      // Return cached data as fallback
      final cachedFile = await _cache.get<FileResource>(
        cacheKey,
        (data) => FileResource.fromJson(data),
      );
      
      if (cachedFile != null) {
        _fileDetailsCache[fileId] = cachedFile;
        return cachedFile;
      }

      rethrow;
    }
  }

  /// Search files with debouncing and caching
  Future<SearchResult> searchFiles({
    required String subjectId,
    required String query,
    int page = 0,
    bool forceRefresh = false,
  }) async {
    await initialize();

    // Debounce search requests
    final searchKey = '${subjectId}_search';
    _searchTimers[searchKey]?.cancel();

    final completer = Completer<SearchResult>();

    _searchTimers[searchKey] = Timer(searchDebounceDelay, () async {
      try {
        final result = await _performSearch(subjectId, query, page, forceRefresh);
        completer.complete(result);
      } catch (e) {
        completer.completeError(e);
      }
    });

    return completer.future;
  }

  /// Perform actual search with caching
  Future<SearchResult> _performSearch(
    String subjectId, 
    String query, 
    int page, 
    bool forceRefresh
  ) async {
    final cacheKey = _cache.getSearchKey(subjectId, query, page: page);

    // Check cache first
    if (!forceRefresh) {
      final cachedResults = await _cache.get<List<FileResource>>(
        cacheKey,
        (data) => (data as List).map((item) => FileResource.fromJson(item)).toList(),
      );

      if (cachedResults != null) {
        return SearchResult(
          files: cachedResults,
          query: query,
          timestamp: DateTime.now(),
          fromCache: true,
        );
      }
    }

    try {
      // Use batch API
      final files = await _batch.addToBatch<List<FileResource>>('searchFiles', {
        'subjectId': subjectId,
        'query': query,
      });

      // Apply pagination to results
      final startIndex = page * defaultPageSize;
      final endIndex = startIndex + defaultPageSize;
      final paginatedFiles = files.skip(startIndex).take(defaultPageSize).toList();

      // Cache the full results
      await _cache.set(cacheKey, files, expiration: Duration(minutes: 15));

      return SearchResult(
        files: paginatedFiles,
        query: query,
        timestamp: DateTime.now(),
        fromCache: false,
      );
    } catch (e) {
      // Return cached data as fallback
      final cachedResults = await _cache.get<List<FileResource>>(
        cacheKey,
        (data) => (data as List).map((item) => FileResource.fromJson(item)).toList(),
      );

      if (cachedResults != null) {
        return SearchResult(
          files: cachedResults,
          query: query,
          timestamp: DateTime.now(),
          fromCache: true,
        );
      }

      rethrow;
    }
  }

  /// Get search stream for reactive search UI
  Stream<SearchResult> getSearchStream({
    required String subjectId,
    required String query,
  }) {
    final streamKey = '${subjectId}_search_$query';
    
    if (!_searchStreamControllers.containsKey(streamKey)) {
      _searchStreamControllers[streamKey] = StreamController<SearchResult>.broadcast();
    }

    // Perform search and emit result
    searchFiles(subjectId: subjectId, query: query).then((result) {
      _searchStreamControllers[streamKey]?.add(result);
    }).catchError((error) {
      _searchStreamControllers[streamKey]?.addError(error);
    });

    return _searchStreamControllers[streamKey]!.stream;
  }

  /// Get file statistics with caching
  Future<Map<String, int>> getFileStats(String subjectId, {bool forceRefresh = false}) async {
    await initialize();

    final cacheKey = _cache.getFileStatsKey(subjectId);

    if (!forceRefresh) {
      final cachedStats = await _cache.get<Map<String, int>>(
        cacheKey,
        (data) => Map<String, int>.from(data),
      );

      if (cachedStats != null) {
        return cachedStats;
      }
    }

    try {
      final stats = await _batch.addToBatch<Map<String, int>>('getFileStats', {
        'subjectId': subjectId,
      });

      await _cache.set(cacheKey, stats, expiration: Duration(hours: 1));
      return stats;
    } catch (e) {
      // Return cached data as fallback
      final cachedStats = await _cache.get<Map<String, int>>(
        cacheKey,
        (data) => Map<String, int>.from(data),
      );

      return cachedStats ?? {};
    }
  }

  /// Prefetch files for better performance
  Future<void> prefetchFiles({
    required String subjectId,
    required List<FileResourceType> types,
    int pagesToPrefetch = 2,
  }) async {
    final futures = <Future>[];

    for (final type in types) {
      for (int page = 0; page < pagesToPrefetch; page++) {
        futures.add(
          getFiles(
            subjectId: subjectId,
            type: type,
            page: page,
          ).catchError((e) {
            // Ignore prefetch errors
            debugPrint('Prefetch error for ${type.value} page $page: $e');
          }),
        );
      }
    }

    await Future.wait(futures);
  }

  /// Clear cache for specific subject
  Future<void> clearSubjectCache(String subjectId) async {
    // This would require implementing pattern-based cache clearing
    // For now, clear all cache
    await _cache.clear();
    _paginatedCache.clear();
    _fileDetailsCache.clear();
    notifyListeners();
  }

  /// Clear all caches
  Future<void> clearAllCache() async {
    await _cache.clear();
    _paginatedCache.clear();
    _fileDetailsCache.clear();
    
    // Close all stream controllers
    for (final controller in _fileStreamControllers.values) {
      controller.close();
    }
    _fileStreamControllers.clear();

    for (final controller in _searchStreamControllers.values) {
      controller.close();
    }
    _searchStreamControllers.clear();

    notifyListeners();
  }

  /// Set loading state
  void _setLoadingState(String key, bool isLoading) {
    _loadingStates[key] = isLoading;
    notifyListeners();
  }

  /// Check if loading
  bool isLoading(String key) {
    return _loadingStates[key] ?? false;
  }

  /// Get service statistics
  Map<String, dynamic> getStats() {
    return {
      'cache': _cache.getStats(),
      'batch': _batch.getStats(),
      'paginatedCache': _paginatedCache.length,
      'fileDetailsCache': _fileDetailsCache.length,
      'activeStreams': _fileStreamControllers.length,
      'activeSearchStreams': _searchStreamControllers.length,
      'loadingStates': _loadingStates.length,
    };
  }

  @override
  void dispose() {
    // Cancel all timers
    for (final timer in _searchTimers.values) {
      timer.cancel();
    }
    _searchTimers.clear();

    // Close all stream controllers
    for (final controller in _fileStreamControllers.values) {
      controller.close();
    }
    _fileStreamControllers.clear();

    for (final controller in _searchStreamControllers.values) {
      controller.close();
    }
    _searchStreamControllers.clear();

    super.dispose();
  }
}
