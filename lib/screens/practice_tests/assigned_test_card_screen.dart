import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/assigned_mcq_supabase_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/app_text.dart';
import '../../screens/practice_tests/mcq_test_screen.dart';
import '../../services/user_profile_service.dart';
import '../../models/user_profile.dart';
import '../profile/personal_info_screen.dart';
import '../../services/test_results_service.dart';
import '../../services/error_message_service.dart';
import '../../services/supabase_service.dart';

class AssignedTestCardScreen extends StatefulWidget {
  const AssignedTestCardScreen({super.key});

  @override
  State<AssignedTestCardScreen> createState() => _AssignedTestCardScreenState();
}

class _AssignedTestCardScreenState extends State<AssignedTestCardScreen> {
  List<Map<String, dynamic>> _assignedTests = [];
  List<String> _completedTestTitles = [];
  bool _isLoading = true;
  String? _error;
  UserProfile? _userProfile;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadUserProfileAndTests();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfileAndTests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load user profile first
      final profile = await UserProfileService.getCurrentUserProfile();
      setState(() {
        _userProfile = profile;
      });

      // Only fetch tests if user has a roll number
      if (profile?.studentId != null && profile!.studentId!.trim().isNotEmpty) {
        await _fetchAssignedTests();
        await _fetchCompletedTests();
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      final message = ErrorMessageService.getFriendlyMessage(e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
      setState(() {
        _error = 'Failed to load user profile: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchAssignedTests() async {
    try {
      final tests = await AssignedMCQSupabaseService.fetchAssignedTests();
      
      // Filter tests by current user's academic path
      List<Map<String, dynamic>> filteredTests = [];
      if (tests != null && _userProfile != null) {
        filteredTests = await _filterTestsByAcademicPath(tests);
      }

      setState(() {
        _assignedTests = filteredTests;
        _isLoading = false;
      });
    } catch (e) {
      final message = ErrorMessageService.getFriendlyMessage(e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
      setState(() {
        _error = 'Failed to load assigned tests: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchCompletedTests() async {
    try {
      final completedTitles =
          await TestResultsService.getUserCompletedTestTitles();
      setState(() {
        _completedTestTitles = completedTitles;
      });
    } catch (e) {
      // Don't show error for completion status
    }
  }

  Future<List<Map<String, dynamic>>> _filterTestsByAcademicPath(
      List<Map<String, dynamic>> tests) async {
    if (_userProfile?.college == null ||
        _userProfile?.branch == null ||
        _userProfile?.semester == null) {
      // If academic path is incomplete, return all tests
      return tests;
    }

    try {
      // Get user's current academic context
      final userCollege = _userProfile!.college!.toLowerCase().trim();
      final userBranch = _userProfile!.branch!.toLowerCase().trim();
      final userSemester = _userProfile!.semester!.toLowerCase().trim();

      // Filter tests directly based on questions table fields (college, branch, semester)
      // Since tests are fetched from admin database, we need to query that database for matching tests
      final filteredTests = <Map<String, dynamic>>[];
      
      for (final test in tests) {
        final testName = test['test_name'];
        if (testName == null) continue;

        // Query the admin database to check if this test has questions for user's academic path
        final questionsResponse = await AssignedMCQSupabaseService.client
            .from('questions')
            .select('college, branch, semester')
            .eq('test_name', testName)
            .ilike('college', userCollege)
            .ilike('branch', userBranch)
            .ilike('semester', userSemester)
            .limit(1);

        // If questions exist for this test matching user's academic path, include the test
        if (questionsResponse.isNotEmpty) {
          filteredTests.add(test);
        }
      }

      return filteredTests;
    } catch (e) {
      // If filtering fails, return all tests to avoid breaking functionality
      return tests;
    }
  }

  Widget _buildTestCard(BuildContext context, Map<String, dynamic> test) {
    // Determine if the test is expired
    final createdAt =
        test['created_at'] != null && test['created_at'].toString() != 'null'
            ? DateTime.tryParse(test['created_at'].toString())
            : null;
    final isExpired =
        createdAt != null && DateTime.now().difference(createdAt).inHours >= 24;

    // Check if user has completed this test
    final testTitle = test['test_name'] ?? '';
    final isCompleted = _completedTestTitles.contains(testTitle);

    // Determine colors based on status
    Color iconColor;
    Color iconBgColor;
    if (isCompleted) {
      iconColor = AppTheme.primaryBlue;
      iconBgColor = AppTheme.primaryBlue.withValues(alpha: 0.13);
    } else if (isExpired) {
      iconColor = Colors.grey;
      iconBgColor = Colors.grey.withValues(alpha: 0.13);
    } else {
      iconColor = AppTheme.success;
      iconBgColor = AppTheme.success.withValues(alpha: 0.13);
    }
    String dateString = 'Date unknown';
    if (createdAt != null) {
      dateString =
          '${createdAt.day.toString().padLeft(2, '0')} '
          '${_monthName(createdAt.month)} '
          '${createdAt.year}, '
          '${_formatHourMinute(createdAt)}';
    }
    return GestureDetector(
      onTap: () async {
        if (isCompleted) {
          // Show completion message
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('You have already completed this test.'),
                backgroundColor: AppTheme.primaryBlue,
                duration: const Duration(seconds: 2),
              ),
            );
          }
          return;
        }

        if (isExpired) {
          // Show expired message
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('This test has expired.'),
                backgroundColor: Colors.grey,
                duration: const Duration(seconds: 2),
              ),
            );
          }
          return;
        }

        // Navigate to the MCQ test screen (unified)
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MCQTestScreen(assignedTest: test),
          ),
        );

        // Refresh completion status when returning from test
        if (result == true) {
          await _fetchCompletedTests();
        }
      },
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Leading Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isCompleted
                      ? Icons.check_circle_rounded
                      : Icons.play_circle_fill_rounded,
                  color: iconColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              // Main Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row: Test Name + Question Count
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Test Name
                        Expanded(
                          child: AppText(
                            test['test_name'] ?? 'Assigned Test',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (test['question_count'] != null) ...[
                          SizedBox(width: 8),
                          Container(
                            constraints: BoxConstraints(
                              minWidth: 30,
                              maxWidth: 55,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue.withValues(
                                alpha: 0.10,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.help_outline_rounded,
                                  size: 13,
                                  color: AppTheme.primaryBlue,
                                ),
                                const SizedBox(width: 3),
                                AppText(
                                  '${test['question_count']} Qs',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: AppTheme.primaryBlue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (isCompleted) ...[
                          SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.primaryBlue.withValues(
                                  alpha: 0.3,
                                ),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_rounded,
                                  size: 12,
                                  color: AppTheme.primaryBlue,
                                ),
                                const SizedBox(width: 3),
                                AppText(
                                  'Completed',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: AppTheme.primaryBlue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (test['subject'] != null &&
                        test['subject'].toString().trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      AppText(
                        test['subject'],
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    // Created Date (no icon)
                    AppText(
                      'Created $dateString',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Trailing Arrow
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 18,
                  color: iconColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month];
  }

  String _formatHourMinute(DateTime dt) {
    int hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? 'PM' : 'AM';
    if (hour == 0) hour = 12;
    if (hour > 12) hour -= 12;
    return '$hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    // Remove always-on mock data. Use real data from _assignedTests.

    // Partition tests into live and expired based on created_at
    final now = DateTime.now();
    final liveTests =
        _assignedTests.where((test) {
            final createdAt =
                test['created_at'] != null
                    ? DateTime.tryParse(test['created_at'].toString())
                    : null;
            // If createdAt is missing or invalid, treat as live
            if (createdAt == null) return true;
            return now.difference(createdAt).inHours < 24;
          }).toList()
          ..sort(
            (a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''),
          );
    final expiredTests =
        _assignedTests.where((test) {
            final createdAt =
                test['created_at'] != null
                    ? DateTime.tryParse(test['created_at'].toString())
                    : null;
            // If createdAt is missing or invalid, do NOT include in expired
            if (createdAt == null) return false;
            return now.difference(createdAt).inHours >= 24;
          }).toList()
          ..sort(
            (a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''),
          );

    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Assigned Tests',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isLoading ? null : _loadUserProfileAndTests,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              isWide ? 40 : 16,
              isWide ? 32 : 20,
              isWide ? 40 : 16,
              isWide ? 24 : 12,
            ),
          child:
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        vertical: isWide ? 48 : 24,
                        horizontal: isWide ? 48 : 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        _error!,
                        style: GoogleFonts.poppins(
                          fontSize: isWide ? 18 : 15,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  )
                  : _userProfile?.studentId == null ||
                      _userProfile!.studentId!.trim().isEmpty
                  ? _buildNoRollNumberMessage()
                  : _assignedTests.isEmpty
                  ? Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        vertical: isWide ? 48 : 24,
                        horizontal: isWide ? 48 : 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        'No assigned tests available.',
                        style: GoogleFonts.poppins(
                          fontSize: isWide ? 18 : 15,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  )
                  : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Always show Live Tests section
                          Container(
                            margin: const EdgeInsets.only(bottom: 8, top: 4),
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 18,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue.withValues(
                                alpha: 0.07,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Live Tests',
                              style: GoogleFonts.poppins(
                                fontSize: isWide ? 22 : 17,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                          ),
                          if (liveTests.isNotEmpty) ...[
                            ...liveTests.map(
                              (test) => Padding(
                                padding: EdgeInsets.only(
                                  bottom: isWide ? 16 : 10,
                                ),
                                child: _buildTestCard(context, test),
                              ),
                            ),
                          ] else ...[
                            // Show simple message when no live tests
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 12,
                              ),
                              child: Text(
                                'No active tests available.',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                          if (expiredTests.isNotEmpty) ...[
                            Container(
                              margin: EdgeInsets.only(
                                bottom: 8,
                                top: liveTests.isNotEmpty ? 18 : 4,
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 18,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Expired Tests',
                                style: GoogleFonts.poppins(
                                  fontSize: isWide ? 20 : 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                            ...expiredTests.map(
                              (test) => Padding(
                                padding: EdgeInsets.only(
                                  bottom: isWide ? 16 : 10,
                                ),
                                child: _buildTestCard(context, test),
                              ),
                            ),
                          ],
                          // Add bottom padding
                          SizedBox(height: isWide ? 32 : 20),
                        ],
                      ),
                    ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoRollNumberMessage() {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(
              Icons.person_add_rounded,
              size: 48,
              color: Colors.orange.shade600,
            ),
          ),
          const SizedBox(height: 24),
          AppText(
            'Roll Number Required',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          AppText(
            'To access assigned tests and view your results, please add your Student ID/Roll Number to your profile.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PersonalInfoScreen(),
                  ),
                ).then((_) {
                  // Reload profile and tests when returning from personal info screen
                  _loadUserProfileAndTests();
                });
              },
              icon: const Icon(Icons.edit_rounded),
              label: Text(
                'Add Roll Number',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Go Back',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
