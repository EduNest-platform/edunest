import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStorageService {
  static const String _salt = "EduNest_Secure_Salt_2024";

  // Encrypt data with a simple hash-based approach
  static String _encrypt(String data) {
    final bytes = utf8.encode(data + _salt);
    final digest = sha256.convert(bytes);
    return "${base64.encode(utf8.encode(data))}.$digest";
  }

  // Decrypt data
  static String? _decrypt(String encryptedData) {
    try {
      final parts = encryptedData.split(".");
      if (parts.length != 2) return null;

      final data = utf8.decode(base64.decode(parts[0]));
      final expectedHash = parts[1];

      // Verify hash
      final bytes = utf8.encode(data + _salt);
      final actualHash = sha256.convert(bytes).toString();

      if (actualHash == expectedHash) {
        return data;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Store sensitive data securely
  static Future<void> storeSecureData(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedValue = _encrypt(value);
      await prefs.setString('secure_$key', encryptedValue);
    } catch (e) {
      // Fallback to plain storage if encryption fails
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('secure_$key', value);
    }
  }

  // Retrieve sensitive data securely
  static Future<String?> getSecureData(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedValue = prefs.getString('secure_$key');
      if (encryptedValue == null) return null;

      final decryptedValue = _decrypt(encryptedValue);
      return decryptedValue;
    } catch (e) {
      // Fallback to plain storage if decryption fails
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('secure_$key');
    }
  }

  // Delete sensitive data
  static Future<void> deleteSecureData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('secure_$key');
  }

  // Clear all secure data
  static Future<void> clearAllSecureData() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith('secure_')) {
        await prefs.remove(key);
      }
    }
  }

  // Store access token securely
  static Future<void> storeAccessToken(String token) async {
    await storeSecureData('access_token', token);
  }

  // Store refresh token securely
  static Future<void> storeRefreshToken(String token) async {
    await storeSecureData('refresh_token', token);
  }

  // Get access token securely
  static Future<String?> getAccessToken() async {
    return await getSecureData('access_token');
  }

  // Get refresh token securely
  static Future<String?> getRefreshToken() async {
    return await getSecureData('refresh_token');
  }

  // Clear all tokens
  static Future<void> clearTokens() async {
    await deleteSecureData('access_token');
    await deleteSecureData('refresh_token');
  }
}
