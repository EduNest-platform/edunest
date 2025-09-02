import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/assignment_mark.dart';
import 'supabase_service.dart';
import 'user_profile_service.dart';
import 'package:flutter/foundation.dart';

class AssignmentMarksService {
  static final SupabaseClient _client = SupabaseService.client;
  
  // Cache management
  static Map<String, List<AssignmentMark>>? _cachedAssignmentMarks;
  static DateTime? _cacheTimestamp;
  static const Duration _cacheDuration = Duration(minutes: 5);
  
  // Callback for cache invalidation
  static void Function()? _cacheInvalidationCallback;
  
  /// Register callback for cache invalidation when user profile changes
  static void registerCacheInvalidationCallback(void Function() callback) {
    _cacheInvalidationCallback = callback;
  }
  
  /// Unregister cache invalidation callback
  static void unregisterCacheInvalidationCallback() {
    _cacheInvalidationCallback = null;
  }
  
  /// Clear all cached assignment marks data
  static void clearCache() {
    _cachedAssignmentMarks = null;
    _cacheTimestamp = null;
    if (kDebugMode) {
      // AssignmentMarksService: Cache cleared
    }
    
    // Trigger callback if registered
    if (_cacheInvalidationCallback != null) {
      _cacheInvalidationCallback!();
    }
  }
  
  /// Check if cache is valid
  static bool _isCacheValid() {
    if (_cachedAssignmentMarks == null || _cacheTimestamp == null) {
      return false;
    }
    return DateTime.now().difference(_cacheTimestamp!) < _cacheDuration;
  }

  /// Get all assignment marks for the current student
  static Future<List<AssignmentMark>> getStudentAssignmentMarks() async {
    try {
      final user = SupabaseService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final studentEmail = user.email;
      final studentId = user.id;
      
      if (studentEmail == null) {
        throw Exception('Student email not found');
      }

      // Use both email and user ID for lookup to handle cases where email is empty in database
      final studentQuery = 'student_email.eq.$studentEmail,student_id.eq.$studentId';

      final response = await _client
          .from('class_assignment_marks')
          .select('*')
          .or(studentQuery)
          .not('assignment_name', 'like', 'Midsem:%') // Exclude midsem marks
          .order('assignment_name');

      return (response as List)
          .map((json) => AssignmentMark.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch assignment marks: $e');
    }
  }

  /// Get assignment marks grouped by assignment name
  static Future<Map<String, List<AssignmentMark>>> getAssignmentMarksGrouped() async {
    final marks = await getStudentAssignmentMarks();
    final Map<String, List<AssignmentMark>> groupedMarks = {};

    for (final mark in marks) {
      if (groupedMarks[mark.assignmentName] == null) {
        groupedMarks[mark.assignmentName] = [];
      }
      groupedMarks[mark.assignmentName]!.add(mark);
    }

    return groupedMarks;
  }

  /// Get available subjects (class IDs) for the current student based on their college, branch, and semester
  static Future<List<String>> getAvailableSubjects() async {
    try {
      final user = SupabaseService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final studentEmail = user.email;
      final userId = user.id;
      
      if (studentEmail == null) {
        throw Exception('Student email not found');
      }

      // Get current user's profile to get their college, branch, and semester
      final userProfile = await UserProfileService.getCurrentUserProfile();
      if (userProfile == null) {
        // Warning: User profile not found for assignment filtering
        // Fallback: return all assignments for this student without filtering using both email and user ID
        final response = await _client
            .from('class_assignment_marks')
            .select('class_id')
            .or('student_email.eq.$studentEmail,student_id.eq.$userId');

        final classIds = (response as List)
            .map((item) => item['class_id'] as String)
            .toSet()
            .toList();

        return classIds;
      }

      // User profile found: College=${userProfile.college}, Branch=${userProfile.branch}, Semester=${userProfile.semester}

      // Get assignment marks for this student using both email and user ID
      final response = await _client
          .from('class_assignment_marks')
          .select('class_id')
          .or('student_email.eq.$studentEmail,student_id.eq.$userId');

      final allClassIds = (response as List)
          .map((item) => item['class_id'] as String)
          .toSet();
      // Found assignment marks for class IDs: $allClassIds

      // For now, let's return all class IDs that have assignments for this student
      // We can add more sophisticated filtering later if needed
      // Returning all available class IDs: $allClassIds
      return allClassIds.toList();

      /* 
      // TODO: Re-enable this more sophisticated filtering once we understand the class-subject relationship
      // Get all subjects that match user's college, branch, and semester
      List<Subject> userSubjects = [];
      if (userProfile.college != null && userProfile.semester != null) {
        userSubjects = await SubjectsService.getSubjectsByCollegeAndSemester(
          userProfile.college!,
          userProfile.semester!,
        );
        // Found ${userSubjects.length} subjects for user context
      } else {
        // Warning: User college or semester is null, using fallback approach
        // Fallback: get all available subjects
        userSubjects = await SubjectsService.getAllSubjects();
      }

      // Get subject IDs that the user should have access to
      final userSubjectIds = userSubjects.map((subject) => subject.id).toSet();
      // User should have access to subject IDs: $userSubjectIds

      // Filter class_ids to only include those that match user's subjects
      final classIds = allClassIds
          .where((classId) => userSubjectIds.contains(classId))
          .toList();

      // Filtered class IDs: $classIds
      return classIds;
      */
    } catch (e) {
      // Error in getAvailableSubjects: $e
      throw Exception('Failed to fetch available subjects: $e');
    }
  }

  /// Get all assignment marks grouped by class ID, filtered by current academic path
  static Future<Map<String, List<AssignmentMark>>> getAllAssignmentMarks() async {
    try {
      // Check cache first
      if (_isCacheValid()) {
        // AssignmentMarksService: Returning cached assignment marks
        return _cachedAssignmentMarks!;
      }

      final userProfile = await UserProfileService.getCurrentUserProfile();
      if (userProfile == null) {
        // No user profile found
        return {};
      }

      // User profile found: College=${userProfile.college}, Branch=${userProfile.branch}, Semester=${userProfile.semester}

      final userEmail = userProfile.email;
      final user = SupabaseService.currentUser;
      final userId = user?.id;
      
      if (userEmail == null && userId == null) {
        // Both user email and user ID are null
        return {};
      }

      // Use both email and user ID for lookup to handle cases where email is empty
      String query;
      if (userEmail != null && userId != null) {
        query = 'student_email.eq.$userEmail,student_id.eq.$userId';
      } else if (userEmail != null) {
        query = 'student_email.eq.$userEmail';
      } else {
        query = 'student_id.eq.$userId';
      }

      final response = await _client
          .from('class_assignment_marks')
          .select('*')
          .or(query);

      if (response.isEmpty) {
        // No assignment marks found for user - Email: $userEmail, ID: $userId
        return {};
      }

      // Found ${response.length} assignment marks records before filtering

      // Filter assignment marks by current academic path
      final filteredResponse = await _filterByCurrentAcademicPath(response, userProfile);
      // Found ${filteredResponse.length} assignment marks records after academic path filtering

      final Map<String, List<AssignmentMark>> groupedMarks = {};
      
      for (final item in filteredResponse) {
        final classId = item['class_id'] as String;
        final assignmentMark = AssignmentMark.fromJson(item);
        
        if (groupedMarks[classId] == null) {
          groupedMarks[classId] = [];
        }
        groupedMarks[classId]!.add(assignmentMark);
      }

      // Cache the results
      _cachedAssignmentMarks = groupedMarks;
      _cacheTimestamp = DateTime.now();
      // AssignmentMarksService: Cached assignment marks for ${groupedMarks.keys.length} classes

      // Assignment marks grouped by class: ${groupedMarks.keys.toSet()}
      return groupedMarks;
    } catch (e) {
      // Error getting all assignment marks: $e
      return {};
    }
  }

  /// Filter assignment marks by current academic path (college, branch, semester)
  static Future<List<dynamic>> _filterByCurrentAcademicPath(
    List<dynamic> assignmentMarks, 
    dynamic userProfile
  ) async {
    try {
      if (userProfile.college == null || userProfile.branch == null || userProfile.semester == null) {
        // Warning: User academic path incomplete, returning all assignment marks
        return assignmentMarks;
      }

      // Get unique class IDs from assignment marks
      final classIds = assignmentMarks
          .map((mark) => mark['class_id'] as String)
          .toSet()
          .toList();
      
      if (classIds.isEmpty) {
        return assignmentMarks;
      }

      if (kDebugMode) {
        // Checking ${classIds.length} class IDs for academic path filtering
      }

      // Get class roster information to check academic context
      final classRosterResponse = await _client
          .from('class_rosters')
          .select('class_id, classes!inner(college, branch, semester)')
          .inFilter('class_id', classIds);

      // Create a set of valid class IDs that match current academic path
      final validClassIds = <String>{};
      
      for (final roster in classRosterResponse) {
        final classId = roster['class_id'] as String;
        final classInfo = roster['classes'];
        
        if (classInfo != null) {
          final college = classInfo['college'] as String?;
          final branch = classInfo['branch'] as String?;
          final semester = classInfo['semester'] as String?;
          
          // Check if class matches current academic path
          final collegeMatch = college?.toLowerCase() == userProfile.college?.toLowerCase();
          final branchMatch = branch?.toLowerCase() == userProfile.branch?.toLowerCase();
          final semesterMatch = semester?.toLowerCase() == userProfile.semester?.toLowerCase();
          
          if (collegeMatch && branchMatch && semesterMatch) {
            validClassIds.add(classId);
            if (kDebugMode) {
              // Class $classId matches academic path: $college, $branch, $semester
            }
          } else {
            if (kDebugMode) {
              // Class $classId does not match academic path: $college, $branch, $semester vs ${userProfile.college}, ${userProfile.branch}, ${userProfile.semester}
            }
          }
        }
      }

      if (kDebugMode) {
        // Valid class IDs for current academic path: $validClassIds
      }

      // Filter assignment marks to only include valid class IDs
      final filteredMarks = assignmentMarks
          .where((mark) => validClassIds.contains(mark['class_id'] as String))
          .toList();

      if (kDebugMode) {
        // Filtered ${assignmentMarks.length} marks down to ${filteredMarks.length} marks for current academic path
      }
      return filteredMarks;
      
    } catch (e) {
      if (kDebugMode) {
        // Error filtering by academic path: $e
      }
      // Return original marks if filtering fails
      return assignmentMarks;
    }
  }

  /// Get class information with subject details for assignment marks
  static Future<Map<String, Map<String, dynamic>>> getClassSubjectInfo(List<String> classIds) async {
    try {
      final Map<String, Map<String, dynamic>> classInfo = {};
      
      for (final classId in classIds) {
        try {
          // Get assignment data for this class to extract subject name
          final assignmentResponse = await _client
              .from('class_assignment_marks')
              .select('assignment_name, class_id, subject_name')
              .eq('class_id', classId)
              .limit(1)
              .maybeSingle();
          
          String subjectName = 'Unknown Subject';
          
          if (assignmentResponse != null) {
            // Use the subject_name from the database if available
            subjectName = assignmentResponse['subject_name'] ?? 'Unknown Subject';
            // Found subject name for class $classId: $subjectName
          } else {
            // No assignment data found for class $classId
          }
          
          classInfo[classId] = {
            'class_name': 'Class $classId',
            'subject_id': classId,
            'subject_name': subjectName,
            'subject_code': null,
          };
          
        } catch (e) {
          // Error getting info for class $classId: $e
          // Fallback information
          classInfo[classId] = {
            'class_name': 'Class $classId',
            'subject_id': classId,
            'subject_name': 'Subject $classId',
            'subject_code': null,
          };
        }
      }
      
      return classInfo;
    } catch (e) {
      // Error in getClassSubjectInfo: $e
      return {};
    }
  }
  static Future<Map<String, List<Assignment>>> getAssignmentsBySubject() async {
    try {
      // Get marks filtered by user's context
      final marks = await getStudentAssignmentMarks();
      
      // Get available subjects for the user (already filtered by college/branch/semester)
      final availableSubjects = await getAvailableSubjects();
      
      // Filter marks to only include those for available subjects
      final filteredMarks = marks.where((mark) => 
        availableSubjects.contains(mark.classId)
      ).toList();

      final Map<String, Map<String, List<AssignmentMark>>> subjectAssignments = {};

      // Group by class_id first, then by assignment_name
      for (final mark in filteredMarks) {
        if (subjectAssignments[mark.classId] == null) {
          subjectAssignments[mark.classId] = {};
        }
        if (subjectAssignments[mark.classId]![mark.assignmentName] == null) {
          subjectAssignments[mark.classId]![mark.assignmentName] = [];
        }
        subjectAssignments[mark.classId]![mark.assignmentName]!.add(mark);
      }

      // Convert to Map<String, List<Assignment>>
      final Map<String, List<Assignment>> result = {};
      for (final entry in subjectAssignments.entries) {
        final classId = entry.key;
        final assignmentGroups = entry.value;
        
        final assignments = <Assignment>[];
        for (final assignmentEntry in assignmentGroups.entries) {
          final assignmentName = assignmentEntry.key;
          final assignmentMarks = assignmentEntry.value;
          final maxMarks = assignmentMarks.isNotEmpty ? (assignmentMarks.first.maxMarks ?? 0.0) : 0.0;
          
          assignments.add(Assignment(
            name: assignmentName,
            maxMarks: maxMarks,
            marks: assignmentMarks,
          ));
        }
        
        result[classId] = assignments;
      }

      return result;
    } catch (e) {
      throw Exception('Failed to fetch assignments by subject: $e');
    }
  }

  /// Get assignments with marks for the current student
  static Future<List<Assignment>> getStudentAssignments() async {
    try {
      final groupedMarks = await getAssignmentMarksGrouped();
      final List<Assignment> assignments = [];

      for (final entry in groupedMarks.entries) {
        final assignmentName = entry.key;
        final marks = entry.value;
        
        // Get max marks from the first mark (should be same for all)
        final maxMarks = marks.isNotEmpty ? (marks.first.maxMarks ?? 0.0) : 0.0;

        assignments.add(Assignment(
          name: assignmentName,
          maxMarks: maxMarks,
          marks: marks,
        ));
      }

      // Sort assignments by name
      assignments.sort((a, b) => a.name.compareTo(b.name));
      
      return assignments;
    } catch (e) {
      throw Exception('Failed to fetch student assignments: $e');
    }
  }

  /// Get assignment marks for a specific subject/class (with user context validation)
  static Future<List<AssignmentMark>> getAssignmentMarksByClass(String classId) async {
    try {
      final user = SupabaseService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final studentEmail = user.email;
      final userId = user.id;
      
      if (studentEmail == null) {
        throw Exception('Student email not found');
      }

      // Validate that the user has access to this class/subject
      final availableSubjects = await getAvailableSubjects();
      if (!availableSubjects.contains(classId)) {
        // Return empty list if user doesn't have access to this subject
        return [];
      }

      // Use both email and user ID for lookup to handle cases where email is empty in database
      final studentQuery = 'student_email.eq.$studentEmail,student_id.eq.$userId';

      final response = await _client
        .from('class_assignment_marks')
        .select('*')
        .eq('class_id', classId)
        .or('student_email.eq.$studentEmail,student_id.eq.$userId')
        .not('assignment_name', 'like', 'Midsem:%') // Exclude midsem marks
        .order('assignment_name');

      return (response as List)
          .map((json) => AssignmentMark.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch assignment marks for class: $e');
    }
  }

  /// Get assignment statistics for the current student
  static Future<Map<String, dynamic>> getAssignmentStatistics() async {
    try {
      final marks = await getStudentAssignmentMarks();
      
      if (marks.isEmpty) {
        return {
          'totalAssignments': 0,
          'averagePercentage': 0.0,
          'totalMarksObtained': 0.0,
          'totalMaxMarks': 0.0,
          'gradeDistribution': <String, int>{},
        };
      }

      final totalAssignments = marks.length;
      final totalMarksObtained = marks.fold(0.0, (sum, mark) => sum + (mark.marks ?? 0));
      final totalMaxMarks = marks.fold(0.0, (sum, mark) => sum + (mark.maxMarks ?? 0));
      final averagePercentage = totalMaxMarks > 0 ? (totalMarksObtained / totalMaxMarks) * 100 : 0;

      // Grade distribution
      final gradeDistribution = <String, int>{};
      for (final mark in marks) {
        final grade = mark.grade;
        gradeDistribution[grade] = (gradeDistribution[grade] ?? 0) + 1;
      }

      return {
        'totalAssignments': totalAssignments,
        'averagePercentage': averagePercentage,
        'totalMarksObtained': totalMarksObtained,
        'totalMaxMarks': totalMaxMarks,
        'gradeDistribution': gradeDistribution,
      };
    } catch (e) {
      throw Exception('Failed to calculate assignment statistics: $e');
    }
  }
}
