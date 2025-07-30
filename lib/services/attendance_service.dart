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
        // Prepare update data with proper validation
        final updateData = <String, dynamic>{'status': status};

        // Only include fields if they are not null and not empty
        if (college != null && college.trim().isNotEmpty) {
          updateData['college'] = college.trim();
        }
        if (branch != null && branch.trim().isNotEmpty) {
          updateData['branch'] = branch.trim();
        }
        if (semesterInt != null && semesterInt > 0) {
          updateData['semester'] = semesterInt;
        }
        if (classNumber != null && classNumber > 0) {
          updateData['class_number'] = classNumber;
        }

        final response =
            await supabase
                .from('attendance')
                .update(updateData)
                .eq('id', existingRecord['id'])
                .select()
                .single();
        return response['id'] as String?;
      } else {
        // Create new record - only if no existing record found
        // Prepare insert data with proper validation
        // Note: created_at is automatically set by the database, updated_at doesn't exist
        final insertData = <String, dynamic>{
          'student_id': studentId,
          'subject_id': subjectId,
          'date': dateString,
          'status': status,
        };

        // Only include fields if they are not null and not empty
        if (college != null && college.trim().isNotEmpty) {
          insertData['college'] = college.trim();
        }
        if (branch != null && branch.trim().isNotEmpty) {
          insertData['branch'] = branch.trim();
        }
        if (semesterInt != null && semesterInt > 0) {
          insertData['semester'] = semesterInt;
        }
        // class_number defaults to 1 in the database, so only set if explicitly provided
        if (classNumber != null && classNumber > 0) {
          insertData['class_number'] = classNumber;
        }

        final response =
            await supabase
                .from('attendance')
                .insert(insertData)
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
          // Prepare update data with proper validation
          // Note: updated_at doesn't exist in the schema, only status and other fields can be updated
          final updateData = <String, dynamic>{'status': status};

          // Only include fields if they are not null and not empty
          if (college != null && college.trim().isNotEmpty) {
            updateData['college'] = college.trim();
          }
          if (branch != null && branch.trim().isNotEmpty) {
            updateData['branch'] = branch.trim();
          }
          if (semesterInt != null && semesterInt > 0) {
            updateData['semester'] = semesterInt;
          }
          // class_number defaults to 1 in the database, so only set if explicitly provided
          if (classNumber != null && classNumber > 0) {
            updateData['class_number'] = classNumber;
          }

          final response =
              await supabase
                  .from('attendance')
                  .update(updateData)
                  .eq('id', existingRecord['id'])
                  .select()
                  .single();
          return response['id'] as String?;
        }
      }

      // Create a more specific error message for common issues
      if (e.toString().contains('PGRST204') ||
          e.toString().contains('column')) {
        throw Exception('Database schema mismatch. Please contact support.');
      } else if (e.toString().contains('400')) {
        throw Exception(
          'Data validation failed. Please check your profile information and ensure all fields are properly filled.',
        );
      } else if (e.toString().contains('foreign key') ||
          e.toString().contains('constraint')) {
        throw Exception(
          'Invalid reference data. Please check your subject and profile information.',
        );
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
