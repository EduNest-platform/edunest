import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';
import '../../services/test_results_service.dart';
import '../../services/network_service.dart';
import 'package:intl/intl.dart';
import '../../widgets/app_text.dart';
import '../../services/error_message_service.dart';
import 'package:flutter/foundation.dart';
import '../../widgets/desktop_sidebar.dart';

class TestResultsListScreen extends StatefulWidget {
  const TestResultsListScreen({super.key});

  @override
  State<TestResultsListScreen> createState() => _TestResultsListScreenState();
}

class _TestResultsListScreenState extends State<TestResultsListScreen> {
  List<Map<String, dynamic>> _testResults = [];
  Map<String, List<Map<String, dynamic>>> _groupedResults = {};
  bool _isLoading = true;
  bool _initialLoading = true;
  String? _error;
  bool _hasNetworkError = false;
  final NetworkService _networkService = NetworkService();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadTestResults();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTestResults() async {
    // Check network connectivity first
    final networkStatus = await _networkService.isConnected();

    if (!networkStatus) {
      setState(() {
        _hasNetworkError = true;
        _isLoading = false;
        _initialLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _initialLoading = false;
      _error = null;
      _hasNetworkError = false;
    });

    try {
      final results = await TestResultsService.getUserTestResults();
      results.sort((a, b) {
        final aDate =
            a['completedAt'] != null && a['completedAt'].toString().isNotEmpty
                ? DateTime.parse(a['completedAt'])
                : DateTime(2000);
        final bDate =
            b['completedAt'] != null && b['completedAt'].toString().isNotEmpty
                ? DateTime.parse(b['completedAt'])
                : DateTime(2000);
        return bDate.compareTo(aDate);
      });
      setState(() {
        _testResults = results;
        _groupedResults = _groupResultsByDate(results);
        _isLoading = false;
      });
    } catch (e) {
      final message = ErrorMessageService.getFriendlyMessage(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
      setState(() {
        _error = 'Failed to load test results: $e';
        _isLoading = false;
        _hasNetworkError = true;
      });
    }
  }

  Future<void> _retryWithNetworkCheck() async {
    setState(() {
      _initialLoading = true;
      _hasNetworkError = false;
    });

    final networkStatus = await _networkService.isConnected();

    if (networkStatus) {
      await _loadTestResults();
    } else {
      setState(() {
        _hasNetworkError = true;
        _initialLoading = false;
      });
    }
  }

  Color _getScoreColor(int score) {
    if (score > 60) return AppTheme.success;
    if (score >= 40) return AppTheme.warning;
    return AppTheme.error;
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return AppTheme.success;
      case 'medium':
        return AppTheme.warning;
      case 'hard':
        return AppTheme.error;
      default:
        return AppTheme.primaryBlue;
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupResultsByDate(
    List<Map<String, dynamic>> results,
  ) {
    final now = DateTime.now();
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final result in results) {
      final createdAt = result['created_at'];
      if (createdAt == null || createdAt.toString().isEmpty) {
        grouped['Unknown'] = [...(grouped['Unknown'] ?? []), result];
        continue;
      }
      final date = DateTime.parse(createdAt);
      final diff = now.difference(date);
      String key;
      if (diff.inDays == 0 && now.day == date.day) {
        key = 'Today';
      } else if (diff.inDays == 1 ||
          (diff.inDays == 0 && now.day != date.day)) {
        key = 'Yesterday';
      } else if (diff.inDays < 7) {
        key = 'This Week';
      } else {
        key = DateFormat('MMMM yyyy').format(date);
      }
      grouped[key] = [...(grouped[key] ?? []), result];
    }
    return grouped;
  }

  Widget _buildTestResultCard(Map<String, dynamic> result) {
    final score = result['score'] ?? 0;
    final testTitle = result['test_title'] ?? '';
    final subjectName = result['subject_name'] ?? '';
    final chapterName = result['chapter_name'] ?? '';
    final difficulty = result['difficulty'] ?? 'unknown';
    final createdAt = result['created_at'] ?? '';
    final timeTaken = result['timeTaken'] ?? 0;
    final correct = result['correct_answers'] ?? result['correctAnswers'] ?? 0;
    final total = result['total_questions'] ?? result['totalQuestions'] ?? 0;
    final date =
        (createdAt != null && createdAt.toString().isNotEmpty)
            ? DateFormat('MMM dd, yyyy').format(DateTime.parse(createdAt))
            : 'Unknown';

    // Title/subtitle logic
    String mainTitle = '';
    String? subTitle;
    if (testTitle.toString().trim().isNotEmpty &&
        testTitle.toString().toLowerCase() != 'unknown') {
      mainTitle = testTitle;
      if (subjectName.toString().trim().isNotEmpty &&
          subjectName.toLowerCase() != 'unknown') {
        subTitle = subjectName;
      } else {
        subTitle = null;
      }
    } else {
      mainTitle = subjectName;
      if (chapterName.toString().trim().isNotEmpty &&
          chapterName.toLowerCase() != 'unknown') {
        subTitle = chapterName;
      } else {
        subTitle = null;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: _getScoreColor(score).withValues(alpha: 0.13),
          width: 1.1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Score Circle
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    _getScoreColor(score),
                    _getScoreColor(score).withValues(alpha: 0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _getScoreColor(score).withValues(alpha: 0.13),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '$score%',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    mainTitle,
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                  ),
                  if (subTitle != null && subTitle.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0, bottom: 4.0),
                      child: AppText(
                        subTitle,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                      ),
                    ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        if (difficulty.toLowerCase() != 'not_assigned' &&
                            difficulty.toLowerCase() != 'unknown' &&
                            difficulty.trim().isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _getDifficultyColor(
                                difficulty,
                              ).withValues(alpha: 0.13),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.bolt_rounded,
                                  size: 14,
                                  color: _getDifficultyColor(difficulty),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  difficulty.toUpperCase(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _getDifficultyColor(difficulty),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 7),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.timer_rounded,
                                size: 13,
                                color: AppTheme.primaryBlue,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${(timeTaken / 60).round()}m',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryBlue,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 13,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                date,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: AppTheme.success,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$correct/$total Correct',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.success,
                          fontSize: 13,
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryBlue.withValues(alpha: 0.13),
                  Colors.white,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(
              Icons.history_rounded,
              size: 64,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'No Test Results',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Complete your first practice test to see results here.',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
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
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.withValues(alpha: 0.13), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Error Loading Results',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _error ?? 'An error occurred while loading test results.',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _retryWithNetworkCheck,
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
              selected: 'test-results',
              onNavigate: (route) => Navigator.pushNamed(context, route),
            ),
            Expanded(
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Use CustomAppBar for desktop as well
                    CustomAppBar(
                      title: 'Test History',
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Main content (centered, constrained)
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 900),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal:
                                  MediaQuery.of(context).size.width > 900
                                      ? 0
                                      : 0,
                              vertical: 0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Content
                                Expanded(
                                  child:
                                      _initialLoading
                                          ? const Center(
                                            child: CircularProgressIndicator(
                                              color: AppTheme.primaryBlue,
                                            ),
                                          )
                                          : _hasNetworkError
                                          ? Center(child: _buildErrorState())
                                          : _isLoading
                                          ? const Center(
                                            child: CircularProgressIndicator(
                                              color: AppTheme.primaryBlue,
                                            ),
                                          )
                                          : _error != null
                                          ? _buildErrorState()
                                          : _testResults.isEmpty
                                          ? _buildEmptyState()
                                          : Scrollbar(
                                            controller: _scrollController,
                                            thumbVisibility:
                                                MediaQuery.of(
                                                  context,
                                                ).size.width >
                                                900,
                                            child: RefreshIndicator(
                                              onRefresh: _retryWithNetworkCheck,
                                              child: ListView(
                                                controller: _scrollController,
                                                children: [
                                                  ..._groupedResults.entries.expand(
                                                    (entry) => [
                                                      Container(
                                                        margin:
                                                            const EdgeInsets.only(
                                                              bottom: 8,
                                                              top: 8,
                                                            ),
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              vertical: 8,
                                                              horizontal: 18,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: AppTheme
                                                              .primaryBlue
                                                              .withValues(
                                                                alpha: 0.07,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          entry.key,
                                                          style: GoogleFonts.poppins(
                                                            fontSize: 18,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color:
                                                                AppTheme
                                                                    .primaryBlue,
                                                          ),
                                                        ),
                                                      ),
                                                      ...entry.value.map(
                                                        _buildTestResultCard,
                                                      ),
                                                    ],
                                                  ),
                                                ],
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
            ),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: CustomAppBar(
        title: 'Test History',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width > 900 ? 40 : 16,
                vertical: 28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(
                        Icons.bar_chart_rounded,
                        color: AppTheme.primaryBlue,
                        size: MediaQuery.of(context).size.width > 900 ? 36 : 28,
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Your Test Results',
                        style: GoogleFonts.poppins(
                          fontSize:
                              MediaQuery.of(context).size.width > 900 ? 32 : 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'View your practice test performance history',
                    style: GoogleFonts.poppins(
                      fontSize:
                          MediaQuery.of(context).size.width > 900 ? 18 : 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Content
                  Expanded(
                    child:
                        _initialLoading
                            ? const Center(
                              child: CircularProgressIndicator(
                                color: AppTheme.primaryBlue,
                              ),
                            )
                            : _hasNetworkError
                            ? Center(child: _buildErrorState())
                            : _isLoading
                            ? const Center(
                              child: CircularProgressIndicator(
                                color: AppTheme.primaryBlue,
                              ),
                            )
                            : _error != null
                            ? _buildErrorState()
                            : _testResults.isEmpty
                            ? _buildEmptyState()
                            : Scrollbar(
                              controller: _scrollController,
                              thumbVisibility:
                                  MediaQuery.of(context).size.width > 900,
                              child: RefreshIndicator(
                                onRefresh: _retryWithNetworkCheck,
                                child: ListView(
                                  controller: _scrollController,
                                  children: [
                                    ..._groupedResults.entries.expand(
                                      (entry) => [
                                        Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 8,
                                            top: 8,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                            horizontal: 18,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryBlue
                                                .withValues(alpha: 0.07),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            entry.key,
                                            style: GoogleFonts.poppins(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primaryBlue,
                                            ),
                                          ),
                                        ),
                                        ...entry.value.map(
                                          _buildTestResultCard,
                                        ),
                                      ],
                                    ),
                                  ],
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
    );
  }
}
