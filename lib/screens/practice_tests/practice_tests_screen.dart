import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/subjects_service.dart';
import '../../models/subject.dart';
import '../../widgets/custom_app_bar.dart';
import 'chapter_selection_screen.dart';
import 'assigned_test_card_screen.dart';
import '../../services/user_profile_service.dart';
import '../../models/user_profile.dart';
import '../../services/network_service.dart';
import '../../widgets/app_text.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/error_message_service.dart';
import '../../mixins/performance_mixin.dart';
import 'package:flutter/foundation.dart';
import '../../widgets/desktop_sidebar.dart';

class PracticeTestsScreen extends StatefulWidget {
  const PracticeTestsScreen({super.key});

  @override
  State<PracticeTestsScreen> createState() => _PracticeTestsScreenState();
}

class _PracticeTestsScreenState extends State<PracticeTestsScreen>
    with NetworkAwareMixin, PerformanceMixin {
  List<Subject> _subjects = [];
  bool _isLoading = true;
  String? _error;
  UserProfile? _userProfile;
  bool _hasNetworkError = false;
  final NetworkService _networkService = NetworkService();

  // Map to store custom color indices for each subject
  final Map<String, int> _subjectColorIndices = {};
  static const String _colorPrefsKey = 'practice_test_subject_colors';

  // Onboarding tip state
  bool _showOnboardingTip = false;
  static const String _onboardingTipKey = 'practice_test_color_onboarding_seen';
  final GlobalKey _firstIconKey = GlobalKey();
  final LayerLink _tooltipLayerLink = LayerLink();

  // Engineering-focused color schemes for different subjects (vibrant colors)
  static final List<Map<String, dynamic>> _subjectColorSchemes = [
    {
      'gradient': [
        const Color(0xFFE91E63),
        const Color(0xFFF48FB1),
      ], // Vibrant Pink to Light Pink (Computer Science)
      'iconBg': const Color(0xFFE91E63),
      'icon': Icons.computer_rounded,
    },
    {
      'gradient': [
        const Color(0xFF4CAF50),
        const Color(0xFF81C784),
      ], // Vibrant Green to Light Green (Mechanical)
      'iconBg': const Color(0xFF4CAF50),
      'icon': Icons.precision_manufacturing_rounded,
    },
    {
      'gradient': [
        const Color(0xFFFF9800),
        const Color(0xFFFFB74D),
      ], // Vibrant Orange to Light Orange (Electrical)
      'iconBg': const Color(0xFFFF9800),
      'icon': Icons.electric_bolt_rounded,
    },
    {
      'gradient': [
        const Color(0xFF9C27B0),
        const Color(0xFFCE93D8),
      ], // Vibrant Purple to Light Purple (Electronics)
      'iconBg': const Color(0xFF9C27B0),
      'icon': Icons.memory_rounded,
    },
    {
      'gradient': [
        const Color(0xFF795548),
        const Color(0xFFA1887F),
      ], // Vibrant Brown to Light Brown (Civil)
      'iconBg': const Color(0xFF795548),
      'icon': Icons.architecture_rounded,
    },
    {
      'gradient': [
        const Color(0xFF607D8B),
        const Color(0xFF90A4AE),
      ], // Vibrant Blue Grey to Light Blue Grey (Chemical)
      'iconBg': const Color(0xFF607D8B),
      'icon': Icons.science_rounded,
    },
    {
      'gradient': [
        const Color(0xFF3F51B5),
        const Color(0xFF9FA8DA),
      ], // Vibrant Indigo to Light Indigo (Information Technology)
      'iconBg': const Color(0xFF3F51B5),
      'icon': Icons.code_rounded,
    },
    {
      'gradient': [
        const Color(0xFF00BCD4),
        const Color(0xFF4DD0E1),
      ], // Vibrant Cyan to Light Cyan (Telecommunication)
      'iconBg': const Color(0xFF00BCD4),
      'icon': Icons.router_rounded,
    },
    {
      'gradient': [
        const Color(0xFF8BC34A),
        const Color(0xFFAED581),
      ], // Vibrant Light Green to Lighter Green (Biomedical)
      'iconBg': const Color(0xFF8BC34A),
      'icon': Icons.medical_services_rounded,
    },
    {
      'gradient': [
        const Color(0xFFFF5722),
        const Color(0xFFFF8A65),
      ], // Vibrant Deep Orange to Light Orange (Robotics)
      'iconBg': const Color(0xFFFF5722),
      'icon': Icons.smart_toy_rounded,
    },
    {
      'gradient': [
        const Color(0xFF673AB7),
        const Color(0xFFB39DDB),
      ], // Vibrant Deep Purple to Light Purple (AI/ML)
      'iconBg': const Color(0xFF673AB7),
      'icon': Icons.psychology_rounded,
    },
    {
      'gradient': [
        const Color(0xFF009688),
        const Color(0xFF4DB6AC),
      ], // Vibrant Teal to Light Teal (Data Science)
      'iconBg': const Color(0xFF009688),
      'icon': Icons.analytics_rounded,
    },
  ];

  // Get color scheme for a subject based on its name (for variety)
  Map<String, dynamic> _getSubjectColorScheme(int index) {
    // Use subject name to generate a more varied color distribution
    final subject = _subjects[index];

    // Check if user has set a custom color for this subject
    if (_subjectColorIndices.containsKey(subject.name)) {
      final customIndex = _subjectColorIndices[subject.name]!;
      return _subjectColorSchemes[customIndex % _subjectColorSchemes.length];
    }

    // Default: Use name hash for initial color
    final nameHash = subject.name.hashCode;
    final colorIndex = (nameHash.abs() % _subjectColorSchemes.length);
    return _subjectColorSchemes[colorIndex];
  }

  // Cycle through color palettes for a subject
  void _cycleSubjectColor(String subjectName) {
    setState(() {
      final currentIndex =
          _subjectColorIndices[subjectName] ??
          (subjectName.hashCode.abs() % _subjectColorSchemes.length);
      final nextIndex = (currentIndex + 1) % _subjectColorSchemes.length;
      _subjectColorIndices[subjectName] = nextIndex;
    });
    _saveSubjectColors();
  }

  // Get appropriate icon for engineering subjects based on name
  IconData _getSubjectIcon(String subjectName) {
    final name = subjectName.toLowerCase();

    // Computer Science & Programming (check first to avoid conflicts)
    if (name.contains('computer') ||
        name.contains('programming') ||
        name.contains('software') ||
        name.contains('compiler') ||
        name.contains('python') ||
        name.contains('c++') ||
        name.contains('c#') ||
        name.contains('java') ||
        name.contains('dsa') ||
        name.contains('data structure') ||
        name.contains('algorithm') ||
        name.contains('database') ||
        name.contains('web') ||
        name.contains('app') ||
        name.contains('mobile') ||
        name.contains('android') ||
        name.contains('ios')) {
      return Icons.laptop_mac_rounded;
    }

    // Mechanical Engineering
    if (name.contains('mechanical') ||
        name.contains('thermodynamics') ||
        name.contains('fluid') ||
        name.contains('dynamics') ||
        name.contains('machines') ||
        name.contains('manufacturing')) {
      return Icons.precision_manufacturing_rounded;
    }

    // Electrical Engineering
    if (name.contains('electrical') ||
        name.contains('circuit') ||
        name.contains('power') ||
        name.contains('electronics') ||
        name.contains('voltage') ||
        name.contains('current')) {
      return Icons.electric_bolt_rounded;
    }

    // Electronics & Communication
    if (name.contains('communication') ||
        name.contains('signal') ||
        name.contains('digital') ||
        name.contains('microprocessor') ||
        name.contains('vlsi') ||
        name.contains('antenna')) {
      return Icons.memory_rounded;
    }

    // Civil Engineering
    if (name.contains('civil') ||
        name.contains('structural') ||
        name.contains('concrete') ||
        name.contains('surveying') ||
        name.contains('transportation') ||
        name.contains('environmental')) {
      return Icons.architecture_rounded;
    }

    // Chemical Engineering
    if (name.contains('chemical') ||
        name.contains('reaction') ||
        name.contains('process') ||
        name.contains('polymer') ||
        name.contains('petroleum')) {
      return Icons.science_rounded;
    }

    // Information Technology
    if (name.contains('information') ||
        name.contains('it') ||
        name.contains('web') ||
        name.contains('database') ||
        name.contains('network') ||
        name.contains('cyber')) {
      return Icons.code_rounded;
    }

    // Telecommunication
    if (name.contains('telecom') ||
        name.contains('wireless') ||
        name.contains('satellite') ||
        name.contains('optical') ||
        name.contains('fiber')) {
      return Icons.router_rounded;
    }

    // Biomedical Engineering
    if (name.contains('biomedical') ||
        name.contains('medical') ||
        name.contains('biomechanics') ||
        name.contains('biomaterials') ||
        name.contains('physiology')) {
      return Icons.medical_services_rounded;
    }

    // Robotics & Automation
    if (name.contains('robotics') ||
        name.contains('automation') ||
        name.contains('control') ||
        name.contains('mechatronics') ||
        name.contains('plc')) {
      return Icons.smart_toy_rounded;
    }

    // AI & Machine Learning
    if (name.contains('artificial') ||
        name.contains('machine learning') ||
        name.contains('ai') ||
        name.contains('neural') ||
        name.contains('deep learning') ||
        name.contains('pattern')) {
      return Icons.psychology_rounded;
    }

    // Data Science & Analytics
    if (name.contains('data') ||
        name.contains('analytics') ||
        name.contains('statistics') ||
        name.contains('probability') ||
        name.contains('optimization')) {
      return Icons.analytics_rounded;
    }

    // Mathematics & Physics (Core subjects)
    if (name.contains('math') ||
        name.contains('calculus') ||
        name.contains('algebra') ||
        name.contains('linear') ||
        name.contains('differential')) {
      return Icons.calculate_rounded;
    }

    if (name.contains('physics') ||
        name.contains('mechanics') ||
        name.contains('electromagnetics') ||
        name.contains('optics') ||
        name.contains('quantum')) {
      return Icons.science_rounded;
    }

    // Default for other engineering subjects
    return Icons.engineering_rounded;
  }

  @override
  void initState() {
    super.initState();
    startScreenMonitoring('practice_tests_screen');
    _loadSavedSubjectColors().then((_) => _loadUserProfileAndSubjects());
  }

  Future<void> _loadSavedSubjectColors() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_colorPrefsKey);
    if (jsonString != null) {
      final Map<String, dynamic> map = json.decode(jsonString);
      setState(() {
        _subjectColorIndices.clear();
        map.forEach((key, value) {
          if (value is int) _subjectColorIndices[key] = value;
        });
      });
    }
  }

  Future<void> _saveSubjectColors() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_colorPrefsKey, json.encode(_subjectColorIndices));
  }

  Future<void> _loadUserProfileAndSubjects() async {
    await startOperationTrace('practice_tests_data_loading');

    // Check network connectivity first
    final networkStatus = await _networkService.isConnected();

    if (!networkStatus) {
      setState(() {
        _hasNetworkError = true;
        _isLoading = false;
      });
      await stopOperationTrace('practice_tests_data_loading');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _hasNetworkError = false;
    });

    try {
      final profile = await UserProfileService.getCurrentUserProfile();
      if (profile == null ||
          profile.college == null ||
          profile.semester == null) {
        setState(() {
          _error = 'Profile incomplete. Please set your college and semester.';
          _isLoading = false;
        });
        await stopOperationTrace('practice_tests_data_loading');
        return;
      }
      _userProfile = profile;
      final subjects = await SubjectsService.getSubjectsByCollegeAndSemester(
        profile.college!,
        profile.semester!,
      );
      // Filter by branch as well
      final branchName = profile.branch ?? '';
      final filteredSubjects =
          subjects.where((subject) {
            final subjectBranch =
                subject.semester?.branch?.name.toLowerCase() ?? '';
            final userBranch = branchName.toLowerCase();
            return subjectBranch.contains(userBranch) ||
                userBranch.contains(subjectBranch);
          }).toList();
      setState(() {
        _subjects = filteredSubjects;
        _isLoading = false;
        _hasNetworkError = false;
      });

      // Check onboarding tip after profile is loaded
      await _checkOnboardingTip();
      await stopOperationTrace('practice_tests_data_loading');
    } catch (e) {
      final message = ErrorMessageService.getFriendlyMessage(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
      await stopOperationTrace('practice_tests_data_loading');
    }
  }

  Future<void> _refreshSubjects() async {
    await _retryWithNetworkCheck();
  }

  Future<void> _retryWithNetworkCheck() async {
    await refreshNetworkStatus();
    final networkStatus = await _networkService.isConnected();

    if (networkStatus) {
      await _loadUserProfileAndSubjects();
    } else {
      setState(() {
        _hasNetworkError = true;
      });
    }
  }

  Future<void> _checkOnboardingTip() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_onboardingTipKey) ?? false;

    // Only show for new users (account created within last 7 days)
    if (!seen && _userProfile != null && _userProfile!.createdAt != null) {
      final accountAge = DateTime.now().difference(_userProfile!.createdAt!);
      final isNewUser = accountAge.inDays <= 7;

      if (isNewUser) {
        setState(() {
          _showOnboardingTip = true;
        });
      }
    }
  }

  Future<void> _dismissOnboardingTip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingTipKey, true);
    setState(() {
      _showOnboardingTip = false;
    });
  }

  Widget _buildSubjectCard(Subject subject) {
    final index = _subjects.indexOf(subject);
    final colorScheme = _getSubjectColorScheme(index);
    final gradientColors = colorScheme['gradient'] as List<Color>;
    final iconBgColor = colorScheme['iconBg'] as Color;
    final subjectIcon = _getSubjectIcon(subject.name);

    return Stack(
      children: [
        // Main card
        Container(
          margin: const EdgeInsets.only(bottom: 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: gradientColors[0].withValues(alpha: 0.03),
                blurRadius: 24,
                offset: const Offset(0, 8),
                spreadRadius: 0,
              ),
            ],
            border: Border.all(
              color: gradientColors[0].withValues(
                alpha: 0.18,
              ), // Subtle colored border
              width: 1.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => ChapterSelectionScreen(subject: subject),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                child: Row(
                  children: [
                    // Professional icon container with color cycling
                    CompositedTransformTarget(
                      link: index == 0 ? _tooltipLayerLink : LayerLink(),
                      child: GestureDetector(
                        key: index == 0 ? _firstIconKey : null,
                        onTap: () {
                          _cycleSubjectColor(subject.name);
                          if (_showOnboardingTip) _dismissOnboardingTip();
                        },
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: gradientColors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: gradientColors[0].withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: Icon(
                            subjectIcon,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Professional content layout
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Subject name with professional typography
                          AppText(
                            subject.name,
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade900,
                              letterSpacing: -0.2,
                              height: 1.4,
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 6),
                          // Professional subject code badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: gradientColors[0].withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: gradientColors[0].withValues(
                                  alpha: 0.12,
                                ),
                                width: 0.5,
                              ),
                            ),
                            child: AppText(
                              subject.code ?? 'No Code',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: gradientColors[0],
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Professional semester info
                          Row(
                            children: [
                              Icon(
                                Icons.school_outlined,
                                size: 14,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 6),
                              AppText(
                                subject.semesterName ?? 'Semester',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 0.1,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Professional arrow indicator with subject color
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: gradientColors[0].withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: gradientColors[0],
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(
              Icons.quiz_rounded,
              size: 60,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 24),
          AppText(
            'No Subjects Available',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          AppText(
            'Practice tests will be available once subjects are added.',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 60,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 24),
          AppText(
            'Error Loading Subjects',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          AppText(
            _error ?? 'An error occurred while loading subjects.',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _refreshSubjects,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 1000;
    final bool isDesktop =
        kIsWeb ||
        Theme.of(context).platform == TargetPlatform.windows ||
        Theme.of(context).platform == TargetPlatform.linux ||
        Theme.of(context).platform == TargetPlatform.macOS;
    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        body: Row(
          children: [
            DesktopSidebar(
              selected: 'practice-tests',
              onNavigate: (route) => Navigator.pushNamed(context, route),
            ),
            Expanded(
              child: Column(
                children: [
                  CustomAppBar(
                    title: 'Practice Tests',
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        if (_isLoading)
                          const Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.primaryBlue,
                            ),
                          )
                        else if (_hasNetworkError)
                          buildNetworkErrorWidget(
                            title: '📡 No Internet Connection',
                            message:
                                'Unable to load practice tests. Please connect to the internet and try again.',
                            customEmoji: '📝',
                            onRetry: _retryWithNetworkCheck,
                          )
                        else
                          SafeArea(
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 1000,
                                ),
                                child: SingleChildScrollView(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isWide ? 40 : 16,
                                      vertical: 20,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Assigned MCQ Tests card at the top
                                        Card(
                                          elevation: 7,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          margin: const EdgeInsets.only(
                                            bottom: 36,
                                          ),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder:
                                                      (context) =>
                                                          const AssignedTestCardScreen(),
                                                ),
                                              );
                                            },
                                            child: Stack(
                                              children: [
                                                // Full-height gradient accent bar
                                                Positioned(
                                                  left: 0,
                                                  top: 0,
                                                  bottom: 0,
                                                  child: Container(
                                                    width: 8,
                                                    decoration: const BoxDecoration(
                                                      gradient: LinearGradient(
                                                        colors: [
                                                          Color(0xFFB6E0FE),
                                                          Color(0xFF7DD3FC),
                                                        ],
                                                        begin:
                                                            Alignment.topCenter,
                                                        end:
                                                            Alignment
                                                                .bottomCenter,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.only(
                                                            topLeft:
                                                                Radius.circular(
                                                                  20,
                                                                ),
                                                            bottomLeft:
                                                                Radius.circular(
                                                                  20,
                                                                ),
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        left: 8,
                                                      ),
                                                  child: Row(
                                                    children: [
                                                      const SizedBox(width: 18),
                                                      // Icon with soft gradient background
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              18,
                                                            ),
                                                        decoration: const BoxDecoration(
                                                          gradient: LinearGradient(
                                                            colors: [
                                                              Color(0xFFB6E0FE),
                                                              Color(0xFF7DD3FC),
                                                            ],
                                                            begin:
                                                                Alignment
                                                                    .topLeft,
                                                            end:
                                                                Alignment
                                                                    .bottomRight,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius.all(
                                                                Radius.circular(
                                                                  14,
                                                                ),
                                                              ),
                                                        ),
                                                        child: const Icon(
                                                          Icons
                                                              .assignment_turned_in_rounded,
                                                          size: 34,
                                                          color: Color(
                                                            0xFF38A3EB,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 18),
                                                      Expanded(
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                vertical: 22,
                                                              ),
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            children: [
                                                              AppText(
                                                                'Assigned MCQ Tests',
                                                                style: GoogleFonts.poppins(
                                                                  fontSize: 19,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Color(
                                                                    0xFF38A3EB,
                                                                  ),
                                                                  letterSpacing:
                                                                      0.1,
                                                                ),
                                                                maxLines: 2,
                                                              ),
                                                              const SizedBox(
                                                                height: 7,
                                                              ),
                                                              AppText(
                                                                'Attempt live or past tests assigned by your professors.',
                                                                style: GoogleFonts.poppins(
                                                                  fontSize:
                                                                      14.5,
                                                                  color:
                                                                      Colors
                                                                          .grey
                                                                          .shade700,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                ),
                                                                maxLines: 2,
                                                              ),
                                                              const SizedBox(
                                                                height: 10,
                                                              ),
                                                              Row(
                                                                children: [
                                                                  const Icon(
                                                                    Icons
                                                                        .play_circle_fill_rounded,
                                                                    color: Color(
                                                                      0xFF38A3EB,
                                                                    ),
                                                                    size: 18,
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 6,
                                                                  ),
                                                                  AppText(
                                                                    'Live & Expired',
                                                                    style: GoogleFonts.poppins(
                                                                      fontSize:
                                                                          13.5,
                                                                      color: Color(
                                                                        0xFF38A3EB,
                                                                      ),
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w500,
                                                                    ),
                                                                    maxLines: 2,
                                                                  ),
                                                                ],
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              right: 18.0,
                                                            ),
                                                        child: Icon(
                                                          Icons
                                                              .arrow_forward_ios_rounded,
                                                          color:
                                                              Colors
                                                                  .grey
                                                                  .shade400,
                                                          size: 22,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        // Engineering subjects section below
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 8,
                                            bottom: 8,
                                          ),
                                          child: AppText(
                                            'Engineering Subjects',
                                            style: GoogleFonts.poppins(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                            maxLines: 2,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          child: AppText(
                                            'Choose your engineering branch to practice MCQ tests',
                                            style: GoogleFonts.poppins(
                                              fontSize: 16,
                                              color: Colors.grey.shade600,
                                            ),
                                            maxLines: 2,
                                          ),
                                        ),
                                        // Content
                                        _error != null
                                            ? _buildErrorState()
                                            : _subjects.isEmpty
                                            ? _buildEmptyState()
                                            : ListView.builder(
                                              shrinkWrap: true,
                                              physics:
                                                  const NeverScrollableScrollPhysics(),
                                              itemCount: _subjects.length,
                                              itemBuilder: (context, index) {
                                                return Padding(
                                                  padding: EdgeInsets.only(
                                                    bottom: isWide ? 10 : 28,
                                                  ),
                                                  child: _buildSubjectCard(
                                                    _subjects[index],
                                                  ),
                                                );
                                              },
                                            ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // Onboarding tooltip overlay
                        if (_showOnboardingTip && _subjects.isNotEmpty)
                          CompositedTransformFollower(
                            link: _tooltipLayerLink,
                            showWhenUnlinked: false,
                            offset: const Offset(-30, 60),
                            child: GestureDetector(
                              onTap: _dismissOnboardingTip,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Gradient arrow
                                  CustomPaint(
                                    size: const Size(28, 14),
                                    painter: _TooltipArrowPainter(
                                      gradient: LinearGradient(
                                        colors: [
                                          _getSubjectColorScheme(
                                            0,
                                          )['gradient'][0],
                                          _getSubjectColorScheme(
                                            0,
                                          )['gradient'][1],
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    constraints: const BoxConstraints(
                                      maxWidth: 260,
                                      minWidth: 180,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          _getSubjectColorScheme(
                                            0,
                                          )['gradient'][0],
                                          _getSubjectColorScheme(
                                            0,
                                          )['gradient'][1],
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _getSubjectColorScheme(
                                            0,
                                          )['gradient'][0].withOpacity(0.18),
                                          blurRadius: 16,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.touch_app_rounded,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                'Customize Colors!',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            GestureDetector(
                                              onTap: _dismissOnboardingTip,
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withOpacity(0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: const Icon(
                                                  Icons.close_rounded,
                                                  size: 16,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Tap any subject icon to change its color',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.white.withOpacity(
                                              0.92,
                                            ),
                                          ),
                                          textAlign: TextAlign.center,
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
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: CustomAppBar(
        title: 'Practice Tests',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBlue),
            )
          else if (_hasNetworkError)
            buildNetworkErrorWidget(
              title: '📡 No Internet Connection',
              message:
                  'Unable to load practice tests. Please connect to the internet and try again.',
              customEmoji: '📝',
              onRetry: _retryWithNetworkCheck,
            )
          else
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isWide ? 40 : 16,
                        vertical: 20,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Assigned MCQ Tests card at the top
                          Card(
                            elevation: 7,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            margin: const EdgeInsets.only(bottom: 36),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) =>
                                            const AssignedTestCardScreen(),
                                  ),
                                );
                              },
                              child: Stack(
                                children: [
                                  // Full-height gradient accent bar
                                  Positioned(
                                    left: 0,
                                    top: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 8,
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Color(0xFFB6E0FE),
                                            Color(0xFF7DD3FC),
                                          ],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        ),
                                        borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(20),
                                          bottomLeft: Radius.circular(20),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Row(
                                      children: [
                                        const SizedBox(width: 18),
                                        // Icon with soft gradient background
                                        Container(
                                          padding: const EdgeInsets.all(18),
                                          decoration: const BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Color(0xFFB6E0FE),
                                                Color(0xFF7DD3FC),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.all(
                                              Radius.circular(14),
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.assignment_turned_in_rounded,
                                            size: 34,
                                            color: Color(0xFF38A3EB),
                                          ),
                                        ),
                                        const SizedBox(width: 18),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 22,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                AppText(
                                                  'Assigned MCQ Tests',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 19,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF38A3EB),
                                                    letterSpacing: 0.1,
                                                  ),
                                                  maxLines: 2,
                                                ),
                                                const SizedBox(height: 7),
                                                AppText(
                                                  'Attempt live or past tests assigned by your professors.',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 14.5,
                                                    color: Colors.grey.shade700,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  maxLines: 2,
                                                ),
                                                const SizedBox(height: 10),
                                                Row(
                                                  children: [
                                                    const Icon(
                                                      Icons
                                                          .play_circle_fill_rounded,
                                                      color: Color(0xFF38A3EB),
                                                      size: 18,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    AppText(
                                                      'Live & Expired',
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontSize: 13.5,
                                                            color: Color(
                                                              0xFF38A3EB,
                                                            ),
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                      maxLines: 2,
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 18.0,
                                          ),
                                          child: Icon(
                                            Icons.arrow_forward_ios_rounded,
                                            color: Colors.grey.shade400,
                                            size: 22,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Engineering subjects section below
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 8),
                            child: AppText(
                              'Engineering Subjects',
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              maxLines: 2,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: AppText(
                              'Choose your engineering branch to practice MCQ tests',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 2,
                            ),
                          ),
                          // Content
                          _error != null
                              ? _buildErrorState()
                              : _subjects.isEmpty
                              ? _buildEmptyState()
                              : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _subjects.length,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      bottom: isWide ? 10 : 28,
                                    ),
                                    child: _buildSubjectCard(_subjects[index]),
                                  );
                                },
                              ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // Onboarding tooltip overlay
          if (_showOnboardingTip && _subjects.isNotEmpty)
            CompositedTransformFollower(
              link: _tooltipLayerLink,
              showWhenUnlinked: false,
              offset: const Offset(-30, 60),
              child: GestureDetector(
                onTap: _dismissOnboardingTip,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Gradient arrow
                    CustomPaint(
                      size: const Size(28, 14),
                      painter: _TooltipArrowPainter(
                        gradient: LinearGradient(
                          colors: [
                            _getSubjectColorScheme(0)['gradient'][0],
                            _getSubjectColorScheme(0)['gradient'][1],
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    Container(
                      constraints: const BoxConstraints(
                        maxWidth: 260,
                        minWidth: 180,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _getSubjectColorScheme(0)['gradient'][0],
                            _getSubjectColorScheme(0)['gradient'][1],
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: _getSubjectColorScheme(
                              0,
                            )['gradient'][0].withOpacity(0.18),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.touch_app_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Customize Colors!',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _dismissOnboardingTip,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap any subject icon to change its color',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.92),
                            ),
                            textAlign: TextAlign.center,
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
    );
  }

  @override
  void dispose() {
    stopScreenMonitoring();
    super.dispose();
  }
}

// Tooltip arrow painter
class _TooltipArrowPainter extends CustomPainter {
  final Gradient gradient;
  _TooltipArrowPainter({required this.gradient});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    paint.shader = gradient.createShader(rect);
    final path =
        Path()
          ..moveTo(0, size.height)
          ..lineTo(size.width / 2, 0)
          ..lineTo(size.width, size.height)
          ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
