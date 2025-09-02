import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/subject.dart';

class SubjectsService {
  static final SupabaseClient _client = Supabase.instance.client;

  // Fetch all subjects with their related data
  static Future<List<Subject>> getAllSubjects() async {
    try {
      // First, try to fetch real data from database
      List<Subject> realSubjects = [];
      try {
        final response = await _client
            .from('subjects')
            .select('''
              *,
              semesters (
                id,
                name,
                branches (
                  id,
                  name,
                  colleges (
                    id,
                    name
                  )
                )
              )
            ''')
            .order('name');

        realSubjects =
            (response as List).map((data) => Subject.fromJson(data)).toList();
            } catch (e) {
        // Continue with sample data if real data fails
      }

      return realSubjects;
    } catch (e) {
      // Return empty list as fallback
      return [];
    }
  }

  // Fetch subjects by semester - OPTIMIZED
  static Future<List<Subject>> getSubjectsBySemester(String semesterId) async {
    try {
      // Query directly with filter instead of fetching all
      final response = await _client
          .from('subjects')
          .select('''
            *,
            semesters (
              id,
              name,
              branches (
                id,
                name,
                colleges (
                  id,
                  name
                )
              )
            )
          ''')
          .eq('semester_id', semesterId)
          .order('name');

      return (response as List).map((data) => Subject.fromJson(data)).toList();
    } catch (e) {
      return [];
    }
  }

  // Search subjects by name or code
  static Future<List<Subject>> searchSubjects(String query) async {
    try {
      // Get all subjects and search
      final allSubjects = await getAllSubjects();
      return allSubjects.where((subject) {
        return subject.name.toLowerCase().contains(query.toLowerCase()) ||
            (subject.code?.toLowerCase().contains(query.toLowerCase()) ??
                false);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // Get subject by ID
  static Future<Subject?> getSubjectById(String id) async {
    try {
      // Get all subjects and find by ID
      final allSubjects = await getAllSubjects();
      try {
        return allSubjects.firstWhere((subject) => subject.id == id);
      } catch (e) {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // Get subjects by college and semester
  static Future<List<Subject>> getSubjectsByCollegeAndSemester(
    String collegeName,
    String semesterName,
  ) async {
    try {
      // Get all subjects and filter by college and semester
      final allSubjects = await getAllSubjects();
      return allSubjects.where((subject) {
        // Normalize college name matching (case insensitive, partial match)
        final subjectCollege =
            subject.semester?.branch?.college?.name.toLowerCase() ?? '';
        final userCollege = collegeName.toLowerCase();
        final matchesCollege =
            subjectCollege.contains(userCollege) ||
            userCollege.contains(subjectCollege) ||
            subjectCollege.contains('niamt') && userCollege.contains('niamt') ||
            subjectCollege.contains('iiit') && userCollege.contains('iiit');

        // Normalize semester name matching (case insensitive, partial match)
        final subjectSemester = subject.semester?.name.toLowerCase() ?? '';
        final userSemester = semesterName.toLowerCase();
        final matchesSemester =
            subjectSemester.contains(userSemester) ||
            userSemester.contains(subjectSemester) ||
            subjectSemester.contains('5th') && userSemester.contains('5th') ||
            subjectSemester.contains('1st') && userSemester.contains('1st');

        return matchesCollege && matchesSemester;
      }).toList();
    } catch (e) {
      // Return empty list as fallback
      return [];
    }
  }
}
