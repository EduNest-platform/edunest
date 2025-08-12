import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/user_profile_service.dart';
import '../../models/user_profile.dart';
import '../../services/supabase_service.dart';
import '../../widgets/drawer_menu.dart';
import '../../services/subjects_service.dart';
import '../../models/subject.dart';
import '../../services/files_service.dart';
import 'Subject Screen/resources_screen.dart';
import 'dart:async';
import 'academic_info_screen.dart';
import 'attendance/attendance_screen.dart';
import '../../widgets/app_text.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../home/resources/notes_screen.dart';
import '../home/resources/pyq_screen.dart';
import '../home/resources/assignments_screen.dart';
import 'Subject Screen/subject_view_screen.dart';
import '../home/resources/code_screen.dart';
import '../home/resources/lab_manuals_screen.dart';
import '../../screens/practice_tests/chapter_selection_screen.dart';
// import '../../mixins/performance_mixin.dart';
import 'dart:io';
import 'home_desktop.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  static bool _didCheckAndroidUpdateForSession = false;
  UserProfile? _userProfile;
  bool _isLoading = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<Subject> _currentSubjects = [];
  bool _subjectsLoading = true;
  List<FileResource> _recentFiles = [];
  bool _recentLoading = true;

  // First-time user onboarding
  bool _isFirstTime = false;
  bool _showOnboarding = false;
  int _currentOnboardingStep = 0;
  final List<GlobalKey> _onboardingKeys = [
    GlobalKey(),
    GlobalKey(),
    GlobalKey(),
    GlobalKey(),
    GlobalKey(),
    GlobalKey(),
  ];

  // Inline search state
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _searchLoading = false;
  Timer? _searchDebounce;
  List<Subject> _allSubjects = [];
  bool _subjectsLoadedForSearch = false;
  final FocusNode _searchFocusNode = FocusNode();
  OverlayEntry? _searchOverlayEntry;

  // Color palette for subject cards
  final List<Color> _subjectCardColors = [
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

  late AnimationController _menuIconController;

  Color _getFileTypeColor(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'notes':
        return AppTheme.fileNotes;
      case 'pyq':
        return AppTheme.filePYQ;
      case 'assignment':
        return AppTheme.assignmentsIcon;
      case 'code':
        return AppTheme.codeIcon;
      case 'lab_manuals':
        return AppTheme.labManualsIcon;
      default:
        return AppTheme.primaryBlue;
    }
  }

  @override
  void initState() {
    super.initState();
    _menuIconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _initializeApp();
    // Android in-app update check
    if (!kIsWeb &&
        Platform.isAndroid &&
        !_HomeScreenState._didCheckAndroidUpdateForSession) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _HomeScreenState._didCheckAndroidUpdateForSession = true;
        _checkForAndroidUpdate();
      });
    }
    // Ensure search field doesn't get focus automatically
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.unfocus();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Unfocus search field when screen becomes active
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.unfocus();
      }
    });
  }

  Future<void> _initializeApp() async {
    // await startOperationTrace('home_data_loading');
    await _loadUserProfile();
    await _loadSubjectsForSearch();
    // Reduced delay for faster onboarding
    await Future.delayed(const Duration(milliseconds: 50));
    await _checkFirstTimeUser();
    // await stopOperationTrace('home_data_loading');
  }

  Future<void> _checkFirstTimeUser() async {
    // Check if user is authenticated
    final currentUser = SupabaseService.client.auth.currentUser;
    if (currentUser == null) {
      return; // Don't show onboarding if user is not authenticated
    }

    // Check if user profile is loaded
    if (_userProfile == null) {
      // Reduced wait time for profile to load
      await Future.delayed(const Duration(milliseconds: 100));
    }

    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;

    // Only show onboarding if user hasn't seen it before
    if (!hasSeenOnboarding) {
      setState(() {
        _isFirstTime = true;
        _showOnboarding = true;
      });

      // Start onboarding after widgets are rendered
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Reduced delay for faster onboarding
        Future.delayed(const Duration(milliseconds: 400), () {
          if (_showOnboarding && mounted) {
            _startOnboarding();
          }
        });
      });
    }
  }

  // Method to force show onboarding (for testing or special cases)
  Future<void> _forceShowOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('has_seen_onboarding');

    setState(() {
      _isFirstTime = true;
      _showOnboarding = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (_showOnboarding && mounted) {
          _startOnboarding();
        }
      });
    });
  }

  void _startOnboarding() async {
    if (_showOnboarding) {
      // Don't mark as seen yet - wait until first tooltip is actually shown
      _showOnboardingStep(0);
    }
  }

  void _showOnboardingStep(int step) async {
    if (!_showOnboarding || step >= _onboardingKeys.length) {
      _endOnboarding();
      return;
    }

    if (mounted) {
      setState(() {
        _currentOnboardingStep = step;
      });
    }

    // Scroll to the target widget and show tooltip
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _onboardingKeys[step].currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );

        // Reduced delay after scrolling for faster onboarding
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _showTooltip(step);
            // Mark as seen only when first tooltip is successfully shown
            if (step == 0) {
              _markOnboardingAsSeen();
            }
          }
        });
      } else {
        // If context is null, try again after a shorter delay
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_showOnboarding && mounted) {
            _showOnboardingStep(step);
          }
        });
      }
    });
  }

  void _showTooltip(int step) {
    final tooltips = [
      {
        'title': 'Search Resources',
        'description':
            'Quickly find notes, assignments, and other study materials across all subjects.',
        'position': 'top',
      },
      {
        'title': 'Browse All Subjects',
        'description': 'Explore all available subjects and their resources.',
        'position': 'bottom',
      },
      {
        'title': 'Academic Info',
        'description': 'Access syllabus, timetables, and academic information.',
        'position': 'bottom',
      },
      {
        'title': 'Practice Tests',
        'description':
            'Take assigned tests and practice with MCQs to improve your knowledge.',
        'position': 'bottom',
      },
      {
        'title': 'Attendance Tracking',
        'description':
            'Monitor your attendance and track your academic progress with detailed reports.',
        'position': 'bottom',
      },
      {
        'title': 'You\'re All Set!',
        'description':
            'You\'ve completed the tour! Explore your subjects and recent activity below.',
        'position': 'bottom',
      },
    ];

    if (step < tooltips.length) {
      _showOverlayTooltip(
        _onboardingKeys[step],
        tooltips[step]['title']!,
        tooltips[step]['description']!,
        tooltips[step]['position']!,
      );
    }
  }

  void _showOverlayTooltip(
    GlobalKey key,
    String title,
    String description,
    String position,
  ) {
    final overlay = Overlay.of(context);
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;

    if (renderBox == null) return;

    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Calculate optimal positioning
    double left = offset.dx - 120;
    double top;

    if (position == 'top') {
      top = offset.dy - 110;
    } else {
      top = offset.dy + size.height + 10;
    }

    // Ensure tooltip stays within screen bounds (especially for Android)
    if (left < 8) left = 8;
    if (left + 240 > screenWidth - 8) left = screenWidth - 248;
    if (top < 8) top = offset.dy + size.height + 10;
    if (top + 160 > screenHeight - 8) top = screenHeight - 168;

    // Special handling for the last onboarding step (step 5) - "Scroll Down"
    if (_currentOnboardingStep == 5) {
      top = screenHeight - 200;
      left = (screenWidth - 240) / 2;
    }

    // Get dynamic colors based on step
    final colors = _getOnboardingColors(_currentOnboardingStep);

    // Remove any existing overlayEntry before inserting a new one
    if (_searchOverlayEntry?.mounted ?? false) {
      _searchOverlayEntry?.remove();
    }
    _searchOverlayEntry = null;

    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder:
          (context) => Positioned(
            left: left,
            top: top,
            child: Material(
              color: Colors.transparent,
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 400),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, 30 * (1 - value)),
                    child: Opacity(
                      opacity: value,
                      child: Container(
                        width: 240,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: colors,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: colors[0].withValues(alpha: 0.3),
                              blurRadius: 25,
                              offset: const Offset(0, 8),
                              spreadRadius: 2,
                            ),
                            BoxShadow(
                              color: colors[1].withValues(alpha: 0.2),
                              blurRadius: 40,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // Moving circle at top left edge
                            Positioned(
                              top: -8,
                              left: -8,
                              child: TweenAnimationBuilder<double>(
                                duration: const Duration(milliseconds: 3000),
                                tween: Tween(begin: 0.0, end: 1.0),
                                builder: (context, animValue, child) {
                                  return Transform.translate(
                                    offset: Offset(
                                      (animValue - 0.5) * 15,
                                      (animValue - 0.5) * 10,
                                    ),
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.08,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            // Two moving circles at bottom left (more visible)
                            ...List.generate(
                              2,
                              (index) => Positioned(
                                bottom: -8 + (index * 12),
                                left: -5 + (index * 8),
                                child: TweenAnimationBuilder<double>(
                                  duration: Duration(
                                    milliseconds: 3500 + (index * 800),
                                  ),
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  builder: (context, animValue, child) {
                                    return Transform.translate(
                                      offset: Offset(
                                        (animValue - 0.5) * 18,
                                        (animValue - 0.5) * 12,
                                      ),
                                      child: Container(
                                        width: 32 + (index * 8),
                                        height: 32 + (index * 8),
                                        decoration: BoxDecoration(
                                          gradient: RadialGradient(
                                            colors: [
                                              Colors.white.withValues(
                                                alpha: 0.18,
                                              ),
                                              Colors.white.withValues(
                                                alpha: 0.10,
                                              ),
                                              Colors.white.withValues(
                                                alpha: 0.04,
                                              ),
                                            ],
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            // Main content
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      TweenAnimationBuilder<double>(
                                        duration: const Duration(
                                          milliseconds: 600,
                                        ),
                                        tween: Tween(begin: 0.0, end: 1.0),
                                        builder: (context, animValue, child) {
                                          return Transform.translate(
                                            offset: Offset(
                                              15 * (1 - animValue),
                                              0,
                                            ),
                                            child: Opacity(
                                              opacity: animValue,
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.25),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withValues(
                                                            alpha: 0.1,
                                                          ),
                                                      blurRadius: 8,
                                                      offset: const Offset(
                                                        0,
                                                        2,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                child: Icon(
                                                  _getOnboardingIcon(
                                                    _currentOnboardingStep,
                                                  ),
                                                  color: Colors.white,
                                                  size: 18,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: TweenAnimationBuilder<double>(
                                          duration: const Duration(
                                            milliseconds: 400,
                                          ),
                                          tween: Tween(begin: 0.0, end: 1.0),
                                          builder: (context, animValue, child) {
                                            return Transform.translate(
                                              offset: Offset(
                                                20 * (1 - animValue),
                                                0,
                                              ),
                                              child: Opacity(
                                                opacity: animValue,
                                                child: Text(
                                                  title,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                    letterSpacing: -0.3,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: IconButton(
                                          onPressed: () {
                                            overlayEntry.remove();
                                            _nextOnboardingStep();
                                          },
                                          icon: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                          padding: const EdgeInsets.all(4),
                                          constraints: const BoxConstraints(
                                            minWidth: 28,
                                            minHeight: 28,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  TweenAnimationBuilder<double>(
                                    duration: const Duration(milliseconds: 500),
                                    tween: Tween(begin: 0.0, end: 1.0),
                                    builder: (context, animValue, child) {
                                      return Transform.translate(
                                        offset: Offset(0, 10 * (1 - animValue)),
                                        child: Opacity(
                                          opacity: animValue,
                                          child: Text(
                                            description,
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              color: Colors.white.withValues(
                                                alpha: 0.95,
                                              ),
                                              height: 1.4,
                                              letterSpacing: -0.1,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      TextButton(
                                        onPressed: () {
                                          overlayEntry.remove();
                                          _endOnboarding();
                                        },
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          'Skip',
                                          style: GoogleFonts.poppins(
                                            color: Colors.white.withValues(
                                              alpha: 0.8,
                                            ),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.white,
                                              Colors.white.withValues(
                                                alpha: 0.9,
                                              ),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.1,
                                              ),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: ElevatedButton(
                                          onPressed: () {
                                            overlayEntry.remove();
                                            _nextOnboardingStep();
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            foregroundColor: colors[0],
                                            shadowColor: Colors.transparent,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                _currentOnboardingStep == 5
                                                    ? 'Finish'
                                                    : 'Next',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(
                                                _currentOnboardingStep == 5
                                                    ? Icons.check_rounded
                                                    : Icons
                                                        .arrow_forward_rounded,
                                                size: 14,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
    );

    overlay.insert(overlayEntry);
    _searchOverlayEntry = overlayEntry;
  }

  void _nextOnboardingStep() {
    _showOnboardingStep(_currentOnboardingStep + 1);
  }

  void _endOnboarding() {
    setState(() {
      _showOnboarding = false;
      _currentOnboardingStep = 0;
    });
  }

  Future<void> _markOnboardingAsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
  }

  IconData _getOnboardingIcon(int step) {
    switch (step) {
      case 0:
        return Icons.search_rounded;
      case 1:
        return Icons.book_rounded;
      case 2:
        return Icons.info_outline_rounded;
      case 3:
        return Icons.quiz_rounded;
      case 4:
        return Icons.calendar_today_rounded;
      case 5:
        return Icons.check_circle_rounded;
      default:
        return Icons.lightbulb_outline_rounded;
    }
  }

  List<Color> _getOnboardingColors(int step) {
    switch (step) {
      case 0:
        return [
          Colors.pinkAccent,
          Colors.pink.shade300,
        ]; // Different from header blue
      case 1:
        return [AppTheme.secondaryGreen, AppTheme.secondaryLight];
      case 2:
        return [Colors.redAccent, Colors.red.shade300];
      case 3:
        return [AppTheme.accentOrange, AppTheme.accentLight];
      case 4:
        return [Colors.purple, Colors.purple.shade300]; // Attendance
      case 5:
        return [Colors.teal, Colors.teal.shade300]; // Scroll down
      default:
        return [AppTheme.primaryBlue, AppTheme.primaryLight];
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await UserProfileService.getCurrentUserProfile();
      setState(() {
        _userProfile = profile;
        _isLoading = false;
      });
      if (profile != null &&
          profile.college != null &&
          profile.semester != null &&
          profile.branch != null) {
        await _loadCurrentSubjects(
          profile.college!,
          profile.branch!,
          profile.semester!.toString(),
        );
        await _loadRecentActivity();
      } else {
        setState(() {
          _subjectsLoading = false;
          _recentLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _subjectsLoading = false;
        _recentLoading = false;
      });
    }
  }

  Future<void> _loadCurrentSubjects(
    String college,
    String branch,
    String semester,
  ) async {
    setState(() {
      _subjectsLoading = true;
    });
    try {
      final subjects = await SubjectsService.getSubjectsByCollegeAndSemester(
        college,
        semester,
      );
      // Filter by branch as well
      final branchName = branch;
      final filteredSubjects =
          subjects.where((subject) {
            final subjectBranch =
                subject.semester?.branch?.name.toLowerCase() ?? '';
            final userBranch = branchName.toLowerCase();
            return subjectBranch.contains(userBranch) ||
                userBranch.contains(subjectBranch);
          }).toList();
      setState(() {
        _currentSubjects = filteredSubjects;
        _subjectsLoading = false;
      });
    } catch (e) {
      setState(() {
        _subjectsLoading = false;
      });
    }
  }

  Future<void> _loadRecentActivity() async {
    setState(() {
      _recentLoading = true;
    });
    try {
      List<FileResource> allFiles = [];
      final uuidRegExp = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}␀?$',
      );
      for (final subject in _currentSubjects) {
        // Only fetch for valid UUIDs
        if (uuidRegExp.hasMatch(subject.id)) {
          final files = await FilesService.getRecentFiles(subject.id, limit: 3);
          allFiles.addAll(files);
        }
      }
      allFiles.sort((a, b) => b.uploadDate.compareTo(a.uploadDate));
      setState(() {
        _recentFiles = allFiles.take(10).toList();
        _recentLoading = false;
      });
    } catch (e) {
      setState(() {
        _recentLoading = false;
      });
    }
  }

  Future<void> _logout(BuildContext context) async {
    try {
      final currentUser = SupabaseService.client.auth.currentUser;

      await AuthService.signOut();

      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadSubjectsForSearch() async {
    if (_subjectsLoadedForSearch) return;
    final profile = await UserProfileService.getCurrentUserProfile();
    List<Subject> subjects;
    if (profile != null &&
        profile.college != null &&
        profile.semester != null &&
        profile.branch != null) {
      subjects = await SubjectsService.getSubjectsByCollegeAndSemester(
        profile.college!,
        profile.semester!.toString(),
      );
      // Filter by branch as well
      final branchName = profile.branch!;
      subjects =
          subjects.where((subject) {
            final subjectBranch =
                subject.semester?.branch?.name.toLowerCase() ?? '';
            final userBranch = branchName.toLowerCase();
            return subjectBranch.contains(userBranch) ||
                userBranch.contains(subjectBranch);
          }).toList();
    } else {
      subjects = await SubjectsService.getAllSubjects();
    }
    setState(() {
      _allSubjects = subjects;
      _subjectsLoadedForSearch = true;
    });
  }

  void _onInlineSearchChanged(String query) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      if (query.trim().isNotEmpty) {
        setState(() {
          _searchLoading = true;
        });
        List<Map<String, dynamic>> allResults = [];
        for (final subject in _allSubjects) {
          // Add both study/resources and practice exam entries for each subject
          if (subject.name.toLowerCase().contains(query.toLowerCase()) ||
              (subject.code?.toLowerCase().contains(query.toLowerCase()) ??
                  false)) {
            allResults.add({
              'type': 'subject',
              'mode': 'study',
              'subject': subject,
            });
            allResults.add({
              'type': 'subject',
              'mode': 'practice',
              'subject': subject,
            });
          }
          final files = await FilesService.searchFiles(
            subject.id,
            query.trim(),
          );
          for (final file in files) {
            allResults.add({'file': file, 'subject': subject});
          }
        }
        setState(() {
          _searchResults = allResults;
          _searchLoading = false;
        });
        if (!(Platform.isWindows || Platform.isMacOS)) {
          _showSearchOverlay();
        }
      } else {
        setState(() {
          _searchResults = [];
        });
        if (!(Platform.isWindows || Platform.isMacOS)) {
          _removeSearchOverlay();
        }
      }
    });
  }

  void _showSearchOverlay() {
    if (Platform.isWindows || Platform.isMacOS) return;
    _removeSearchOverlay();
    if (_searchResults.isEmpty && !_searchLoading) return;
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    final offset = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
    _searchOverlayEntry = OverlayEntry(
      builder:
          (context) => Positioned(
            left: 24,
            right: 24,
            top: offset.dy + 100, // adjust as needed
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 350),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child:
                    _searchLoading
                        ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        )
                        : _searchResults.isEmpty
                        ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'No files found',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        )
                        : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _searchResults.length,
                          itemBuilder: (context, idx) {
                            final result = _searchResults[idx];
                            final file = result['file'];
                            final subject = result['subject'];
                            final isFile = file != null;
                            final isSubject = result['type'] == 'subject';
                            IconData iconData = Icons.insert_drive_file_rounded;
                            Color iconColor = AppTheme.primaryBlue;
                            String title = '';
                            String subtitle = '';
                            VoidCallback? onTap;
                            if (isFile) {
                              switch (file.fileType?.toLowerCase()) {
                                case 'notes':
                                  iconData = Icons.description_rounded;
                                  iconColor = AppTheme.fileNotes;
                                  break;
                                case 'pyq':
                                  iconData = Icons.quiz_rounded;
                                  iconColor = AppTheme.filePYQ;
                                  break;
                                case 'assignment':
                                  iconData = Icons.assignment_rounded;
                                  iconColor = AppTheme.assignmentsIcon;
                                  break;
                                case 'code':
                                  iconData = Icons.code_rounded;
                                  iconColor = AppTheme.codeIcon;
                                  break;
                                case 'lab_manuals':
                                  iconData = Icons.science_rounded;
                                  iconColor = AppTheme.labManualsIcon;
                                  break;
                                case 'other':
                                  iconData = Icons.folder_rounded;
                                  iconColor = Colors.indigo;
                                  break;
                                default:
                                  iconData = Icons.insert_drive_file_rounded;
                                  iconColor = AppTheme.primaryBlue;
                              }
                              title = file.name;
                              subtitle = subject.name;
                              onTap = () {
                                _removeSearchOverlay();
                                switch (file.fileType?.toLowerCase()) {
                                  case 'notes':
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => NotesScreen(
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
                                            (context) => PYQScreen(
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
                                            (context) => AssignmentsScreen(
                                              subject: subject,
                                              showAppBar: true,
                                            ),
                                      ),
                                    );
                                    break;
                                  case 'code':
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => CodeScreen(
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
                                            (context) => LabManualsScreen(
                                              subject: subject,
                                              showAppBar: true,
                                            ),
                                      ),
                                    );
                                    break;
                                  default:
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => ResourcesScreen(
                                              subject: subject,
                                            ),
                                      ),
                                    );
                                    break;
                                }
                              };
                            } else if (isSubject) {
                              final isPractice = result['mode'] == 'practice';
                              iconData =
                                  isPractice
                                      ? Icons.fact_check_rounded
                                      : Icons.menu_book_rounded;
                              iconColor =
                                  isPractice
                                      ? AppTheme.accentOrange
                                      : Colors.lightBlueAccent;
                              title = subject.name;
                              subtitle =
                                  isPractice
                                      ? 'Practice Exam'
                                      : 'Study Resources';
                              onTap = () {
                                _removeSearchOverlay();
                                if (isPractice) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => ChapterSelectionScreen(
                                            subject: subject,
                                          ),
                                    ),
                                  );
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SubjectViewScreen(),
                                    ),
                                  );
                                }
                              };
                            }
                            return ListTile(
                              leading: Icon(iconData, color: iconColor),
                              title: Text(
                                title,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle:
                                  subtitle.isNotEmpty
                                      ? Text(
                                        subtitle,
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          color: Colors.grey.shade600,
                                        ),
                                      )
                                      : null,
                              onTap: onTap,
                            );
                          },
                        ),
              ),
            ),
          ),
    );
    overlay.insert(_searchOverlayEntry!);
  }

  void _removeSearchOverlay() {
    if (Platform.isWindows || Platform.isMacOS) return;
    _searchOverlayEntry?.remove();
    _searchOverlayEntry = null;
  }

  @override
  void dispose() {
    _menuIconController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    _removeSearchOverlay();
    super.dispose();
  }

  // Method to handle when screen becomes active
  void _onScreenActive() {
    if (mounted) {
      _searchFocusNode.unfocus();
      _searchController.clear();
      _removeSearchOverlay();
    }
  }

  Widget _buildHomeSearchBar() {
    if (Platform.isWindows || Platform.isMacOS) {
      // Render only the search bar, HomeDesktop will handle dropdown
      return Container(
        key: _onboardingKeys[0],
        margin: const EdgeInsets.only(bottom: 32, top: 1),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.primaryBlue.withValues(alpha: 0.18),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryBlue.withValues(alpha: 0.07),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          autofocus: false,
          onChanged: _onInlineSearchChanged,
          style: GoogleFonts.poppins(fontSize: 15, color: Colors.black87),
          decoration: InputDecoration(
            hintText: 'Search resources...',
            hintStyle: GoogleFonts.poppins(
              color: Colors.grey.shade500,
              fontSize: 15,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: AppTheme.primaryBlue.withValues(alpha: 0.7),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      );
    }
    return Container(
      key: _onboardingKeys[0],
      margin: const EdgeInsets.only(bottom: 32, top: 1),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.primaryBlue.withValues(alpha: 0.18),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FocusScope(
        child: Focus(
          onFocusChange: (hasFocus) {
            if (!hasFocus) _removeSearchOverlay();
          },
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            autofocus: false,
            onChanged: _onInlineSearchChanged,
            style: GoogleFonts.poppins(fontSize: 15, color: Colors.black87),
            decoration: InputDecoration(
              hintText: 'Search resources...',
              hintStyle: GoogleFonts.poppins(
                color: Colors.grey.shade500,
                fontSize: 15,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: AppTheme.primaryBlue.withValues(alpha: 0.7),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryBlue, AppTheme.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      'Welcome back!',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 3),
                    AppText(
                      _userProfile?.fullName ?? 'Student',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.pushNamed(context, '/profile');
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.school_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        'Your Academic Path',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.location_city,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: AppText(
                              _userProfile?.college ?? 'College',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.account_tree_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: AppText(
                                  _userProfile?.branch ?? 'Branch',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(Icons.school, color: Colors.white, size: 14),
                              const SizedBox(width: 5),
                              Expanded(
                                child: AppText(
                                  _userProfile?.semester?.toString() ??
                                      'Semester',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (_userProfile?.studentId != null &&
                              _userProfile!.studentId!.trim().isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(
                                  Icons.badge_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: AppText(
                                    _userProfile!.studentId!,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          'Quick Actions',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryBlue,
          ),
        ),
        const SizedBox(height: 16),
        // First row
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                key: _onboardingKeys[1],
                icon: Icons.book_rounded,
                title: 'Browse All Subjects',
                subtitle: 'Discover all subjects',
                color: AppTheme.primaryBlue,
                onTap: () {
                  Navigator.pushNamed(context, '/subjects');
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionCard(
                key: _onboardingKeys[2],
                icon: Icons.info_outline_rounded,
                title: 'Academic Info',
                subtitle: 'Syllabus & Timetable',
                color: AppTheme.primaryLight,
                onTap: () {
                  if (_currentSubjects.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => AcademicInfoScreen(
                              subjectId: _currentSubjects.first.id,
                            ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No subject found for Academic Info.'),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Second row
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                key: _onboardingKeys[3],
                icon: Icons.quiz_rounded,
                title: 'Practice Tests',
                subtitle: 'Test your knowledge',
                color: Colors.orange,
                onTap: () {
                  Navigator.pushNamed(context, '/practice-tests');
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionCard(
                key: _onboardingKeys[4],
                icon: Icons.calendar_today_rounded,
                title: 'Attendance',
                subtitle: 'Track your attendance',
                color: Colors.purple,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AttendanceScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    Key? key,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 160, // Increased height to prevent overflow
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.1), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon section
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            // Text section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  AppText(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  AppText(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AppText(
              'Recent Activity',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_recentLoading)
          const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryBlue),
          ),
        if (!_recentLoading && _recentFiles.isEmpty)
          Center(
            child: AppText(
              'No recent activity found.',
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
            ),
          ),
        if (!_recentLoading && _recentFiles.isNotEmpty)
          Column(
            children:
                _recentFiles
                    .take(10)
                    .map(
                      (file) => _buildActivityItem(
                        icon: Icons.file_present_rounded,
                        title: file.name,
                        subtitle:
                            '${file.fileType} • Uploaded by ${file.uploadedBy} • ${_formatTimeAgo(file.uploadDate)}',
                        color: _getFileTypeColor(file.fileType),
                      ),
                    )
                    .toList(),
          ),
      ],
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
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
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                AppText(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) {
      return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
    }
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildMyCurrentSubjects() {
    return Column(
      key: _onboardingKeys[5],
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AppText(
              'My Current Subjects',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryBlue,
              ),
            ),
            TextButton(
              onPressed: () {
                // Navigate to full subjects view
                if (_currentSubjects.isNotEmpty) {
                  Navigator.pushNamed(context, '/subjects');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No subjects to view.')),
                  );
                }
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: AppText(
                'View All',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_subjectsLoading)
          const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryBlue),
          ),
        if (!_subjectsLoading && _currentSubjects.isEmpty)
          Center(
            child: AppText(
              'No subjects found for your college and semester.',
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
            ),
          ),
        if (!_subjectsLoading && _currentSubjects.isNotEmpty)
          Column(
            children:
                _currentSubjects.take(4).toList().asMap().entries.map((entry) {
                  final idx = entry.key;
                  final subject = entry.value;
                  final color =
                      _subjectCardColors[idx % _subjectCardColors.length];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildSubjectCard(
                      subjectName: subject.name,
                      subjectCode: subject.code ?? '',
                      resourceCount: subject.resourceCount,
                      lastActivity: '',
                      color: color,
                      semesterName: subject.semesterName,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => ResourcesScreen(subject: subject),
                          ),
                        );
                      },
                    ),
                  );
                }).toList(),
          ),
      ],
    );
  }

  Widget _buildSubjectCard({
    required String subjectName,
    required String subjectCode,
    required int resourceCount,
    required String lastActivity,
    required Color color,
    required VoidCallback onTap,
    String? semesterName,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 115,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.book_rounded, color: color, size: 28),
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
                          subjectName,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (semesterName != null && semesterName.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: AppText(
                            semesterName,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: color,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  AppText(
                    subjectCode,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.file_present_rounded,
                        size: 15,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      AppText(
                        '$resourceCount resources',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isWindows || Platform.isMacOS) {
      return Scaffold(
        body: HomeDesktop(
          userProfile: _userProfile,
          isLoading: _isLoading,
          currentSubjects: _currentSubjects,
          subjectsLoading: _subjectsLoading,
          recentFiles: _recentFiles,
          recentLoading: _recentLoading,
          onLogout: () => _logout(context),
          onSubjectTap: (subject) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ResourcesScreen(subject: subject),
              ),
            );
          },
          searchController: _searchController,
          searchFocusNode: _searchFocusNode,
          searchResults: _searchResults,
          searchLoading: _searchLoading,
          onSearchChanged: _onInlineSearchChanged,
          onSearchUnfocus: () {
            _searchFocusNode.unfocus();
            _searchController.clear();
            _searchResults = [];
            _removeSearchOverlay();
            setState(() {});
          },
        ),
      );
    }
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey.shade50,
      endDrawer: const DrawerMenu(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.school, color: AppTheme.primaryBlue, size: 27),
            ),
            const SizedBox(width: 12),
            AppText(
              'EduNest',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                fontSize: 24,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              _scaffoldKey.currentState?.openEndDrawer();
            },
            icon: const Icon(
              Icons.menu_rounded,
              color: Colors.black87,
              size: 29,
            ),
            tooltip: 'Menu',
          ),
        ],
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: FocusScope(
        autofocus: false,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            FocusScope.of(context).unfocus();
            _onScreenActive();
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHomeSearchBar(),
                _buildWelcomeSection(),
                const SizedBox(height: 32),
                _buildQuickActions(),
                const SizedBox(height: 32),
                _buildMyCurrentSubjects(),
                const SizedBox(height: 32),
                _buildRecentActivity(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _checkForAndroidUpdate() async {
    try {
      const latestJsonUrl =
          'https://raw.githubusercontent.com/Ranojitdas/EduNest-desktop/main/latest.json';
      final response = await http.get(Uri.parse(latestJsonUrl));
      if (response.statusCode == 200) {
        final latest = jsonDecode(response.body);
        final latestVersion = latest['version'] ?? '';
        final latestApkUrl =
            latest['android']?['download_url'] ?? latest['download_url'];
        if (latestVersion.isEmpty || latestApkUrl == null) return;
        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;
        if (_isNewerVersion(latestVersion, currentVersion)) {
          if (!mounted) return;
          _showAndroidUpdateDialog(
            latestVersion,
            latestApkUrl,
            latest['release_notes'],
          );
        }
      }
    } catch (e) {
      // Ignore update errors
    }
  }

  bool _isNewerVersion(String latest, String current) {
    List<int> latestParts =
        latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> currentParts =
        current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (int i = 0; i < latestParts.length; i++) {
      if (i >= currentParts.length) return true;
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return false;
  }

  void _showAndroidUpdateDialog(
    String latestVersion,
    String apkUrl,
    String? releaseNotes,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF3A8DFF), // Bluish
                    Color(0xFF6DD5FA), // Lighter blue
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3A8DFF).withValues(alpha: 0.18),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with icon
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.system_update_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Title
                    Text(
                      'Update Available',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    // Version info
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Version $latestVersion',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Description
                    Text(
                      'A new version of EduNest is available with the latest features and improvements.',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Later',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white,
                                  Colors.white.withValues(alpha: 0.9),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: () async {
                                Navigator.of(context).pop();
                                await launchUrl(
                                  Uri.parse(apkUrl),
                                  mode: LaunchMode.externalApplication,
                                );
                                // DO NOT show WhatsNewDialog here. It should only show after the app is updated and restarted.
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: const Color(0xFF3A8DFF),
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.download_rounded, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Update',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }
}
