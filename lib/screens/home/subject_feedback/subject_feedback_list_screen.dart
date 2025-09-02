import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/custom_app_bar.dart';
import '../../../services/subjects_service.dart';
import '../../../services/user_profile_service.dart';
import '../../../models/user_profile.dart';
import '../../../models/subject.dart';
import 'feedback_form_screen.dart';

class SubjectFeedbackListScreen extends StatefulWidget {
  const SubjectFeedbackListScreen({super.key});

  @override
  State<SubjectFeedbackListScreen> createState() => _SubjectFeedbackListScreenState();
}

class _SubjectFeedbackListScreenState extends State<SubjectFeedbackListScreen> {
  List<Subject> _subjects = [];
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  UserProfile? _userProfile;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Get user profile first
      _userProfile = await UserProfileService.getCurrentUserProfile();
      
      if (_userProfile == null || 
          _userProfile!.college == null || 
          _userProfile!.branch == null || 
          _userProfile!.semester == null) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Please complete your profile setup first';
          _isLoading = false;
        });
        return;
      }

      // Get subjects for user's college and semester
      final subjects = await SubjectsService.getSubjectsByCollegeAndSemester(
        _userProfile!.college!,
        _userProfile!.semester!,
      );

      // Filter by branch
      final filteredSubjects = subjects.where((subject) {
        final subjectBranch = subject.semester?.branch?.name.toLowerCase() ?? '';
        final userBranch = _userProfile!.branch!.toLowerCase();
        return subjectBranch.contains(userBranch) || userBranch.contains(subjectBranch);
      }).toList();

      setState(() {
        _subjects = filteredSubjects;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to load subjects: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          CustomAppBar(
            title: 'Class Feedback',
            subtitle: 'Select a subject to give feedback',
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _loadSubjects,
              ),
            ],
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _hasError
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              size: isDesktop ? 80 : 64,
                              color: Colors.grey.shade400,
                            ),
                            SizedBox(height: isDesktop ? 24 : 16),
                            Text(
                              'Something went wrong',
                              style: GoogleFonts.poppins(
                                fontSize: isDesktop ? 22 : 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            SizedBox(height: isDesktop ? 12 : 8),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isDesktop ? 40 : 24,
                              ),
                              child: Text(
                                _errorMessage ?? 'Unknown error occurred',
                                style: GoogleFonts.poppins(
                                  fontSize: isDesktop ? 16 : 14,
                                  color: Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            SizedBox(height: isDesktop ? 32 : 24),
                            ElevatedButton(
                              onPressed: _loadSubjects,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryBlue,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  horizontal: isDesktop ? 32 : 24,
                                  vertical: isDesktop ? 16 : 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(isDesktop ? 12 : 8),
                                ),
                              ),
                              child: Text(
                                'Retry',
                                style: GoogleFonts.poppins(
                                  fontSize: isDesktop ? 16 : 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : _subjects.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.school_outlined,
                                  size: isDesktop ? 80 : 64,
                                  color: Colors.grey.shade400,
                                ),
                                SizedBox(height: isDesktop ? 24 : 16),
                                Text(
                                  'No subjects found',
                                  style: GoogleFonts.poppins(
                                    fontSize: isDesktop ? 22 : 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                SizedBox(height: isDesktop ? 12 : 8),
                                Text(
                                  'No subjects available for feedback',
                                  style: GoogleFonts.poppins(
                                    fontSize: isDesktop ? 16 : 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: isDesktop ? 1000 : double.infinity,
                              ),
                              child: isDesktop
                                  ? _buildDesktopGrid()
                                  : _buildMobileList(),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(32),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
        childAspectRatio: 2.5,
      ),
      itemCount: _subjects.length,
      itemBuilder: (context, index) {
        final subject = _subjects[index];
        return _buildSubjectCard(subject);
      },
    );
  }

  Widget _buildMobileList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _subjects.length,
      itemBuilder: (context, index) {
        final subject = _subjects[index];
        return _buildSubjectCard(subject);
      },
    );
  }

  Widget _buildSubjectCard(Subject subject) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    
    // Define a list of color combinations arranged to avoid similar colors nearby
    // Order: Green -> Red -> Blue -> Orange -> Purple -> Cyan -> Pink -> Lime -> Indigo -> Teal
    final List<Map<String, Color>> colorSchemes = [
      {
        'primary': const Color(0xFFEC4899), // Pink - 7th
        'secondary': const Color(0xFFFDF2F8),
        'accent': const Color(0xFFDB2777),
      },
      
      {
        'primary': const Color(0xFF10B981), // Emerald (Green) - 1st
        'secondary': const Color(0xFFECFDF5),
        'accent': const Color(0xFF059669),
      },
      
      {
        'primary': const Color(0xFF3B82F6), // Blue - 3rd
        'secondary': const Color(0xFFEFF6FF),
        'accent': const Color(0xFF2563EB),
      },
      {
        'primary': const Color(0xFFF59E0B), // Amber (Orange) - 4th
        'secondary': const Color(0xFFFEFBF2),
        'accent': const Color(0xFFD97706),
      },
      {
        'primary': const Color(0xFF8B5CF6), // Violet (Purple) - 5th
        'secondary': const Color(0xFFF5F3FF),
        'accent': const Color(0xFF7C3AED),
      },
      {
        'primary': const Color(0xFF06B6D4), // Cyan - 6th
        'secondary': const Color(0xFFECFEFF),
        'accent': const Color(0xFF0891B2),
      },
      {
        'primary': const Color(0xFFEF4444), // Red - 2nd
        'secondary': const Color(0xFFFEF2F2),
        'accent': const Color(0xFFDC2626),
      },
      {
        'primary': const Color(0xFF84CC16), // Lime (Bright Green) - 8th
        'secondary': const Color(0xFFF7FEE7),
        'accent': const Color(0xFF65A30D),
      },
      {
        'primary': const Color(0xFF6366F1), // Indigo (Deep Blue) - 9th
        'secondary': const Color(0xFFEEF2FF),
        'accent': const Color(0xFF4F46E5),
      },
      {
        'primary': const Color(0xFF14B8A6), // Teal (Blue-Green) - 10th
        'secondary': const Color(0xFFF0FDFA),
        'accent': const Color(0xFF0D9488),
      },
    ];
    
    // Use subject index to ensure consistent and distinct color assignment
    final subjectIndex = _subjects.indexOf(subject);
    final colorIndex = subjectIndex % colorSchemes.length;
    final colorScheme = colorSchemes[colorIndex];
    
    return Container(
      margin: EdgeInsets.only(bottom: isDesktop ? 0 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            colorScheme['secondary']!.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
        boxShadow: [
          BoxShadow(
            color: colorScheme['primary']!.withValues(alpha: 0.12),
            blurRadius: isDesktop ? 20 : 16,
            offset: const Offset(0, 6),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          color: colorScheme['primary']!.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
          splashColor: colorScheme['primary']!.withValues(alpha: 0.06),
          highlightColor: colorScheme['primary']!.withValues(alpha: 0.03),
          hoverColor: colorScheme['primary']!.withValues(alpha: 0.02),
          onTap: () => _navigateToFeedbackForm(subject),
          child: Padding(
            padding: EdgeInsets.all(isDesktop ? 24 : 20),
            child: Row(
              children: [
                Container(
                  width: isDesktop ? 56 : 48,
                  height: isDesktop ? 56 : 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colorScheme['primary']!.withValues(alpha: 0.15),
                        colorScheme['primary']!.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
                    border: Border.all(
                      color: colorScheme['primary']!.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    _getSubjectIcon(subject.name),
                    color: colorScheme['accent']!,
                    size: isDesktop ? 28 : 24,
                  ),
                ),
                SizedBox(width: isDesktop ? 20 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        subject.name,
                        style: GoogleFonts.poppins(
                          fontSize: isDesktop ? 18 : 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subject.code != null) ...[
                        SizedBox(height: isDesktop ? 6 : 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                colorScheme['primary']!.withValues(alpha: 0.12),
                                colorScheme['primary']!.withValues(alpha: 0.08),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colorScheme['primary']!.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            subject.code!,
                            style: GoogleFonts.poppins(
                              fontSize: isDesktop ? 12 : 11,
                              fontWeight: FontWeight.w600,
                              color: colorScheme['accent']!,
                            ),
                          ),
                        ),
                      ],
                      if (subject.description != null && isDesktop) ...[
                        const SizedBox(height: 8),
                        Text(
                          subject.description!,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: isDesktop ? 16 : 12),
                Container(
                  padding: EdgeInsets.all(isDesktop ? 12 : 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colorScheme['primary']!.withValues(alpha: 0.12),
                        colorScheme['primary']!.withValues(alpha: 0.06),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(isDesktop ? 14 : 12),
                    border: Border.all(
                      color: colorScheme['primary']!.withValues(alpha: 0.18),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.feedback_rounded,
                    color: colorScheme['accent']!,
                    size: isDesktop ? 20 : 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to get appropriate icon for different subjects
  IconData _getSubjectIcon(String subjectName) {
    final name = subjectName.toLowerCase();
    
    if (name.contains('math') || name.contains('calculus') || name.contains('algebra')) {
      return Icons.calculate_rounded;
    } else if (name.contains('physics') || name.contains('science')) {
      return Icons.science_rounded;
    } else if (name.contains('chemistry')) {
      return Icons.biotech_rounded;
    } else if (name.contains('computer') || name.contains('programming') || name.contains('software')) {
      return Icons.computer_rounded;
    } else if (name.contains('english') || name.contains('literature') || name.contains('language')) {
      return Icons.menu_book_rounded;
    } else if (name.contains('history') || name.contains('social')) {
      return Icons.history_edu_rounded;
    } else if (name.contains('economics') || name.contains('business') || name.contains('management')) {
      return Icons.business_rounded;
    } else if (name.contains('art') || name.contains('design')) {
      return Icons.palette_rounded;
    } else if (name.contains('music')) {
      return Icons.music_note_rounded;
    } else if (name.contains('research') || name.contains('operational')) {
      return Icons.analytics_rounded;
    } else {
      return Icons.school_rounded;
    }
  }

  void _navigateToFeedbackForm(Subject subject) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FeedbackFormScreen(
          subject: subject,
          userProfile: _userProfile!,
        ),
      ),
    );
  }
}
