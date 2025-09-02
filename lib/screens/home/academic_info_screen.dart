import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import 'Syllabus & Timetable/syllabus_viewer_screen.dart';
import 'Syllabus & Timetable/timetable_viewer_screen.dart';
import '../../services/user_profile_service.dart';
import '../../models/user_profile.dart';
import '../../widgets/custom_app_bar.dart';
import '../../services/network_service.dart';
import 'package:flutter/foundation.dart';
import '../../widgets/desktop_sidebar.dart';
import 'Assignment marks/assignment_subjects_screen.dart';
import 'Midsem marks/midsem_subjects_screen.dart';
import 'subject_feedback/subject_feedback_list_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/skeleton_loading.dart';

class AcademicInfoScreen extends StatefulWidget {
  const AcademicInfoScreen({super.key});

  @override
  State<AcademicInfoScreen> createState() => _AcademicInfoScreenState();
}

class _AcademicInfoScreenState extends State<AcademicInfoScreen>
    with NetworkAwareMixin {
  String? _semesterId;
  bool _hasNetworkError = false;
  bool _isLoading = true;
  final NetworkService _networkService = NetworkService();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
      _hasNetworkError = false;
    });

    // Check network connectivity first
    final networkStatus = await _networkService.isConnected();

    if (!networkStatus) {
      setState(() {
        _hasNetworkError = true;
        _isLoading = false;
      });
      return;
    }

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final userProfile = await UserProfileService.getCurrentUserProfile();
        if (userProfile != null && mounted) {
          // Get semester ID based on user's academic path
          final semesterId = await _getSemesterIdFromProfile(userProfile);
          setState(() {
            _semesterId = semesterId;
            _hasNetworkError = false;
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasNetworkError = true;
          _isLoading = false;
        });
      }
    }
  }

  Future<String?> _getSemesterIdFromProfile(UserProfile profile) async {
    try {
      if (profile.college == null || profile.branch == null || profile.semester == null) {
        return null;
      }

      // First get college ID
      final collegeResponse = await Supabase.instance.client
          .from('colleges')
          .select('id')
          .eq('name', profile.college!)
          .single();

      final collegeId = collegeResponse['id'] as String;

      // Then get branch ID
      final branchResponse = await Supabase.instance.client
          .from('branches')
          .select('id')
          .eq('name', profile.branch!)
          .eq('college_id', collegeId)
          .single();

      final branchId = branchResponse['id'] as String;

      // Finally get semester ID
      final semesterResponse = await Supabase.instance.client
          .from('semesters')
          .select('id')
          .eq('name', profile.semester!)
          .eq('branch_id', branchId)
          .single();

      return semesterResponse['id'] as String?;
    } catch (e) {
      return null;
    }
  }

  Future<void> _retryWithNetworkCheck() async {
    await refreshNetworkStatus();
    final networkStatus = await _networkService.isConnected();

    if (networkStatus) {
      _loadUserProfile();
    } else {
      setState(() {
        _hasNetworkError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;
    final bool isDesktop =
        kIsWeb ||
        Theme.of(context).platform == TargetPlatform.windows ||
        Theme.of(context).platform == TargetPlatform.linux ||
        Theme.of(context).platform == TargetPlatform.macOS;
    if (isDesktop) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Row(
          children: [
            DesktopSidebar(
              selected: 'academic-info',
              onNavigate: (route) => Navigator.pushNamed(context, route),
            ),
            Expanded(
              child:
                  _hasNetworkError
                      ? buildNetworkErrorWidget(
                        title: '📡 No Internet Connection',
                        message:
                            'Unable to load academic information. Please connect to the internet and try again.',
                        customEmoji: '📚',
                        onRetry: _retryWithNetworkCheck,
                      )
                      : Column(
                        children: [
                          CustomAppBar(
                            title: 'Academic Info',
                            subtitle: 'Syllabus and Timetable',
                            leading: IconButton(
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 20,
                              ),
                              onPressed: () => Navigator.of(context).maybePop(),
                            ),
                            actions: [
                              IconButton(
                                icon: const Icon(Icons.refresh_rounded),
                                onPressed: _loadUserProfile,
                              ),
                            ],
                          ),
                          Expanded(
                            child: _isLoading
                                ? Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    children: [
                                      // Academic cards skeleton
                                      Row(
                                        children: [
                                          Expanded(child: SkeletonLoading(width: double.infinity, height: 120)),
                                          SizedBox(width: 16),
                                          Expanded(child: SkeletonLoading(width: double.infinity, height: 120)),
                                        ],
                                      ),
                                      SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Expanded(child: SkeletonLoading(width: double.infinity, height: 120)),
                                          SizedBox(width: 16),
                                          Expanded(child: SkeletonLoading(width: double.infinity, height: 120)),
                                        ],
                                      ),
                                    ],
                                  ),
                                )
                                : SingleChildScrollView(
                                  child: Center(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 1200,
                                      ),
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 32,
                                              vertical: 32,
                                            ),
                                        child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  children: [
                                                  // Remove header and subtitle for Android/iOS
                                                  Container(
                                                    padding:
                                                        EdgeInsets.all(
                                                          isWide ? 40 : 24,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        begin: Alignment.topLeft,
                                                        end: Alignment.bottomRight,
                                                        colors: [
                                                          Colors.white,
                                                          Colors.grey.shade50,
                                                        ],
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            24,
                                                          ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black.withValues(alpha: 0.08),
                                                          blurRadius: 20,
                                                          offset: const Offset(0, 6),
                                                          spreadRadius: 0,
                                                        ),
                                                        BoxShadow(
                                                          color: Colors.black.withValues(alpha: 0.04),
                                                          blurRadius: 8,
                                                          offset: const Offset(0, 3),
                                                          spreadRadius: 0,
                                                        ),
                                                      ],
                                                      border: Border.all(
                                                        color: Colors.grey.shade200,
                                                        width: 0.5,
                                                      ),
                                                    ),
                                                    child:
                                                        isWide
                                                            ? Column(
                                                              children: [
                                                                // First row with Assignment Marks card
                                                                SizedBox(
                                                                  width: double.infinity,
                                                                  child: _AcademicInfoCard(
                                                                    icon:
                                                                        Icons
                                                                            .assignment_turned_in_rounded,
                                                                    title:
                                                                        'Assignment Marks',
                                                                    subtitle:
                                                                        'View your assignment scores',
                                                                    color:
                                                                        AppTheme
                                                                            .assignmentsIcon,
                                                                    onTap: () {
                                                                      Navigator.push(
                                                                        context,
                                                                        MaterialPageRoute(
                                                                          builder:
                                                                              (
                                                                                context,
                                                                              ) => const AssignmentSubjectsScreen(),
                                                                        ),
                                                                      );
                                                                    },
                                                                  ),
                                                                ),
                                                                const SizedBox(height: 24),
                                                                // Midsem Marks
                                                                SizedBox(
                                                                  width: double.infinity,
                                                                  child: _AcademicInfoCard(
                                                                    icon: Icons.quiz_outlined,
                                                                    title: 'Midsem Marks',
                                                                    subtitle: 'View your midsem exam scores',
                                                                    color: AppTheme.secondaryGreen,
                                                                    onTap: () {
                                                                      Navigator.push(
                                                                        context,
                                                                        MaterialPageRoute(
                                                                          builder: (context) => const MidsemSubjectsScreen(),
                                                                        ),
                                                                      );
                                                                    },
                                                                  ),
                                                                ),
                                                                const SizedBox(height: 24),
                                                                // Third row with Class Feedback
                                                                SizedBox(
                                                                  width: double.infinity,
                                                                  child: _AcademicInfoCard(
                                                                    icon: Icons.feedback_rounded,
                                                                    title: 'Class Feedback',
                                                                    subtitle: 'Give feedback for your subjects',
                                                                    color: AppTheme.accentOrange,
                                                                    onTap: () {
                                                                      Navigator.push(
                                                                        context,
                                                                        MaterialPageRoute(
                                                                          builder: (context) => const SubjectFeedbackListScreen(),
                                                                        ),
                                                                      );
                                                                    },
                                                                  ),
                                                                ),
                                                                const SizedBox(height: 24),
                                                                // Third row with Syllabus and Timetable
                                                                Row(
                                                                  children: [
                                                                    Expanded(
                                                                      child: _AcademicInfoCard(
                                                                        icon:
                                                                            Icons
                                                                                .menu_book_rounded,
                                                                        title:
                                                                            'Syllabus',
                                                                        subtitle:
                                                                            'Check your semester syllabus',
                                                                        color:
                                                                            AppTheme
                                                                                .primaryBlue,
                                                                        onTap:
                                                                            _semesterId !=
                                                                                    null
                                                                                ? () {
                                                                                  Navigator.push(
                                                                                    context,
                                                                                    MaterialPageRoute(
                                                                                      builder:
                                                                                          (
                                                                                            context,
                                                                                          ) => SyllabusViewerScreen(
                                                                                            semesterId:
                                                                                                _semesterId!,
                                                                                          ),
                                                                                    ),
                                                                                  );
                                                                                }
                                                                                : () {
                                                                                  ScaffoldMessenger.of(
                                                                                    context,
                                                                                  ).showSnackBar(
                                                                                    const SnackBar(
                                                                                      content: Text(
                                                                                        'Syllabus not available for your academic path yet.',
                                                                                      ),
                                                                                      backgroundColor:
                                                                                          Colors.orange,
                                                                                    ),
                                                                                  );
                                                                                },
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                      width: 24,
                                                                    ),
                                                                    Expanded(
                                                                      child: _AcademicInfoCard(
                                                                        icon:
                                                                            Icons
                                                                                .access_time_rounded,
                                                                        title:
                                                                            'Timetable',
                                                                        subtitle:
                                                                            'View your class schedule',
                                                                        color:
                                                                            AppTheme
                                                                                .primaryLight,
                                                                        onTap:
                                                                            _semesterId !=
                                                                                    null
                                                                                ? () {
                                                                                  Navigator.push(
                                                                                    context,
                                                                                    MaterialPageRoute(
                                                                                      builder:
                                                                                          (
                                                                                            context,
                                                                                          ) => TimetableViewerScreen(
                                                                                            semesterId:
                                                                                                _semesterId!,
                                                                                          ),
                                                                                    ),
                                                                                  );
                                                                                }
                                                                                : () {
                                                                                  ScaffoldMessenger.of(
                                                                                    context,
                                                                                  ).showSnackBar(
                                                                                    const SnackBar(
                                                                                      content: Text(
                                                                                        'Timetable not available for your academic path yet.',
                                                                                      ),
                                                                                    ),
                                                                                  );
                                                                                },
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ],
                                                            )
                                                            : Column(
                                                              children: [
                                                                // Assignment Marks - moved to top for mobile
                                                                _AcademicInfoCard(
                                                                  icon:
                                                                      Icons
                                                                          .assignment_turned_in_rounded,
                                                                  title:
                                                                      'Assignment Marks',
                                                                  subtitle:
                                                                      'View your assignment scores',
                                                                  color:
                                                                      AppTheme
                                                                          .assignmentsIcon,
                                                                  onTap: () {
                                                                    Navigator.push(
                                                                      context,
                                                                      MaterialPageRoute(
                                                                        builder:
                                                                            (
                                                                              context,
                                                                            ) => const AssignmentSubjectsScreen(),
                                                                      ),
                                                                    );
                                                                  },
                                                                ),
                                                                const SizedBox(
                                                                  height: 20,
                                                                ),
                                                                // Midsem Marks
                                                                _AcademicInfoCard(
                                                                  icon: Icons.quiz_outlined,
                                                                  title: 'Midsem Marks',
                                                                  subtitle: 'View your midsem exam scores',
                                                                  color: AppTheme.secondaryGreen,
                                                                  onTap: () {
                                                                    Navigator.push(
                                                                      context,
                                                                      MaterialPageRoute(
                                                                        builder: (context) => const MidsemSubjectsScreen(),
                                                                      ),
                                                                    );
                                                                  },
                                                                ),
                                                                const SizedBox(
                                                                  height: 20,
                                                                ),
                                                                _AcademicInfoCard(
                                                                  icon: Icons.feedback_rounded,
                                                                  title: 'Class Feedback',
                                                                  subtitle: 'Give feedback for your subjects',
                                                                  color: AppTheme.accentOrange,
                                                                  onTap: () {
                                                                    Navigator.push(
                                                                      context,
                                                                      MaterialPageRoute(
                                                                        builder: (context) => const SubjectFeedbackListScreen(),
                                                                      ),
                                                                    );
                                                                  },
                                                                ),
                                                                const SizedBox(
                                                                  height: 20,
                                                                ),
                                                                _AcademicInfoCard(
                                                                  icon:
                                                                      Icons
                                                                          .menu_book_rounded,
                                                                  title:
                                                                      'Syllabus',
                                                                  subtitle:
                                                                      'Check your semester syllabus',
                                                                  color:
                                                                      AppTheme
                                                                          .primaryBlue,
                                                                  onTap:
                                                                      _semesterId !=
                                                                              null
                                                                          ? () {
                                                                            Navigator.push(
                                                                              context,
                                                                              MaterialPageRoute(
                                                                                builder:
                                                                                    (
                                                                                      context,
                                                                                    ) => SyllabusViewerScreen(
                                                                                      semesterId:
                                                                                          _semesterId!,
                                                                                    ),
                                                                              ),
                                                                            );
                                                                          }
                                                                          : () {
                                                                            ScaffoldMessenger.of(
                                                                              context,
                                                                            ).showSnackBar(
                                                                              const SnackBar(
                                                                                content: Text(
                                                                                  'Syllabus not available for your academic path yet.',
                                                                                ),
                                                                                backgroundColor:
                                                                                    Colors.orange,
                                                                              ),
                                                                            );
                                                                          },
                                                                ),
                                                                const SizedBox(
                                                                  height: 20,
                                                                ),
                                                                _AcademicInfoCard(
                                                                  icon:
                                                                      Icons
                                                                          .access_time_rounded,
                                                                  title:
                                                                      'Timetable',
                                                                  subtitle:
                                                                      'View your class schedule',
                                                                  color:
                                                                      AppTheme
                                                                          .accentOrange,
                                                                  onTap:
                                                                      _semesterId !=
                                                                              null
                                                                          ? () {
                                                                            Navigator.push(
                                                                              context,
                                                                              MaterialPageRoute(
                                                                                builder:
                                                                                    (
                                                                                      context,
                                                                                    ) => TimetableViewerScreen(
                                                                                      semesterId:
                                                                                          _semesterId!,
                                                                                    ),
                                                                              ),
                                                                            );
                                                                          }
                                                                          : () {
                                                                            ScaffoldMessenger.of(
                                                                              context,
                                                                            ).showSnackBar(
                                                                              const SnackBar(
                                                                                content: Text(
                                                                                  'Timetable not available for your academic path yet.',
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
                          ),
                        ],
                      ),
            ),
          ],
        ),
      );
    } else {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body:
            _hasNetworkError
                ? buildNetworkErrorWidget(
                  title: '📡 No Internet Connection',
                  message:
                      'Unable to load academic information. Please connect to the internet and try again.',
                  customEmoji: '📚',
                  onRetry: _retryWithNetworkCheck,
                )
                : Column(
                  children: [
                    CustomAppBar(
                      title: 'Academic Info',
                      subtitle: 'Syllabus and Timetable',
                      leading: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 20,
                        ),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded),
                          onPressed: _loadUserProfile,
                        ),
                      ],
                    ),
                    Expanded(
                      child: _isLoading
                          ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                SkeletonLoading(width: double.infinity, height: 100),
                                SizedBox(height: 16),
                                SkeletonLoading(width: double.infinity, height: 100),
                                SizedBox(height: 16),
                                SkeletonLoading(width: double.infinity, height: 100),
                                SizedBox(height: 16),
                                SkeletonLoading(width: double.infinity, height: 100),
                              ],
                            ),
                          )
                          : Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.center,
                              children: [
                              _AcademicInfoCard(
                                icon:
                                    Icons
                                        .menu_book_rounded,
                                title: 'Syllabus',
                                subtitle:
                                    'Check your semester syllabus',
                                color:
                                    AppTheme
                                        .primaryBlue,
                                onTap:
                                    _semesterId != null
                                        ? () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                      builder:
                                                          (
                                                            context,
                                                          ) => SyllabusViewerScreen(
                                                            semesterId:
                                                                _semesterId!,
                                                          ),
                                                    ),
                                                  );
                                                }
                                                : () {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content:
                                                          Text(
                                                            'Syllabus not available for your academic path yet.',
                                                          ),
                                                      backgroundColor:
                                                          Colors.orange,
                                                    ),
                                                  );
                                                },
                                      ),
                                      const SizedBox(
                                        height: 16,
                                      ),
                                      _AcademicInfoCard(
                                        icon:
                                            Icons
                                                .schedule_rounded,
                                        title: 'Timetable',
                                        subtitle:
                                            'View your class schedule',
                                        color: Colors.red,
                                        onTap:
                                            _semesterId != null
                                                ? () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder:
                                                          (
                                                            context,
                                                          ) => TimetableViewerScreen(
                                                            semesterId:
                                                                _semesterId!,
                                                          ),
                                                    ),
                                                  );
                                                }
                                                : () {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content:
                                                          Text(
                                                            'Timetable not available for your academic path yet.',
                                                          ),
                                                      backgroundColor:
                                                          Colors.orange,
                                                    ),
                                                  );
                                                },
                                      ),
                                      const SizedBox(
                                        height: 16,
                                      ),
                                      _AcademicInfoCard(
                                        icon: Icons
                                            .assignment_turned_in_rounded,
                                        title: 'Assignment Marks',
                                        subtitle:
                                            'View your assignment scores',
                                        color: AppTheme.assignmentsIcon,
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const AssignmentSubjectsScreen(),
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(
                                        height: 16,
                                      ),
                                      // Midsem Marks
                                      _AcademicInfoCard(
                                        icon: Icons.quiz_outlined,
                                        title: 'Midsem Marks',
                                        subtitle: 'View your midsem exam scores',
                                        color: AppTheme.secondaryGreen,
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => const MidsemSubjectsScreen(),
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(
                                        height: 16,
                                      ),
                                      _AcademicInfoCard(
                                        icon: Icons.feedback_rounded,
                                        title: 'Class Feedback',
                                        subtitle: 'Give feedback for your subjects',
                                        color: AppTheme.accentOrange,
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => const SubjectFeedbackListScreen(),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                    ),
                  ],
                ),
      );
    }
  }
}

class _AcademicInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;
  const _AcademicInfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      splashColor: color.withValues(alpha: 0.1),
      highlightColor: color.withValues(alpha: 0.05),
      child: Container(
        padding: EdgeInsets.all(isDesktop ? 32 : 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.grey.shade50,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
              spreadRadius: 0,
            ),
          ],
          border: Border.all(
            color: color.withValues(alpha: 0.15), 
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isDesktop ? 20 : 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.15),
                    color.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: color.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Icon(icon, color: color, size: isDesktop ? 36 : 32),
            ),
            SizedBox(width: isDesktop ? 24 : 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: isDesktop ? 20 : 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: isDesktop ? 8 : 6),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: isDesktop ? 15 : 14,
                      color: Colors.grey.shade600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: isDesktop ? 20 : 16),
            Container(
              padding: EdgeInsets.all(isDesktop ? 10 : 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.arrow_forward_ios_rounded, 
                color: color, 
                size: isDesktop ? 20 : 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
