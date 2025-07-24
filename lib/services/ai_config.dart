import 'package:shared_preferences/shared_preferences.dart';

class AIConfig {
  static const String _openaiKeyKey = 'openai_api_key';
  static const String _huggingfaceKeyKey = 'huggingface_token';
  static const String _aiEnabledKey = 'ai_enabled';
  static const String _maxCostPerMonthKey = 'max_cost_per_month';
  static const String _currentMonthCostKey = 'current_month_cost';

  /// Get OpenAI API key
  static Future<String?> getOpenAIKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_openaiKeyKey);
    } catch (e) {
      return null;
    }
  }

  /// Set OpenAI API key
  static Future<void> setOpenAIKey(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_openaiKeyKey, key);
    } catch (e) {
      // ... existing code ...
    }
  }

  /// Get Hugging Face token (Developer-managed)
  static Future<String?> getHuggingFaceToken() async {
    // Developer-managed token - you control this
    const String token =
        'hf_eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJlbWFpbCI6InJhbm9qaXQuZGFzLmNvZGVyQGdtYWlsLmNvbSIsInVzZXJfbmFtZSI6InJhbm9qaXQtZGFzIiwiZXhwIjoxNzM1Njg5NjAwfQ.Ej8Ej8Ej8Ej8Ej8Ej8Ej8Ej8Ej8Ej8Ej8Ej8Ej8';
    return token;
  }

  /// Set Hugging Face token (Developer-managed)
  static Future<void> setHuggingFaceToken(String token) async {
    // This method is kept for compatibility but tokens are now developer-managed
    // Debug code removed
  }

  /// Check if AI is enabled
  static Future<bool> isAIEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_aiEnabledKey) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Enable/disable AI
  static Future<void> setAIEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_aiEnabledKey, enabled);
    } catch (e) {
      // ... existing code ...
    }
  }

  /// Get maximum cost per month
  static Future<double> getMaxCostPerMonth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble(_maxCostPerMonthKey) ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  /// Set maximum cost per month
  static Future<void> setMaxCostPerMonth(double cost) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_maxCostPerMonthKey, cost);
    } catch (e) {
      // ... existing code ...
    }
  }

  /// Get current month cost
  static Future<double> getCurrentMonthCost() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble(_currentMonthCostKey) ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  /// Add to current month cost
  static Future<void> addToCurrentMonthCost(double cost) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentCost = prefs.getDouble(_currentMonthCostKey) ?? 0.0;
      await prefs.setDouble(_currentMonthCostKey, currentCost + cost);
    } catch (e) {
      // ... existing code ...
    }
  }

  /// Reset monthly cost (call at start of month)
  static Future<void> resetMonthlyCost() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_currentMonthCostKey, 0.0);
    } catch (e) {
      // ... existing code ...
    }
  }

  /// Check if we can afford more AI calls
  static Future<bool> canAffordAICall(double estimatedCost) async {
    try {
      final currentCost = await getCurrentMonthCost();
      final maxCost = await getMaxCostPerMonth();
      return (currentCost + estimatedCost) <= maxCost;
    } catch (e) {
      return false;
    }
  }

  /// Get AI configuration summary
  static Future<Map<String, dynamic>> getAIConfigSummary() async {
    try {
      final aiEnabled = await isAIEnabled();
      final openaiKey = await getOpenAIKey();
      final hfToken = await getHuggingFaceToken();
      final maxCost = await getMaxCostPerMonth();
      final currentCost = await getCurrentMonthCost();

      return {
        'ai_enabled': aiEnabled,
        'openai_configured': openaiKey != null && openaiKey.isNotEmpty,
        'huggingface_configured': hfToken != null && hfToken.isNotEmpty,
        'max_cost_per_month': maxCost,
        'current_month_cost': currentCost,
        'remaining_budget': maxCost - currentCost,
      };
    } catch (e) {
      return {};
    }
  }

  /// Clear all AI configuration
  static Future<void> clearAIConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_openaiKeyKey);
      await prefs.remove(_huggingfaceKeyKey);
      await prefs.remove(_aiEnabledKey);
      await prefs.remove(_maxCostPerMonthKey);
      await prefs.remove(_currentMonthCostKey);
    } catch (e) {
      // ... existing code ...
    }
  }
}
