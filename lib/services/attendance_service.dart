import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/attendance_record.dart';
import 'user_profile_service.dart';
import 'free_plan_optimizer_service.dart';

class AttendanceService {
  final supabase = Supabase.instance.client;

  // Get student self-tracked attendance from the new attendance table
  Future<List<AttendanceRecord>> getStudentAttendance(
    String studentRoll,
  ) async {
    try {
      final response = await supabase
          .from('attendance')
          .select()
          .eq('student_id', studentRoll)
          .order('date', ascending: false);
      
      if ((response as List).isEmpty) {
        return [];
      }
      
      // Get all unique subject IDs to resolve names
      final subjectIds = (response as List)
          .map((json) => json['subject_id'] as String)
          .toSet()
          .toList();
      
      // Resolve subject names
      final subjectNames = await _resolveSubjectNames(subjectIds);
      
      return (response as List)
          .map((json) => _convertStudentAttendanceToRecord(json, studentRoll, subjectNames))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Helper method to resolve subject IDs to names
  Future<Map<String, String>> _resolveSubjectNames(List<String> subjectIds) async {
    final Map<String, String> subjectNames = {};
    
    if (subjectIds.isEmpty) return subjectNames;
    
    try {
      // Try to get subject names from the subjects table
      final subjectsResponse = await supabase
          .from('subjects')
          .select('id, name');
      
      for (final subject in (subjectsResponse as List)) {
        subjectNames[subject['id'] as String] = subject['name'] as String;
      }
      
    } catch (e) {
      // If we can't resolve names, we'll use the IDs as fallback
    }
    
    return subjectNames;
  }

  // Helper method to convert student attendance table format to AttendanceRecord
  AttendanceRecord _convertStudentAttendanceToRecord(
    Map<String, dynamic> json, 
    String studentRoll, 
    Map<String, String> subjectNames
  ) {
    final subjectId = json['subject_id'] as String;
    final subjectName = subjectNames[subjectId] ?? subjectId;
    
    return AttendanceRecord(
      id: json['id'] as String,
      classId: 'student_tracked_${json['id']}',
      studentRollNumber: studentRoll,
      studentName: 'Student',
      date: DateTime.parse(json['date'] as String),
      status: json['status'] as String,
      professorEmail: 'self_tracked@student.com',
      subjectName: subjectName,
      collegeName: json['college'] as String?,
      branchName: json['branch'] as String?,
      semesterName: json['semester']?.toString(),
      classNumber: json['class_number'] as int?,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  // Get student attendance with subject name resolution (same as getStudentAttendance)
  Future<List<AttendanceRecord>> getStudentAttendanceWithSubjectNames(
    String studentRoll,
  ) async {
    // This method is now the same as getStudentAttendance since we always resolve subject names
    return getStudentAttendance(studentRoll);
  }

  // Get professor-managed attendance from the professor_attendance table
  Future<List<AttendanceRecord>> getStudentAttendanceByContext(
    String studentIdentifier, {
    String? college,
    String? branch,
    String? semester,
  }) async {
    try {
      // First, try to get the user's roll number from their profile
      String? rollNumber = studentIdentifier;
      
      try {
        final profile = await UserProfileService.getCurrentUserProfile();
        if (profile?.studentId != null && profile!.studentId!.isNotEmpty) {
          rollNumber = profile.studentId; // Use the roll number from profile
        }
      } catch (e) {
        // If profile fetch fails, use the provided identifier
        print('Could not fetch profile for roll number, using identifier: $e');
      }

      // Ensure we have a valid roll number
      if (rollNumber == null || rollNumber.isEmpty) {
        print('No valid roll number found for student attendance query');
        return [];
      }

      var query = supabase
          .from('professor_attendance')
          .select()
          .eq('student_roll_number', rollNumber);

      if (college != null) {
        query = query.eq('college_name', college);
      }
      if (branch != null) {
        query = query.eq('branch_name', branch);
      }
      if (semester != null) {
        query = query.eq('semester_name', semester);
      }

      final response = await query.order('date', ascending: false);
      
      return (response as List)
          .map((json) => _convertProfessorAttendanceToRecord(json))
          .toList();
    } catch (e) {
      print('Error getting professor attendance: $e');
      return [];
    }
  }

  // Helper method to convert professor_attendance table format to AttendanceRecord
  AttendanceRecord _convertProfessorAttendanceToRecord(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] as String,
      classId: json['class_id'] as String,
      studentRollNumber: json['student_roll_number'] as String,
      studentName: json['student_name'] as String,
      date: DateTime.parse(json['date'] as String),
      status: json['status'] as String,
      professorEmail: 'professor@system.com', // Default since professor_email column was removed
      subjectName: json['subject_name'] as String,
      collegeName: json['college_name'] as String?,
      branchName: json['branch_name'] as String?,
      semesterName: json['semester_name'] as String?,
      classNumber: json['class_number'] as int?,
      createdAt: null, // created_at column was also removed
    );
  }

  Future<String?> markAttendance({
    required String studentId,
    required String subjectId,
    required DateTime date,
    required String status,
    String? college,
    String? branch,
    String? semester,
    int? classNumber,
  }) async {
    try {
      
      // Validate that we have valid UUIDs
      if (!_isValidUUID(studentId)) {
        throw Exception('Invalid student ID format. Expected UUID.');
      }
      
      if (!_isValidUUID(subjectId)) {
        throw Exception('Invalid subject ID format. Expected UUID.');
      }
      
      // First check if a record already exists for this date/subject/student
      final existingRecords = await supabase
          .from('attendance')
          .select()
          .eq('student_id', studentId)
          .eq('subject_id', subjectId)
          .eq('date', date.toIso8601String().split('T')[0])
          .eq('class_number', classNumber ?? 1);
      

      
      if ((existingRecords as List).isNotEmpty) {
        // Update existing record
        final recordId = existingRecords[0]['id'];

        // OPTIMIZED: Use FreePlanOptimizerService for attendance updates
        await FreePlanOptimizerService.optimizedDatabaseOperation(
          'update_attendance_record',
          () => supabase.from('attendance').update({
            'status': status,
          }).eq('id', recordId),
          useCache: false, // Don't cache write operations
          priority: 2, // Medium priority for attendance updates
        );
        return recordId;
      } else {
        // Create new record
        final insertData = {
          'student_id': studentId,
          'subject_id': subjectId,
          'date': date.toIso8601String().split('T')[0], // Format as YYYY-MM-DD
          'status': status,
          'college': college,
          'branch': branch,
          'semester': semester != null ? int.tryParse(semester) : null,
          'class_number': classNumber ?? 1,
        };
        
        // OPTIMIZED: Use FreePlanOptimizerService for attendance inserts
        final response = await FreePlanOptimizerService.optimizedDatabaseOperation(
          'insert_attendance_record',
          () => supabase.from('attendance').insert(insertData).select(),
          useCache: false, // Don't cache write operations
          priority: 2, // Medium priority for attendance inserts
        );
        
        return (response as List).isNotEmpty ? response[0]['id'] : null;
      }
    } catch (e) {
      rethrow;
    }
  }

  // Helper method to validate UUID format
  bool _isValidUUID(String uuid) {
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    );
    return uuidRegex.hasMatch(uuid);
  }

  Future<void> updateAttendance(String recordId, String status) async {
    throw Exception('Attendance updates are restricted to professors.');
  }

  Future<void> deleteAttendance(String recordId) async {
    await supabase.from('attendance').delete().eq('id', recordId);
  }
}
