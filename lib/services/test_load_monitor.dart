import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

/// Specialized monitoring for test load scenarios
class TestLoadMonitor {
  static final Map<String, TestLoadStats> _testStats = {};
  static Timer? _monitoringTimer;
  static bool _isMonitoring = false;

  /// Start monitoring test load
  static void startMonitoring(String testId, int expectedStudents) {
    _testStats[testId] = TestLoadStats(
      testId: testId,
      expectedStudents: expectedStudents,
      startTime: DateTime.now(),
    );

    if (!_isMonitoring) {
      _isMonitoring = true;
      _monitoringTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _checkTestLoad(),
      );
    }

    if (kDebugMode) {
      print('📊 Test load monitoring started for $testId ($expectedStudents expected)');
    }
  }

  /// Stop monitoring test load
  static void stopMonitoring(String testId) {
    final stats = _testStats.remove(testId);
    if (stats != null && kDebugMode) {
      final duration = DateTime.now().difference(stats.startTime);
      print('📊 Test completed: $testId (${duration.inMinutes}min, ${stats.peakConcurrent} peak users)');
    }

    if (_testStats.isEmpty) {
      _isMonitoring = false;
      _monitoringTimer?.cancel();
    }
  }

  /// Record student joining test
  static void recordStudentJoin(String testId, String studentId) {
    final stats = _testStats[testId];
    if (stats != null) {
      stats.currentStudents.add(studentId);
      stats.peakConcurrent = max(stats.peakConcurrent, stats.currentStudents.length);
      
      if (kDebugMode && stats.currentStudents.length % 10 == 0) {
        print('📈 Test $testId: ${stats.currentStudents.length} concurrent users');
      }
    }
  }

  /// Record student leaving test
  static void recordStudentLeave(String testId, String studentId) {
    final stats = _testStats[testId];
    if (stats != null) {
      stats.currentStudents.remove(studentId);
    }
  }

  /// Check current test load and provide recommendations
  static void _checkTestLoad() {
    for (final stats in _testStats.values) {
      final currentLoad = stats.currentStudents.length;
      final expectedLoad = stats.expectedStudents;
      
      if (currentLoad >= expectedLoad * 0.8) {
        // 80% of expected load reached
        _triggerHighLoadOptimizations(stats.testId);
      }
      
      if (currentLoad >= 45) {
        // Critical threshold reached
        _triggerCriticalLoadMode(stats.testId);
      }
    }
  }

  /// Trigger optimizations for high load
  static void _triggerHighLoadOptimizations(String testId) {
    if (kDebugMode) {
      print('⚡ High load detected for test $testId - applying optimizations');
    }
    
    // Could trigger:
    // - Increased cache retention
    // - Reduced background operations
    // - Priority queue adjustments
  }

  /// Trigger critical load mode
  static void _triggerCriticalLoadMode(String testId) {
    if (kDebugMode) {
      print('🚨 Critical load detected for test $testId - emergency optimizations active');
    }
    
    // Could trigger:
    // - Emergency connection pool expansion
    // - Deferred non-critical operations
    // - Enhanced error recovery
  }

  /// Get current test statistics
  static Map<String, dynamic> getTestStats() {
    final totalConcurrent = _testStats.values
        .map((s) => s.currentStudents.length)
        .fold(0, (a, b) => a + b);
    
    final maxPeak = _testStats.values
        .map((s) => s.peakConcurrent)
        .fold(0, (a, b) => max(a, b));

    return {
      'active_tests': _testStats.length,
      'total_concurrent_users': totalConcurrent,
      'peak_concurrent_users': maxPeak,
      'tests': _testStats.map((id, stats) => MapEntry(id, {
        'current_students': stats.currentStudents.length,
        'expected_students': stats.expectedStudents,
        'peak_concurrent': stats.peakConcurrent,
        'duration_minutes': DateTime.now().difference(stats.startTime).inMinutes,
      })),
    };
  }
}

/// Statistics for individual test sessions
class TestLoadStats {
  final String testId;
  final int expectedStudents;
  final DateTime startTime;
  final Set<String> currentStudents = {};
  int peakConcurrent = 0;

  TestLoadStats({
    required this.testId,
    required this.expectedStudents,
    required this.startTime,
  });
}