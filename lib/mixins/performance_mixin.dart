import 'package:flutter/material.dart';
import '../services/performance_service.dart';

mixin PerformanceMixin<T extends StatefulWidget> on State<T> {
  final PerformanceService _performanceService = PerformanceService();
  String? _currentTrace;

  /// Start monitoring screen performance
  Future<void> startScreenMonitoring(String screenName) async {
    _currentTrace = screenName;
    await _performanceService.startScreenTrace(screenName);
  }

  /// Stop monitoring screen performance
  Future<void> stopScreenMonitoring() async {
    if (_currentTrace != null) {
      await _performanceService.stopScreenTrace(_currentTrace!);
      _currentTrace = null;
    }
  }

  /// Start a custom operation trace
  Future<void> startOperationTrace(String operationName) async {
    await _performanceService.startTrace(operationName);
  }

  /// Stop a custom operation trace
  Future<void> stopOperationTrace(String operationName) async {
    await _performanceService.stopTrace(operationName);
  }

  /// Add a custom metric
  Future<void> addMetric(String traceName, String metricName, int value) async {
    await _performanceService.addMetric(traceName, metricName, value);
  }

  /// Monitor network request
  Future<void> monitorNetworkRequest(String url, String method) async {
    await _performanceService.monitorNetworkRequest(url, method);
  }

  @override
  void dispose() {
    stopScreenMonitoring();
    super.dispose();
  }
}
