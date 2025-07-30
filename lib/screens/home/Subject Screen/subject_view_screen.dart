import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../services/user_profile_service.dart';
import '../../../services/subjects_service.dart';
import '../../../models/user_profile.dart';
import '../../../models/subject.dart';
import 'resources_screen.dart';
import '../../../widgets/custom_app_bar.dart';
import '../../../services/network_service.dart';
import '../../../services/error_message_service.dart';
import 'package:flutter/foundation.dart';
import '../../../widgets/desktop_sidebar.dart';

class SubjectViewScreen extends StatefulWidget {
  const SubjectViewScreen({super.key});

  @override
  State<SubjectViewScreen> createState() => _SubjectViewScreenState();
}

class _SubjectViewScreenState extends State<SubjectViewScreen>
    with SingleTickerProviderStateMixin, NetworkAwareMixin {
  UserProfile? _userProfile;
  bool _isLoading = true;
  bool _isGridView = false;
  String _searchQuery = '';
  List<Subject> _allSubjects = [];
  List<Subject> _filteredSubjects = [];
  late AnimationController _refreshController;
  bool _hasNetworkError = false;
  final NetworkService _networkService = NetworkService();
  final ScrollController _scrollController = ScrollController();

  // Color palette for subjects
  final List<Color> _subjectColors = [
    AppTheme.primaryBlue,
    AppTheme.primaryLight,
    Colors.orange,
    Colors.green,
    Colors.purple,
    Colors.teal,
    Colors.indigo,
    Colors.red,
    Colors.pink,
    Colors.amber,
    Colors.cyan,
    Colors.deepPurple,
  ];

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _initializeData();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    // Check network connectivity first
    final networkStatus = await _networkService.isConnected();

    if (!networkStatus) {
      setState(() {
        _hasNetworkError = true;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasNetworkError = false;
    });

    // Load user profile first
    await _loadUserProfile();
    // Then load subjects (which will use the user profile for filtering)
    await _loadSubjects();
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await UserProfileService.getCurrentUserProfile();
      setState(() {
        _userProfile = profile;
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

  Future<void> _loadSubjects() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<Subject> subjects;

      // If user profile is available, filter by college, branch, and semester
      if (_userProfile != null &&
          _userProfile!.college != null &&
          _userProfile!.branch != null &&
          _userProfile!.semester != null) {
        final collegeName = _userProfile!.college!;
        final branchName = _userProfile!.branch!;
        final semesterName = _userProfile!.semester!.toString();

        // Fetch by college and semester first (optimized query)
        subjects = await SubjectsService.getSubjectsByCollegeAndSemester(
          collegeName,
          semesterName,
        );

        // Optimize branch filtering with early return if no subjects
        if (subjects.isNotEmpty) {
          // Now filter by branch (case-insensitive, partial match)
          subjects =
              subjects.where((subject) {
                final subjectBranch =
                    subject.semester?.branch?.name.toLowerCase() ?? '';
                final userBranch = branchName.toLowerCase();
                return subjectBranch.contains(userBranch) ||
                    userBranch.contains(subjectBranch);
              }).toList();
        }

        // Only fallback if we have no subjects and it's worth trying
        if (subjects.isEmpty && _userProfile!.college != null) {
          // Quick fallback to all subjects for college only
          final allSubjects = await SubjectsService.getAllSubjects();
          subjects =
              allSubjects.where((subject) {
                final subjectCollege =
                    subject.semester?.branch?.college?.name.toLowerCase() ?? '';
                final userCollege = collegeName.toLowerCase();
                final subjectBranch =
                    subject.semester?.branch?.name.toLowerCase() ?? '';
                final userBranch = branchName.toLowerCase();
                return (subjectCollege.contains(userCollege) ||
                        userCollege.contains(subjectCollege)) &&
                    (subjectBranch.contains(userBranch) ||
                        userBranch.contains(subjectBranch));
              }).toList();
        }
      } else {
        // Fallback to all subjects if user profile is not available
        subjects = await SubjectsService.getAllSubjects();
      }

      setState(() {
        _allSubjects = subjects;
        _filteredSubjects = subjects;
        _isLoading = false;
        _hasNetworkError = false;
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

  Future<void> _retryWithNetworkCheck() async {
    await refreshNetworkStatus();
    final networkStatus = await _networkService.isConnected();

    if (networkStatus) {
      await _initializeData();
    } else {
      setState(() {
        _hasNetworkError = true;
      });
    }
  }

  void _filterSubjects() {
    setState(() {
      _filteredSubjects =
          _allSubjects.where((subject) {
            final matchesSearch =
                subject.name.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                (subject.code?.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ??
                    false);
            return matchesSearch;
          }).toList();
    });
  }

  Color _getSubjectColor(String subjectId) {
    // Generate a consistent color based on subject ID
    final hash = subjectId.hashCode;
    return _subjectColors[hash.abs() % _subjectColors.length];
  }

  Widget _buildSearchBar() {
    final bool isDesktop =
        kIsWeb ||
        Theme.of(context).platform == TargetPlatform.windows ||
        Theme.of(context).platform == TargetPlatform.linux ||
        Theme.of(context).platform == TargetPlatform.macOS;
    return Container(
      margin:
          isDesktop
              ? const EdgeInsets.symmetric(horizontal: 24, vertical: 8)
              : const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.grey.shade200.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 1),
            spreadRadius: 0,
          ),
        ],
      ),
      child: TextField(
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
          _filterSubjects();
        },
        decoration: InputDecoration(
          hintText: 'Search subjects by name or code...',
          hintStyle: GoogleFonts.poppins(
            color: Colors.grey.shade500,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Colors.grey.shade600,
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildViewToggle() {
    final bool isDesktop =
        kIsWeb ||
        Theme.of(context).platform == TargetPlatform.windows ||
        Theme.of(context).platform == TargetPlatform.linux ||
        Theme.of(context).platform == TargetPlatform.macOS;
    return Container(
      margin:
          isDesktop
              ? const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
              : const EdgeInsets.only(left: 24, right: 24, top: 12, bottom: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${_filteredSubjects.length} subjects found',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildToggleButton(Icons.view_list_rounded, false),
                _buildToggleButton(Icons.grid_view_rounded, true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(IconData icon, bool isGrid) {
    final isSelected = _isGridView == isGrid;

    return GestureDetector(
      onTap: () {
        setState(() {
          _isGridView = isGrid;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade600 : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isSelected ? Colors.white : Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _buildSubjectGrid({bool isWide = false}) {
    int crossAxisCount = 2;
    if (isWide) {
      crossAxisCount = 4;
    } else if (MediaQuery.of(context).size.width > 600) {
      crossAxisCount = 3;
    }
    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: isWide ? 8 : 0),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: isWide ? 1.05 : 0.88, // Less tall cards
        crossAxisSpacing: isWide ? 8 : 6,
        mainAxisSpacing: isWide ? 8 : 6,
      ),
      itemCount: _filteredSubjects.length,
      itemBuilder: (context, index) {
        return _buildSubjectCard(_filteredSubjects[index]);
      },
    );
  }

  Widget _buildSubjectList({bool isWide = false}) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: isWide ? 8 : 0),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredSubjects.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.only(bottom: isWide ? 6 : 4),
          child: _buildSubjectListCard(_filteredSubjects[index]),
        );
      },
    );
  }

  Widget _buildSubjectCard(Subject subject) {
    final color = _getSubjectColor(subject.id);
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResourcesScreen(subject: subject),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.18), // Subtle colored border
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: color.withValues(alpha: 0.03),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon and subject name header
            Builder(
              builder: (context) {
                final bool isDesktop =
                    kIsWeb ||
                    Theme.of(context).platform == TargetPlatform.windows ||
                    Theme.of(context).platform == TargetPlatform.linux ||
                    Theme.of(context).platform == TargetPlatform.macOS;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: color.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: Icon(Icons.book_rounded, color: color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    isDesktop
                        ? Expanded(
                          child: Text(
                            subject.name,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade900,
                              height: 1.4,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                        : Flexible(
                          child: Text(
                            subject.name,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade900,
                              height: 1.4,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            // Subject code badge
            if ((subject.code ?? '').isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: color.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
                child: Text(
                  subject.code!,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            const Spacer(),
            // Footer with semester and resource count
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.file_present_rounded, size: 12, color: color),
                      const SizedBox(width: 4),
                      Text(
                        '${subject.resourceCount}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: color.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    subject.semesterName?.split(' ').first ?? '',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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

  Widget _buildSubjectListCard(Subject subject) {
    // Use the same design as _buildSubjectCard from practice_tests_screen.dart
    // We'll use the subject color logic from this file for now
    final color = _getSubjectColor(subject.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
            color: color.withValues(alpha: 0.03),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          color: color.withValues(alpha: 0.18), // Subtle colored border
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
                builder: (context) => ResourcesScreen(subject: subject),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.book_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subject name
                      Text(
                        subject.name,
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade900,
                          letterSpacing: -0.2,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // Subject code badge
                      if ((subject.code ?? '').isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: color.withValues(alpha: 0.12),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            subject.code!,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: color,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      // Semester info
                      Row(
                        children: [
                          Icon(
                            Icons.school_outlined,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Text(
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
                // Arrow indicator
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: color.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: color,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _refreshData() async {
    await _retryWithNetworkCheck();
  }

  Widget _buildAppBar() {
    return CustomAppBar(
      title: 'My Subjects',
      subtitle: 'Course materials and resources',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      actions: [
        IconButton(
          icon: AnimatedBuilder(
            animation: _refreshController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _refreshController.value * 6.3,
                child: const Icon(Icons.refresh_rounded, size: 18),
              );
            },
          ),
          onPressed: () async {
            if (!_refreshController.isAnimating) {
              _refreshController.forward(from: 0);
            }
            await _refreshData();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Subjects refreshed'),
                  backgroundColor: Colors.green.shade600,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  duration: const Duration(milliseconds: 1500),
                ),
              );
            }
          },
          tooltip: 'Refresh',
        ),
      ],
    );
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
              selected: 'subjects',
              onNavigate: (route) => Navigator.pushNamed(context, route),
            ),
            Expanded(
              child:
                  _hasNetworkError
                      ? buildNetworkErrorWidget(
                        title: '📡 No Internet Connection',
                        message:
                            'Unable to load subjects. Please connect to the internet and try again.',
                        customEmoji: '📚',
                        onRetry: _retryWithNetworkCheck,
                      )
                      : Column(
                        children: [
                          _buildAppBar(),
                          Expanded(
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 1000,
                                ),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isWide ? 40 : 12,
                                    vertical: isWide ? 28 : 12,
                                  ),
                                  child:
                                      _isLoading
                                          ? const Center(
                                            child: CircularProgressIndicator(
                                              color: AppTheme.primaryBlue,
                                            ),
                                          )
                                          : Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              Builder(
                                                builder: (context) {
                                                  final bool isDesktop =
                                                      kIsWeb ||
                                                      Theme.of(
                                                            context,
                                                          ).platform ==
                                                          TargetPlatform
                                                              .windows ||
                                                      Theme.of(
                                                            context,
                                                          ).platform ==
                                                          TargetPlatform
                                                              .linux ||
                                                      Theme.of(
                                                            context,
                                                          ).platform ==
                                                          TargetPlatform.macOS;
                                                  return SizedBox(
                                                    height: isDesktop ? 18 : 0,
                                                  );
                                                },
                                              ),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Expanded(
                                                    flex: isWide ? 2 : 3,
                                                    child: _buildSearchBar(),
                                                  ),
                                                  SizedBox(
                                                    width: isWide ? 24 : 8,
                                                  ),
                                                  Expanded(
                                                    flex: 1,
                                                    child: _buildViewToggle(),
                                                  ),
                                                ],
                                              ),
                                              Builder(
                                                builder: (context) {
                                                  final bool isDesktop =
                                                      kIsWeb ||
                                                      Theme.of(
                                                            context,
                                                          ).platform ==
                                                          TargetPlatform
                                                              .windows ||
                                                      Theme.of(
                                                            context,
                                                          ).platform ==
                                                          TargetPlatform
                                                              .linux ||
                                                      Theme.of(
                                                            context,
                                                          ).platform ==
                                                          TargetPlatform.macOS;
                                                  return SizedBox(
                                                    height: isDesktop ? 18 : 0,
                                                  );
                                                },
                                              ),
                                              Expanded(
                                                child:
                                                    _filteredSubjects.isEmpty
                                                        ? Center(
                                                          child: Container(
                                                            padding:
                                                                EdgeInsets.symmetric(
                                                                  vertical:
                                                                      isWide
                                                                          ? 48
                                                                          : 24,
                                                                  horizontal:
                                                                      isWide
                                                                          ? 48
                                                                          : 16,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color:
                                                                  Colors.white,
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    20,
                                                                  ),
                                                              boxShadow: [
                                                                BoxShadow(
                                                                  color: Colors
                                                                      .black
                                                                      .withValues(
                                                                        alpha:
                                                                            0.04,
                                                                      ),
                                                                  blurRadius:
                                                                      16,
                                                                  offset:
                                                                      const Offset(
                                                                        0,
                                                                        4,
                                                                      ),
                                                                ),
                                                              ],
                                                            ),
                                                            child: Column(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .search_off_rounded,
                                                                  size:
                                                                      isWide
                                                                          ? 64
                                                                          : 48,
                                                                  color:
                                                                      Colors
                                                                          .grey
                                                                          .shade400,
                                                                ),
                                                                const SizedBox(
                                                                  height: 18,
                                                                ),
                                                                Text(
                                                                  'No subjects found',
                                                                  style: GoogleFonts.poppins(
                                                                    fontSize:
                                                                        isWide
                                                                            ? 22
                                                                            : 18,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                    color:
                                                                        Colors
                                                                            .grey
                                                                            .shade700,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  height: 10,
                                                                ),
                                                                Text(
                                                                  'Subjects will appear here once they are\nadded for your college and semester',
                                                                  textAlign:
                                                                      TextAlign
                                                                          .center,
                                                                  style: GoogleFonts.poppins(
                                                                    fontSize:
                                                                        isWide
                                                                            ? 16
                                                                            : 14,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w400,
                                                                    color:
                                                                        Colors
                                                                            .grey
                                                                            .shade600,
                                                                    height: 1.4,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        )
                                                        : Scrollbar(
                                                          controller:
                                                              _scrollController,
                                                          thumbVisibility:
                                                              isWide,
                                                          child: SingleChildScrollView(
                                                            controller:
                                                                _scrollController,
                                                            child: Padding(
                                                              padding:
                                                                  EdgeInsets.only(
                                                                    top:
                                                                        isWide
                                                                            ? 8
                                                                            : 0,
                                                                  ),
                                                              child:
                                                                  _isGridView
                                                                      ? _buildSubjectGrid(
                                                                        isWide:
                                                                            isWide,
                                                                      )
                                                                      : _buildSubjectList(
                                                                        isWide:
                                                                            isWide,
                                                                      ),
                                                            ),
                                                          ),
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
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body:
          _hasNetworkError
              ? buildNetworkErrorWidget(
                title: '📡 No Internet Connection',
                message:
                    'Unable to load subjects. Please connect to the internet and try again.',
                customEmoji: '📚',
                onRetry: _retryWithNetworkCheck,
              )
              : Column(
                children: [
                  _buildAppBar(),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isWide ? 40 : 12,
                            vertical: isWide ? 28 : 12,
                          ),
                          child:
                              _isLoading
                                  ? const Center(
                                    child: CircularProgressIndicator(
                                      color: AppTheme.primaryBlue,
                                    ),
                                  )
                                  : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      const SizedBox(height: 18),
                                      // Search bar and toggle centered for desktop
                                      Builder(
                                        builder: (context) {
                                          final bool isDesktop =
                                              kIsWeb ||
                                              Theme.of(context).platform ==
                                                  TargetPlatform.windows ||
                                              Theme.of(context).platform ==
                                                  TargetPlatform.linux ||
                                              Theme.of(context).platform ==
                                                  TargetPlatform.macOS;
                                          if (isDesktop) {
                                            return Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Expanded(
                                                  flex: isWide ? 2 : 3,
                                                  child: _buildSearchBar(),
                                                ),
                                                SizedBox(
                                                  width: isWide ? 24 : 8,
                                                ),
                                                Expanded(
                                                  flex: 1,
                                                  child: _buildViewToggle(),
                                                ),
                                              ],
                                            );
                                          } else {
                                            return Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                _buildSearchBar(),
                                                const SizedBox(height: 8),
                                                _buildViewToggle(),
                                              ],
                                            );
                                          }
                                        },
                                      ),
                                      const SizedBox(height: 18),
                                      Expanded(
                                        child:
                                            _filteredSubjects.isEmpty
                                                ? Center(
                                                  child: Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          vertical:
                                                              isWide ? 48 : 24,
                                                          horizontal:
                                                              isWide ? 48 : 16,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            20,
                                                          ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black
                                                              .withValues(
                                                                alpha: 0.04,
                                                              ),
                                                          blurRadius: 16,
                                                          offset: const Offset(
                                                            0,
                                                            4,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons
                                                              .search_off_rounded,
                                                          size:
                                                              isWide ? 64 : 48,
                                                          color:
                                                              Colors
                                                                  .grey
                                                                  .shade400,
                                                        ),
                                                        const SizedBox(
                                                          height: 18,
                                                        ),
                                                        Text(
                                                          'No subjects found',
                                                          style:
                                                              GoogleFonts.poppins(
                                                                fontSize:
                                                                    isWide
                                                                        ? 22
                                                                        : 18,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color:
                                                                    Colors
                                                                        .grey
                                                                        .shade700,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          height: 10,
                                                        ),
                                                        Text(
                                                          'Subjects will appear here once they are\nadded for your college and semester',
                                                          textAlign:
                                                              TextAlign.center,
                                                          style:
                                                              GoogleFonts.poppins(
                                                                fontSize:
                                                                    isWide
                                                                        ? 16
                                                                        : 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w400,
                                                                color:
                                                                    Colors
                                                                        .grey
                                                                        .shade600,
                                                                height: 1.4,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                )
                                                : Scrollbar(
                                                  controller: _scrollController,
                                                  thumbVisibility: isWide,
                                                  child: SingleChildScrollView(
                                                    controller:
                                                        _scrollController,
                                                    child: Padding(
                                                      padding: EdgeInsets.only(
                                                        top: isWide ? 8 : 0,
                                                      ),
                                                      child:
                                                          _isGridView
                                                              ? _buildSubjectGrid(
                                                                isWide: isWide,
                                                              )
                                                              : _buildSubjectList(
                                                                isWide: isWide,
                                                              ),
                                                    ),
                                                  ),
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
}
