import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../../widgets/app_text.dart';
import '../auth/change_password_screen.dart';
import '../../services/session_tracking_service.dart';
import '../../services/error_message_service.dart';
import '../../widgets/desktop_sidebar.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  bool _biometricEnabled = false;
  bool _twoFactorEnabled = false;
  bool _loginNotifications = true;
  bool _deviceLock = true;
  bool _autoLock = true;
  bool _locationSharing = false;
  bool _dataAnalytics = true;
  String _autoLockTime = '5 minutes';
  String _sessionTimeout = '30 minutes';

  List<SessionInfo> _activeSessions = [];
  List<LoginHistoryEntry> _loginHistory = [];
  bool _isLoadingSessions = false;
  bool _isLoadingHistory = false;

  final List<String> _autoLockTimes = [
    'Immediately',
    '1 minute',
    '5 minutes',
    '15 minutes',
    '30 minutes',
  ];
  final List<String> _sessionTimeouts = [
    '15 minutes',
    '30 minutes',
    '1 hour',
    '4 hours',
    'Never',
  ];

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

    // Load session data
    _loadSessionData();
  }

  Future<void> _loadSessionData() async {
    setState(() {
      _isLoadingSessions = true;
      _isLoadingHistory = true;
    });

    try {
      final sessions = await SessionTrackingService.getActiveSessions();
      final history = await SessionTrackingService.getLoginHistory();

      setState(() {
        _activeSessions = sessions;
        _loginHistory = history;
        _isLoadingSessions = false;
        _isLoadingHistory = false;
      });
    } catch (e) {
      final message = ErrorMessageService.getFriendlyMessage(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Color _getAppBarColor() {
    // Interpolate between red and orange as the app bar collapses
    // expandedHeight = 120, toolbarHeight = 56
    const double expanded = 120.0;
    const double collapsed = 56.0;
    double t = (_scrollOffset / (expanded - collapsed)).clamp(0, 1);
    return Color.lerp(Colors.red.shade600, Colors.orange.shade400, t) ??
        Colors.red.shade600;
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

  Widget _buildSecurityCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color gradientStart,
    required Color gradientEnd,
    Widget? trailing,
    VoidCallback? onTap,
    bool isDanger = false,
    bool isPremium = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors:
              isDanger
                  ? [Colors.red.shade50, Colors.red.shade100]
                  : [Colors.white, Colors.grey.shade50],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              isDanger
                  ? Colors.red.shade200
                  : isPremium
                  ? Colors.amber.shade300
                  : Colors.grey.shade200,
          width: isDanger || isPremium ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [gradientStart, gradientEnd],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: gradientStart.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: AppText(
                              title,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color:
                                    isDanger
                                        ? Colors.red.shade700
                                        : Colors.black87,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          if (isPremium)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.amber.shade400,
                                    Colors.amber.shade600,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: AppText(
                                'PRO',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      AppText(
                        subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color:
                              isDanger
                                  ? Colors.red.shade600
                                  : Colors.grey.shade600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing,
                if (onTap != null && trailing == null)
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.grey.shade400,
                    size: 16,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchSetting({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color gradientStart,
    required Color gradientEnd,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return _buildSecurityCard(
      title: title,
      subtitle: subtitle,
      icon: icon,
      color: color,
      gradientStart: gradientStart,
      gradientEnd: gradientEnd,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: color,
        activeTrackColor: color.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildDropdownSetting({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color gradientStart,
    required Color gradientEnd,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    return _buildSecurityCard(
      title: title,
      subtitle: subtitle,
      icon: icon,
      color: color,
      gradientStart: gradientStart,
      gradientEnd: gradientEnd,
      trailing: DropdownButton<String>(
        value: value,
        onChanged: (newValue) {
          if (newValue != null) onChanged(newValue);
        },
        underline: Container(),
        icon: Icon(Icons.arrow_drop_down_rounded, color: color),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine if app bar is collapsed
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
                    selected: 'security',
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
                          backgroundColor: _getAppBarColor(),
                          elevation: 0,
                          title:
                              isCollapsed
                                  ? AppText(
                                    'Security',
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
                            background: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.red.shade600,
                                    Colors.red.shade500,
                                    Colors.orange.shade600,
                                  ],
                                ),
                              ),
                              child: Stack(
                                children: [
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(height: 16),
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
                                            Icons.security_rounded,
                                            size: 22,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        AppText(
                                          'Security',
                                          style: GoogleFonts.poppins(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        AppText(
                                          'Protect your account',
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
                                    // Section: Authentication
                                    _sectionHeader('Authentication'),
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
                                            title: 'Biometric Login',
                                            subtitle:
                                                'Use fingerprint or face ID',
                                            icon: Icons.fingerprint_rounded,
                                            value: _biometricEnabled,
                                            onChanged: (value) {
                                              setState(
                                                () => _biometricEnabled = value,
                                              );
                                              if (value) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Biometric authentication enabled',
                                                    ),
                                                    backgroundColor:
                                                        Colors.green,
                                                  ),
                                                );
                                              }
                                            },
                                          ),
                                          _divider(),
                                          _switchTile(
                                            title: 'Two-Factor Authentication',
                                            subtitle:
                                                'Add an extra layer of security with TOTP',
                                            icon: Icons.verified_user_rounded,
                                            value: _twoFactorEnabled,
                                            onChanged: (value) {
                                              setState(
                                                () => _twoFactorEnabled = value,
                                              );
                                              if (value)
                                                _showTwoFactorSetupDialog();
                                            },
                                          ),
                                          _divider(),
                                          _simpleTile(
                                            title: 'Change Password',
                                            subtitle:
                                                'Update your account password',
                                            icon: Icons.lock_rounded,
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder:
                                                      (context) =>
                                                          const ChangePasswordScreen(),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Section: Login Security
                                    _sectionHeader('Login Security'),
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
                                            title: 'Login Notifications',
                                            subtitle:
                                                'Get notified of new logins',
                                            icon:
                                                Icons
                                                    .notifications_active_rounded,
                                            value: _loginNotifications,
                                            onChanged:
                                                (value) => setState(
                                                  () =>
                                                      _loginNotifications =
                                                          value,
                                                ),
                                          ),
                                          _divider(),
                                          _dropdownTile(
                                            title: 'Session Timeout',
                                            subtitle:
                                                'Auto-logout after inactivity',
                                            icon: Icons.timer_rounded,
                                            value: _sessionTimeout,
                                            options: _sessionTimeouts,
                                            onChanged:
                                                (value) => setState(
                                                  () => _sessionTimeout = value,
                                                ),
                                          ),
                                          _divider(),
                                          _simpleTile(
                                            title: 'Active Sessions',
                                            subtitle:
                                                '${_activeSessions.length} active sessions',
                                            icon: Icons.devices_rounded,
                                            onTap: _showActiveSessionsDialog,
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Section: Device Security
                                    _sectionHeader('Device Security'),
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
                                            title: 'Device Lock',
                                            subtitle: 'Require device unlock',
                                            icon:
                                                Icons
                                                    .screen_lock_portrait_rounded,
                                            value: _deviceLock,
                                            onChanged:
                                                (value) => setState(
                                                  () => _deviceLock = value,
                                                ),
                                          ),
                                          _divider(),
                                          _switchTile(
                                            title: 'Auto Lock',
                                            subtitle: 'Lock app when inactive',
                                            icon: Icons.lock_clock_rounded,
                                            value: _autoLock,
                                            onChanged:
                                                (value) => setState(
                                                  () => _autoLock = value,
                                                ),
                                          ),
                                          _divider(),
                                          _dropdownTile(
                                            title: 'Auto Lock Time',
                                            subtitle: 'Time before app locks',
                                            icon: Icons.access_time_rounded,
                                            value: _autoLockTime,
                                            options: _autoLockTimes,
                                            onChanged:
                                                (value) => setState(
                                                  () => _autoLockTime = value,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Section: Privacy Controls
                                    _sectionHeader('Privacy Controls'),
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
                                            title: 'Location Sharing',
                                            subtitle: 'Share location with app',
                                            icon: Icons.location_on_rounded,
                                            value: _locationSharing,
                                            onChanged:
                                                (value) => setState(
                                                  () =>
                                                      _locationSharing = value,
                                                ),
                                          ),
                                          _divider(),
                                          _switchTile(
                                            title: 'Data Analytics',
                                            subtitle: 'Help improve the app',
                                            icon: Icons.analytics_rounded,
                                            value: _dataAnalytics,
                                            onChanged:
                                                (value) => setState(
                                                  () => _dataAnalytics = value,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Section: Security Logs
                                    _sectionHeader('Security Logs'),
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
                                            title: 'Login History',
                                            subtitle:
                                                '${_loginHistory.length} recent attempts',
                                            icon: Icons.history_rounded,
                                            onTap: _showLoginHistoryDialog,
                                          ),
                                          _divider(),
                                          _simpleTile(
                                            title: 'Security Events',
                                            subtitle:
                                                'Monitor security activities',
                                            icon: Icons.security_rounded,
                                            onTap: _showSecurityEventsDialog,
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Section: Danger Zone
                                    _sectionHeader('Danger Zone'),
                                    Card(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: BorderSide(
                                          color: Colors.red,
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
                                            title: 'Delete Account',
                                            subtitle:
                                                'Permanently delete your account',
                                            icon: Icons.delete_forever_rounded,
                                            iconColor: Colors.red,
                                            onTap: _showDeleteAccountDialog,
                                            isDanger: true,
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
                        backgroundColor: _getAppBarColor(),
                        elevation: 0,
                        title:
                            isCollapsed
                                ? AppText(
                                  'Security',
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
                          background: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.red.shade600,
                                  Colors.red.shade500,
                                  Colors.orange.shade600,
                                ],
                              ),
                            ),
                            child: Stack(
                              children: [
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
                                      SizedBox(height: 35),
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
                                          Icons.security_rounded,
                                          size: 22,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      AppText(
                                        'Security',
                                        style: GoogleFonts.poppins(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      AppText(
                                        'Protect your account',
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
                              // Section: Authentication
                              _sectionHeader('Authentication'),
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
                                      title: 'Biometric Login',
                                      subtitle: 'Use fingerprint or face ID',
                                      icon: Icons.fingerprint_rounded,
                                      value: _biometricEnabled,
                                      onChanged: (value) {
                                        setState(
                                          () => _biometricEnabled = value,
                                        );
                                        if (value) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Biometric authentication enabled',
                                              ),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                    _divider(),
                                    _switchTile(
                                      title: 'Two-Factor Authentication',
                                      subtitle:
                                          'Add an extra layer of security with TOTP',
                                      icon: Icons.verified_user_rounded,
                                      value: _twoFactorEnabled,
                                      onChanged: (value) {
                                        setState(
                                          () => _twoFactorEnabled = value,
                                        );
                                        if (value) _showTwoFactorSetupDialog();
                                      },
                                    ),
                                    _divider(),
                                    _simpleTile(
                                      title: 'Change Password',
                                      subtitle: 'Update your account password',
                                      icon: Icons.lock_rounded,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) =>
                                                    const ChangePasswordScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),

                              // Section: Login Security
                              _sectionHeader('Login Security'),
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
                                      title: 'Login Notifications',
                                      subtitle: 'Get notified of new logins',
                                      icon: Icons.notifications_active_rounded,
                                      value: _loginNotifications,
                                      onChanged:
                                          (value) => setState(
                                            () => _loginNotifications = value,
                                          ),
                                    ),
                                    _divider(),
                                    _dropdownTile(
                                      title: 'Session Timeout',
                                      subtitle: 'Auto-logout after inactivity',
                                      icon: Icons.timer_rounded,
                                      value: _sessionTimeout,
                                      options: _sessionTimeouts,
                                      onChanged:
                                          (value) => setState(
                                            () => _sessionTimeout = value,
                                          ),
                                    ),
                                    _divider(),
                                    _simpleTile(
                                      title: 'Active Sessions',
                                      subtitle:
                                          '${_activeSessions.length} active sessions',
                                      icon: Icons.devices_rounded,
                                      onTap: _showActiveSessionsDialog,
                                    ),
                                  ],
                                ),
                              ),

                              // Section: Device Security
                              _sectionHeader('Device Security'),
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
                                      title: 'Device Lock',
                                      subtitle: 'Require device unlock',
                                      icon: Icons.screen_lock_portrait_rounded,
                                      value: _deviceLock,
                                      onChanged:
                                          (value) => setState(
                                            () => _deviceLock = value,
                                          ),
                                    ),
                                    _divider(),
                                    _switchTile(
                                      title: 'Auto Lock',
                                      subtitle: 'Lock app when inactive',
                                      icon: Icons.lock_clock_rounded,
                                      value: _autoLock,
                                      onChanged:
                                          (value) =>
                                              setState(() => _autoLock = value),
                                    ),
                                    _divider(),
                                    _dropdownTile(
                                      title: 'Auto Lock Time',
                                      subtitle: 'Time before app locks',
                                      icon: Icons.access_time_rounded,
                                      value: _autoLockTime,
                                      options: _autoLockTimes,
                                      onChanged:
                                          (value) => setState(
                                            () => _autoLockTime = value,
                                          ),
                                    ),
                                  ],
                                ),
                              ),

                              // Section: Privacy Controls
                              _sectionHeader('Privacy Controls'),
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
                                      title: 'Location Sharing',
                                      subtitle: 'Share location with app',
                                      icon: Icons.location_on_rounded,
                                      value: _locationSharing,
                                      onChanged:
                                          (value) => setState(
                                            () => _locationSharing = value,
                                          ),
                                    ),
                                    _divider(),
                                    _switchTile(
                                      title: 'Data Analytics',
                                      subtitle: 'Help improve the app',
                                      icon: Icons.analytics_rounded,
                                      value: _dataAnalytics,
                                      onChanged:
                                          (value) => setState(
                                            () => _dataAnalytics = value,
                                          ),
                                    ),
                                  ],
                                ),
                              ),

                              // Section: Security Logs
                              _sectionHeader('Security Logs'),
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
                                      title: 'Login History',
                                      subtitle:
                                          '${_loginHistory.length} recent attempts',
                                      icon: Icons.history_rounded,
                                      onTap: _showLoginHistoryDialog,
                                    ),
                                    _divider(),
                                    _simpleTile(
                                      title: 'Security Events',
                                      subtitle: 'Monitor security activities',
                                      icon: Icons.security_rounded,
                                      onTap: _showSecurityEventsDialog,
                                    ),
                                  ],
                                ),
                              ),

                              // Section: Danger Zone
                              _sectionHeader('Danger Zone'),
                              Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: Colors.red,
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
                                      title: 'Delete Account',
                                      subtitle:
                                          'Permanently delete your account',
                                      icon: Icons.delete_forever_rounded,
                                      iconColor: Colors.red,
                                      onTap: _showDeleteAccountDialog,
                                      isDanger: true,
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
    bool isDanger = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: iconColor ?? (isDanger ? Colors.red : AppTheme.primaryBlue),
      ),
      title: AppText(
        title,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: isDanger ? Colors.red : null,
        ),
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

  void _showTwoFactorSetupDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.verified_user_rounded, color: Colors.blue, size: 24),
              const SizedBox(width: 8),
              AppText(
                'Two-Factor Setup',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                'Set up two-factor authentication for enhanced security:',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              const SizedBox(height: 16),
              _buildSetupStep(
                '1',
                'Download an authenticator app (Google Authenticator, Authy)',
              ),
              _buildSetupStep('2', 'Scan the QR code or enter the setup key'),
              _buildSetupStep('3', 'Enter the 6-digit code to verify'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: AppText(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Two-factor authentication setup initiated'),
                    backgroundColor: Colors.blue,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: AppText(
                'Setup',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSetupStep(String number, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: AppText(
                number,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AppText(
              description,
              style: GoogleFonts.poppins(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _showActiveSessionsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.devices_rounded, color: Colors.indigo, size: 24),
              const SizedBox(width: 8),
              AppText(
                'Active Sessions',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content:
              _isLoadingSessions
                  ? const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator()),
                  )
                  : _activeSessions.isEmpty
                  ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.devices_other_rounded,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      AppText(
                        'No active sessions found',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      AppText(
                        'You are currently logged in on this device only',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                  : Column(
                    mainAxisSize: MainAxisSize.min,
                    children:
                        _activeSessions.map((session) {
                          return _buildSessionItem(
                            session.deviceName,
                            '${session.deviceType} • ${session.browser}',
                            _formatTimeAgo(session.loginTime),
                            session.isCurrent,
                            session: session,
                          );
                        }).toList(),
                  ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: AppText(
                'Close',
                style: GoogleFonts.poppins(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Other sessions logged out'),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: AppText(
                'Logout Others',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildSessionItem(
    String device,
    String type,
    String time,
    bool isCurrent, {
    SessionInfo? session,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrent ? Colors.blue.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrent ? Colors.blue.shade200 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isCurrent ? Icons.phone_android_rounded : Icons.computer_rounded,
            color: isCurrent ? Colors.blue : Colors.grey.shade600,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  device,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: isCurrent ? Colors.blue.shade700 : Colors.black87,
                  ),
                ),
                AppText(
                  '$type • $time',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          if (isCurrent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: AppText(
                'Current',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else if (session != null)
            IconButton(
              onPressed: () => _terminateSession(session.sessionId),
              icon: Icon(
                Icons.close_rounded,
                color: Colors.red.shade400,
                size: 18,
              ),
              tooltip: 'Terminate session',
            ),
        ],
      ),
    );
  }

  void _showLoginHistoryDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.history_rounded,
                color: Colors.grey.shade700,
                size: 24,
              ),
              const SizedBox(width: 8),
              AppText(
                'Login History',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content:
              _isLoadingHistory
                  ? const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator()),
                  )
                  : _loginHistory.isEmpty
                  ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      AppText(
                        'No login history found',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      AppText(
                        'Your login attempts will appear here',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                  : Column(
                    mainAxisSize: MainAxisSize.min,
                    children:
                        _loginHistory.take(10).map((entry) {
                          return _buildHistoryItem(
                            entry.isSuccess
                                ? 'Successful Login'
                                : 'Failed Login',
                            entry.deviceName,
                            _formatTimeAgo(entry.timestamp),
                            entry.isSuccess,
                            failureReason: entry.failureReason,
                          );
                        }).toList(),
                  ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: AppText(
                'Close',
                style: GoogleFonts.poppins(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHistoryItem(
    String action,
    String device,
    String time,
    bool isSuccess, {
    String? failureReason,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
            color: isSuccess ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  action,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                AppText(
                  '$device • $time',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (failureReason != null && !isSuccess)
                  AppText(
                    'Reason: $failureReason',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.red.shade600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _terminateSession(String sessionId) async {
    final success = await SessionTrackingService.terminateSession(sessionId);
    if (success) {
      // Reload session data
      await _loadSessionData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session terminated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(); // Close dialog
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to terminate session'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSecurityEventsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.security_rounded,
                color: Colors.red.shade600,
                size: 24,
              ),
              const SizedBox(width: 8),
              AppText(
                'Security Events',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: AppText(
            'No security events detected. Your account is secure.',
            style: GoogleFonts.poppins(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: AppText(
                'Close',
                style: GoogleFonts.poppins(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_rounded, color: Colors.red, size: 24),
              const SizedBox(width: 8),
              AppText(
                'Delete Account',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: AppText(
            'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently lost.',
            style: GoogleFonts.poppins(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: AppText(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Account deletion requested'),
                    backgroundColor: Colors.red,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: AppText(
                'Delete',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
