import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:async';

class AndroidProctoringService {
  static const MethodChannel _channel = MethodChannel('android_proctoring');
  static const EventChannel _eventChannel = EventChannel(
    'android_proctoring_events',
  );

  static bool _isProctoringActive = false;
  static StreamSubscription? _eventSubscription;
  static Function(String)? _onViolationDetected;
  static Function()? _onTestTerminated;

  /// Initialize Android proctoring service
  static Future<void> initialize() async {
    if (!Platform.isAndroid) return;

    try {
      await _channel.invokeMethod('initialize');
    } catch (e) {
      debugPrint('Failed to initialize Android proctoring: $e');
    }
  }

  /// Start proctoring mode with enhanced security
  static Future<bool> startProctoring({
    required Function(String) onViolationDetected,
    required Function() onTestTerminated,
  }) async {
    if (!Platform.isAndroid) return false;

    try {
      _onViolationDetected = onViolationDetected;
      _onTestTerminated = onTestTerminated;

      // Start native Android proctoring
      final result = await _channel.invokeMethod('startProctoring');
      _isProctoringActive = result == true;

      if (_isProctoringActive) {
        _startEventListening();
        debugPrint('Android proctoring started successfully');
      }

      return _isProctoringActive;
    } catch (e) {
      debugPrint('Failed to start Android proctoring: $e');
      return false;
    }
  }

  /// Stop proctoring mode
  static Future<void> stopProctoring() async {
    if (!Platform.isAndroid || !_isProctoringActive) return;

    try {
      await _channel.invokeMethod('stopProctoring');
      _isProctoringActive = false;
      _eventSubscription?.cancel();
      _eventSubscription = null;
      debugPrint('Android proctoring stopped');
    } catch (e) {
      debugPrint('Failed to stop Android proctoring: $e');
    }
  }

  /// Check if proctoring is currently active
  static bool get isProctoringActive => _isProctoringActive;

  /// Start listening for proctoring events
  static void _startEventListening() {
    _eventSubscription?.cancel();
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        _handleProctoringEvent(event);
      },
      onError: (error) {
        debugPrint('Proctoring event error: $error');
      },
    );
  }

  /// Handle proctoring events from native Android
  static void _handleProctoringEvent(dynamic event) {
    if (event is Map) {
      final eventType = event['type'] as String?;
      final details = event['details'] as String?;

      switch (eventType) {
        case 'app_switch_detected':
          _onViolationDetected?.call('App switching detected: $details');
          break;
        case 'recent_apps_pressed':
          _onViolationDetected?.call('Recent apps button pressed');
          break;
        case 'home_button_pressed':
          _onViolationDetected?.call('Home button pressed');
          break;
        case 'back_button_pressed':
          _onViolationDetected?.call('Back button pressed');
          break;
        case 'split_screen_attempted':
          _onViolationDetected?.call('Split screen mode attempted');
          break;
        case 'screenshot_attempted':
          _onViolationDetected?.call('Screenshot attempted');
          break;
        case 'screen_record_attempted':
          _onViolationDetected?.call('Screen recording attempted');
          break;
        case 'test_terminated':
          _onTestTerminated?.call();
          break;
        default:
          debugPrint('Unknown proctoring event: $eventType');
      }
    }
  }

  /// Force terminate the test due to violation
  static Future<void> terminateTest() async {
    if (!Platform.isAndroid) return;

    try {
      await _channel.invokeMethod('terminateTest');
    } catch (e) {
      debugPrint('Failed to terminate test: $e');
    }
  }

  /// Get proctoring status and capabilities
  static Future<Map<String, dynamic>> getProctoringStatus() async {
    if (!Platform.isAndroid) {
      return {'supported': false, 'reason': 'Not Android platform'};
    }

    try {
      final status = await _channel.invokeMethod('getStatus');
      return Map<String, dynamic>.from(status);
    } catch (e) {
      return {'supported': false, 'reason': 'Error: $e'};
    }
  }

  /// Check if device supports advanced proctoring features
  static Future<bool> isAdvancedProctoringSupported() async {
    if (!Platform.isAndroid) return false;

    try {
      final status = await getProctoringStatus();
      return status['supported'] == true && status['advancedFeatures'] == true;
    } catch (e) {
      return false;
    }
  }
}
