import 'package:flutter/material.dart';
import 'dart:io';

/// Simple network service to check connectivity
class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  void initialize() {}

  Future<bool> isConnected() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Check if Supabase endpoints are reachable
  Future<bool> isSupabaseReachable() async {
    try {
      // Try to resolve the Supabase hostname
      final result = await InternetAddress.lookup('vpjzxhfrqyspcbgmwqjd.supabase.co');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}

/// Mixin for network-aware widgets
mixin NetworkAwareMixin<T extends StatefulWidget> on State<T> {
  Future<void> refreshNetworkStatus() async {
    // Override this method in your widget for custom behavior
    // Default implementation does nothing - override as needed
  }
}

/// Widget to show a consistent network error UI
Widget buildNetworkErrorWidget({
  required String title,
  required String message,
  String? customEmoji,
  required VoidCallback onRetry,
}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (customEmoji != null)
            Text(
              customEmoji,
              style: const TextStyle(fontSize: 48),
            ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    ),
  );
} 