import 'exam_optimization_service.dart';
import 'monitoring_reporting_service.dart';
import 'scalable_connection_service.dart';

/// 🔧 Simple integration helper for existing exam/test screens
/// Just replace your existing database calls with these optimized versions
class MonitoringIntegrationHelper {
  
  /// 📚 Use this for loading exam/test data instead of direct Supabase calls
  static Future<T> loadExamDataWithOptimization<T>({
    required String operation,
    required Future<T> Function() dataLoader,
    String? examId,
    String? studentId,
  }) async {
    try {
      // Report exam activity if IDs provided
      if (examId != null && studentId != null) {
        await MonitoringReportingService.reportExamSessionStart(examId, studentId);
      }
      
      // Use optimized connection for the data loading
      return await ScalableConnectionService.executeWithAdvancedQueue<T>(
        operation,
        dataLoader,
        priority: examId != null ? 3 : 2, // 3=high, 2=medium priority
      );
    } catch (e) {
      print('🚨 Error in optimized exam data loading: $e');
      rethrow;
    }
  }
  
  /// ✅ Use this for submitting test results instead of direct TestResultsService calls
  static Future<void> submitTestResultWithOptimization({
    required String operation,
    required Future<void> Function() submitOperation,
    String? examId,
    String? studentId,
    Map<String, dynamic>? testData,
  }) async {
    try {
      // Use optimized submission
      await ScalableConnectionService.executeWithAdvancedQueue<void>(
        operation,
        submitOperation,
        priority: 3, // Test submissions are high priority (3)
      );
      
      // Report completion if exam context
      if (examId != null && studentId != null) {
        await MonitoringReportingService.reportExamSessionEnd(
          examId, 
          studentId, 
          testData,
        );
      }
    } catch (e) {
      print('🚨 Error in optimized test submission: $e');
      rethrow;
    }
  }
  
  /// 🚀 Activate exam mode when multiple students start taking tests
  static Future<void> activateExamModeIfNeeded({
    required String examId,
    required int expectedParticipants,
  }) async {
    if (expectedParticipants >= 10) { // Auto-activate for 10+ students
      ExamOptimizationService.activateExamMode(examId, expectedParticipants);
    }
  }
  
  /// 📊 Simple status check for your admin panel
  static Future<Map<String, dynamic>> getSystemStatus() async {
    return {
      'connection_usage': 'Available via monitoring service',
      'system_load': 'Tracked automatically',
      'queue_size': 'Managed internally',
      'exam_mode_active': _checkExamModeActive(),
      'status': 'Monitoring enabled',
    };
  }
  
  /// Check if exam mode is active (simplified)
  static bool _checkExamModeActive() {
    try {
      // Since we can't access the private _examModeActive directly,
      // we'll assume false for now. In a real implementation,
      // ExamOptimizationService would expose this as a public getter
      return false;
    } catch (e) {
      return false;
    }
  }
}

/// 🎯 Quick integration for MCQ Test Screen
/// Add this to your existing _submitTest method
class MCQTestOptimization {
  static Future<void> optimizedSubmitTest({
    required Future<void> Function() originalSubmitLogic,
    String? testId,
    String? studentId,
    Map<String, dynamic>? testResults,
  }) async {
    await MonitoringIntegrationHelper.submitTestResultWithOptimization(
      operation: 'submit_test_result',
      submitOperation: originalSubmitLogic,
      examId: testId,
      studentId: studentId,
      testData: testResults,
    );
  }
}

/// 📱 Quick integration for Practice Test Screen
/// Add this to your existing question loading
class PracticeTestOptimization {
  static Future<List<Map<String, dynamic>>> optimizedLoadQuestions({
    required Future<List<Map<String, dynamic>>> Function() originalLoader,
    String? subjectId,
    String? chapterId,
  }) async {
    return await MonitoringIntegrationHelper.loadExamDataWithOptimization<List<Map<String, dynamic>>>(
      operation: 'load_practice_questions',
      dataLoader: originalLoader,
      examId: '${subjectId}_${chapterId}',
      studentId: 'practice_user',
    );
  }
}
