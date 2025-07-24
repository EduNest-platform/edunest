import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class SessionInfo {
  final String sessionId;
  final String deviceName;
  final String deviceType;
  final String browser;
  final String location;
  final DateTime loginTime;
  final DateTime? lastActivity;
  final bool isCurrent;
  final String ipAddress;

  SessionInfo({
    required this.sessionId,
    required this.deviceName,
    required this.deviceType,
    required this.browser,
    required this.location,
    required this.loginTime,
    this.lastActivity,
    required this.isCurrent,
    required this.ipAddress,
  });

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'deviceName': deviceName,
      'deviceType': deviceType,
      'browser': browser,
      'location': location,
      'loginTime': loginTime.toIso8601String(),
      'lastActivity': lastActivity?.toIso8601String(),
      'isCurrent': isCurrent,
      'ipAddress': ipAddress,
    };
  }

  factory SessionInfo.fromJson(Map<String, dynamic> json) {
    return SessionInfo(
      sessionId: json['sessionId'],
      deviceName: json['deviceName'],
      deviceType: json['deviceType'],
      browser: json['browser'],
      location: json['location'],
      loginTime: DateTime.parse(json['loginTime']),
      lastActivity:
          json['lastActivity'] != null
              ? DateTime.parse(json['lastActivity'])
              : null,
      isCurrent: json['isCurrent'] ?? false,
      ipAddress: json['ipAddress'] ?? 'Unknown',
    );
  }
}

class LoginHistoryEntry {
  final String id;
  final DateTime timestamp;
  final String deviceName;
  final String deviceType;
  final String browser;
  final String location;
  final bool isSuccess;
  final String? failureReason;
  final String ipAddress;

  LoginHistoryEntry({
    required this.id,
    required this.timestamp,
    required this.deviceName,
    required this.deviceType,
    required this.browser,
    required this.location,
    required this.isSuccess,
    this.failureReason,
    required this.ipAddress,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'deviceName': deviceName,
      'deviceType': deviceType,
      'browser': browser,
      'location': location,
      'isSuccess': isSuccess,
      'failureReason': failureReason,
      'ipAddress': ipAddress,
    };
  }

  factory LoginHistoryEntry.fromJson(Map<String, dynamic> json) {
    return LoginHistoryEntry(
      id: json['id'],
      timestamp: DateTime.parse(json['timestamp']),
      deviceName: json['deviceName'],
      deviceType: json['deviceType'],
      browser: json['browser'],
      location: json['location'],
      isSuccess: json['isSuccess'],
      failureReason: json['failureReason'],
      ipAddress: json['ipAddress'] ?? 'Unknown',
    );
  }
}

class SessionTrackingService {
  static const String _sessionsKey = 'user_sessions';
  static const String _loginHistoryKey = 'login_history';
  static const int _maxLoginHistoryEntries = 50;
  static const int _maxSessions = 10;

  // Get current device information
  static Future<Map<String, String>> _getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    Map<String, String> deviceData = {};

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceData['deviceName'] = '${androidInfo.brand} ${androidInfo.model}';
        deviceData['deviceType'] = 'Android';
        deviceData['browser'] = 'EduNest Mobile App';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceData['deviceName'] = '${iosInfo.name} ${iosInfo.model}';
        deviceData['deviceType'] = 'iOS';
        deviceData['browser'] = 'EduNest Mobile App';
      } else {
        deviceData['deviceName'] = 'Unknown Device';
        deviceData['deviceType'] = 'Unknown';
        deviceData['browser'] = 'Unknown';
      }
    } catch (e) {
      deviceData['deviceName'] = 'Unknown Device';
      deviceData['deviceType'] = 'Unknown';
      deviceData['browser'] = 'Unknown';
    }

    // TODO: Implement real device/location data here
    deviceData['location'] = 'New Delhi, India';
    deviceData['ipAddress'] = '192.168.1.1'; // Mock IP

    return deviceData;
  }

  // Record a new login session
  static Future<void> recordLoginSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceInfo = await _getDeviceInfo();
      final sessionId = DateTime.now().millisecondsSinceEpoch.toString();

      final session = SessionInfo(
        sessionId: sessionId,
        deviceName: deviceInfo['deviceName']!,
        deviceType: deviceInfo['deviceType']!,
        browser: deviceInfo['browser']!,
        location: deviceInfo['location']!,
        loginTime: DateTime.now(),
        lastActivity: DateTime.now(),
        isCurrent: true,
        ipAddress: deviceInfo['ipAddress']!,
      );

      // Get existing sessions
      final sessionsJson = prefs.getStringList(_sessionsKey) ?? [];
      List<SessionInfo> sessions =
          sessionsJson
              .map((json) => SessionInfo.fromJson(jsonDecode(json)))
              .toList();

      // Mark all existing sessions as not current
      for (int i = 0; i < sessions.length; i++) {
        sessions[i] = SessionInfo(
          sessionId: sessions[i].sessionId,
          deviceName: sessions[i].deviceName,
          deviceType: sessions[i].deviceType,
          browser: sessions[i].browser,
          location: sessions[i].location,
          loginTime: sessions[i].loginTime,
          lastActivity: sessions[i].lastActivity,
          isCurrent: false,
          ipAddress: sessions[i].ipAddress,
        );
      }

      // Add new session
      sessions.add(session);

      // Keep only the most recent sessions
      if (sessions.length > _maxSessions) {
        sessions.sort((a, b) => b.loginTime.compareTo(a.loginTime));
        sessions = sessions.take(_maxSessions).toList();
      }

      // Save sessions
      final sessionsToSave =
          sessions.map((session) => jsonEncode(session.toJson())).toList();
      await prefs.setStringList(_sessionsKey, sessionsToSave);

      // Record in login history
      await recordLoginHistory(true);
    } catch (e) {
      // Handle error silently
    }
  }

  // Record login history entry
  static Future<void> recordLoginHistory(
    bool isSuccess, {
    String? failureReason,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceInfo = await _getDeviceInfo();

      final entry = LoginHistoryEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        deviceName: deviceInfo['deviceName']!,
        deviceType: deviceInfo['deviceType']!,
        browser: deviceInfo['browser']!,
        location: deviceInfo['location']!,
        isSuccess: isSuccess,
        failureReason: failureReason,
        ipAddress: deviceInfo['ipAddress']!,
      );

      // Get existing history
      final historyJson = prefs.getStringList(_loginHistoryKey) ?? [];
      List<LoginHistoryEntry> history =
          historyJson
              .map((json) => LoginHistoryEntry.fromJson(jsonDecode(json)))
              .toList();

      // Add new entry
      history.add(entry);

      // Keep only the most recent entries
      if (history.length > _maxLoginHistoryEntries) {
        history.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        history = history.take(_maxLoginHistoryEntries).toList();
      }

      // Save history
      final historyToSave =
          history.map((entry) => jsonEncode(entry.toJson())).toList();
      await prefs.setStringList(_loginHistoryKey, historyToSave);
    } catch (e) {
      // Handle error silently
    }
  }

  // Get all active sessions
  static Future<List<SessionInfo>> getActiveSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionsJson = prefs.getStringList(_sessionsKey) ?? [];

      final sessions =
          sessionsJson
              .map((json) => SessionInfo.fromJson(jsonDecode(json)))
              .toList();

      return sessions;
    } catch (e) {
      return [];
    }
  }

  // Get login history
  static Future<List<LoginHistoryEntry>> getLoginHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList(_loginHistoryKey) ?? [];

      List<LoginHistoryEntry> history =
          historyJson
              .map((json) => LoginHistoryEntry.fromJson(jsonDecode(json)))
              .toList();

      // Sort by timestamp (newest first)
      history.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return history;
    } catch (e) {
      return [];
    }
  }

  // Terminate a specific session
  static Future<bool> terminateSession(String sessionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionsJson = prefs.getStringList(_sessionsKey) ?? [];
      List<SessionInfo> sessions =
          sessionsJson
              .map((json) => SessionInfo.fromJson(jsonDecode(json)))
              .toList();

      // Remove the session
      sessions.removeWhere((session) => session.sessionId == sessionId);

      // Save updated sessions
      final sessionsToSave =
          sessions.map((session) => jsonEncode(session.toJson())).toList();
      await prefs.setStringList(_sessionsKey, sessionsToSave);

      return true;
    } catch (e) {
      return false;
    }
  }

  // Terminate all other sessions (except current)
  static Future<bool> terminateAllOtherSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionsJson = prefs.getStringList(_sessionsKey) ?? [];
      List<SessionInfo> sessions =
          sessionsJson
              .map((json) => SessionInfo.fromJson(jsonDecode(json)))
              .toList();

      // Keep only the current session
      sessions = sessions.where((session) => session.isCurrent).toList();

      // Save updated sessions
      final sessionsToSave =
          sessions.map((session) => jsonEncode(session.toJson())).toList();
      await prefs.setStringList(_sessionsKey, sessionsToSave);

      return true;
    } catch (e) {
      return false;
    }
  }

  // Update last activity for current session
  static Future<void> updateLastActivity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionsJson = prefs.getStringList(_sessionsKey) ?? [];
      List<SessionInfo> sessions =
          sessionsJson
              .map((json) => SessionInfo.fromJson(jsonDecode(json)))
              .toList();

      // Update current session's last activity
      for (int i = 0; i < sessions.length; i++) {
        if (sessions[i].isCurrent) {
          sessions[i] = SessionInfo(
            sessionId: sessions[i].sessionId,
            deviceName: sessions[i].deviceName,
            deviceType: sessions[i].deviceType,
            browser: sessions[i].browser,
            location: sessions[i].location,
            loginTime: sessions[i].loginTime,
            lastActivity: DateTime.now(),
            isCurrent: true,
            ipAddress: sessions[i].ipAddress,
          );
          break;
        }
      }

      // Save updated sessions
      final sessionsToSave =
          sessions.map((session) => jsonEncode(session.toJson())).toList();
      await prefs.setStringList(_sessionsKey, sessionsToSave);
    } catch (e) {
      // Handle error silently
    }
  }

  // Clear all session data (for logout)
  static Future<void> clearAllSessionData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionsKey);
      await prefs.remove(_loginHistoryKey);
    } catch (e) {
      // Handle error silently
    }
  }

  // Get current session
  static Future<SessionInfo?> getCurrentSession() async {
    try {
      final sessions = await getActiveSessions();
      return sessions.firstWhere((session) => session.isCurrent);
    } catch (e) {
      return null;
    }
  }

  // Check if user has multiple active sessions
  static Future<bool> hasMultipleSessions() async {
    try {
      final sessions = await getActiveSessions();
      return sessions.length > 1;
    } catch (e) {
      return false;
    }
  }
}
