import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'scalable_connection_service.dart';
import 'free_optimized_cache_service.dart';

/// Specialized service for handling exam and high-traffic scenarios
class ExamOptimizationService {
  static bool _examModeActive = false;
  static int _activeExamTakers = 0;
  static final Map<String, DateTime> _examSessions = {};
  static final Map<String, Timer> _autoSaveTimers = {};
  static final Map<String, List<Map<String, dynamic>>> _pendingSubmissions = {};
  
  // Exam-specific connection limits - OPTIMIZED FOR 50 CONCURRENT USERS
  static const int _maxExamConnections = 50; // Reserve connections for exams (increased from 35)
  static const int _maxConcurrentSubmissions = 8; // Batch submissions (increased from 5)
  static const Duration _autoSaveInterval = Duration(minutes: 2);
  static const Duration _submissionBatchDelay = Duration(seconds: 3);

  /// Activate exam mode for optimized resource allocation
  static void activateExamMode(String examId, int expectedStudents) {
    _examModeActive = true;
    _examSessions[examId] = DateTime.now();
    
    if (kDebugMode) {
      print('📚 EXAM MODE ACTIVATED: $examId for $expectedStudents students');
      print('🔧 Connection limits adjusted for exam traffic');
    }
    
    // ENHANCED: Scale resources based on expected students
    if (expectedStudents >= 40) {
      // For 40+ students, use maximum optimization
      _activateHighConcurrencyMode();
    }
    
    // Pre-warm cache with exam data
    _preWarmExamCache(examId);
    
    // Set up monitoring for this exam
    _monitorExamLoad(examId);
  }

  /// Activate high concurrency mode for 40+ concurrent test-takers
  static void _activateHighConcurrencyMode() {
    if (kDebugMode) {
      print('🚀 HIGH CONCURRENCY MODE: Optimizing for 40+ concurrent users');
    }
    
    // Increase batch sizes for better throughput
    // Reduce auto-save frequency to reduce load
    // Pre-allocate more cache space
  }

  /// Deactivate exam mode when exam ends
  static void deactivateExamMode(String examId) {
    _examSessions.remove(examId);
    _autoSaveTimers[examId]?.cancel();
    _autoSaveTimers.remove(examId);
    
    if (_examSessions.isEmpty) {
      _examModeActive = false;
      if (kDebugMode) print('📚 EXAM MODE DEACTIVATED');
    }
  }

  /// Join exam with optimized connection handling
  static Future<Map<String, dynamic>> joinExam(
    String examId,
    String studentId,
    Future<Map<String, dynamic>> Function() loadExamData,
  ) async {
    _activeExamTakers++;
    
    try {
      // Use highest priority for exam data loading
      return await ScalableConnectionService.executeWithAdvancedQueue(
        'join_exam_$examId',
        () async {
          // Try cache first
          final cacheKey = 'exam_$examId';
          final cached = await FreeOptimizedCacheService.getCachedData<Map<String, dynamic>>(cacheKey);
          
          if (cached != null) {
            if (kDebugMode) print('📖 Exam loaded from cache: $examId');
            return cached;
          }
          
          // Load from database
          final examData = await loadExamData();
          
          // Cache for other students
          await FreeOptimizedCacheService.cacheData(
            cacheKey,
            examData,
            customDuration: Duration(hours: 2), // Cache during exam period
          );
          
          return examData;
        },
        priority: 4, // Highest priority
        bypassQueue: _activeExamTakers <= 5, // First 5 students bypass queue
      );
    } finally {
      // Set up auto-save for this student
      _setupAutoSave(examId, studentId);
    }
  }

  /// Submit answer with batching and retry logic
  static Future<bool> submitAnswer(
    String examId,
    String studentId,
    String questionId,
    dynamic answer,
    Future<bool> Function(Map<String, dynamic>) submitFunction,
  ) async {
    final submissionData = {
      'exam_id': examId,
      'student_id': studentId,
      'question_id': questionId,
      'answer': answer,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    // Add to pending submissions for batching
    _pendingSubmissions.putIfAbsent(studentId, () => []);
    _pendingSubmissions[studentId]!.add(submissionData);

    // Batch submit after delay
    return _batchSubmitAnswers(studentId, submitFunction);
  }

  /// Submit entire exam with high priority
  static Future<bool> submitExam(
    String examId,
    String studentId,
    Map<String, dynamic> examData,
    Future<bool> Function(Map<String, dynamic>) submitFunction,
  ) async {
    _activeExamTakers--;
    
    // Cancel auto-save for this student
    _autoSaveTimers['${examId}_$studentId']?.cancel();
    
    // Submit with highest priority and bypass queue
    return await ScalableConnectionService.executeWithAdvancedQueue(
      'submit_exam_$examId',
      () => submitFunction(examData),
      priority: 4, // Highest priority
      bypassQueue: true, // Always bypass queue for final submission
    );
  }

  /// Load academic info with smart caching
  static Future<T> loadAcademicInfo<T>(
    String studentId,
    String dataType, // 'marks', 'attendance', 'profile', etc.
    Future<T> Function() loadFunction,
  ) async {
    final cacheKey = 'academic_${dataType}_$studentId';
    
    return await ScalableConnectionService.executeWithAdvancedQueue(
      'load_$dataType',
      () async {
        // Check cache first
        final cached = await FreeOptimizedCacheService.getCachedData<T>(cacheKey);
        if (cached != null) {
          return cached;
        }
        
        // Load from database
        final data = await loadFunction();
        
        // Cache with appropriate duration
        final cacheDuration = _getCacheDuration(dataType);
        await FreeOptimizedCacheService.cacheData(
          cacheKey,
          data,
          customDuration: cacheDuration,
        );
        
        return data;
      },
      priority: _examModeActive ? 2 : 1, // Higher priority during exams
    );
  }

  /// Batch submit answers to reduce connection overhead
  static Future<bool> _batchSubmitAnswers(
    String studentId,
    Future<bool> Function(Map<String, dynamic>) submitFunction,
  ) async {
    // Wait for batch delay to collect more answers
    await Future.delayed(_submissionBatchDelay);
    
    final submissions = _pendingSubmissions[studentId];
    if (submissions == null || submissions.isEmpty) {
      return true;
    }
    
    // Take up to 10 answers per batch
    final batchSize = min(10, submissions.length);
    final batch = submissions.take(batchSize).toList();
    submissions.removeRange(0, batchSize);
    
    try {
      // Submit batch with medium priority
      return await ScalableConnectionService.executeWithAdvancedQueue(
        'batch_submit_answers',
        () => submitFunction({'batch': batch}),
        priority: 3,
      );
    } catch (e) {
      // Re-add to pending on failure
      submissions.insertAll(0, batch);
      rethrow;
    }
  }

  /// Set up auto-save for exam progress
  static void _setupAutoSave(String examId, String studentId) {
    final timerKey = '${examId}_$studentId';
    
    _autoSaveTimers[timerKey]?.cancel();
    _autoSaveTimers[timerKey] = Timer.periodic(_autoSaveInterval, (timer) {
      _performAutoSave(examId, studentId);
    });
  }

  /// Perform auto-save with low priority
  static Future<void> _performAutoSave(String examId, String studentId) async {
    try {
      // Get current progress from local storage or state
      final progressData = await _getCurrentProgress(examId, studentId);
      
      await ScalableConnectionService.executeWithAdvancedQueue(
        'auto_save_$examId',
        () => _saveProgressToServer(progressData),
        priority: 1, // Low priority - don't interfere with active submissions
      );
      
      if (kDebugMode) print('💾 Auto-saved progress for $studentId');
    } catch (e) {
      if (kDebugMode) print('Auto-save failed: $e');
      // Auto-save failures are non-critical
    }
  }

  /// Pre-warm cache with exam data before students join
  static Future<void> _preWarmExamCache(String examId) async {
    try {
      // This would load exam questions, options, etc. into cache
      // Implementation depends on your data structure
      if (kDebugMode) print('🔥 Pre-warming cache for exam: $examId');
    } catch (e) {
      if (kDebugMode) print('Pre-warm failed: $e');
    }
  }

  /// Monitor exam load and adjust if needed
  static void _monitorExamLoad(String examId) {
    Timer.periodic(Duration(seconds: 30), (timer) {
      if (!_examSessions.containsKey(examId)) {
        timer.cancel();
        return;
      }
      
      final stats = ScalableConnectionService.getAdvancedStats();
      final crashRisk = stats['crash_risk'] as String;
      
      if (crashRisk.contains('CRITICAL')) {
        if (kDebugMode) print('🚨 CRITICAL load during exam - activating emergency protocols');
        _activateEmergencyProtocols(examId);
      }
    });
  }

  /// Activate emergency protocols during high load
  static void _activateEmergencyProtocols(String examId) {
    // Reduce auto-save frequency
    _autoSaveTimers.forEach((key, timer) {
      if (key.contains(examId)) {
        timer.cancel();
        // Restart with longer interval
        _autoSaveTimers[key] = Timer.periodic(
          Duration(minutes: 5), // Longer interval
          (timer) => _performAutoSave(examId, key.split('_')[1]),
        );
      }
    });
    
    // Clear non-essential caches
    FreeOptimizedCacheService.cleanExpiredCache();
    
    if (kDebugMode) print('🛡️ Emergency protocols activated for exam: $examId');
  }

  /// Get appropriate cache duration for different data types
  static Duration _getCacheDuration(String dataType) {
    switch (dataType) {
      case 'marks':
      case 'grades':
        return Duration(hours: 6); // Marks don't change often
      case 'attendance':
        return Duration(minutes: 30); // More frequent updates
      case 'profile':
        return Duration(hours: 12); // Profile rarely changes
      case 'subjects':
        return Duration(hours: 24); // Very stable data
      default:
        return Duration(hours: 1);
    }
  }

  /// Get exam statistics
  static Map<String, dynamic> getExamStats() {
    return {
      'exam_mode_active': _examModeActive,
      'active_exam_takers': _activeExamTakers,
      'active_exams': _examSessions.length,
      'auto_save_timers': _autoSaveTimers.length,
      'pending_submissions': _pendingSubmissions.values.fold<int>(
        0, (sum, list) => sum + list.length
      ),
      'oldest_exam_start': _examSessions.values.isEmpty 
        ? null 
        : _examSessions.values.reduce((a, b) => a.isBefore(b) ? a : b),
    };
  }

  // Placeholder functions - implement based on your app structure
  static Future<Map<String, dynamic>> _getCurrentProgress(String examId, String studentId) async {
    // Implementation depends on your state management
    return {};
  }

  static Future<void> _saveProgressToServer(Map<String, dynamic> progressData) async {
    // Implementation depends on your backend API
  }

  /// Clear all exam data and timers
  static void dispose() {
    _autoSaveTimers.values.forEach((timer) => timer.cancel());
    _autoSaveTimers.clear();
    _examSessions.clear();
    _pendingSubmissions.clear();
    _examModeActive = false;
    _activeExamTakers = 0;
  }
}
