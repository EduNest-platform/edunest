import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase/supabase.dart';
import 'free_plan_optimizer_service.dart';
import 'test_load_monitor.dart';

class AssignedMCQSupabaseService {
  static const String supabaseUrl = 'https://pfuzvpihupvhjshxiofn.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBmdXp2cGlodXB2aGpzaHhpb2ZuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE1Mjg1MjIsImV4cCI6MjA2NzEwNDUyMn0.WAPJG6iaxuCAM75yCRu6UOcck37XuilVoDJK3uwyx-k';

  static final SupabaseClient client = SupabaseClient(
    supabaseUrl,
    supabaseAnonKey,
  );

  /// Fetches questions for a given test name
  static Future<List<Map<String, dynamic>>> fetchQuestionsForTest(
    String testName,
  ) async {
    return FreePlanOptimizerService.optimizedDatabaseOperation(
      'fetch_questions_for_test_$testName',
      () async {
        // Start monitoring for this test
        TestLoadMonitor.startMonitoring(testName, 50);
        
        final response = await client
            .from('questions')
            .select()
            .eq('test_name', testName)
            .order('created_at');
        return List<Map<String, dynamic>>.from(response);
      },
      cacheDuration: const Duration(minutes: 10), // Cache questions for 10 minutes
    );
  }

  /// Fetches a list of assigned tests (unique test_name values) from the questions table
  static Future<List<Map<String, dynamic>>> fetchAssignedTests() async {
    return FreePlanOptimizerService.optimizedDatabaseOperation(
      'fetch_assigned_tests',
      () async {
        // Get all unique test_names
        final response = await client
            .from('questions')
            .select('test_name')
            .not('test_name', 'is', null);

        final testNames =
            response
                .map((row) => row['test_name'])
                .where((name) => name != null)
                .toSet()
                .toList();

        List<Map<String, dynamic>> assignedTests = [];

        for (final testName in testNames) {
          // Fetch all questions for this test_name
          final questionsResponse = await client
              .from('questions')
              .select('test_name, created_at, subject, duration_minutes')
              .eq('test_name', testName);

          if (questionsResponse.isNotEmpty) {
            final testRow = questionsResponse.first;
            final questionCount = questionsResponse.length;

            assignedTests.add({...testRow, 'question_count': questionCount});
          }
        }
        return assignedTests;
      },
      cacheDuration: const Duration(minutes: 15), // Cache assigned tests list
    );
  }
}
