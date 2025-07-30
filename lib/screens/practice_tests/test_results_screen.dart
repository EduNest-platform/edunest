import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/subject.dart';
import '../../widgets/custom_app_bar.dart';
import 'test_results_list_screen.dart';
import '../../services/test_results_service.dart';
import '../../widgets/app_text.dart';

class TestResultsScreen extends StatefulWidget {
  /// Optional: Subject object (for subject-based tests)
  final Subject? subject;

  /// Optional: Chapter map (for chapter-based tests)
  final Map<String, dynamic>? chapter;

  /// Optional: Difficulty string (for difficulty-based tests)
  final String? difficulty;

  /// Optional: Title of the test (for assigned or generic tests)
  final String? testTitle;

  /// Optional: Type of test (e.g., 'assigned', 'practice', etc.)
  final String? testType;

  /// Required: Score as integer percentage
  final int score;

  /// Required: Percentage as double
  final double percentage;

  /// Required: Number of correct answers
  final int correctAnswers;

  /// Required: Total number of questions
  final int totalQuestions;

  /// Required: Time taken in seconds
  final int timeTaken;

  /// Required: User answers (question index to answer key)
  final Map<int, dynamic> userAnswers;

  /// Required: List of questions (for review)
  final List<Map<String, dynamic>> questions;

  const TestResultsScreen({
    super.key,
    this.subject,
    this.chapter,
    this.difficulty,
    this.testTitle,
    this.testType,
    required this.score,
    required this.percentage,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.timeTaken,
    required this.userAnswers,
    required this.questions,
  });

  @override
  State<TestResultsScreen> createState() => _TestResultsScreenState();
}

class _TestResultsScreenState extends State<TestResultsScreen> {
  @override
  void initState() {
    super.initState();
  }

  String _getPerformanceMessage() {
    if (widget.percentage >= 90) return 'Excellent! Outstanding performance!';
    if (widget.percentage >= 80) return 'Great job! Well done!';
    if (widget.percentage >= 70) return 'Good work! Keep it up!';
    if (widget.percentage >= 60) return 'Not bad! Room for improvement.';
    if (widget.percentage >= 50) return 'You can do better!';
    return 'Keep practicing! You\'ll improve!';
  }

  Color _getScoreColor() {
    if (widget.percentage >= 90) return AppTheme.success;
    if (widget.percentage >= 80) return AppTheme.success;
    if (widget.percentage >= 70) return AppTheme.warning;
    if (widget.percentage >= 60) return AppTheme.warning;
    return AppTheme.error;
  }

  Widget _buildScoreCard() {
    final isWide = MediaQuery.of(context).size.width > 800;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: widget.percentage),
      duration: const Duration(seconds: 1),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return Container(
          width: double.infinity,
          padding:
              isWide
                  ? const EdgeInsets.symmetric(vertical: 32, horizontal: 40)
                  : const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_getScoreColor().withValues(alpha: 0.13), Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: _getScoreColor().withValues(alpha: 0.18),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: _getScoreColor().withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child:
              isWide
                  ? Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Animated Score Circle
                      Container(
                        width: 140,
                        height: 140,
                        margin: const EdgeInsets.only(right: 36),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 140,
                              height: 140,
                              child: CircularProgressIndicator(
                                value: animatedValue / 100,
                                strokeWidth: 10,
                                backgroundColor: _getScoreColor().withValues(
                                  alpha: 0.08,
                                ),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _getScoreColor(),
                                ),
                              ),
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${animatedValue.round()}%',
                                  style: GoogleFonts.poppins(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: _getScoreColor(),
                                  ),
                                ),
                                Text(
                                  'Score',
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    color: _getScoreColor(),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _getPerformanceMessage(),
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.left,
                        ),
                      ),
                    ],
                  )
                  : Column(
                    children: [
                      // Animated Score Circle
                      Container(
                        width: 120,
                        height: 120,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 120,
                              height: 120,
                              child: CircularProgressIndicator(
                                value: animatedValue / 100,
                                strokeWidth: 10,
                                backgroundColor: _getScoreColor().withValues(
                                  alpha: 0.08,
                                ),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _getScoreColor(),
                                ),
                              ),
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${animatedValue.round()}%',
                                  style: GoogleFonts.poppins(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: _getScoreColor(),
                                  ),
                                ),
                                Text(
                                  'Score',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: _getScoreColor(),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Performance Message
                      Text(
                        _getPerformanceMessage(),
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
        );
      },
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatBlock(
            icon: Icons.check_circle_rounded,
            value: '${widget.correctAnswers}',
            label: 'Correct',
            color: AppTheme.success,
          ),
          _verticalDivider(),
          _buildStatBlock(
            icon: Icons.cancel_rounded,
            value: '${widget.totalQuestions - widget.correctAnswers}',
            label: 'Incorrect',
            color: AppTheme.error,
          ),
          _verticalDivider(),
          _buildStatBlock(
            icon: Icons.quiz_rounded,
            value: '${widget.totalQuestions}',
            label: 'Total',
            color: AppTheme.primaryBlue,
          ),
          _verticalDivider(),
          _buildStatBlock(
            icon: Icons.timer_rounded,
            value: _formatElapsedTime(widget.timeTaken),
            label: 'Time',
            color: AppTheme.warning,
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      height: 48,
      width: 1.2,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Colors.grey.withValues(alpha: 0.13),
    );
  }

  Widget _buildStatBlock({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewAnswersCard() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showReviewAnswersModal(),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.quiz_rounded,
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
                      'Review Your Answers',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'See your chosen answers and correct answers',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.grey.shade400,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReviewAnswersModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildReviewAnswersModal(),
    );
  }

  Widget _buildReviewAnswersModal() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.quiz_rounded,
                    color: AppTheme.primaryBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Review Your Answers',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          // Questions List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: widget.questions.length,
              itemBuilder: (context, index) {
                final question = widget.questions[index];
                final userAnswerRaw = widget.userAnswers[index];
                final correctAnswerRaw = question['correctanswer'];
                final userAnswer =
                    userAnswerRaw is int
                        ? userAnswerRaw
                        : int.tryParse(userAnswerRaw?.toString() ?? '') ?? 0;
                final correctAnswer =
                    correctAnswerRaw is int
                        ? correctAnswerRaw
                        : int.tryParse(correctAnswerRaw?.toString() ?? '') ?? 0;
                final options = List<String>.from(question['options'] ?? []);
                final isCorrect = userAnswer == correctAnswer;

                return _buildQuestionReviewCard(
                  index: index + 1,
                  question: question['question'] ?? '',
                  options: options,
                  userAnswer: userAnswer,
                  correctAnswer: correctAnswer,
                  isCorrect: isCorrect,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionReviewCard({
    required int index,
    required String question,
    required List<String> options,
    required dynamic userAnswer,
    required int correctAnswer,
    required bool isCorrect,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isCorrect
                  ? AppTheme.success.withValues(alpha: 0.3)
                  : AppTheme.error.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color:
                  isCorrect
                      ? AppTheme.success.withValues(alpha: 0.1)
                      : AppTheme.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Q$index',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isCorrect ? AppTheme.success : AppTheme.error,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Question Text
          Text(
            question,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          // Options
          ...options.asMap().entries.map((entry) {
            final optionIndex = entry.key;
            final optionText = entry.value;
            final isUserChoice =
                userAnswer != null &&
                (userAnswer == optionIndex ||
                    userAnswer.toString() == optionIndex.toString());
            final isCorrectChoice = correctAnswer == optionIndex;

            Color backgroundColor = Colors.grey.shade50;
            Color borderColor = Colors.grey.shade200;
            Color textColor = Colors.black87;
            IconData? icon;
            Color iconColor = Colors.transparent;

            if (isUserChoice && isCorrectChoice) {
              // User chose correctly
              backgroundColor = AppTheme.success.withValues(alpha: 0.1);
              borderColor = AppTheme.success;
              textColor = AppTheme.success;
              icon = Icons.check_circle_rounded;
              iconColor = AppTheme.success;
            } else if (isUserChoice && !isCorrectChoice) {
              // User chose incorrectly
              backgroundColor = AppTheme.error.withValues(alpha: 0.1);
              borderColor = AppTheme.error;
              textColor = AppTheme.error;
              icon = Icons.cancel_rounded;
              iconColor = AppTheme.error;
            } else if (!isUserChoice && isCorrectChoice) {
              // User didn't choose but this is correct
              backgroundColor = AppTheme.success.withValues(alpha: 0.1);
              borderColor = AppTheme.success;
              textColor = AppTheme.success;
              icon = Icons.check_circle_rounded;
              iconColor = AppTheme.success;
            } else {
              // Other options (not chosen, not correct)
              backgroundColor = Colors.grey.shade50;
              borderColor = Colors.grey.shade200;
              textColor = Colors.grey.shade600;
              icon = null;
              iconColor = Colors.transparent;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: borderColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: Center(
                      child: Text(
                        String.fromCharCode(65 + optionIndex), // A, B, C, D
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      optionText,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: textColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (icon != null) ...[
                    const SizedBox(width: 8),
                    Icon(icon, color: iconColor, size: 18),
                  ],
                  if (isUserChoice && !isCorrectChoice) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Your Choice',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.error,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTestInfoCard() {
    final infoRows = <Widget>[];
    if (widget.testTitle != null) {
      infoRows.add(
        _buildInfoRowWithIcon(
          Icons.assignment_turned_in_rounded,
          'Test',
          widget.testTitle!,
        ),
      );
    }
    if (widget.testType != null) {
      infoRows.add(
        _buildInfoRowWithIcon(Icons.category_rounded, 'Type', widget.testType!),
      );
    }
    if (widget.subject != null) {
      infoRows.add(
        _buildInfoRowWithIcon(
          Icons.book_rounded,
          'Subject',
          widget.subject!.name,
        ),
      );
    }
    if (widget.chapter != null) {
      infoRows.add(
        _buildInfoRowWithIcon(
          Icons.topic_rounded,
          'Chapter',
          widget.chapter!['name'] ?? 'N/A',
        ),
      );
    }
    if (widget.difficulty != null) {
      infoRows.add(
        _buildInfoRowWithIcon(
          Icons.trending_up_rounded,
          'Difficulty',
          widget.difficulty!.toUpperCase(),
        ),
      );
    }
    infoRows.add(
      _buildInfoRowWithIcon(
        Icons.calendar_today_rounded,
        'Completed',
        DateTime.now().toString().substring(0, 16),
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Text(
              'Test Information',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryBlue,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Divider(
              color: AppTheme.primaryBlue.withValues(alpha: 0.18),
              thickness: 1.2,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Use two columns if wide enough, else single column
                if (constraints.maxWidth > 420 && infoRows.length > 2) {
                  final left = <Widget>[];
                  final right = <Widget>[];
                  for (int i = 0; i < infoRows.length; i++) {
                    if (i % 2 == 0) {
                      left.add(infoRows[i]);
                    } else {
                      right.add(infoRows[i]);
                    }
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Column(children: left)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(children: right)),
                    ],
                  );
                } else {
                  return Column(children: infoRows);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRowWithIcon(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppTheme.primaryBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatElapsedTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: CustomAppBar(
        title: 'Test Results',
        subtitle: widget.testTitle ?? widget.subject?.name ?? '',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TestResultsListScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 40 : 16,
                vertical: 28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Score Card
                  _buildScoreCard(),
                  const SizedBox(height: 32),

                  // Stats Card
                  _buildStatsCard(),
                  const SizedBox(height: 32),

                  // Review Answers Card
                  _buildReviewAnswersCard(),
                  const SizedBox(height: 32),

                  // Test Info Card
                  _buildTestInfoCard(),
                  const SizedBox(height: 40),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retake Test'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryBlue,
                            side: const BorderSide(color: AppTheme.primaryBlue),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              '/home',
                              (route) => false,
                            );
                          },
                          icon: const Icon(Icons.home_rounded),
                          label: const Text('Go Home'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
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
      ),
    );
  }
}
