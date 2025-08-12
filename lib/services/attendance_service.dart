import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/attendance_record.dart';

class AttendanceService {
  final supabase = Supabase.instance.client;

  Future<List<AttendanceRecord>> getStudentAttendance(
    String studentRoll,
  ) async {
    final response = await supabase
        .from('attendance')
        .select()
        .eq('student_id', studentRoll)
        .order('date', ascending: false);
    return (response as List)
        .map((json) => AttendanceRecord.fromJson(json))
        .toList();
  }

  Future<List<AttendanceRecord>> getStudentAttendanceByContext(
    String studentRoll, {
    String? college,
    String? branch,
    String? semester,
  }) async {
    var query = supabase
        .from('attendance')
        .select()
        .eq('student_id', studentRoll);

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
    throw Exception('Attendance can only be marked by professors.');
  }

  Future<void> updateAttendance(String recordId, String status) async {
    throw Exception('Attendance updates are restricted to professors.');
  }

  Future<void> deleteAttendance(String recordId) async {
    throw Exception('Attendance deletions are restricted to professors.');
  }
}
