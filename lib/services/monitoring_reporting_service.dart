import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'scalable_connection_service.dart';
import 'exam_optimization_service.dart';
import 'free_optimized_cache_service.dart';

/// Service to send monitoring data to Supabase ADMIN database for Super Admin dashboard
class MonitoringReportingService {
  // 🔧 ADMIN DATABASE CREDENTIALS (separate from main app database)
  static const String _adminSupabaseUrl = 'https://pfuzvpihupvhjshxiofn.supabase.co';
  static const String _adminSupabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBmdXp2cGlodXB2aGpzaHhpb2ZuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE1Mjg1MjIsImV4cCI6MjA2NzEwNDUyMn0.WAPJG6iaxuCAM75yCRu6UOcck37XuilVoDJK3uwyx-k';
  
  static SupabaseClient? _adminClient;
  static Timer? _reportingTimer;
  static bool _isReporting = false;
  static String? _appVersion;
  static String? _platform;
  
  /// Initialize monitoring reporting to ADMIN database
  static Future<void> initialize() async {
    if (_isReporting) return;
    
    // Initialize admin client (separate from main app database)
    try {
      _adminClient = SupabaseClient(_adminSupabaseUrl, _adminSupabaseKey);
      print('✅ Connected to admin monitoring database');
    } catch (e) {
      print('⚠️ Warning: Could not connect to admin database: $e');
      return;
    }
    
    // Get app info
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = packageInfo.version;
      _platform = Platform.isAndroid ? 'Android' : 
                  Platform.isIOS ? 'iOS' : 
                  Platform.isWindows ? 'Windows' : 
                  Platform.isMacOS ? 'macOS' : 
                  Platform.isLinux ? 'Linux' : 'Unknown';
    } catch (e) {
      _appVersion = 'Unknown';
      _platform = 'Unknown';
    }
    
    _isReporting = true;
    
    // Report stats every 5 minutes instead of 30 seconds
    _reportingTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _reportSystemStats(),
    );
    
    // Initial report
    await _reportSystemStats();
    
    if (kDebugMode) {
      print('📊 Monitoring reporting service initialized');
    }
  }
  
  /// Stop monitoring reporting
  static void dispose() {
    _reportingTimer?.cancel();
    _isReporting = false;
  }
  
  /// Report current system statistics to Supabase
  static Future<void> _reportSystemStats() async {
    if (!_isReporting) return;
    
    try {
      // Gather stats from all monitoring services
      final systemStats = ScalableConnectionService.getAdvancedStats();
      final examStats = ExamOptimizationService.getExamStats();
      final cacheStats = FreeOptimizedCacheService.getCacheStats();
      
      // Send data to ADMIN database using simplified function
      await _adminClient!.rpc('insert_monitoring_data', params: {
        'p_active_connections': systemStats['active_connections'] ?? 0,
        'p_max_connections': systemStats['max_connections'] ?? 60,
        'p_queue_size': systemStats['queue_size'] ?? 0,
        'p_system_load': (systemStats['current_load'] ?? 0).toDouble(),
        'p_crash_risk': _mapCrashRisk(systemStats['crash_risk'] ?? 'LOW'),
        'p_peak_users': systemStats['peak_concurrent_users'] ?? 0,
        'p_cache_hit_rate': (cacheStats['cache_hit_potential'] ?? 0).toDouble(),
        'p_cache_entries': cacheStats['valid_entries'] ?? 0,
        'p_exam_mode_active': examStats['exam_mode_active'] ?? false,
        'p_active_test_takers': examStats['active_exam_takers'] ?? 0,
        'p_active_exams': examStats['active_exams'] ?? 0,
        'p_circuit_breaker_open': systemStats['circuit_breaker_open'] ?? false,
        'p_app_version': _appVersion,
        'p_platform': _platform,
        'p_metadata': {
          'failure_count': systemStats['failure_count'] ?? 0,
          'total_operations_today': systemStats['total_operations_today'] ?? 0,
          'estimated_max_users': systemStats['estimated_max_users'] ?? 0,
          'timestamp': DateTime.now().toIso8601String(),
        },
      });
      
      if (kDebugMode) {
        final connections = systemStats['active_connections'] ?? 0;
        final load = systemStats['current_load'] ?? 0;
        print('📊 Reported stats: ${connections} connections, ${load}% load');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('📊 Failed to report monitoring stats: $e');
      }
      // Don't rethrow - monitoring reporting shouldn't break app functionality
    }
  }
  
  /// Report exam session start
  static Future<void> reportExamSessionStart(
    String examId,
    String studentId,
  ) async {
    if (_adminClient == null) return;
    
    try {
      await _adminClient!.from('exam_sessions').insert({
        'exam_id': examId,
        'student_id': studentId,
        'status': 'active',
        'start_time': DateTime.now().toIso8601String(),
      });
      
      if (kDebugMode) {
        print('📚 Reported exam session start: $examId for $studentId');
      }
    } catch (e) {
      if (kDebugMode) print('Failed to report exam session start: $e');
    }
  }
  
  /// Report exam session end
  static Future<void> reportExamSessionEnd(
    String examId,
    String studentId,
    Map<String, dynamic>? finalAnswers,
  ) async {
    if (_adminClient == null) return;
    
    try {
      await _adminClient!
          .from('exam_sessions')
          .update({
            'status': 'completed',
            'end_time': DateTime.now().toIso8601String(),
            'test_data': finalAnswers ?? {},
          })
          .eq('exam_id', examId)
          .eq('student_id', studentId)
          .eq('status', 'active');
      
      if (kDebugMode) {
        print('📚 Reported exam session end: $examId for $studentId');
      }
    } catch (e) {
      if (kDebugMode) print('Failed to report exam session end: $e');
    }
  }
  
  /// Report emergency action from admin
  static Future<void> reportEmergencyAction(
    String actionType,
    Map<String, dynamic>? details,
    bool success,
  ) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      
      await Supabase.instance.client.from('emergency_actions').insert({
        'action_type': actionType,
        'performed_by': user.id,
        'details': details ?? {},
        'success': success,
      });
      
      if (kDebugMode) {
        print('🚨 Reported emergency action: $actionType (success: $success)');
      }
    } catch (e) {
      if (kDebugMode) print('Failed to report emergency action: $e');
    }
  }
  
  /// Report critical system events
  static Future<void> reportCriticalEvent(
    String eventType,
    String description,
    Map<String, dynamic>? metadata,
  ) async {
    try {
      // Store in metadata of monitoring stats for immediate visibility
      await Supabase.instance.client.rpc('update_system_monitoring_stats', params: {
        'p_active_connections': 0,
        'p_max_connections': 60,
        'p_queue_size': 0,
        'p_system_load': 0.0,
        'p_crash_risk': 'CRITICAL',
        'p_peak_users': 0,
        'p_cache_hit_rate': 0.0,
        'p_cache_entries': 0,
        'p_metadata': {
          'critical_event': {
            'type': eventType,
            'description': description,
            'metadata': metadata ?? {},
            'timestamp': DateTime.now().toIso8601String(),
          }
        },
      });
      
      if (kDebugMode) {
        print('🚨 CRITICAL EVENT REPORTED: $eventType - $description');
      }
    } catch (e) {
      if (kDebugMode) print('Failed to report critical event: $e');
    }
  }
  
  /// Get monitoring data for local debugging
  static Map<String, dynamic> getCurrentStats() {
    return {
      'reporting_active': _isReporting,
      'app_version': _appVersion,
      'platform': _platform,
      'last_report_time': DateTime.now().toIso8601String(),
    };
  }
  
  /// Manual report trigger (for testing)
  static Future<void> forceReport() async {
    await _reportSystemStats();
  }
  
  /// Map internal crash risk format to database format
  static String _mapCrashRisk(String crashRisk) {
    // Extract just the risk level from strings like "CRITICAL (95%)"
    if (crashRisk.contains('CRITICAL')) return 'CRITICAL';
    if (crashRisk.contains('HIGH')) return 'HIGH';
    if (crashRisk.contains('MEDIUM')) return 'MEDIUM';
    return 'LOW';
  }
  
  /// Check if monitoring tables exist
  static Future<bool> verifyMonitoringSetup() async {
    try {
      // Try to query the monitoring table
      await Supabase.instance.client
          .from('system_monitoring')
          .select('id')
          .limit(1);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Monitoring tables not set up. Run create_monitoring_tables.sql');
      }
      return false;
    }
  }
}

/// Extension to integrate monitoring with existing services
extension MonitoringIntegration on ExamOptimizationService {
  /// Enhanced joinExam with monitoring
  static Future<Map<String, dynamic>> joinExamWithMonitoring(
    String examId,
    String studentId,
    Future<Map<String, dynamic>> Function() loadExamData,
  ) async {
    // Report exam session start
    await MonitoringReportingService.reportExamSessionStart(examId, studentId);
    
    try {
      // Use existing joinExam method
      return await ExamOptimizationService.joinExam(examId, studentId, loadExamData);
    } catch (e) {
      // Report critical event if exam join fails
      await MonitoringReportingService.reportCriticalEvent(
        'exam_join_failure',
        'Student failed to join exam',
        {'exam_id': examId, 'student_id': studentId, 'error': e.toString()},
      );
      rethrow;
    }
  }
  
  /// Enhanced submitExam with monitoring
  static Future<bool> submitExamWithMonitoring(
    String examId,
    String studentId,
    Map<String, dynamic> examData,
    Future<bool> Function(Map<String, dynamic>) submitFunction,
  ) async {
    try {
      final result = await ExamOptimizationService.submitExam(
        examId, studentId, examData, submitFunction,
      );
      
      // Report exam session end on success
      await MonitoringReportingService.reportExamSessionEnd(
        examId, studentId, examData,
      );
      
      return result;
    } catch (e) {
      // Report critical event if exam submission fails
      await MonitoringReportingService.reportCriticalEvent(
        'exam_submit_failure',
        'Student failed to submit exam',
        {'exam_id': examId, 'student_id': studentId, 'error': e.toString()},
      );
      rethrow;
    }
  }
}
