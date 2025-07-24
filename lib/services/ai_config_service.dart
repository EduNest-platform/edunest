import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AIConfigService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Check if AI is properly configured
  static Future<bool> isAIConfigured() async {
    try {
      final response =
          await _supabase
              .from('ai_config')
              .select('huggingface_token')
              .single();

      if (response != null && response['huggingface_token'] != null) {
        final token = response['huggingface_token'] as String;
        return token.isNotEmpty && token.startsWith('hf_');
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get Hugging Face token
  static Future<String?> getHuggingFaceToken() async {
    try {
      final response =
          await _supabase
              .from('ai_config')
              .select('huggingface_token')
              .single();

      if (response != null && response['huggingface_token'] != null) {
        final token = response['huggingface_token'] as String;
        if (token.isNotEmpty && token.startsWith('hf_')) {
          return token;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Test AI configuration
  static Future<Map<String, dynamic>> testAIConfiguration() async {
    try {
      final token = await getHuggingFaceToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'No Hugging Face token configured',
          'details': 'Please configure a token in the admin panel',
        };
      }

      // Test the token with a simple API call
      final response = await _testHuggingFaceToken(token);
      return response;
    } catch (e) {
      return {
        'success': false,
        'message': 'Error testing AI configuration',
        'details': e.toString(),
      };
    }
  }

  /// Test Hugging Face token with direct API call
  static Future<Map<String, dynamic>> _testHuggingFaceToken(
    String token,
  ) async {
    try {
      // Use the same reliable method as the admin panel
      final response = await http.post(
        Uri.parse(
          'https://api-inference.huggingface.co/models/facebook/bart-large-cnn',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'inputs': 'Hello world'}),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Token is valid', 'details': ''};
      } else if (response.statusCode == 401) {
        return {'success': false, 'message': 'Invalid token', 'details': ''};
      } else if (response.statusCode == 503) {
        return {'success': false, 'message': 'Model loading', 'details': ''};
      } else if (response.statusCode == 429) {
        return {
          'success': false,
          'message': 'Rate limit reached',
          'details': '',
        };
      } else {
        return {'success': false, 'message': 'API call failed', 'details': ''};
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error in token test',
        'details': e.toString(),
      };
    }
  }

  /// Get AI configuration status
  static Future<Map<String, dynamic>> getConfigurationStatus() async {
    try {
      final isConfigured = await isAIConfigured();

      if (!isConfigured) {
        return {
          'configured': false,
          'status': 'Not Configured',
          'message': 'Please configure Hugging Face token in admin panel',
          'canUseAI': false,
        };
      }

      // Test the configuration
      final testResult = await testAIConfiguration();

      return {
        'configured': true,
        'status': testResult['success'] ? 'Working' : 'Error',
        'message': testResult['message'],
        'details': testResult['details'],
        'canUseAI': testResult['success'],
      };
    } catch (e) {
      return {
        'configured': false,
        'status': 'Error',
        'message': 'Error checking configuration',
        'details': e.toString(),
        'canUseAI': false,
      };
    }
  }
}
