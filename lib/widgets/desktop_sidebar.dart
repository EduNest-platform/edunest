import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class DesktopSidebar extends StatelessWidget {
  final String selected;
  final void Function(String route) onNavigate;
  final VoidCallback? onLogout;
  const DesktopSidebar({
    Key? key,
    required this.selected,
    required this.onNavigate,
    this.onLogout,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: AppTheme.primaryBlue,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.school, color: Colors.white, size: 32),
              const SizedBox(width: 10),
              Text(
                'EduNest',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _SidebarSectionLabel('MAIN'),
          _SidebarButton(
            icon: Icons.home_rounded,
            label: 'Home',
            selected: selected == 'home',
            onTap: () => onNavigate('/home'),
          ),
          _SidebarButton(
            icon: Icons.calendar_today_rounded,
            label: 'Attendance',
            selected: selected == 'attendance',
            onTap: () => onNavigate('/attendance'),
          ),
          _SidebarButton(
            icon: Icons.quiz_rounded,
            label: 'Practice Tests',
            selected: selected == 'practice-tests',
            onTap: () => onNavigate('/practice-tests'),
          ),
          _SidebarButton(
            icon: Icons.analytics_rounded,
            label: 'Test Results',
            selected: selected == 'test-results',
            onTap: () => onNavigate('/test-results'),
          ),
          _SidebarButton(
            icon: Icons.book_rounded,
            label: 'Browse Subjects',
            selected: selected == 'subjects',
            onTap: () => onNavigate('/subjects'),
          ),
          _SidebarButton(
            icon: Icons.info_outline_rounded,
            label: 'Academic Info',
            selected: selected == 'academic-info',
            onTap: () => onNavigate('/academic-info'),
          ),
          const SizedBox(height: 16),
          _SidebarSectionLabel('ACCOUNT'),
          _SidebarButton(
            icon: Icons.person_rounded,
            label: 'My Profile',
            selected: selected == 'profile',
            onTap: () => onNavigate('/profile'),
          ),
          _SidebarButton(
            icon: Icons.settings_rounded,
            label: 'Settings',
            selected: selected == 'settings',
            onTap: () => onNavigate('/settings'),
          ),
          _SidebarButton(
            icon: Icons.security_rounded,
            label: 'Security',
            selected: selected == 'security',
            onTap: () => onNavigate('/security'),
          ),
          _SidebarButton(
            icon: Icons.notifications_rounded,
            label: 'Notifications',
            selected: selected == 'notifications',
            onTap: () => onNavigate('/notifications'),
          ),
          const SizedBox(height: 16),
          _SidebarSectionLabel('SUPPORT'),
          _SidebarButton(
            icon: Icons.help_rounded,
            label: 'Help & Support',
            selected: selected == 'help-support',
            onTap: () => onNavigate('/help-support'),
          ),
          _SidebarButton(
            icon: Icons.info_rounded,
            label: 'About EduNest',
            selected: selected == 'about',
            onTap: () => onNavigate('/about'),
          ),
          const SizedBox(height: 24),
          Divider(color: Colors.white.withOpacity(0.2)),
          _SidebarButton(
            icon: Icons.logout_rounded,
            label: 'Logout',
            selected: false,
            onTap: onLogout ?? () {},
            iconColor: Colors.red,
            isDestructive: true,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SidebarSectionLabel extends StatelessWidget {
  final String label;
  const _SidebarSectionLabel(this.label);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 0, 4),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white.withOpacity(0.7),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SidebarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? iconColor;
  final bool isDestructive;
  const _SidebarButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.iconColor,
    this.isDestructive = false,
  });
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: iconColor ?? (selected ? Colors.white : Colors.white70),
      ),
      title: Text(
        label,
        style: GoogleFonts.poppins(
          color:
              isDestructive
                  ? Colors.red
                  : (selected ? Colors.white : Colors.white70),
        ),
      ),
      selected: selected,
      onTap: onTap,
      selectedTileColor: Colors.white.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}
