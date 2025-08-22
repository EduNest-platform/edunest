import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';
import '../../../theme/app_theme.dart';
import '../../../models/subject.dart';
import '../../../models/assignment_mark.dart';
import '../../../services/assignment_marks_service.dart';
import '../../../widgets/custom_app_bar.dart';
import '../../../services/network_service.dart';
import '../../../widgets/desktop_sidebar.dart';

class SubjectAssignmentMarksScreen extends StatefulWidget {
  final Subject subject;

  const SubjectAssignmentMarksScreen({
    super.key,
    required this.subject,
  });

  @override
  State<SubjectAssignmentMarksScreen> createState() => _SubjectAssignmentMarksScreenState();
}

class _SubjectAssignmentMarksScreenState extends State<SubjectAssignmentMarksScreen> {
  final NetworkService _networkService = NetworkService();
  bool _isLoading = true;
  bool _hasNetworkError = false;
  List<AssignmentMark> _marks = [];
  Map<String, dynamic> _statistics = {};

  @override
  void initState() {
    super.initState();
    _loadAssignmentMarks();
  }

  Future<void> _loadAssignmentMarks() async {
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

      // Get marks for this subject/class
      final marks = await AssignmentMarksService.getAssignmentMarksByClass(widget.subject.id);
      
      // Calculate statistics
      final statistics = await AssignmentMarksService.getAssignmentStatistics();

      if (mounted) {
        setState(() {
          _marks = marks;
          _statistics = statistics;
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
    final isWide = MediaQuery.of(context).size.width > 800;

    return Column(
      children: [
        CustomAppBar(
          title: widget.subject.name,
          subtitle: 'Assignment Marks',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadAssignmentMarks,
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
                    'Loading assignment marks...',
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
            child: isWide ? _buildDesktopLayout() : _buildMobileLayout(),
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
            onPressed: _loadAssignmentMarks,
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

  Widget _buildDesktopLayout() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Statistics Cards
          _buildStatisticsRow(),
          const SizedBox(height: 24),
          // Assignments List
          Expanded(
            child: _buildAssignmentsList(true),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Statistics
            _buildStatisticsCards(),
            const SizedBox(height: 20),
            // Assignments
            _buildMobileAssignmentsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileAssignmentsList() {
    if (_marks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.assignment_outlined,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'No Assignments Found',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No assignments found for ${widget.subject.name}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Assignments',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          // Use Column with separate cards instead of ListView for mobile
          ...List.generate(
            _marks.length,
            (index) => Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: index == _marks.length - 1 ? 20 : 12,
              ),
              child: _buildAssignmentCard(_marks[index], false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsRow() {
    return Row(
      children: [
        Expanded(child: _buildStatCard('Total Assignments', '${_marks.length}', Icons.assignment_outlined, AppTheme.primaryBlue)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('Average Score', '${(_statistics['averagePercentage'] ?? 0.0).toStringAsFixed(1)}%', Icons.analytics_outlined, AppTheme.secondaryGreen)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('Total Marks', '${(_statistics['totalMarksObtained'] ?? 0.0).toStringAsFixed(0)}', Icons.trending_up_rounded, AppTheme.accentOrange)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('Max Marks', '${(_statistics['totalMaxMarks'] ?? 0.0).toStringAsFixed(0)}', Icons.score_outlined, AppTheme.primaryLight)),
      ],
    );
  }

  Widget _buildStatisticsCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildStatCard('Total Assignments', '${_marks.length}', Icons.assignment_outlined, AppTheme.primaryBlue)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard('Average Score', '${(_statistics['averagePercentage'] ?? 0.0).toStringAsFixed(1)}%', Icons.analytics_outlined, AppTheme.secondaryGreen)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildStatCard('Total Marks', '${(_statistics['totalMarksObtained'] ?? 0.0).toStringAsFixed(0)}', Icons.trending_up_rounded, AppTheme.accentOrange)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard('Max Marks', '${(_statistics['totalMaxMarks'] ?? 0.0).toStringAsFixed(0)}', Icons.score_outlined, AppTheme.primaryLight)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentsList(bool isDesktop) {
    if (_marks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.assignment_outlined,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'No Assignments Found',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No assignments found for ${widget.subject.name}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // Add this to prevent expansion
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Assignments',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          // Use Flexible instead of Expanded for mobile, keep Expanded for desktop
          if (isDesktop)
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                itemCount: _marks.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final mark = _marks[index];
                  return _buildAssignmentCard(mark, isDesktop);
                },
              ),
            )
          else
            // For mobile, use a constrained container instead of Expanded
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6, // Limit height
              ),
              child: ListView.separated(
                shrinkWrap: true, // Important: let ListView size itself
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                itemCount: _marks.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final mark = _marks[index];
                  return _buildAssignmentCard(mark, isDesktop);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAssignmentCard(AssignmentMark mark, bool isDesktop) {
    final percentage = mark.percentage;
    final grade = mark.grade;
    final gradeColorString = mark.gradeColor;
    final gradeColor = Color(int.parse(gradeColorString.substring(1), radix: 16) + 0xFF000000);

    if (isDesktop) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.assignment_outlined,
                color: AppTheme.primaryBlue,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mark.assignmentName,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${mark.marks.toStringAsFixed(1)}/${mark.maxMarks.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: gradeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: gradeColor.withOpacity(0.3)),
              ),
              child: Text(
                grade,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: gradeColor,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    mark.assignmentName,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: gradeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: gradeColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    grade,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: gradeColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Marks: ${mark.marks.toStringAsFixed(1)}/${mark.maxMarks.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: gradeColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
  }
}
