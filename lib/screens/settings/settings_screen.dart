import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../../widgets/app_text.dart';
import '../../widgets/desktop_sidebar.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  bool _autoDownloadEnabled = false;
  String _selectedLanguage = 'English';
  final String _selectedTheme = 'System Default';

  final List<String> _languages = [
    'English',
    'Hindi',
    'Spanish',
    'French',
    'German',
  ];
  final List<String> _themes = ['System Default', 'Light', 'Dark'];

  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset =
            _scrollController.hasClients ? _scrollController.offset : 0.0;
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Helper function to launch URLs
  Future<void> _launchInApp(BuildContext context, String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(
      url,
      mode: LaunchMode.inAppWebView, // This opens the URL inside the app
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not launch $urlString'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _getCollapsedAppBarColor(bool isCollapsed) {
    return isCollapsed ? AppTheme.primaryBlue : Colors.transparent;
  }

  BoxDecoration _getAppBarDecoration(bool isCollapsed) {
    if (isCollapsed) {
      // Blue gradient when collapsed
      return BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primaryBlue, AppTheme.primaryLight],
        ),
      );
    } else {
      // Original animated gradient
      return BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryBlue,
            AppTheme.primaryLight,
            Colors.purple.shade400,
          ],
        ),
      );
    }
  }



  Widget _buildAppBarLeading(bool isCollapsed) {
    // Always use the floating, rounded, shadowed back button design
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.black87),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isCollapsed = _scrollOffset > 50;
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final maxContentWidth = 900.0;
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body:
          isDesktop
              ? Row(
                children: [
                  DesktopSidebar(
                    selected: 'settings',
                    onNavigate: (route) => Navigator.pushNamed(context, route),
                    onLogout: () {
                      // Implement logout logic if needed
                    },
                  ),
                  Expanded(
                    child: CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        SliverAppBar(
                          expandedHeight: 180,
                          floating: false,
                          pinned: true,
                          backgroundColor: _getCollapsedAppBarColor(
                            isCollapsed,
                          ),
                          forceElevated: true,
                          elevation: 0,
                          title:
                              isCollapsed
                                  ? AppText(
                                    'Settings',
                                    style: GoogleFonts.poppins(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: -0.5,
                                    ),
                                  )
                                  : null,
                          leading: _buildAppBarLeading(isCollapsed),
                          flexibleSpace: FlexibleSpaceBar(
                            background: Stack(
                              fit: StackFit.expand,
                              children: [
                                Container(
                                  decoration: _getAppBarDecoration(isCollapsed),
                                ),
                                Positioned(
                                  top: -30,
                                  right: -30,
                                  child: Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.1,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const SizedBox(height: 16),
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.3,
                                            ),
                                            width: 2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.1,
                                              ),
                                              blurRadius: 20,
                                              offset: const Offset(0, 10),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.settings_rounded,
                                          size: 22,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      AppText(
                                        'Settings',
                                        style: GoogleFonts.poppins(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      AppText(
                                        'Customize your experience',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: Colors.white.withValues(
                                            alpha: 0.9,
                                          ),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth: maxContentWidth,
                              ),
                              margin: const EdgeInsets.symmetric(vertical: 24),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Account Settings
                                    _sectionHeader('Account Settings'),
                                    Card(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: BorderSide(
                                          color: AppTheme.primaryBlue
                                              .withValues(alpha: 0.18),
                                          width: 1.5,
                                        ),
                                      ),
                                      elevation: 4,
                                      margin: const EdgeInsets.only(
                                        top: 10,
                                        bottom: 24,
                                      ),
                                      child: Column(
                                        children: [
                                          _simpleTile(
                                            title: 'Edit Profile',
                                            subtitle:
                                                'Update your personal information and preferences',
                                            icon: Icons.edit_rounded,
                                            onTap: () {
                                              Navigator.pushNamed(
                                                context,
                                                '/profile',
                                              );
                                            },
                                          ),
                                          _divider(),
                                          _simpleTile(
                                            title: 'Security Settings',
                                            subtitle:
                                                'Manage authentication, privacy, and account protection',
                                            icon: Icons.security_rounded,
                                            iconColor: Colors.red,
                                            onTap: () {
                                              Navigator.pushNamed(
                                                context,
                                                '/security',
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),

                                    // App Preferences
                                    _sectionHeader('App Preferences'),
                                    Card(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: BorderSide(
                                          color: AppTheme.primaryBlue
                                              .withValues(alpha: 0.18),
                                          width: 1.5,
                                        ),
                                      ),
                                      elevation: 4,
                                      margin: const EdgeInsets.only(
                                        top: 10,
                                        bottom: 24,
                                      ),
                                      child: Column(
                                        children: [
                                          _dropdownTile(
                                            title: 'Language',
                                            subtitle:
                                                'Choose your preferred language',
                                            icon: Icons.language_rounded,
                                            value: _selectedLanguage,
                                            options: _languages,
                                            onChanged: (value) {
                                              setState(() {
                                                _selectedLanguage = value;
                                              });
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Language support coming soon!',
                                                  ),
                                                  backgroundColor:
                                                      Colors.orange,
                                                ),
                                              );
                                            },
                                          ),
                                          _divider(),
                                          _switchTile(
                                            title: 'Dark Mode',
                                            subtitle: 'Enable dark theme',
                                            icon: Icons.dark_mode_rounded,
                                            value: _darkModeEnabled,
                                            onChanged: (value) {
                                              setState(() {
                                                _darkModeEnabled = value;
                                              });
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Coming soon!'),
                                                  backgroundColor:
                                                      Colors.orange,
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Notifications
                                    _sectionHeader('Notifications'),
                                    Card(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: BorderSide(
                                          color: AppTheme.primaryBlue
                                              .withValues(alpha: 0.18),
                                          width: 1.5,
                                        ),
                                      ),
                                      elevation: 4,
                                      margin: const EdgeInsets.only(
                                        top: 10,
                                        bottom: 24,
                                      ),
                                      child: Column(
                                        children: [
                                          _switchTile(
                                            title: 'Push Notifications',
                                            subtitle:
                                                'Receive app notifications',
                                            icon:
                                                Icons
                                                    .notifications_active_rounded,
                                            value: _notificationsEnabled,
                                            onChanged: (value) {
                                              setState(() {
                                                _notificationsEnabled = value;
                                              });
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    value
                                                        ? 'Push notifications enabled (coming soon!)'
                                                        : 'Push notifications disabled (coming soon!)',
                                                  ),
                                                  backgroundColor:
                                                      Colors.orange,
                                                ),
                                              );
                                            },
                                          ),
                                          _divider(),
                                          _simpleTile(
                                            title: 'Notification Preferences',
                                            subtitle:
                                                'Customize notification settings',
                                            icon:
                                                Icons
                                                    .settings_applications_rounded,
                                            onTap: () {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Notification preferences coming soon!',
                                                  ),
                                                  backgroundColor:
                                                      Colors.orange,
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Data & Storage
                                    _sectionHeader('Data & Storage'),
                                    Card(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: BorderSide(
                                          color: AppTheme.primaryBlue
                                              .withValues(alpha: 0.18),
                                          width: 1.5,
                                        ),
                                      ),
                                      elevation: 4,
                                      margin: const EdgeInsets.only(
                                        top: 10,
                                        bottom: 24,
                                      ),
                                      child: Column(
                                        children: [
                                          _switchTile(
                                            title: 'Auto Download',
                                            subtitle:
                                                'Automatically download new resources',
                                            icon: Icons.download_rounded,
                                            value: _autoDownloadEnabled,
                                            onChanged: (value) {
                                              setState(() {
                                                _autoDownloadEnabled = value;
                                              });
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    value
                                                        ? 'Auto download enabled (coming soon!)'
                                                        : 'Auto download disabled (coming soon!)',
                                                  ),
                                                  backgroundColor:
                                                      Colors.orange,
                                                ),
                                              );
                                            },
                                          ),
                                          _divider(),
                                          _simpleTile(
                                            title: 'Clear Cache',
                                            subtitle: 'Free up storage space',
                                            icon:
                                                Icons.cleaning_services_rounded,
                                            onTap: () {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Cache clearing feature coming soon!',
                                                  ),
                                                  backgroundColor:
                                                      Colors.orange,
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Privacy & Legal
                                    _sectionHeader('Privacy & Legal'),
                                    Card(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: BorderSide(
                                          color: AppTheme.primaryBlue
                                              .withValues(alpha: 0.18),
                                          width: 1.5,
                                        ),
                                      ),
                                      elevation: 4,
                                      margin: const EdgeInsets.only(
                                        top: 10,
                                        bottom: 24,
                                      ),
                                      // Your updated Column widget
                                      child: Column(
                                        children: [
                                          _simpleTile(
                                            title: 'Privacy Policy',
                                            subtitle: 'Read our privacy policy',
                                            icon: Icons.privacy_tip_rounded,
                                            onTap: () {
                                              // Opens the Privacy Policy inside the app
                                              _launchInApp(
                                                context,
                                                'http://edunest.me/EduNest-Privacy-Policy/',
                                              );
                                            },
                                          ),
                                          _divider(),
                                          _simpleTile(
                                            title: 'Terms of Service',
                                            subtitle:
                                            'Read our terms of service',
                                            icon: Icons.description_rounded,
                                            onTap: () {
                                              // Opens the Terms of Service inside the app
                                              _launchInApp(
                                                context,
                                                'http://edunest.me/EduNest-Terms-Condition/',
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Support
                                    _sectionHeader('Support'),
                                    Card(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: BorderSide(
                                          color: AppTheme.primaryBlue
                                              .withValues(alpha: 0.18),
                                          width: 1.5,
                                        ),
                                      ),
                                      elevation: 4,
                                      margin: const EdgeInsets.only(
                                        top: 10,
                                        bottom: 24,
                                      ),
                                      child: Column(
                                        children: [
                                          _simpleTile(
                                            title: 'Help & Support',
                                            subtitle:
                                                'Get help and contact support',
                                            icon: Icons.help_outline_rounded,
                                            onTap: () {
                                              Navigator.pushNamed(
                                                context,
                                                '/help-support',
                                              );
                                            },
                                          ),
                                          _divider(),
                                          _simpleTile(
                                            title: 'About EduNest',
                                            subtitle:
                                                'Learn more about the app',
                                            icon: Icons.info_rounded,
                                            onTap: () {
                                              Navigator.pushNamed(
                                                context,
                                                '/about',
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Account Management
                                    _sectionHeader('Account Management'),
                                    Card(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: BorderSide(
                                          color: AppTheme.primaryBlue
                                              .withValues(alpha: 0.18),
                                          width: 1.5,
                                        ),
                                      ),
                                      elevation: 4,
                                      margin: const EdgeInsets.only(
                                        top: 10,
                                        bottom: 40,
                                      ),
                                      child: Column(
                                        children: [
                                          _simpleTile(
                                            title: 'Export Data',
                                            subtitle:
                                                'Download your account data',
                                            icon: Icons.download_rounded,
                                            onTap: () {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Data export feature coming soon!',
                                                  ),
                                                  backgroundColor:
                                                      Colors.orange,
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
              : Align(
                alignment: Alignment.topCenter,
                child: Container(
                  constraints:
                      isDesktop
                          ? BoxConstraints(maxWidth: maxContentWidth)
                          : null,
                  margin:
                      isDesktop
                          ? const EdgeInsets.symmetric(vertical: 24)
                          : null,
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      SliverAppBar(
                        expandedHeight: 120,
                        floating: false,
                        pinned: true,
                        backgroundColor: _getCollapsedAppBarColor(isCollapsed),
                        forceElevated: true,
                        elevation: 0,
                        title:
                            isCollapsed
                                ? AppText(
                                  'Settings',
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                )
                                : null,
                        leading: _buildAppBarLeading(isCollapsed),
                        flexibleSpace: FlexibleSpaceBar(
                          background: Stack(
                            fit: StackFit.expand,
                            children: [
                              Container(
                                decoration: _getAppBarDecoration(isCollapsed),
                              ),
                              Positioned(
                                top: -30,
                                right: -30,
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(height: 35),
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.3,
                                          ),
                                          width: 2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.1,
                                            ),
                                            blurRadius: 20,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.settings_rounded,
                                        size: 22,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    AppText(
                                      'Settings',
                                      style: GoogleFonts.poppins(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    AppText(
                                      'Customize your experience',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding:
                              isDesktop
                                  ? const EdgeInsets.symmetric(horizontal: 32)
                                  : const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Account Settings
                              _sectionHeader('Account Settings'),
                              Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: AppTheme.primaryBlue.withValues(
                                      alpha: 0.18,
                                    ),
                                    width: 1.5,
                                  ),
                                ),
                                elevation: 4,
                                margin: const EdgeInsets.only(
                                  top: 10,
                                  bottom: 24,
                                ),
                                child: Column(
                                  children: [
                                    _simpleTile(
                                      title: 'Edit Profile',
                                      subtitle:
                                          'Update your personal information and preferences',
                                      icon: Icons.edit_rounded,
                                      onTap: () {
                                        Navigator.pushNamed(
                                          context,
                                          '/profile',
                                        );
                                      },
                                    ),
                                    _divider(),
                                    _simpleTile(
                                      title: 'Security Settings',
                                      subtitle:
                                          'Manage authentication, privacy, and account protection',
                                      icon: Icons.security_rounded,
                                      iconColor: Colors.red,
                                      onTap: () {
                                        Navigator.pushNamed(
                                          context,
                                          '/security',
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),

                              // App Preferences
                              _sectionHeader('App Preferences'),
                              Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: AppTheme.primaryBlue.withValues(
                                      alpha: 0.18,
                                    ),
                                    width: 1.5,
                                  ),
                                ),
                                elevation: 4,
                                margin: const EdgeInsets.only(
                                  top: 10,
                                  bottom: 24,
                                ),
                                child: Column(
                                  children: [
                                    _dropdownTile(
                                      title: 'Language',
                                      subtitle:
                                          'Choose your preferred language',
                                      icon: Icons.language_rounded,
                                      value: _selectedLanguage,
                                      options: _languages,
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedLanguage = value;
                                        });
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Language support coming soon!',
                                            ),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                      },
                                    ),
                                    _divider(),
                                    _switchTile(
                                      title: 'Dark Mode',
                                      subtitle: 'Enable dark theme',
                                      icon: Icons.dark_mode_rounded,
                                      value: _darkModeEnabled,
                                      onChanged: (value) {
                                        setState(() {
                                          _darkModeEnabled = value;
                                        });
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Coming soon!'),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),

                              // Notifications
                              _sectionHeader('Notifications'),
                              Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: AppTheme.primaryBlue.withValues(
                                      alpha: 0.18,
                                    ),
                                    width: 1.5,
                                  ),
                                ),
                                elevation: 4,
                                margin: const EdgeInsets.only(
                                  top: 10,
                                  bottom: 24,
                                ),
                                child: Column(
                                  children: [
                                    _switchTile(
                                      title: 'Push Notifications',
                                      subtitle: 'Receive app notifications',
                                      icon: Icons.notifications_active_rounded,
                                      value: _notificationsEnabled,
                                      onChanged: (value) {
                                        setState(() {
                                          _notificationsEnabled = value;
                                        });
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              value
                                                  ? 'Push notifications enabled (coming soon!)'
                                                  : 'Push notifications disabled (coming soon!)',
                                            ),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                      },
                                    ),
                                    _divider(),
                                    _simpleTile(
                                      title: 'Notification Preferences',
                                      subtitle:
                                          'Customize notification settings',
                                      icon: Icons.settings_applications_rounded,
                                      onTap: () {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Notification preferences coming soon!',
                                            ),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),

                              // Data & Storage
                              _sectionHeader('Data & Storage'),
                              Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: AppTheme.primaryBlue.withValues(
                                      alpha: 0.18,
                                    ),
                                    width: 1.5,
                                  ),
                                ),
                                elevation: 4,
                                margin: const EdgeInsets.only(
                                  top: 10,
                                  bottom: 24,
                                ),
                                child: Column(
                                  children: [
                                    _switchTile(
                                      title: 'Auto Download',
                                      subtitle:
                                          'Automatically download new resources',
                                      icon: Icons.download_rounded,
                                      value: _autoDownloadEnabled,
                                      onChanged: (value) {
                                        setState(() {
                                          _autoDownloadEnabled = value;
                                        });
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              value
                                                  ? 'Auto download enabled (coming soon!)'
                                                  : 'Auto download disabled (coming soon!)',
                                            ),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                      },
                                    ),
                                    _divider(),
                                    _simpleTile(
                                      title: 'Clear Cache',
                                      subtitle: 'Free up storage space',
                                      icon: Icons.cleaning_services_rounded,
                                      onTap: () {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Cache clearing feature coming soon!',
                                            ),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),

                              // Privacy & Legal
                              _sectionHeader('Privacy & Legal'),
                              Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: AppTheme.primaryBlue.withValues(
                                      alpha: 0.18,
                                    ),
                                    width: 1.5,
                                  ),
                                ),
                                elevation: 4,
                                margin: const EdgeInsets.only(
                                  top: 10,
                                  bottom: 24,
                                ),
                                // Your updated Column widget
                                child: Column(
                                  children: [
                                    _simpleTile(
                                      title: 'Privacy Policy',
                                      subtitle: 'Read our privacy policy',
                                      icon: Icons.privacy_tip_rounded,
                                      onTap: () {
                                        // Opens the Privacy Policy inside the app
                                        _launchInApp(
                                          context,
                                          'http://edunest.me/EduNest-Privacy-Policy/',
                                        );
                                      },
                                    ),
                                    _divider(),
                                    _simpleTile(
                                      title: 'Terms of Service',
                                      subtitle:
                                      'Read our terms of service',
                                      icon: Icons.description_rounded,
                                      onTap: () {
                                        // Opens the Terms of Service inside the app
                                        _launchInApp(
                                          context,
                                          'http://edunest.me/EduNest-Terms-Condition/',
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),

                              // Support
                              _sectionHeader('Support'),
                              Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: AppTheme.primaryBlue.withValues(
                                      alpha: 0.18,
                                    ),
                                    width: 1.5,
                                  ),
                                ),
                                elevation: 4,
                                margin: const EdgeInsets.only(
                                  top: 10,
                                  bottom: 24,
                                ),
                                child: Column(
                                  children: [
                                    _simpleTile(
                                      title: 'Help & Support',
                                      subtitle: 'Get help and contact support',
                                      icon: Icons.help_outline_rounded,
                                      onTap: () {
                                        Navigator.pushNamed(
                                          context,
                                          '/help-support',
                                        );
                                      },
                                    ),
                                    _divider(),
                                    _simpleTile(
                                      title: 'About EduNest',
                                      subtitle: 'Learn more about the app',
                                      icon: Icons.info_rounded,
                                      onTap: () {
                                        Navigator.pushNamed(context, '/about');
                                      },
                                    ),
                                  ],
                                ),
                              ),

                              // Account Management
                              _sectionHeader('Account Management'),
                              Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: AppTheme.primaryBlue.withValues(
                                      alpha: 0.18,
                                    ),
                                    width: 1.5,
                                  ),
                                ),
                                elevation: 4,
                                margin: const EdgeInsets.only(
                                  top: 10,
                                  bottom: 40,
                                ),
                                child: Column(
                                  children: [
                                    _simpleTile(
                                      title: 'Export Data',
                                      subtitle: 'Download your account data',
                                      icon: Icons.download_rounded,
                                      onTap: () {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Data export feature coming soon!',
                                            ),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: AppText(
        title,
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryBlue,
        ),
      ),
    );
  }

  Widget _divider() =>
      Divider(height: 1, thickness: 1, color: Colors.grey.shade200);

  Widget _switchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryBlue),
      title: AppText(
        title,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: AppText(
        subtitle,
        style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
      ),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.primaryBlue,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _dropdownTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryBlue),
      title: AppText(
        title,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: AppText(
        subtitle,
        style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
      ),
      trailing: DropdownButton<String>(
        value: value,
        onChanged: (newValue) {
          if (newValue != null) onChanged(newValue);
        },
        underline: Container(),
        icon: Icon(Icons.arrow_drop_down_rounded, color: AppTheme.primaryBlue),
        items:
            options.map((String option) {
              return DropdownMenuItem<String>(
                value: option,
                child: AppText(
                  option,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
              );
            }).toList(),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _simpleTile({
    required String title,
    required String subtitle,
    required IconData icon,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? AppTheme.primaryBlue),
      title: AppText(
        title,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: AppText(
        subtitle,
        style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 18,
        color: Colors.grey.shade400,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
