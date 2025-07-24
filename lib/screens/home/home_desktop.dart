import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/user_profile.dart';
import '../../models/subject.dart';
import '../../services/files_service.dart';
import 'attendance/attendance_tracking_screen.dart';
import 'Subject Screen/subject_view_screen.dart';
import 'resources/notes_screen.dart';
import 'resources/pyq_screen.dart';
import 'resources/assignments_screen.dart';
import 'resources/code_screen.dart';
import 'resources/lab_manuals_screen.dart';
import 'Subject Screen/resources_screen.dart';
import '../practice_tests/chapter_selection_screen.dart';
import '../../../main.dart'; // For navigatorKey
import 'package:flutter/services.dart';
import 'academic_info_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../widgets/whats_new_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeDesktop extends StatefulWidget {
  final UserProfile? userProfile;
  final bool isLoading;
  final List<Subject> currentSubjects;
  final bool subjectsLoading;
  final List<FileResource> recentFiles;
  final bool recentLoading;
  final VoidCallback onLogout;
  final void Function(Subject) onSubjectTap;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final List<Map<String, dynamic>> searchResults;
  final bool searchLoading;
  final void Function(String) onSearchChanged;
  final VoidCallback onSearchUnfocus;
  final void Function(BuildContext, Map<String, dynamic>)?
  onDesktopSearchNavigate;
  const HomeDesktop({
    Key? key,
    required this.userProfile,
    required this.isLoading,
    required this.currentSubjects,
    required this.subjectsLoading,
    required this.recentFiles,
    required this.recentLoading,
    required this.onLogout,
    required this.onSubjectTap,
    required this.searchController,
    required this.searchFocusNode,
    required this.searchResults,
    required this.searchLoading,
    required this.onSearchChanged,
    required this.onSearchUnfocus,
    this.onDesktopSearchNavigate,
  }) : super(key: key);
  @override
  State<HomeDesktop> createState() => _HomeDesktopState();
}

class _HomeDesktopState extends State<HomeDesktop>
    with SingleTickerProviderStateMixin {
  double _opacity = 0.0;
  bool _didCheckUpdate = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 80), () {
      setState(() {
        _opacity = 1.0;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didCheckUpdate &&
        (Theme.of(context).platform == TargetPlatform.windows ||
            Theme.of(context).platform == TargetPlatform.linux ||
            Theme.of(context).platform == TargetPlatform.macOS)) {
      _didCheckUpdate = true;
      _checkForUpdate();
      _showWhatsNewIfNeeded();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomeDesktop oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  static final List<Color> _subjectCardColors = [
    AppTheme.primaryBlue,
    AppTheme.secondaryGreen,
    AppTheme.accentOrange,
    AppTheme.codeIcon,
    AppTheme.labManualsIcon,
    AppTheme.pyqIcon,
    AppTheme.primaryLight,
    AppTheme.secondaryLight,
    AppTheme.accentLight,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Row(
        children: [
          // Sidebar
          Container(
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
                // MAIN Section
                _SidebarSectionLabel('MAIN'),
                _SidebarButton(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  selected: true,
                  onTap: () {
                    Navigator.pushReplacementNamed(context, '/home');
                  },
                ),
                _SidebarButton(
                  icon: Icons.calendar_today_rounded,
                  label: 'Attendance',
                  selected: false,
                  onTap: () {
                    Navigator.pushNamed(context, '/attendance');
                  },
                ),
                _SidebarButton(
                  icon: Icons.quiz_rounded,
                  label: 'Practice Tests',
                  selected: false,
                  onTap: () {
                    Navigator.pushNamed(context, '/practice-tests');
                  },
                ),
                _SidebarButton(
                  icon: Icons.analytics_rounded,
                  label: 'Test Results',
                  selected: false,
                  onTap: () {
                    Navigator.pushNamed(context, '/test-results');
                  },
                ),
                _SidebarButton(
                  icon: Icons.book_rounded,
                  label: 'Browse Subjects',
                  selected: false,
                  onTap: () {
                    Navigator.pushNamed(context, '/subjects');
                  },
                ),
                _SidebarButton(
                  icon: Icons.info_outline_rounded,
                  label: 'Academic Info',
                  selected: false,
                  onTap: () {
                    if (widget.currentSubjects.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No subjects available.')),
                      );
                      return;
                    }
                    final subject = widget.currentSubjects.first;
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                        builder:
                            (context) =>
                                AcademicInfoScreen(subjectId: subject.id),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                // ACCOUNT Section
                _SidebarSectionLabel('ACCOUNT'),
                _SidebarButton(
                  icon: Icons.person_rounded,
                  label: 'My Profile',
                  selected: false,
                  onTap: () {
                    Navigator.pushNamed(context, '/profile');
                  },
                ),
                _SidebarButton(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  selected: false,
                  onTap: () {
                    Navigator.pushNamed(context, '/settings');
                  },
                ),
                _SidebarButton(
                  icon: Icons.security_rounded,
                  label: 'Security',
                  selected: false,
                  onTap: () {
                    Navigator.pushNamed(context, '/security');
                  },
                ),
                _SidebarButton(
                  icon: Icons.notifications_rounded,
                  label: 'Notifications',
                  selected: false,
                  onTap: () {
                    Navigator.pushNamed(context, '/notifications');
                  },
                ),
                const SizedBox(height: 16),
                // SUPPORT Section
                _SidebarSectionLabel('SUPPORT'),
                _SidebarButton(
                  icon: Icons.help_rounded,
                  label: 'Help & Support',
                  selected: false,
                  onTap: () {
                    Navigator.pushNamed(context, '/help-support');
                  },
                ),
                _SidebarButton(
                  icon: Icons.info_rounded,
                  label: 'About EduNest',
                  selected: false,
                  onTap: () {
                    Navigator.pushNamed(context, '/about');
                  },
                ),
                const SizedBox(height: 24),
                Divider(color: Colors.white.withOpacity(0.2)),
                _SidebarButton(
                  icon: Icons.logout_rounded,
                  label: 'Logout',
                  selected: false,
                  onTap: () async {
                    final shouldLogout = await showDialog<bool>(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            title: Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.12),
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
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                              ],
                            ),
                            content: const Text(
                              'Are you sure you want to logout?',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                                letterSpacing: 0.1,
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed:
                                    () => Navigator.of(context).pop(false),
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
                                onPressed:
                                    () => Navigator.of(context).pop(true),
                                child: const Text('Logout'),
                              ),
                            ],
                          ),
                    );
                    if (shouldLogout == true) {
                      widget.onLogout();
                    }
                  },
                  iconColor: Colors.red,
                  isDestructive: true,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          // Main Content with fade-in animation
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
              child: AnimatedOpacity(
                opacity: _opacity,
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOut,
                child:
                    widget.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : SizedBox.expand(
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Main content column
                              SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 1) Place 'Welcome,' and the user's name on the same line in the header
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 28),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 28,
                                        vertical: 22,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: AppTheme.primaryBlue
                                              .withOpacity(0.18),
                                          width: 1.4,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.04,
                                            ),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      'Welcome, ',
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontSize: 28,
                                                            color:
                                                                Colors
                                                                    .grey
                                                                    .shade600,
                                                          ),
                                                    ),
                                                    Text(
                                                      widget
                                                              .userProfile
                                                              ?.fullName ??
                                                          'Student',
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 28,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            AppTheme
                                                                .primaryBlue,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 10),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.school_rounded,
                                                      color:
                                                          AppTheme.primaryBlue,
                                                      size: 18,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      widget
                                                              .userProfile
                                                              ?.college ??
                                                          '-',
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontSize: 15,
                                                            color:
                                                                Colors.black87,
                                                          ),
                                                    ),
                                                    const SizedBox(width: 16),
                                                    Icon(
                                                      Icons
                                                          .account_tree_rounded,
                                                      color:
                                                          AppTheme.primaryLight,
                                                      size: 18,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      widget
                                                              .userProfile
                                                              ?.branch ??
                                                          '-',
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontSize: 15,
                                                            color:
                                                                Colors.black87,
                                                          ),
                                                    ),
                                                    const SizedBox(width: 16),
                                                    Icon(
                                                      Icons
                                                          .calendar_today_rounded,
                                                      color: Colors.orange,
                                                      size: 18,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      widget
                                                              .userProfile
                                                              ?.semester
                                                              ?.toString() ??
                                                          '-',
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontSize: 15,
                                                            color:
                                                                Colors.black87,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Removed profile icon
                                        ],
                                      ),
                                    ),
                                    // Replace 'My Subjects' header with a more prominent, styled header
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryBlue,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'My Subjects',
                                          style: GoogleFonts.poppins(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primaryBlue,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 18),
                                    widget.subjectsLoading
                                        ? const Center(
                                          child: CircularProgressIndicator(),
                                        )
                                        : widget.currentSubjects.isEmpty
                                        ? Text(
                                          'No subjects found.',
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            color: Colors.grey,
                                          ),
                                        )
                                        : Center(
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxWidth: 1200,
                                            ),
                                            child: LayoutBuilder(
                                              builder: (context, constraints) {
                                                int crossAxisCount = 4;
                                                double width =
                                                    constraints.maxWidth;
                                                if (width < 600) {
                                                  crossAxisCount = 1;
                                                } else if (width < 900) {
                                                  crossAxisCount = 2;
                                                } else if (width < 1200) {
                                                  crossAxisCount = 3;
                                                }
                                                return GridView.builder(
                                                  shrinkWrap: true,
                                                  physics:
                                                      const NeverScrollableScrollPhysics(),
                                                  gridDelegate:
                                                      SliverGridDelegateWithFixedCrossAxisCount(
                                                        crossAxisCount:
                                                            crossAxisCount,
                                                        mainAxisSpacing: 12,
                                                        crossAxisSpacing: 12,
                                                        childAspectRatio: 1.165,
                                                      ),
                                                  itemCount:
                                                      widget
                                                          .currentSubjects
                                                          .length,
                                                  itemBuilder: (context, idx) {
                                                    final subject =
                                                        widget
                                                            .currentSubjects[idx];
                                                    final color =
                                                        _subjectCardColors[idx %
                                                            _subjectCardColors
                                                                .length];
                                                    return _SubjectCard(
                                                      subject: subject,
                                                      color: color,
                                                      onAttendanceTap: () {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder:
                                                                (
                                                                  context,
                                                                ) => AttendanceTrackingScreen(
                                                                  subject: {
                                                                    'id':
                                                                        subject
                                                                            .id,
                                                                    'name':
                                                                        subject
                                                                            .name,
                                                                  },
                                                                ),
                                                          ),
                                                        );
                                                      },
                                                    );
                                                  },
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                    const SizedBox(height: 32),
                                    // 2) Redesign Recent Activity header and list
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryBlue,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Recent Activity',
                                          style: GoogleFonts.poppins(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primaryBlue,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 18),
                                    widget.recentLoading
                                        ? const Center(
                                          child: CircularProgressIndicator(),
                                        )
                                        : widget.recentFiles.isEmpty
                                        ? Text(
                                          'No recent activity found.',
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            color: Colors.grey,
                                          ),
                                        )
                                        : ListView.separated(
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          itemCount:
                                              widget.recentFiles.length > 10
                                                  ? 10
                                                  : widget.recentFiles.length,
                                          separatorBuilder:
                                              (_, __) =>
                                                  const SizedBox(height: 12),
                                          itemBuilder: (context, idx) {
                                            final file =
                                                widget.recentFiles[idx];
                                            final accentColors = [
                                              AppTheme.primaryBlue,
                                              AppTheme.secondaryGreen,
                                              AppTheme.accentOrange,
                                              AppTheme.codeIcon,
                                              AppTheme.labManualsIcon,
                                              AppTheme.pyqIcon,
                                              AppTheme.primaryLight,
                                              AppTheme.secondaryLight,
                                              AppTheme.accentLight,
                                            ];
                                            final color =
                                                accentColors[idx %
                                                    accentColors.length];
                                            return GestureDetector(
                                              onTap: () {
                                                final fileType =
                                                    file.fileType
                                                        ?.toLowerCase() ??
                                                    '';
                                                final subject = widget
                                                    .currentSubjects
                                                    .firstWhere(
                                                      (s) =>
                                                          s.id ==
                                                          file.subjectId,
                                                      orElse:
                                                          () =>
                                                              widget
                                                                      .currentSubjects
                                                                      .isNotEmpty
                                                                  ? widget
                                                                      .currentSubjects
                                                                      .first
                                                                  : (throw Exception(
                                                                    'No subjects available',
                                                                  )),
                                                    );
                                                if (subject == null) return;
                                                switch (fileType) {
                                                  case 'notes':
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder:
                                                            (
                                                              context,
                                                            ) => NotesScreen(
                                                              subject: subject,
                                                              showAppBar: true,
                                                            ),
                                                      ),
                                                    );
                                                    break;
                                                  case 'pyq':
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder:
                                                            (
                                                              context,
                                                            ) => PYQScreen(
                                                              subject: subject,
                                                              showAppBar: true,
                                                            ),
                                                      ),
                                                    );
                                                    break;
                                                  case 'assignment':
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder:
                                                            (context) =>
                                                                AssignmentsScreen(
                                                                  subject:
                                                                      subject,
                                                                  showAppBar:
                                                                      true,
                                                                ),
                                                      ),
                                                    );
                                                    break;
                                                  case 'code':
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder:
                                                            (
                                                              context,
                                                            ) => CodeScreen(
                                                              subject: subject,
                                                              showAppBar: true,
                                                            ),
                                                      ),
                                                    );
                                                    break;
                                                  case 'lab_manuals':
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder:
                                                            (context) =>
                                                                LabManualsScreen(
                                                                  subject:
                                                                      subject,
                                                                  showAppBar:
                                                                      true,
                                                                ),
                                                      ),
                                                    );
                                                    break;
                                                  default:
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder:
                                                            (context) =>
                                                                ResourcesScreen(
                                                                  subject:
                                                                      subject,
                                                                ),
                                                      ),
                                                    );
                                                    break;
                                                }
                                              },
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: color.withOpacity(
                                                    0.08,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border(
                                                    left: BorderSide(
                                                      color: color,
                                                      width: 6,
                                                    ),
                                                  ),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 18,
                                                      vertical: 14,
                                                    ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .file_present_rounded,
                                                      color: color,
                                                      size: 28,
                                                    ),
                                                    const SizedBox(width: 16),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            file.name,
                                                            style: GoogleFonts.poppins(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              fontSize: 16,
                                                              color:
                                                                  Colors
                                                                      .black87,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 2,
                                                          ),
                                                          Text(
                                                            file.fileType ?? '',
                                                            style: GoogleFonts.poppins(
                                                              fontSize: 13,
                                                              color:
                                                                  Colors
                                                                      .grey
                                                                      .shade700,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 16),
                                                    Text(
                                                      _formatTimeAgo(
                                                        file.uploadDate,
                                                      ),
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontSize: 13,
                                                            color: color,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                    ),
                                                  ],
                                                ),
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
    );
  }

  Future<void> _showWhatsNewIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSeenVersion = prefs.getString('last_seen_version') ?? '';
    if (lastSeenVersion != currentVersion) {
      // Only show if not already seen for this version
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(context: context, builder: (context) => WhatsNewDialog());
      });
      await prefs.setString('last_seen_version', currentVersion);
    }
  }

  Future<void> _checkForUpdate() async {
    try {
      final response = await http.get(Uri.parse(latestJsonUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = data['version']?.toString() ?? '';
        final downloadUrl = data['download_url']?.toString() ?? '';
        if (_isNewerVersion(latestVersion, currentVersion)) {
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: true,
              builder:
                  (context) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    title: Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: const Icon(
                            Icons.system_update_rounded,
                            color: Colors.blue,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Update Available',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'A new version ( 24latestVersion) of EduNest is available!',
                        ),
                        const SizedBox(height: 10),
                        const Text('See what\'s new:'),
                        const SizedBox(height: 10),
                        WhatsNewDialog(),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Later'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () async {
                          Navigator.of(context).pop();
                          if (downloadUrl.isNotEmpty) {
                            _launchURL(downloadUrl);
                            // Mark WhatsNew as unseen so it shows after update
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.remove('last_seen_version');
                          }
                        },
                        child: const Text('Download'),
                      ),
                    ],
                  ),
            );
          }
        }
      }
    } catch (e) {
      // Ignore update errors
    }
  }

  bool _isNewerVersion(String latest, String current) {
    // Remove any non-numeric characters and split by .
    List<int> parseVersion(String v) =>
        v
            .replaceAll(RegExp(r'[^0-9.]'), '')
            .split('.')
            .where((e) => e.isNotEmpty)
            .map(int.parse)
            .toList();
    final latestParts = parseVersion(latest);
    final currentParts = parseVersion(current);
    for (int i = 0; i < latestParts.length; i++) {
      if (i >= currentParts.length) return true;
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return false;
  }

  void _launchURL(String url) async {
    // Use url_launcher
    try {
      // ignore: use_build_context_synchronously
      await showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Open Download Page?'),
              content: Text(
                'This will open your browser to download the latest version.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    // ignore: deprecated_member_use
                    await Future.delayed(const Duration(milliseconds: 100));
                    // ignore: deprecated_member_use
                    await Future.microtask(() async {
                      // ignore: deprecated_member_use
                      await launchUrl(Uri.parse(url));
                    });
                  },
                  child: const Text('Open'),
                ),
              ],
            ),
      );
    } catch (e) {}
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24)
      return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
    if (diff.inDays < 7)
      return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
    return '${date.day}/${date.month}/${date.year}';
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

class _SubjectCard extends StatelessWidget {
  final Subject subject;
  final Color color;
  final VoidCallback onAttendanceTap;
  const _SubjectCard({
    required this.subject,
    required this.color,
    required this.onAttendanceTap,
  });
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.10),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: color.withOpacity(0.13), width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        constraints: const BoxConstraints(minHeight: 340),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.book_rounded, color: color, size: 26),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    subject.name,
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: _SubjectActionButton(
                color: color,
                icon: Icons.menu_book_rounded,
                label: 'Resources',
                onPressed: () {
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (context) => SubjectViewScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: _SubjectActionButton(
                color: color,
                icon: Icons.quiz_rounded,
                label: 'Practice Test',
                onPressed: () {
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder:
                          (context) => ChapterSelectionScreen(subject: subject),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: _SubjectActionButton(
                color: color,
                icon: Icons.calendar_today_rounded,
                label: 'Attendance',
                onPressed: onAttendanceTap,
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _SubjectActionButton extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  const _SubjectActionButton({
    required this.color,
    required this.icon,
    required this.label,
    required this.onPressed,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.13),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: color, size: 22),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: color,
              fontSize: 15,
              letterSpacing: 0.1,
            ),
          ),
        ),
        style: TextButton.styleFrom(
          foregroundColor: color,
          minimumSize: const Size(120, 38),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
