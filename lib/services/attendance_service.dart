import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/attendance_record.dart';

class AttendanceService {
  final supabase = Supabase.instance.client;

  Future<List<AttendanceRecord>> getStudentAttendance(String studentId) async {
    final response = await supabase
        .from('attendance')
        .select()
        .eq('student_id', studentId)
        .order('date', ascending: false);
    if (response == null) return [];
    return (response as List)
        .map((json) => AttendanceRecord.fromJson(json))
        .toList();
  }

  Future<List<AttendanceRecord>> getStudentAttendanceByContext(
    String studentId, {
    String? college,
    String? branch,
    String? semester,
  }) async {
    var query = supabase
        .from('attendance')
        .select()
        .eq('student_id', studentId);

    if (college != null) {
      query = query.eq('college', college);
    }
    if (branch != null) {
      query = query.eq('branch', branch);
    }
    if (semester != null) {
      // Convert semester string to integer if possible
      final semesterMatch = RegExp(r'(\d+)').firstMatch(semester);
      if (semesterMatch != null) {
        final semesterInt = int.tryParse(semesterMatch.group(1)!);
        if (semesterInt != null) {
          query = query.eq('semester', semesterInt);
        }
      }
    }

    final response = await query.order('date', ascending: false);
    if (response == null) return [];
    return (response as List)
        .map((json) => AttendanceRecord.fromJson(json))
        .toList();
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
    // Convert semester string to integer if possible
    int? semesterInt;
    if (semester != null) {
      // Extract number from semester string (e.g., "5th Semester" -> 5)
      final semesterMatch = RegExp(r'(\d+)').firstMatch(semester);
      if (semesterMatch != null) {
        semesterInt = int.tryParse(semesterMatch.group(1)!);
      }
    }

    try {
      final dateString = date.toIso8601String().split('T')[0];

      // Check if attendance record already exists for this student, subject, date, and class number
      var query = supabase
          .from('attendance')
          .select()
          .eq('student_id', studentId)
          .eq('subject_id', subjectId)
          .eq('date', dateString);

      // If class number is provided, include it in the query
      if (classNumber != null) {
        query = query.eq('class_number', classNumber);
      }

      final existingRecord = await query.maybeSingle();

      if (existingRecord != null) {
        // Update existing record - ensures only one record per student per subject per day per class
        final response =
            await supabase
                .from('attendance')
                .update({
                  'status': status,
                  'college': college,
                  'branch': branch,
                  'semester': semesterInt,
                  'class_number': classNumber,
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('id', existingRecord['id'])
                .select()
                .single();
        return response['id'] as String?;
      } else {
        // Create new record - only if no existing record found
        final response =
            await supabase
                .from('attendance')
                .insert({
                  'student_id': studentId,
                  'subject_id': subjectId,
                  'date': dateString,
                  'status': status,
                  'college': college,
                  'branch': branch,
                  'semester': semesterInt,
                  'class_number': classNumber,
                  'created_at': DateTime.now().toIso8601String(),
                })
                .select()
                .single();
        return response['id'] as String?;
      }
    } catch (e) {
      // Handle potential unique constraint violations
      if (e.toString().contains('duplicate key') ||
          e.toString().contains('unique constraint')) {
        // If we get a duplicate key error, try to update the existing record
        final dateString = date.toIso8601String().split('T')[0];
        var query = supabase
            .from('attendance')
            .select()
            .eq('student_id', studentId)
            .eq('subject_id', subjectId)
            .eq('date', dateString);

        if (classNumber != null) {
          query = query.eq('class_number', classNumber);
        }

        final existingRecord = await query.maybeSingle();

        if (existingRecord != null) {
          final response =
              await supabase
                  .from('attendance')
                  .update({
                    'status': status,
                    'college': college,
                    'branch': branch,
                    'semester': semesterInt,
                    'class_number': classNumber,
                    'updated_at': DateTime.now().toIso8601String(),
                  })
                  .eq('id', existingRecord['id'])
                  .select()
                  .single();
          return response['id'] as String?;
        }
      }
      rethrow;
    }
  }

  Future<void> updateAttendance(String recordId, String status) async {
    await supabase
        .from('attendance')
        .update({'status': status})
        .eq('id', recordId);
  }

  Future<void> deleteAttendance(String recordId) async {
    await supabase.from('attendance').delete().eq('id', recordId);
  }
}
