import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../theme/app_theme.dart';
import '../../widgets/desktop_sidebar.dart';
import '../../widgets/custom_app_bar.dart';
import '../../services/fcm_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  bool _assignmentNotifications = true;
  bool _midsemNotifications = true;
  bool _generalNotifications = true;
  String? _fcmToken;

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _assignmentNotifications = prefs.getBool('assignment_notifications') ?? true;
      _midsemNotifications = prefs.getBool('midsem_notifications') ?? true;
      _generalNotifications = prefs.getBool('general_notifications') ?? true;
      
      // Only initialize FCM on mobile platforms
      if (defaultTargetPlatform == TargetPlatform.android || 
          defaultTargetPlatform == TargetPlatform.iOS) {
        try {
          final fcmService = FCMService();
          await fcmService.initialize();
          _fcmToken = await FirebaseMessaging.instance.getToken();
        } catch (e) {
          if (kDebugMode) {
            print('FCM initialization error: $e');
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading notification settings: $e');
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleNotification(String type, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('${type}_notifications', value);
      
      setState(() {
        switch (type) {
          case 'assignment':
            _assignmentNotifications = value;
            break;
          case 'midsem':
            _midsemNotifications = value;
            break;
          case 'general':
            _generalNotifications = value;
            break;
        }
      });
      
      // Show feedback
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${type.capitalize()} notifications ${value ? 'enabled' : 'disabled'}'),
            backgroundColor: value ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error toggling notification: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 768; // Typical breakpoint for desktop
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: !isDesktop ? CustomAppBar(
        title: 'Notifications',
        subtitle: 'Manage your notification preferences',
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: AppTheme.primaryBlue,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ) : null,
      body: Row(
        children: [
          if (isDesktop) // Only show sidebar on desktop
            DesktopSidebar(
              selected: 'notifications',
              onNavigate: (route) {
                if (route == Navigator.defaultRouteName) return;
                if (route.startsWith('/') && route != ModalRoute.of(context)?.settings.name) {
                  Navigator.pushReplacementNamed(context, route);
                }
              },
              onLogout: () {
                // Handle logout if needed
              },
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildNotificationSettings(),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationSettings() {
    final isDesktop = MediaQuery.of(context).size.width > 768;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildServiceStatusCard(),
          SizedBox(height: isDesktop ? 24 : 16),
          _buildNotificationToggleCard(),
          SizedBox(height: isDesktop ? 24 : 16),
          _buildUpcomingServicesCard(),
          SizedBox(height: isDesktop ? 0 : 80), // Extra bottom padding for mobile
        ],
      ),
    );
  }

  Widget _buildServiceStatusCard() {
    final bool isWindows = defaultTargetPlatform == TargetPlatform.windows;
    final isDesktop = MediaQuery.of(context).size.width > 768;
    
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(
        horizontal: isDesktop ? 16.0 : 8.0, 
        vertical: isDesktop ? 8.0 : 4.0
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Row(
                children: [
                  Icon(
                    isWindows ? Icons.info_outline : Icons.notifications_active,
                    color: isWindows ? Colors.blue : Colors.green,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Notification Service Status',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isWindows 
                  ? Colors.blue.withValues(alpha: 0.1) 
                  : _fcmToken != null 
                    ? Colors.green.withValues(alpha: 0.1) 
                    : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isWindows 
                    ? Colors.blue 
                    : _fcmToken != null 
                      ? Colors.green 
                      : Colors.red,
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isWindows ? Icons.info : 
                      (_fcmToken != null ? Icons.check_circle : Icons.error),
                    color: isWindows ? Colors.blue : 
                      (_fcmToken != null ? Colors.green : Colors.red),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isWindows
                          ? 'Push notifications are not supported on Windows desktop.\nYou can still manage your notification preferences below.'
                          : _fcmToken != null 
                              ? 'Notification service is active and ready to receive notifications'
                              : 'Notification service is not available. Please check your connection.',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: isWindows 
                          ? Colors.blue.shade800 
                          : _fcmToken != null 
                            ? Colors.green.shade700 
                            : Colors.red.shade700,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!isWindows && _fcmToken != null) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  'Device Token: ${_fcmToken!.substring(0, 20)}...',
                  style: GoogleFonts.robotoMono(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationToggleCard() {
    final isDesktop = MediaQuery.of(context).size.width > 768;
    
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(
        horizontal: isDesktop ? 16.0 : 8.0, 
        vertical: isDesktop ? 8.0 : 4.0
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Row(
                children: [
                  Icon(
                    Icons.tune,
                    color: AppTheme.primaryBlue,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Notification Preferences',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildNotificationToggle(
              'Assignment Marks',
              'Get notified when new assignment marks are published',
              Icons.assignment,
              Colors.blue,
              _assignmentNotifications,
              (value) => _toggleNotification('assignment', value),
            ),
            const SizedBox(height: 8),
            _buildNotificationToggle(
              'Midsem Results',
              'Get notified when midsem results are available',
              Icons.school,
              Colors.orange,
              _midsemNotifications,
              (value) => _toggleNotification('midsem', value),
            ),
            const SizedBox(height: 8),
            _buildNotificationToggle(
              'General Updates',
              'Get notified about app updates',
              Icons.info,
              Colors.green,
              _generalNotifications,
              (value) => _toggleNotification('general', value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationToggle(
    String title,
    String description,
    IconData icon,
    Color color,
    bool value,
    Function(bool) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: true, // Always true to show it's always on
            onChanged: (bool newValue) {
              // Show a snackbar when user tries to toggle
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Notifications cannot be disabled. They are essential for important updates.',
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: color,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
              }
            },
            activeColor: color,
            activeTrackColor: color.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingServicesCard() {
    final isDesktop = MediaQuery.of(context).size.width > 768;
    
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(
        horizontal: isDesktop ? 16.0 : 8.0, 
        vertical: isDesktop ? 8.0 : 4.0
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Row(
                children: [
                  Icon(
                    Icons.upcoming,
                    color: AppTheme.primaryBlue,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Upcoming Notification Services',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildUpcomingService(
              'Attendance Alerts',
              'Get notified when your attendance falls below 75%',
              Icons.warning,
              Colors.amber,
              'Coming Soon',
            ),
            const SizedBox(height: 8),
            _buildUpcomingService(
              'Test Reminders',
              'Receive reminders for upcoming tests and assignments',
              Icons.quiz,
              Colors.purple,
              'Coming Soon',
            ),
            const SizedBox(height: 8),
            _buildUpcomingService(
              'Subject Feedback',
              'Get notified about new feedback campaigns',
              Icons.feedback,
              Colors.teal,
              'Coming Soon',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingService(
    String title,
    String description,
    IconData icon,
    Color color,
    String status,
  ) {
    return Container(
      width: double.infinity, // Take full width
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color.withValues(alpha: 0.7), size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    status,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }
}
