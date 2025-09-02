import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subject.dart';

class SubjectCacheService {
  static const String _cacheKey = 'cached_subjects';
  static const String _timestampKey = 'subjects_cache_timestamp';
  static const Duration _cacheValidityDuration = Duration(hours: 2);

  /// Load subjects from cache if available and valid
  static Future<List<Subject>> loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check cache timestamp
      final timestamp = prefs.getInt(_timestampKey);
      if (timestamp == null) {
        print('📱 CACHE: No timestamp found');
        return [];
      }
      
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      
      if (now.difference(cacheTime) > _cacheValidityDuration) {
        print('📱 CACHE: Cache expired (${now.difference(cacheTime).inMinutes} minutes old)');
        return [];
      }
      
      // Load cached data
      final cachedJson = prefs.getString(_cacheKey);
      if (cachedJson == null) {
        print('📱 CACHE: No cached data found');
        return [];
      }
      
      final List<dynamic> decoded = jsonDecode(cachedJson);
      final subjects = decoded.map((json) => Subject.fromJson(json)).toList();
      
      print('📱 CACHE: Loaded ${subjects.length} subjects from cache');
      return subjects;
    } catch (e) {
      print('📱 CACHE: Error loading from cache: $e');
      return [];
    }
  }

  /// Save subjects to cache
  static Future<void> saveToCache(List<Subject> subjects) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final encoded = jsonEncode(subjects.map((s) => s.toJson()).toList());
      await prefs.setString(_cacheKey, encoded);
      await prefs.setInt(_timestampKey, DateTime.now().millisecondsSinceEpoch);
      
      print('📱 CACHE: Saved ${subjects.length} subjects to cache');
    } catch (e) {
      print('📱 CACHE: Error saving to cache: $e');
    }
  }

  /// Clear cache
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_timestampKey);
      print('📱 CACHE: Cache cleared');
    } catch (e) {
      print('📱 CACHE: Error clearing cache: $e');
    }
  }

  /// Check if cache is valid
  static Future<bool> isCacheValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_timestampKey);
      
      if (timestamp == null) return false;
      
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      
      return now.difference(cacheTime) <= _cacheValidityDuration;
    } catch (e) {
      return false;
    }
  }
}