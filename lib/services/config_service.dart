import 'dart:io';
import 'package:flutter/foundation.dart';

class ConfigService {
  // Environment-based configuration
  static const bool _isProduction = bool.fromEnvironment('dart.vm.product');

  // Supabase configuration
  static String get supabaseUrl {
    if (_isProduction) {
      // In production, use environment variables or secure storage
      return const String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: 'https://vpjzxhfrqyspcbgmwqjd.supabase.co',
      );
    } else {
      // In development, use hardcoded values (less secure but convenient)
      return 'https://vpjzxhfrqyspcbgmwqjd.supabase.co';
    }
  }

  static String get supabaseAnonKey {
    if (_isProduction) {
      // In production, use environment variables or secure storage
      return const String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZwanp4aGZycXlzcGNiZ213cWpkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTExMDQ5NzIsImV4cCI6MjA2NjY4MDk3Mn0.x9dnZg6gvSUWVfuL4-CB6dKUY6sESE1xyM_v9Wmv4Tc',
      );
    } else {
      // In development, use hardcoded values
      return 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZwanp4aGZycXlzcGNiZ213cWpkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTExMDQ5NzIsImV4cCI6MjA2NjY4MDk3Mn0.x9dnZg6gvSUWVfuL4-CB6dKUY6sESE1xyM_v9Wmv4Tc';
    }
  }

  // Security configuration
  static const bool enableCertificatePinning = true;
  static const bool enableNetworkSecurity = true;
  static const int maxFileUploadSize = 50 * 1024 * 1024; // 50MB
  static const List<String> allowedFileTypes = [
    'pdf',
    'doc',
    'docx',
    'ppt',
    'pptx',
    'xls',
    'xlsx',
    'jpg',
    'jpeg',
    'png',
    'gif',
    'mp4',
    'avi',
    'mov',
  ];

  // Rate limiting configuration
  static const int maxApiCallsPerMinute = 60;
  static const int maxLoginAttempts = 5;
  static const Duration lockoutDuration = Duration(minutes: 15);

  // Validation methods
  static bool isValidFileType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return allowedFileTypes.contains(extension);
  }

  static bool isValidFileSize(int fileSize) {
    return fileSize <= maxFileUploadSize;
  }

  static String sanitizeFileName(String fileName) {
    // Remove potentially dangerous characters
    return fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  }
}
