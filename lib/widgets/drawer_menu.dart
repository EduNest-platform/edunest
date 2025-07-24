import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/supabase_auth_service.dart'; // For SupabaseAuthService
import '../services/user_profile_service.dart';
import '../models/user_profile.dart';
import '../../main.dart';

class DrawerMenu extends StatefulWidget {
  const DrawerMenu({super.key});

  @override
  State<DrawerMenu> createState() => _DrawerMenuState();
}

class _DrawerMenuState extends State<DrawerMenu> {
  UserProfile? _userProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await UserProfileService.getCurrentUserProfile();
      setState(() {
        _userProfile = profile;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    bool isLoggingOut = false;
    String? error;
    await showDialog(
      context: context,
      barrierDismissible: !isLoggingOut,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              title: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: const Icon(
                      Icons.logout_rounded,
                      color: Colors.red,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Logout',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ],
              ),
              backgroundColor: Colors.white,
              elevation: 8,
              shadowColor: Colors.black.withValues(alpha: 0.08),
              content:
                  isLoggingOut
                      ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          SizedBox(height: 8),
                          CircularProgressIndicator(),
                          SizedBox(height: 24),
                          Text('Logging out...'),
                        ],
                      )
                      : error != null
                      ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error, color: Colors.red, size: 40),
                          const SizedBox(height: 12),
                          Text(
                            error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                      )
                      : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          const Text(
                            'Are you sure you want to logout?',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                              letterSpacing: 0.1,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            decoration: BoxDecoration(
                              color: Color(0xFFE3F6FF),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 6,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: Color(0xFF2196F3),
                                  size: 15,
                                ),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Tip: You can change your academic path from your profile.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF222B45),
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
              actions:
                  isLoggingOut
                      ? []
                      : error != null
                      ? [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () async {
                            setState(() {
                              isLoggingOut = true;
                              error = null;
                            });
                            try {
                              await SupabaseAuthService.signOut().timeout(
                                const Duration(seconds: 10),
                                onTimeout:
                                    () => throw Exception('Logout timed out'),
                              );
                              Navigator.of(
                                dialogContext,
                                rootNavigator: true,
                              ).pop();
                              Future.delayed(
                                const Duration(milliseconds: 100),
                                () {
                                  navigatorKey.currentState
                                      ?.pushNamedAndRemoveUntil(
                                        '/login',
                                        (route) => false,
                                      );
                                },
                              );
                            } catch (e) {
                              setState(() {
                                error = 'Logout failed: $e';
                                isLoggingOut = false;
                              });
                            }
                          },
                          child: const Text('Retry'),
                        ),
                      ]
                      : [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () async {
                            setState(() {
                              isLoggingOut = true;
                              error = null;
                            });
                            try {
                              await SupabaseAuthService.signOut().timeout(
                                const Duration(seconds: 10),
                                onTimeout:
                                    () => throw Exception('Logout timed out'),
                              );
                              Navigator.of(
                                dialogContext,
                                rootNavigator: true,
                              ).pop();
                              Future.delayed(
                                const Duration(milliseconds: 100),
                                () {
                                  navigatorKey.currentState
                                      ?.pushNamedAndRemoveUntil(
                                        '/login',
                                        (route) => false,
                                      );
                                },
                              );
                            } catch (e) {
                              setState(() {
                                error = 'Logout failed: $e';
                                isLoggingOut = false;
                              });
                            }
                          },
                          child: const Text('Logout'),
                        ),
                      ],
            );
          },
        );
      },
    );
  }

  Widget _buildUserHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryBlue, AppTheme.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          // User Avatar
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child:
                  _userProfile?.profileImageUrl != null &&
                          _userProfile!.profileImageUrl!.isNotEmpty
                      ? Image.network(
                        _userProfile!.profileImageUrl!,
                        fit: BoxFit.cover,
                        width: 60,
                        height: 60,
                        errorBuilder:
                            (context, error, stackTrace) => const Icon(
                              Icons.person_rounded,
                              size: 30,
                              color: Colors.white,
                            ),
                      )
                      : const Icon(
                        Icons.person_rounded,
                        size: 30,
                        color: Colors.white,
                      ),
            ),
          ),
          const SizedBox(height: 16),
          // User Name
          Text(
            _userProfile?.fullName ?? 'Student',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          // User Email
          Text(
            AuthService.currentUser?.email ?? 'No email',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 12),
          // Academic Path Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.school_rounded, color: Colors.white, size: 14),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '${_userProfile?.college ?? 'College'} • ${_userProfile?.branch ?? 'Branch'}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (iconColor ?? AppTheme.primaryBlue).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor ?? AppTheme.primaryBlue, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDestructive ? Colors.red : Colors.black87,
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios_rounded,
        color: AppTheme.textSecondary,
        size: 16,
      ),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          _buildUserHeader(),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Main Navigation
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'MAIN',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                _buildMenuItem(
                  icon: Icons.home_rounded,
                  title: 'Home',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, '/home');
                  },
                ),
                _buildMenuItem(
                  icon: Icons.calendar_today_rounded,
                  title: 'Attendance',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/attendance');
                  },
                ),
                _buildMenuItem(
                  icon: Icons.quiz_rounded,
                  title: 'Practice Tests',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/practice-tests');
                  },
                ),
                _buildMenuItem(
                  icon: Icons.analytics_rounded,
                  title: 'Test Results',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/test-results');
                  },
                ),
                _buildMenuItem(
                  icon: Icons.book_rounded,
                  title: 'Browse Subjects',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/subjects');
                  },
                ),

                // Account Section
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'ACCOUNT',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                _buildMenuItem(
                  icon: Icons.person_rounded,
                  title: 'My Profile',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/profile');
                  },
                ),
                _buildMenuItem(
                  icon: Icons.settings_rounded,
                  title: 'Settings',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/settings');
                  },
                ),
                _buildMenuItem(
                  icon: Icons.security_rounded,
                  title: 'Security',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/security');
                  },
                ),
                _buildMenuItem(
                  icon: Icons.notifications_rounded,
                  title: 'Notifications',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/notifications');
                  },
                ),

                // Support Section
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'SUPPORT',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                _buildMenuItem(
                  icon: Icons.help_rounded,
                  title: 'Help & Support',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/help-support');
                  },
                ),

                _buildMenuItem(
                  icon: Icons.info_rounded,
                  title: 'About EduNest',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/about');
                  },
                ),

                const SizedBox(height: 20),

                // Logout Section
                _buildMenuItem(
                  icon: Icons.logout_rounded,
                  title: 'Logout',
                  iconColor: Colors.red,
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(context);
                    _showLogoutDialog(context);
                  },
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
