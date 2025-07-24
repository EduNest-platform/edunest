import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HybridAIService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static const int _cacheExpiryHours = 24;

  /// Fetch questions from Supabase for a given subject, chapter, and difficulty
  static Future<List<Map<String, dynamic>>> fetchQuestions({
    required String subject,
    required String chapter,
    required String difficulty,
    int limit = 20,
  }) async {
    try {
      final response = await _supabase
          .from('questions')
          .select()
          .eq('subject', subject)
          .eq('chapter', chapter)
          .eq('difficulty', difficulty)
          .limit(limit);
      if (response != null && response is List) {
        return List<Map<String, dynamic>>.from(response);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Cache management (optional, for offline/fast access)
  static Future<List<Map<String, dynamic>>> getCachedQuestions(
    String subject,
    String chapter,
    String difficulty,
    int questionCount,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'questions_${subject}_${chapter}_${difficulty}';
      final cachedData = prefs.getString(cacheKey);
      if (cachedData != null) {
        final cache = jsonDecode(cachedData) as Map<String, dynamic>;
        final timestamp = DateTime.parse(cache['timestamp']);
        final questions = List<Map<String, dynamic>>.from(cache['questions']);
        if (DateTime.now().difference(timestamp).inHours < _cacheExpiryHours) {
          return questions.take(questionCount).toList();
        }
      }
    } catch (e) {
      // ... existing code ...
    }
    return [];
  }

  static Future<void> cacheQuestions(
    List<Map<String, dynamic>> questions,
    String subject,
    String chapter,
    String difficulty,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'questions_${subject}_${chapter}_${difficulty}';
      final cache = {
        'timestamp': DateTime.now().toIso8601String(),
        'questions': questions,
      };
      await prefs.setString(cacheKey, jsonEncode(cache));
    } catch (e) {
      // ... existing code ...
    }
  }
}
