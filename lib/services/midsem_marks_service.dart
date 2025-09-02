import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/assignment_mark.dart';
import 'supabase_service.dart';
import 'user_profile_service.dart';
import 'package:flutter/foundation.dart';

class MidsemMarksService {
  static final SupabaseClient _client = SupabaseService.client;
  
  // Cache management
  static Map<String, List<AssignmentMark>>? _cachedMidsemMarks;
  static DateTime? _cacheTimestamp;
  static const Duration _cacheDuration = Duration(minutes: 5);
  static VoidCallback? _cacheInvalidationCallback;
  
  /// Register callback for cache invalidation
  static void registerCacheInvalidationCallback(VoidCallback callback) {
    _cacheInvalidationCallback = callback;
  }
  
  /// Unregister cache invalidation callback
  static void unregisterCacheInvalidationCallback() {
    _cacheInvalidationCallback = null;
  }
  
  /// Clear cache and trigger callback
  static void clearCache() {
    _cachedMidsemMarks = null;
    _cacheTimestamp = null;
    if (kDebugMode) {
      // MidsemMarksService cache cleared
    }
    _cacheInvalidationCallback?.call();
  }

  /// Get all midsem marks for the current student
  static Future<List<AssignmentMark>> getStudentMidsemMarks() async {
    try {
      final userProfile = await UserProfileService.getCurrentUserProfile();
      if (userProfile == null) {
        throw Exception('User profile not found');
      }

      final userEmail = userProfile.email;
      final user = SupabaseService.currentUser;
      final userId = user?.id;
      
      if (userEmail == null && userId == null) {
        throw Exception('Both user email and user ID are null');
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
          .like('assignment_name', 'Midsem:%')
          .or(query)
          .order('graded_at', ascending: false);

      // Debug: Log fetched midsem data
      // Fetched ${response.length} midsem records
      if (response.isNotEmpty) {
        // Sample record: ${response.first}
        final assignmentNames = response.map((r) => r['assignment_name']).toSet();
        // Assignment names: $assignmentNames
      }

      return (response as List)
          .map((json) {
            final mark = AssignmentMark.fromJson(json);
            // Remove 'Midsem: ' prefix for display
            if (mark.assignmentName.startsWith('Midsem: ')) {
              mark.assignmentName = mark.assignmentName.substring(8);
            }
            return mark;
          })
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch midsem marks: $e');
    }
  }

  /// Get midsem marks grouped by assignment name
  static Future<Map<String, List<AssignmentMark>>> getMidsemMarksGrouped() async {
    final marks = await getStudentMidsemMarks();
    final Map<String, List<AssignmentMark>> groupedMarks = {};

    for (final mark in marks) {
      if (groupedMarks[mark.assignmentName] == null) {
        groupedMarks[mark.assignmentName] = [];
      }
      groupedMarks[mark.assignmentName]!.add(mark);
    }

    return groupedMarks;
  }

  /// Get all midsem marks grouped by class ID (used for subject listing)
  static Future<Map<String, List<AssignmentMark>>> getAllMidsemMarks() async {
    try {
      // Check cache first
      if (_cachedMidsemMarks != null && 
          _cacheTimestamp != null && 
          DateTime.now().difference(_cacheTimestamp!) < _cacheDuration) {
        if (kDebugMode) {
          // Returning cached midsem marks
        }
        return _cachedMidsemMarks!;
      }
      
      final userProfile = await UserProfileService.getCurrentUserProfile();
      if (userProfile == null) {
        // No user profile found
        return {};
      }

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
          .like('assignment_name', 'Midsem:%')
          .or(query)
          .order('created_at', ascending: false);

      // Debug: Log all midsem marks data
      // getAllMidsemMarks - ${response.length} records

      final marks = (response as List)
          .map((json) {
            final mark = AssignmentMark.fromJson(json);
            // Remove 'Midsem: ' prefix for display
            if (mark.assignmentName.startsWith('Midsem: ')) {
              mark.assignmentName = mark.assignmentName.substring(8);
            }
            return mark;
          })
          .toList();
      
      // Apply academic path filtering
      final filteredMarks = await _filterByCurrentAcademicPath(marks, userProfile);
      
      // Group marks by class_id
      final Map<String, List<AssignmentMark>> groupedMarks = {};
      for (final mark in filteredMarks) {
        if (groupedMarks[mark.classId] == null) {
          groupedMarks[mark.classId] = [];
        }
        groupedMarks[mark.classId]!.add(mark);
      }
      
      // Cache the results
      _cachedMidsemMarks = groupedMarks;
      _cacheTimestamp = DateTime.now();
      
      return groupedMarks;
    } catch (e) {
      throw Exception('Failed to fetch all midsem marks: $e');
    }
  }

  /// Get midsem marks for a specific subject/class
  static Future<List<AssignmentMark>> getSubjectMidsemMarks(String classId) async {
    try {
      final userProfile = await UserProfileService.getCurrentUserProfile();
      if (userProfile == null) {
        throw Exception('User profile not found');
      }

      final userEmail = userProfile.email;
      final user = SupabaseService.currentUser;
      final userId = user?.id;
      
      if (userEmail == null && userId == null) {
        throw Exception('Both user email and user ID are null');
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
          .eq('class_id', classId)
          .like('assignment_name', 'Midsem:%')
          .or(query)
          .order('graded_at', ascending: false);

      // Debug: Log subject-specific midsem marks
      // getSubjectMidsemMarks for $classId - ${response.length} records

      return (response as List)
          .map((json) {
            final mark = AssignmentMark.fromJson(json);
            // Remove 'Midsem: ' prefix for display
            if (mark.assignmentName.startsWith('Midsem: ')) {
              mark.assignmentName = mark.assignmentName.substring(8);
            }
            return mark;
          })
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch subject midsem marks: $e');
    }
  }

  /// Get class information with subject details for midsem marks
  static Future<Map<String, Map<String, dynamic>>> getClassSubjectInfo(List<String> classIds) async {
    try {
      final Map<String, Map<String, dynamic>> classInfo = {};
      
      for (final classId in classIds) {
        try {
          // Get midsem data for this class to extract subject name
          final midsemResponse = await _client
              .from('class_assignment_marks')
              .select('assignment_name, class_id, subject_name')
              .eq('class_id', classId)
              .like('assignment_name', 'Midsem:%')
              .limit(1)
              .maybeSingle();
          
          String subjectName = 'Unknown Subject';
          
          if (midsemResponse != null) {
            // Use the subject_name from the database if available
            subjectName = midsemResponse['subject_name'] ?? 'Unknown Subject';
            // Found subject name for class $classId: $subjectName
          } else {
            // No midsem data found for class $classId
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

  /// Get midsem marks statistics for a student
  static Future<Map<String, dynamic>> getMidsemStatistics() async {
    try {
      final marks = await getStudentMidsemMarks();
      
      if (marks.isEmpty) {
        return {
          'totalExams': 0,
          'averagePercentage': 0.0,
          'totalMarks': 0.0,
          'maxPossibleMarks': 0.0,
          'gradedExams': 0,
          'pendingExams': 0,
        };
      }

      final gradedMarks = marks.where((mark) => mark.marks != null && mark.marks! >= 0).toList();
      final pendingMarks = marks.where((mark) => mark.marks == null).toList();

      double totalMarks = 0;
      double maxPossibleMarks = 0;
      double totalPercentage = 0;

      for (final mark in gradedMarks) {
        totalMarks += mark.marks!;
        maxPossibleMarks += mark.maxMarks ?? 0;
        if (mark.maxMarks != null && mark.maxMarks! > 0) {
          totalPercentage += (mark.marks! / mark.maxMarks!) * 100;
        }
      }

      return {
        'totalExams': marks.length,
        'averagePercentage': gradedMarks.isNotEmpty ? totalPercentage / gradedMarks.length : 0.0,
        'totalMarks': totalMarks,
        'maxPossibleMarks': maxPossibleMarks,
        'gradedExams': gradedMarks.length,
        'pendingExams': pendingMarks.length,
        'overallPercentage': maxPossibleMarks > 0 ? (totalMarks / maxPossibleMarks) * 100 : 0.0,
      };
    } catch (e) {
      throw Exception('Failed to calculate midsem statistics: $e');
    }
  }

  /// Get recent midsem marks (last 5)
  static Future<List<AssignmentMark>> getRecentMidsemMarks({int limit = 5}) async {
    try {
      final marks = await getStudentMidsemMarks();
      
      // Filter only graded marks and sort by graded date
      final gradedMarks = marks
          .where((mark) => mark.marks != null && mark.gradedAt != null)
          .toList();
      
      gradedMarks.sort((a, b) => b.gradedAt!.compareTo(a.gradedAt!));
      
      return gradedMarks.take(limit).toList();
    } catch (e) {
      throw Exception('Failed to fetch recent midsem marks: $e');
    }
  }
  
  /// Filter midsem marks by current academic path (college, branch, semester)
  static Future<List<AssignmentMark>> _filterByCurrentAcademicPath(
    List<AssignmentMark> midsemMarks, 
    dynamic userProfile
  ) async {
    try {
      if (midsemMarks.isEmpty) {
        if (kDebugMode) {
          // No midsem marks to filter
        }
        return midsemMarks;
      }
      
      final currentCollege = userProfile.college?.toString().trim();
      final currentBranch = userProfile.branch?.toString().trim();
      final currentSemester = userProfile.semester?.toString().trim();
      
      if (kDebugMode) {
        // Filtering midsem marks by academic path:
        //   College: $currentCollege
        //   Branch: $currentBranch
        //   Semester: $currentSemester
      }
      
      // If academic path is incomplete, return all marks (graceful fallback)
      if (currentCollege == null || currentCollege.isEmpty ||
          currentBranch == null || currentBranch.isEmpty ||
          currentSemester == null || currentSemester.isEmpty) {
        if (kDebugMode) {
          // Incomplete academic path, returning all midsem marks
        }
        return midsemMarks;
      }
      
      // Get unique class IDs from midsem marks
      final classIds = midsemMarks.map((mark) => mark.classId).toSet().toList();
      
      if (classIds.isEmpty) {
        if (kDebugMode) {
          // No class IDs found in midsem marks
        }
        return midsemMarks;
      }
      
      // Query class_rosters with classes join to get academic context
      final classRosterResponse = await _client
          .from('class_rosters')
          .select('class_id, classes!inner(college, branch, semester)')
          .inFilter('class_id', classIds);
      
      if (kDebugMode) {
        // Class roster query returned ${classRosterResponse.length} records
      }
      
      // Extract valid class IDs that match current academic path
      final validClassIds = <String>{};
      
      for (final roster in classRosterResponse) {
        final classId = roster['class_id'] as String;
        final classInfo = roster['classes'] as Map<String, dynamic>;
        
        final classCollege = classInfo['college']?.toString().trim();
        final classBranch = classInfo['branch']?.toString().trim();
        final classSemester = classInfo['semester']?.toString().trim();
        
        // Case-insensitive comparison
        final collegeMatch = classCollege?.toLowerCase() == currentCollege.toLowerCase();
        final branchMatch = classBranch?.toLowerCase() == currentBranch.toLowerCase();
        final semesterMatch = classSemester?.toLowerCase() == currentSemester.toLowerCase();
        
        if (collegeMatch && branchMatch && semesterMatch) {
          validClassIds.add(classId);
          if (kDebugMode) {
            // Class $classId matches academic path: $classCollege, $classBranch, $classSemester
          }
        } else {
          if (kDebugMode) {
            // Class $classId does not match: $classCollege, $classBranch, $classSemester
          }
        }
      }
      
      // Filter midsem marks to only include valid class IDs
      final filteredMarks = midsemMarks
          .where((mark) => validClassIds.contains(mark.classId))
          .toList();
      
      if (kDebugMode) {
        // Filtered midsem marks from ${midsemMarks.length} to ${filteredMarks.length}
        // Valid class IDs: $validClassIds
      }
      
      return filteredMarks;
    } catch (e) {
      if (kDebugMode) {
        // ERROR: Failed to filter midsem marks by academic path: $e
      }
      // Return original marks on error (graceful fallback)
      return midsemMarks;
    }
  }
}
