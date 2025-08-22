import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../services/assignment_marks_service.dart';
import '../../../models/subject.dart';
import '../../../widgets/custom_app_bar.dart';
import '../../../services/network_service.dart';
import 'package:flutter/foundation.dart';
import '../../../widgets/desktop_sidebar.dart';
import 'subject_assignment_marks_screen.dart';

class AssignmentSubjectsScreen extends StatefulWidget {
  const AssignmentSubjectsScreen({super.key});

  @override
  State<AssignmentSubjectsScreen> createState() => _AssignmentSubjectsScreenState();
}

class _AssignmentSubjectsScreenState extends State<AssignmentSubjectsScreen>
    with SingleTickerProviderStateMixin {
  final NetworkService _networkService = NetworkService();
  bool _isLoading = true;
  bool _hasNetworkError = false;
  List<Subject> _subjects = [];
  Map<String, int> _assignmentCounts = {};

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    setState(() {
      _isLoading = true;
      _hasNetworkError = false;
    });

    try {
      final networkStatus = await _networkService.isConnected();
      if (!networkStatus) {
        setState(() {
          _hasNetworkError = true;
          _isLoading = false;
        });
        return;
      }

      // Get all class IDs that have assignment marks for the user
      final assignmentMarksByClass = await AssignmentMarksService.getAllAssignmentMarks();
      final classIds = assignmentMarksByClass.keys.toList();
      
      if (classIds.isEmpty) {
        setState(() {
          _subjects = [];
          _assignmentCounts = {};
          _isLoading = false;
          _hasNetworkError = false;
        });
        return;
      }

      // Get class and subject information
      final classSubjectInfo = await AssignmentMarksService.getClassSubjectInfo(classIds);
      
      final subjects = <Subject>[];
      final assignmentCounts = <String, int>{};
      
      for (final classId in classIds) {
        final info = classSubjectInfo[classId];
        if (info != null) {
          // Create a Subject object from the class info
          subjects.add(Subject(
            id: classId,
            name: info['subject_name'],
            code: info['subject_code'],
            semesterId: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ));
          assignmentCounts[classId] = assignmentMarksByClass[classId]?.length ?? 0;
        } else {
          // Fallback if no info found
          subjects.add(Subject(
            id: classId,
            name: 'Unknown Subject',
            code: '',
            semesterId: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ));
          assignmentCounts[classId] = assignmentMarksByClass[classId]?.length ?? 0;
        }
      }

      if (mounted) {
        setState(() {
          _subjects = subjects;
          _assignmentCounts = assignmentCounts;
          _isLoading = false;
          _hasNetworkError = false;
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

  @override
  Widget build(BuildContext context) {
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
              selected: 'assignment-marks',
              onNavigate: (route) => Navigator.pushNamed(context, route),
            ),
            Expanded(child: _buildContent()),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        CustomAppBar(
          title: 'Assignment Marks',
          subtitle: 'Select a subject to view assignments',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadSubjects,
            ),
          ],
        ),
        if (_hasNetworkError)
          Expanded(
            child: _buildErrorWidget(),
          )
        else if (_isLoading)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Loading subjects...',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: _buildSubjectsList(),
          ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off_rounded,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Internet Connection',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please check your connection and try again',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadSubjects,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectsList() {
    if (_subjects.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No Subjects Found',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No assignments found for your current college, branch, and semester',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Please check your profile settings or contact your instructor',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 800;

    if (isWide) {
      // Responsive grid based on screen width
      int crossAxisCount = 2;
      if (screenWidth > 1200) {
        crossAxisCount = 4;
      } else if (screenWidth > 1000) {
        crossAxisCount = 3;
      }
      
      return GridView.builder(
        padding: const EdgeInsets.all(24),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 24,
          mainAxisSpacing: 24,
          childAspectRatio: 1.1, // Slightly taller for better content fit
        ),
        itemCount: _subjects.length,
        itemBuilder: (context, index) {
          final subject = _subjects[index];
          return _buildSubjectCard(subject, isWide);
        },
      );
    } else {
      return ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _subjects.length,
        itemBuilder: (context, index) {
          final subject = _subjects[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: _buildSubjectCard(subject, isWide),
          );
        },
      );
    }
  }

  Widget _buildSubjectCard(Subject subject, bool isWide) {
    final assignmentCount = _assignmentCounts[subject.id] ?? 0;
    
    return Container(
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
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          color: Colors.grey.shade200,
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          splashColor: AppTheme.primaryBlue.withOpacity(0.1),
          highlightColor: AppTheme.primaryBlue.withOpacity(0.05),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SubjectAssignmentMarksScreen(
                  subject: subject,
                ),
              ),
            );
          },
          child: Padding(
            padding: EdgeInsets.all(isWide ? 24 : 20),
            child: isWide 
                ? _buildDesktopSubjectCard(subject, assignmentCount)
                : _buildMobileSubjectCard(subject, assignmentCount),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopSubjectCard(Subject subject, int assignmentCount) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min, // Important: don't expand to fill all space
      children: [
        // Enhanced icon with gradient background
        Container(
          padding: const EdgeInsets.all(16), // Reduced from 20
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryBlue.withOpacity(0.15),
                AppTheme.primaryBlue.withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(20), // Reduced from 24
            border: Border.all(
              color: AppTheme.primaryBlue.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Icon(
            Icons.auto_stories_rounded,
            size: 32, // Reduced from 36
            color: AppTheme.primaryBlue,
          ),
        ),
        const SizedBox(height: 14), // Reduced from 20
        
        // Subject name with better typography
        Flexible( // Wrap with Flexible to prevent overflow
          child: Text(
            subject.name,
            style: GoogleFonts.poppins(
              fontSize: 16, // Reduced from 18
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 6), // Reduced from 8
        
        // Subject code with styling
        if (subject.code != null && subject.code!.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), // Reduced padding
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6), // Reduced from 8
              border: Border.all(
                color: Colors.grey.shade300,
                width: 0.5,
              ),
            ),
            child: Text(
              subject.code!,
              style: GoogleFonts.poppins(
                fontSize: 11, // Reduced from 12
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 12), // Reduced from 16
        ] else ...[
          const SizedBox(height: 8), // Reduced from 12
        ],
        
        // Assignment count with enhanced styling
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // Reduced padding
          decoration: BoxDecoration(
            gradient: assignmentCount > 0 
                ? LinearGradient(
                    colors: [
                      AppTheme.assignmentsTagBg,
                      AppTheme.assignmentsTagBg.withOpacity(0.8),
                    ],
                  )
                : LinearGradient(
                    colors: [
                      Colors.grey.shade100,
                      Colors.grey.shade50,
                    ],
                  ),
            borderRadius: BorderRadius.circular(20), // Reduced from 24
            boxShadow: assignmentCount > 0 ? [
              BoxShadow(
                color: AppTheme.assignmentsTagBg.withOpacity(0.2), // Reduced opacity
                blurRadius: 6, // Reduced from 8
                offset: const Offset(0, 2),
              ),
            ] : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.assignment_rounded,
                size: 14, // Reduced from 16
                color: assignmentCount > 0 
                    ? AppTheme.assignmentsTagText
                    : Colors.grey.shade600,
              ),
              const SizedBox(width: 4), // Reduced from 6
              Text(
                '$assignmentCount assignment${assignmentCount != 1 ? 's' : ''}',
                style: GoogleFonts.poppins(
                  fontSize: 12, // Reduced from 13
                  fontWeight: FontWeight.w600,
                  color: assignmentCount > 0 
                      ? AppTheme.assignmentsTagText
                      : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12), // Reduced from 16
        
        // Action indicator with animation hint
        Container(
          padding: const EdgeInsets.all(6), // Reduced from 8
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10), // Reduced from 12
          ),
          child: Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16, // Reduced from 18
            color: AppTheme.primaryBlue,
          ),
        ),
      ],
    );
  }

  Widget _buildMobileSubjectCard(Subject subject, int assignmentCount) {
    return Row(
      children: [
        // Enhanced icon container
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryBlue.withOpacity(0.15),
                AppTheme.primaryBlue.withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.primaryBlue.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Icon(
            Icons.auto_stories_rounded,
            size: 28,
            color: AppTheme.primaryBlue,
          ),
        ),
        const SizedBox(width: 18),
        
        // Content section
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Subject name
              Text(
                subject.name,
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              // Subject code
              if (subject.code != null && subject.code!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    subject.code!,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 8),
              
              // Assignment count with icon
              Row(
                children: [
                  Icon(
                    Icons.assignment_rounded,
                    size: 14,
                    color: assignmentCount > 0 
                        ? AppTheme.assignmentsTagText
                        : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$assignmentCount assignment${assignmentCount != 1 ? 's' : ''}',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: assignmentCount > 0 
                          ? AppTheme.assignmentsTagText
                          : Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(width: 12),
        
        // Action indicator
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: AppTheme.primaryBlue,
          ),
        ),
      ],
    );
  }
}
