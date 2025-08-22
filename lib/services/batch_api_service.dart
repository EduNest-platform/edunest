import 'dart:async';
import 'dart:collection';
import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/files_service.dart';
import '../services/rate_limiter_service.dart';

class BatchRequest {
  final String id;
  final String type;
  final Map<String, dynamic> params;
  final Completer<dynamic> completer;
  final DateTime timestamp;

  BatchRequest({
    required this.id,
    required this.type,
    required this.params,
    required this.completer,
    required this.timestamp,
  });
}

class BatchResponse {
  final String requestId;
  final dynamic data;
  final dynamic error;
  final bool success;

  BatchResponse({
    required this.requestId,
    required this.data,
    this.error,
    this.success = true,
  });
}

class BatchApiService {
  static BatchApiService? _instance;
  static BatchApiService get instance => _instance ??= BatchApiService._();
  
  BatchApiService._();

  static final SupabaseClient _supabase = Supabase.instance.client;
  
  // Batch configuration
  static const int maxBatchSize = 10;
  static const Duration batchTimeout = Duration(milliseconds: 500);
  static const Duration maxWaitTime = Duration(seconds: 5);
  
  final Queue<BatchRequest> _pendingRequests = Queue<BatchRequest>();
  Timer? _batchTimer;
  bool _isProcessing = false;

  /// Add a request to the batch queue
  Future<T> addToBatch<T>(String type, Map<String, dynamic> params) async {
    final completer = Completer<T>();
    final request = BatchRequest(
      id: _generateRequestId(),
      type: type,
      params: params,
      completer: completer,
      timestamp: DateTime.now(),
    );

    _pendingRequests.add(request);
    
    // Start batch timer if not already running
    _startBatchTimer();
    
    return completer.future;
  }

  /// Generate unique request ID
  String _generateRequestId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${_pendingRequests.length}';
  }

  /// Start batch processing timer
  void _startBatchTimer() {
    if (_batchTimer != null && _batchTimer!.isActive) return;

    _batchTimer = Timer(batchTimeout, () {
      _processBatch();
    });
  }

  /// Process current batch of requests
  Future<void> _processBatch() async {
    if (_isProcessing || _pendingRequests.isEmpty) return;

    _isProcessing = true;
    
    try {
      // Group requests by type
      final Map<String, List<BatchRequest>> groupedRequests = {};
      final List<BatchRequest> currentBatch = [];
      
      // Take up to maxBatchSize requests
      while (_pendingRequests.isNotEmpty && currentBatch.length < maxBatchSize) {
        final request = _pendingRequests.removeFirst();
        
        // Check if request has timed out
        if (DateTime.now().difference(request.timestamp) > maxWaitTime) {
          request.completer.completeError('Request timeout');
          continue;
        }
        
        currentBatch.add(request);
        
        if (!groupedRequests.containsKey(request.type)) {
          groupedRequests[request.type] = [];
        }
        groupedRequests[request.type]!.add(request);
      }

      // Process each group
      await Future.wait(
        groupedRequests.entries.map((entry) => _processGroup(entry.key, entry.value))
      );

    } catch (e) {
      // Handle any processing errors
      developer.log('Batch processing error: $e', name: 'BatchApiService');
    } finally {
      _isProcessing = false;
      
      // Schedule next batch if there are more requests
      if (_pendingRequests.isNotEmpty) {
        _startBatchTimer();
      }
    }
  }

  /// Process a group of requests of the same type
  Future<void> _processGroup(String type, List<BatchRequest> requests) async {
    try {
      switch (type) {
        case 'getFiles':
          await _processGetFilesBatch(requests);
          break;
        case 'getFileDetails':
          await _processGetFileDetailsBatch(requests);
          break;
        case 'searchFiles':
          await _processSearchFilesBatch(requests);
          break;
        case 'getFileStats':
          await _processGetFileStatsBatch(requests);
          break;
        default:
          // Handle unknown request types
          for (final request in requests) {
            request.completer.completeError('Unknown request type: $type');
          }
      }
    } catch (e) {
      // Complete all requests with error
      for (final request in requests) {
        if (!request.completer.isCompleted) {
          request.completer.completeError(e);
        }
      }
    }
  }

  /// Process batch of getFiles requests
  Future<void> _processGetFilesBatch(List<BatchRequest> requests) async {
    try {
      // Group by subject and file type for optimization
      final Map<String, List<BatchRequest>> subjectGroups = {};
      
      for (final request in requests) {
        final subjectId = request.params['subjectId'];
        final fileType = request.params['fileType'];
        final key = '${subjectId}_$fileType';
        
        if (!subjectGroups.containsKey(key)) {
          subjectGroups[key] = [];
        }
        subjectGroups[key]!.add(request);
      }

      // Process each subject group
      for (final entry in subjectGroups.entries) {
        await _processSingleGetFilesGroup(entry.value);
      }
    } catch (e) {
      for (final request in requests) {
        if (!request.completer.isCompleted) {
          request.completer.completeError(e);
        }
      }
    }
  }

  /// Process single group of getFiles requests for same subject/type
  Future<void> _processSingleGetFilesGroup(List<BatchRequest> requests) async {
    if (requests.isEmpty) return;

    final firstRequest = requests.first;
    final subjectId = firstRequest.params['subjectId'];
    final fileType = firstRequest.params['fileType'];

    try {
      // Make single API call for all requests in this group
      final response = await RateLimiterService.executeWithLimit(() async {
        return await _supabase
            .from('files')
            .select()
            .eq('subject_id', subjectId)
            .eq('file_type', fileType)
            .order('created_at', ascending: false);
      });

      final files = (response as List)
          .map((file) => FileResource.fromJson(file))
          .toList();

      // Complete all requests with the same result
      for (final request in requests) {
        if (!request.completer.isCompleted) {
          // Apply pagination if specified
          final limit = request.params['limit'] as int?;
          final offset = request.params['offset'] as int?;
          
          List<FileResource> paginatedFiles = files;
          if (offset != null) {
            paginatedFiles = files.skip(offset).toList();
          }
          if (limit != null) {
            paginatedFiles = paginatedFiles.take(limit).toList();
          }
          
          request.completer.complete(paginatedFiles);
        }
      }
    } catch (e) {
      for (final request in requests) {
        if (!request.completer.isCompleted) {
          request.completer.completeError(e);
        }
      }
    }
  }

  /// Process batch of getFileDetails requests
  Future<void> _processGetFileDetailsBatch(List<BatchRequest> requests) async {
    try {
      // Extract all file IDs
      final fileIds = requests.map((r) => r.params['fileId']).toList();

      // Make single batch query
      final response = await RateLimiterService.executeWithLimit(() async {
        return await _supabase
            .from('files')
            .select()
            .inFilter('id', fileIds);
      });

      final filesMap = <String, FileResource>{};
      for (final fileData in response as List) {
        final file = FileResource.fromJson(fileData);
        filesMap[file.id] = file;
      }

      // Complete individual requests
      for (final request in requests) {
        if (!request.completer.isCompleted) {
          final fileId = request.params['fileId'];
          final file = filesMap[fileId];
          request.completer.complete(file);
        }
      }
    } catch (e) {
      for (final request in requests) {
        if (!request.completer.isCompleted) {
          request.completer.completeError(e);
        }
      }
    }
  }

  /// Process batch of searchFiles requests
  Future<void> _processSearchFilesBatch(List<BatchRequest> requests) async {
    try {
      // Group by subject and query for optimization
      final Map<String, List<BatchRequest>> searchGroups = {};
      
      for (final request in requests) {
        final subjectId = request.params['subjectId'];
        final query = request.params['query'];
        final key = '${subjectId}_$query';
        
        if (!searchGroups.containsKey(key)) {
          searchGroups[key] = [];
        }
        searchGroups[key]!.add(request);
      }

      // Process each search group
      for (final entry in searchGroups.entries) {
        await _processSingleSearchGroup(entry.value);
      }
    } catch (e) {
      for (final request in requests) {
        if (!request.completer.isCompleted) {
          request.completer.completeError(e);
        }
      }
    }
  }

  /// Process single group of search requests
  Future<void> _processSingleSearchGroup(List<BatchRequest> requests) async {
    if (requests.isEmpty) return;

    final firstRequest = requests.first;
    final subjectId = firstRequest.params['subjectId'];
    final query = firstRequest.params['query'];

    try {
      final response = await RateLimiterService.executeWithLimit(() async {
        return await _supabase
            .from('files')
            .select()
            .eq('subject_id', subjectId)
            .or('name.ilike.%$query%,description.ilike.%$query%')
            .order('created_at', ascending: false);
      });

      final files = (response as List)
          .map((file) => FileResource.fromJson(file))
          .toList();

      // Complete all requests with the same result
      for (final request in requests) {
        if (!request.completer.isCompleted) {
          request.completer.complete(files);
        }
      }
    } catch (e) {
      for (final request in requests) {
        if (!request.completer.isCompleted) {
          request.completer.completeError(e);
        }
      }
    }
  }

  /// Process batch of getFileStats requests
  Future<void> _processGetFileStatsBatch(List<BatchRequest> requests) async {
    try {
      // Extract all subject IDs
      final subjectIds = requests.map((r) => r.params['subjectId']).toList();

      // Make single batch query
      final response = await RateLimiterService.executeWithLimit(() async {
        return await _supabase
            .from('files')
            .select('subject_id, file_type')
            .inFilter('subject_id', subjectIds);
      });

      // Group results by subject
      final Map<String, Map<String, int>> subjectStats = {};
      for (final fileData in response as List) {
        final subjectId = fileData['subject_id'];
        final fileType = fileData['file_type'];
        
        if (!subjectStats.containsKey(subjectId)) {
          subjectStats[subjectId] = {};
        }
        
        subjectStats[subjectId]![fileType] = 
            (subjectStats[subjectId]![fileType] ?? 0) + 1;
      }

      // Complete individual requests
      for (final request in requests) {
        if (!request.completer.isCompleted) {
          final subjectId = request.params['subjectId'];
          final stats = subjectStats[subjectId] ?? {};
          request.completer.complete(stats);
        }
      }
    } catch (e) {
      for (final request in requests) {
        if (!request.completer.isCompleted) {
          request.completer.completeError(e);
        }
      }
    }
  }

  /// Get batch queue statistics
  Map<String, dynamic> getStats() {
    final typeCount = <String, int>{};
    for (final request in _pendingRequests) {
      typeCount[request.type] = (typeCount[request.type] ?? 0) + 1;
    }

    return {
      'queueSize': _pendingRequests.length,
      'isProcessing': _isProcessing,
      'typeBreakdown': typeCount,
      'batchTimerActive': _batchTimer?.isActive ?? false,
    };
  }

  /// Clear all pending requests
  void clearQueue() {
    // Complete all pending requests with cancellation error
    while (_pendingRequests.isNotEmpty) {
      final request = _pendingRequests.removeFirst();
      if (!request.completer.isCompleted) {
        request.completer.completeError('Request cancelled');
      }
    }

    // Cancel batch timer
    _batchTimer?.cancel();
    _batchTimer = null;
  }

  /// Force process current batch immediately
  Future<void> flush() async {
    _batchTimer?.cancel();
    await _processBatch();
  }

  /// Dispose of the service
  void dispose() {
    clearQueue();
  }
}
