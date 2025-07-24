import 'package:firebase_performance/firebase_performance.dart';

class PerformanceService {
  static final PerformanceService _instance = PerformanceService._internal();
  factory PerformanceService() => _instance;
  PerformanceService._internal();

  // Store active traces to properly stop them
  final Map<String, Trace> _activeTraces = {};
  final Map<String, HttpMetric> _activeHttpMetrics = {};

  /// Start a custom trace for a specific operation
  Future<void> startTrace(String traceName) async {
    try {
      final trace = FirebasePerformance.instance.newTrace(traceName);
      _activeTraces[traceName] = trace;
      await trace.start();
    } catch (e) {
      // Silently handle errors to avoid breaking the app
    }
  }

  /// Stop a custom trace
  Future<void> stopTrace(String traceName) async {
    try {
      final trace = _activeTraces[traceName];
      if (trace != null) {
        await trace.stop();
        _activeTraces.remove(traceName);
      }
    } catch (e) {}
  }

  /// Add a custom metric to a trace
  Future<void> addMetric(String traceName, String metricName, int value) async {
    try {
      final trace = _activeTraces[traceName];
      if (trace != null) {
        trace.setMetric(metricName, value);
      }
    } catch (e) {}
  }

  /// Start monitoring a screen load
  Future<void> startScreenTrace(String screenName) async {
    try {
      final traceName = 'screen_load_$screenName';
      final trace = FirebasePerformance.instance.newTrace(traceName);
      _activeTraces[traceName] = trace;
      await trace.start();
    } catch (e) {}
  }

  /// Stop monitoring a screen load
  Future<void> stopScreenTrace(String screenName) async {
    try {
      final traceName = 'screen_load_$screenName';
      final trace = _activeTraces[traceName];
      if (trace != null) {
        await trace.stop();
        _activeTraces.remove(traceName);
      }
    } catch (e) {}
  }

  /// Start monitoring a network request
  Future<void> startNetworkRequest(String url, String method) async {
    try {
      final metric = FirebasePerformance.instance.newHttpMetric(
        url,
        HttpMethod.values.firstWhere(
          (e) =>
              e.toString().split('.').last.toUpperCase() ==
              method.toUpperCase(),
          orElse: () => HttpMethod.Get,
        ),
      );
      _activeHttpMetrics[url] = metric;
      await metric.start();
    } catch (e) {}
  }

  /// Stop monitoring a network request
  Future<void> stopNetworkRequest(String url, {int? responseCode}) async {
    try {
      final metric = _activeHttpMetrics[url];
      if (metric != null) {
        if (responseCode != null) {
          metric.httpResponseCode = responseCode;
        }
        await metric.stop();
        _activeHttpMetrics.remove(url);
      }
    } catch (e) {}
  }

  /// Monitor network requests (simplified version)
  Future<void> monitorNetworkRequest(String url, String method) async {
    try {
      final metric = FirebasePerformance.instance.newHttpMetric(
        url,
        HttpMethod.values.firstWhere(
          (e) =>
              e.toString().split('.').last.toUpperCase() ==
              method.toUpperCase(),
          orElse: () => HttpMethod.Get,
        ),
      );
      await metric.start();
      // You can add custom attributes here
      metric.httpResponseCode = 200;
      await metric.stop();
    } catch (e) {}
  }
}
