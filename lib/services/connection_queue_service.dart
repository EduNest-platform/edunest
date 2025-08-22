import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

class ConnectionQueueService {
  static final Queue<_QueuedOperation> _operationQueue = Queue();
  static int _activeConnections = 0;
  static const int _maxConnections = 50; // Keep buffer below 60 limit
  static bool _isProcessing = false;

  /// Add operation to queue if connections are full
  static Future<T> executeWithQueue<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    // If we have available connections, execute immediately
    if (_activeConnections < _maxConnections) {
      return _executeOperation(operationName, operation);
    }

    // Otherwise, queue the operation
    final completer = Completer<T>();
    _operationQueue.add(_QueuedOperation<T>(
      name: operationName,
      operation: operation,
      completer: completer,
    ));

    if (kDebugMode) {
      print('⏳ Queued operation: $operationName (${_operationQueue.length} in queue)');
    }

    _processQueue();
    return completer.future;
  }

  static Future<T> _executeOperation<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    _activeConnections++;
    if (kDebugMode) {
      print('🔗 Executing: $operationName ($_activeConnections/$_maxConnections active)');
    }

    try {
      final result = await operation().timeout(
        const Duration(seconds: 8), // Shorter timeout to free connections faster
      );
      return result;
    } finally {
      _activeConnections--;
      _processQueue(); // Process next queued operation
    }
  }

  static Future<void> _processQueue() async {
    if (_isProcessing || _operationQueue.isEmpty || _activeConnections >= _maxConnections) {
      return;
    }

    _isProcessing = true;

    while (_operationQueue.isNotEmpty && _activeConnections < _maxConnections) {
      final queuedOp = _operationQueue.removeFirst();
      
      try {
        final result = await _executeOperation(queuedOp.name, queuedOp.operation);
        queuedOp.completer.complete(result);
      } catch (e) {
        queuedOp.completer.completeError(e);
      }
    }

    _isProcessing = false;
  }

  /// Get queue statistics
  static Map<String, int> getStats() {
    return {
      'active_connections': _activeConnections,
      'queued_operations': _operationQueue.length,
      'max_connections': _maxConnections,
      'available_slots': _maxConnections - _activeConnections,
    };
  }

  /// Clear queue (emergency use)
  static void clearQueue() {
    while (_operationQueue.isNotEmpty) {
      final op = _operationQueue.removeFirst();
      op.completer.completeError(Exception('Queue cleared'));
    }
  }
}

class _QueuedOperation<T> {
  final String name;
  final Future<T> Function() operation;
  final Completer<T> completer;

  _QueuedOperation({
    required this.name,
    required this.operation,
    required this.completer,
  });
}
