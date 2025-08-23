import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import 'free_plan_optimizer_service.dart';
import 'test_load_monitor.dart';

class TestResultsService {
  static final SupabaseClient _supabase = SupabaseService.client;

  /// Save test result to Supabase
  static Future<bool> saveTestResult({
    required String subjectId,
    required String subjectName,
    required String chapterId,
    required String chapterName,
    required String difficulty,
    required int totalQuestions,
    required int correctAnswers,
    required int score,
    required int timeTaken,
    String testTitle = '',
  }) async {
    return FreePlanOptimizerService.optimizedDatabaseOperation(
      'save_test_result_${testTitle.isNotEmpty ? testTitle : subjectName}',
      () async {
        try {
          final user = _supabase.auth.currentUser;
          if (user == null) return false;

          // Record test completion in monitoring
          if (testTitle.isNotEmpty) {
            // Note: Test completion recording handled by TestLoadMonitor separately
          }

          final response =
              await _supabase
                  .from('test_results')
                  .insert({
                    'user_id': user.id,
                    'subject_id': subjectId,
                    'subject_name': subjectName,
                    'chapter_id': chapterId,
                    'chapter_name': chapterName,
                    'difficulty': difficulty,
                    'total_questions': totalQuestions,
                    'correct_answers': correctAnswers,
                    'score': score,
                    'time_taken': timeTaken,
                    'created_at': DateTime.now().toIso8601String(),
                    'test_title': testTitle,
                  })
                  .select()
                  .single();

          return response != null;
        } catch (e) {
          return false;
        }
      },
    );
  }

  /// Get user's test results from Supabase
  static Future<List<Map<String, dynamic>>> getUserTestResults() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      final response = await _supabase
          .from('test_results')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  /// Check if user has already completed a specific assigned test
  static Future<bool> hasUserCompletedTest(String testTitle) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final response = await _supabase
          .from('test_results')
          .select('id')
          .eq('user_id', user.id)
          .eq('test_title', testTitle)
          .limit(1);

      return response.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get user's completed assigned tests
  static Future<List<String>> getUserCompletedTestTitles() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      final response = await _supabase
          .from('test_results')
          .select('test_title')
          .eq('user_id', user.id)
          .not('test_title', 'is', null)
          .neq('test_title', '');

      return response
          .map((result) => result['test_title'] as String)
          .where((title) => title.isNotEmpty)
          .toSet() // Remove duplicates
          .toList();
          return [];
    } catch (e) {
      return [];
    }
  }

  /// Get test statistics for a user
  static Future<Map<String, dynamic>> getUserTestStats() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return {};

      final response = await _supabase
          .from('test_results')
          .select('score, difficulty, subject_name, chapter_name, time_taken')
          .eq('user_id', user.id);

      final results = (response as List).cast<Map<String, dynamic>>();

      if (results.isEmpty) return {};

      // Calculate statistics
      int totalTests = results.length;
      double averageScore =
          results.fold(0.0, (sum, result) => sum + (result['score'] ?? 0)) /
          totalTests;
      int bestScore = results.fold<int>(
        0,
        (max, result) =>
            ((result['score'] ?? 0) as int) > max
                ? ((result['score'] ?? 0) as int)
                : max,
      );
      int worstScore = results.fold<int>(
        100,
        (min, result) =>
            ((result['score'] ?? 100) as int) < min
                ? ((result['score'] ?? 100) as int)
                : min,
      );
      int totalTimeSpent = results.fold<int>(
        0,
        (sum, result) => sum + ((result['time_taken'] ?? 0) as int),
      );

      // Count by difficulty
      Map<String, int> difficultyCount = {};
      for (final result in results) {
        final difficulty = result['difficulty'] ?? 'unknown';
        difficultyCount[difficulty] = (difficultyCount[difficulty] ?? 0) + 1;
      }

      // Get most tested subjects
      Map<String, int> subjectCount = {};
      for (final result in results) {
        final subject = result['subject_name'] ?? 'Unknown';
        subjectCount[subject] = (subjectCount[subject] ?? 0) + 1;
      }

      // Get recent tests (last 10)
      List<Map<String, dynamic>> recentTests = [];
      final recentResponse = await _supabase
          .from('test_results')
          .select(
            'id, subject_name, chapter_name, difficulty, score, created_at',
          )
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(10);

      recentTests = (recentResponse as List).cast<Map<String, dynamic>>();
    
      return {
        'totalTests': totalTests,
        'averageScore': averageScore.round(),
        'bestScore': bestScore,
        'worstScore': worstScore,
        'totalTimeSpent': totalTimeSpent,
        'difficultyCount': difficultyCount,
        'subjectCount': subjectCount,
        'recentTests': recentTests,
        'bestSubject': _getBestSubjectFromStats({
          'subjectBreakdown': subjectCount,
        }),
        'weakestSubject': _getWeakestSubjectFromStats({
          'subjectBreakdown': subjectCount,
        }),
      };
    } catch (e) {
      return {};
    }
  }

  /// Fallback method for test statistics calculation
  static Future<Map<String, dynamic>> _getUserTestStatsFallback() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return {};

      final response = await _supabase
          .from('test_results')
          .select('score, difficulty, subject_name, chapter_name')
          .eq('user_id', user.id);

      final results = (response as List).cast<Map<String, dynamic>>();

      if (results.isEmpty) return {};

      // Calculate statistics
      int totalTests = results.length;
      double averageScore =
          results.fold(0.0, (sum, result) => sum + (result['score'] ?? 0)) /
          totalTests;

      // Count by difficulty
      Map<String, int> difficultyCount = {};
      Map<String, double> difficultyScores = {};

      for (final result in results) {
        final difficulty = result['difficulty'] ?? 'unknown';
        difficultyCount[difficulty] = (difficultyCount[difficulty] ?? 0) + 1;
        difficultyScores[difficulty] =
            (difficultyScores[difficulty] ?? 0) + (result['score'] ?? 0);
      }

      // Calculate average scores by difficulty
      Map<String, double> averageScoresByDifficulty = {};
      difficultyScores.forEach((difficulty, totalScore) {
        averageScoresByDifficulty[difficulty] =
            totalScore / difficultyCount[difficulty]!;
      });

      // Get most tested subjects
      Map<String, int> subjectCount = {};
      for (final result in results) {
        final subject = result['subject_name'] ?? 'Unknown';
        subjectCount[subject] = (subjectCount[subject] ?? 0) + 1;
      }

      // Get most tested chapters
      Map<String, int> chapterCount = {};
      for (final result in results) {
        final chapter = result['chapter_name'] ?? 'Unknown';
        chapterCount[chapter] = (chapterCount[chapter] ?? 0) + 1;
      }

      return {
        'totalTests': totalTests,
        'averageScore': averageScore.round(),
        'difficultyCount': difficultyCount,
        'averageScoresByDifficulty': averageScoresByDifficulty,
        'subjectCount': subjectCount,
        'chapterCount': chapterCount,
        'bestSubject': _getBestSubject(subjectCount, results),
        'weakestSubject': _getWeakestSubject(subjectCount, results),
      };
    } catch (e) {
      return {};
    }
  }

  /// Get best performing subject from stats
  static String _getBestSubjectFromStats(Map<String, dynamic> stats) {
    final subjectCount = Map<String, int>.from(stats['subjectBreakdown'] ?? {});
    if (subjectCount.isEmpty) return 'None';

    String bestSubject = 'Unknown';
    int maxCount = 0;

    subjectCount.forEach((subject, count) {
      if (count > maxCount) {
        maxCount = count;
        bestSubject = subject;
      }
    });

    return bestSubject;
  }

  /// Get weakest performing subject from stats
  static String _getWeakestSubjectFromStats(Map<String, dynamic> stats) {
    final subjectCount = Map<String, int>.from(stats['subjectBreakdown'] ?? {});
    if (subjectCount.isEmpty) return 'None';

    String weakestSubject = 'Unknown';
    int minCount = 999;

    subjectCount.forEach((subject, count) {
      if (count < minCount) {
        minCount = count;
        weakestSubject = subject;
      }
    });

    return weakestSubject;
  }

  /// Get best performing subject
  static String _getBestSubject(
    Map<String, int> subjectCount,
    List<Map<String, dynamic>> results,
  ) {
    if (subjectCount.isEmpty) return 'None';

    Map<String, double> subjectScores = {};
    for (final result in results) {
      final subject = result['subject_name'] ?? 'Unknown';
      subjectScores[subject] =
          (subjectScores[subject] ?? 0) + (result['score'] ?? 0);
    }

    String bestSubject = 'Unknown';
    double bestScore = 0;

    subjectScores.forEach((subject, totalScore) {
      final averageScore = totalScore / subjectCount[subject]!;
      if (averageScore > bestScore) {
        bestScore = averageScore;
        bestSubject = subject;
      }
    });

    return bestSubject;
  }

  /// Get weakest performing subject
  static String _getWeakestSubject(
    Map<String, int> subjectCount,
    List<Map<String, dynamic>> results,
  ) {
    if (subjectCount.isEmpty) return 'None';

    Map<String, double> subjectScores = {};
    for (final result in results) {
      final subject = result['subject_name'] ?? 'Unknown';
      subjectScores[subject] =
          (subjectScores[subject] ?? 0) + (result['score'] ?? 0);
    }

    String weakestSubject = 'Unknown';
    double lowestScore = 100;

    subjectScores.forEach((subject, totalScore) {
      final averageScore = totalScore / subjectCount[subject]!;
      if (averageScore < lowestScore) {
        lowestScore = averageScore;
        weakestSubject = subject;
      }
    });

    return weakestSubject;
  }

  /// Get recent test results (last 10)
  static Future<List<Map<String, dynamic>>> getRecentTestResults({
    int limit = 10,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      final response = await _supabase
          .from('test_results')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  /// Delete a test result
  static Future<bool> deleteTestResult(String resultId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      await _supabase
          .from('test_results')
          .delete()
          .eq('id', resultId)
          .eq('user_id', user.id);

      return true;
    } catch (e) {
      return false;
    }
  }
}
