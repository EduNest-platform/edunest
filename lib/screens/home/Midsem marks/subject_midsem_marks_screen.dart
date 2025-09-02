import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';
import '../../../theme/app_theme.dart';
import '../../../models/subject.dart';
import '../../../models/assignment_mark.dart';
import '../../../services/midsem_marks_service.dart';
import '../../../widgets/custom_app_bar.dart';
import '../../../services/network_service.dart';
import '../../../widgets/desktop_sidebar.dart';

class SubjectMidsemMarksScreen extends StatefulWidget {
  final Subject subject;

  const SubjectMidsemMarksScreen({
    super.key,
    required this.subject,
  });

  @override
  State<SubjectMidsemMarksScreen> createState() => _SubjectMidsemMarksScreenState();
}

class _SubjectMidsemMarksScreenState extends State<SubjectMidsemMarksScreen> {
  final NetworkService _networkService = NetworkService();
  bool _isLoading = true;
  bool _hasNetworkError = false;
  List<AssignmentMark> _marks = [];
  Map<String, dynamic> _statistics = {};

  @override
  void initState() {
    super.initState();
    _loadMidsemMarks();
  }

  Future<void> _loadMidsemMarks() async {
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

      // Get midsem marks for this specific subject/class
      final marks = await MidsemMarksService.getSubjectMidsemMarks(widget.subject.id);
      
      // Calculate statistics
      final statistics = _calculateStatistics(marks);

      setState(() {
        _marks = marks;
        _statistics = statistics;
        _isLoading = false;
      });

    } catch (e) {
      if (kDebugMode) {
        print('Error loading midsem marks: $e');
      }
      setState(() {
        _hasNetworkError = true;
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _calculateStatistics(List<AssignmentMark> marks) {
    if (marks.isEmpty) {
      return {
        'totalExams': 0,
        'averageScore': 0.0,
        'highestScore': 0.0,
        'lowestScore': 0.0,
        'totalMarks': 0.0,
        'maxPossibleMarks': 0.0,
      };
    }

    final validMarks = marks.where((mark) => mark.marks != null && mark.marks! > 0).toList();
    
    if (validMarks.isEmpty) {
      return {
        'totalExams': marks.length,
        'averageScore': 0.0,
        'highestScore': 0.0,
        'lowestScore': 0.0,
        'totalMarks': 0.0,
        'maxPossibleMarks': marks.fold(0.0, (sum, mark) => sum + (mark.maxMarks ?? 0)),
      };
    }

    final scores = validMarks.map((mark) => (mark.marks! / mark.maxMarks!) * 100).toList();
    final totalMarks = validMarks.fold(0.0, (sum, mark) => sum + mark.marks!);
    final maxPossibleMarks = validMarks.fold(0.0, (sum, mark) => sum + mark.maxMarks!);

    return {
      'totalExams': marks.length,
      'averageScore': scores.isNotEmpty ? scores.reduce((a, b) => a + b) / scores.length : 0.0,
      'highestScore': scores.isNotEmpty ? scores.reduce((a, b) => a > b ? a : b) : 0.0,
      'lowestScore': scores.isNotEmpty ? scores.reduce((a, b) => a < b ? a : b) : 0.0,
      'totalMarks': totalMarks,
      'maxPossibleMarks': maxPossibleMarks,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 768;
    
    if (isDesktop) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Row(
          children: [
            DesktopSidebar(
              selected: 'midsem_marks',
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
          subtitle: 'Midsem Marks',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadMidsemMarks,
            ),
          ],
        ),
        if (_hasNetworkError)
          Expanded(
            child: _buildErrorState(),
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
                    'Loading midsem marks...',
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

  Widget _buildDesktopLayout() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Statistics Cards
          _buildStatisticsRow(),
          const SizedBox(height: 24),
          // Exams List
          Expanded(
            child: _buildMarksSection(),
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
            // Exams
            _buildMarksSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsRow() {
    final stats = _statistics;
    final totalExams = stats['totalExams'] ?? 0;
    final averageScore = stats['averageScore'] ?? 0.0;
    final totalMarks = stats['totalMarks'] ?? 0.0;
    final maxPossibleMarks = stats['maxPossibleMarks'] ?? 0.0;
    
    return Row(
      children: [
        Expanded(child: _buildStatCard('Total Exams', '$totalExams', Icons.quiz_outlined, AppTheme.primaryBlue)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('Average Score', '${averageScore.toStringAsFixed(1)}%', Icons.analytics_outlined, AppTheme.secondaryGreen)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('Total Marks', '${totalMarks.toStringAsFixed(0)}', Icons.trending_up_rounded, AppTheme.accentOrange)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('Max Marks', '${maxPossibleMarks.toStringAsFixed(0)}', Icons.score_outlined, AppTheme.primaryLight)),
      ],
    );
  }

  Widget _buildStatisticsCards() {
    final stats = _statistics;
    final totalExams = stats['totalExams'] ?? 0;
    final averageScore = stats['averageScore'] ?? 0.0;
    final totalMarks = stats['totalMarks'] ?? 0.0;
    final maxPossibleMarks = stats['maxPossibleMarks'] ?? 0.0;
    
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildStatCard('Total Exams', '$totalExams', Icons.quiz_outlined, AppTheme.primaryBlue)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard('Average Score', '${averageScore.toStringAsFixed(1)}%', Icons.analytics_outlined, AppTheme.secondaryGreen)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildStatCard('Total Marks', '${totalMarks.toStringAsFixed(0)}', Icons.trending_up_rounded, AppTheme.accentOrange)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard('Max Marks', '${maxPossibleMarks.toStringAsFixed(0)}', Icons.score_outlined, AppTheme.primaryLight)),
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
            color: Colors.black.withValues(alpha: 0.05),
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
              color: color.withValues(alpha: 0.1),
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

  Widget _buildMarksSection() {
    if (_marks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
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
                Icons.quiz_outlined,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'No Midsem Results Yet',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your midsem exam results for ${widget.subject.name}\nwill appear here once published.',
                textAlign: TextAlign.center,
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
            color: Colors.black.withValues(alpha: 0.05),
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
              'Midsem Examinations',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          // Group marks by exam name
          ...() {
            final Map<String, List<AssignmentMark>> groupedMarks = {};
            for (final mark in _marks) {
              if (!groupedMarks.containsKey(mark.assignmentName)) {
                groupedMarks[mark.assignmentName] = [];
              }
              groupedMarks[mark.assignmentName]!.add(mark);
            }
            return groupedMarks.entries.map((entry) => 
              Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  bottom: entry.key == groupedMarks.keys.last ? 20 : 12,
                ),
                child: _buildExamCard(entry.key, entry.value),
              ),
            );
          }(),
        ],
      ),
    );
  }

  Widget _buildExamCard(String examName, List<AssignmentMark> examMarks) {
    final mark = examMarks.first; // Should only be one mark per exam per student
    final percentage = mark.marks != null && mark.maxMarks != null && mark.maxMarks! > 0
        ? (mark.marks! / mark.maxMarks!) * 100
        : 0.0;
    final gradeColor = _getGradeColor(percentage);
    final grade = _getGrade(percentage);

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
                  examName,
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
                  color: gradeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: gradeColor.withValues(alpha: 0.3)),
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
                mark.marks != null && mark.maxMarks != null
                    ? 'Marks: ${mark.marks!.toStringAsFixed(1)}/${mark.maxMarks!.toStringAsFixed(0)}'
                    : 'Marks: Not Graded',
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
          if (mark.gradedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Graded on: ${_formatDate(mark.gradedAt!)}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getGradeColor(double percentage) {
    if (percentage >= 90) return Colors.green;
    if (percentage >= 80) return Colors.lightGreen;
    if (percentage >= 70) return Colors.orange;
    if (percentage >= 60) return Colors.deepOrange;
    return Colors.red;
  }

  String _getGrade(double percentage) {
    if (percentage >= 90) return 'A+';
    if (percentage >= 85) return 'A';
    if (percentage >= 80) return 'B+';
    if (percentage >= 75) return 'B';
    if (percentage >= 70) return 'C+';
    if (percentage >= 65) return 'C';
    if (percentage >= 60) return 'D';
    return 'F';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.quiz_outlined,
            size: 80,
            color: AppTheme.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No Midsem Results Yet',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your midsem exam results for ${widget.subject.name}\nwill appear here once published.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadMidsemMarks,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
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
          Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.red.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Connection Error',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please check your internet connection\nand try again.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadMidsemMarks,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
