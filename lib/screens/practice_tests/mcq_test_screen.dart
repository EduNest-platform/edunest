import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/subject.dart';
import '../../widgets/custom_app_bar.dart';
import '../../services/test_results_service.dart';
import 'test_results_screen.dart';
import '../../services/supabase_service.dart';
import '../../services/network_service.dart';
import '../../widgets/app_text.dart';
import '../../services/assigned_mcq_supabase_service.dart';
import '../../services/error_message_service.dart';
import '../../mixins/performance_mixin.dart';
import 'package:window_manager/window_manager.dart';

class MCQTestScreen extends StatefulWidget {
  final Subject? subject;
  final Map<String, dynamic>? chapter;
  final String? difficulty;
  final int? questionCount;
  final Map<String, dynamic>? assignedTest;
  final bool? isProctored;

  const MCQTestScreen({
    super.key,
    this.subject,
    this.chapter,
    this.difficulty,
    this.questionCount,
    this.assignedTest,
    this.isProctored,
  });

  @override
  State<MCQTestScreen> createState() => _MCQTestScreenState();
}

Future<List<Map<String, dynamic>>> fetchQuestionsFromSupabase({
  required String topicId,
  required String difficulty,
  required int questionCount,
}) async {
  final client = SupabaseService.client;
  try {
    // Always fetch 15 questions from the database (the maximum pool size)
    // Then limit to user's requested count to ensure we never have blank questions
    final response = await client
        .from('questions')
        .select()
        .eq('topic_id', topicId)
        .eq('difficulty', difficulty)
        .limit(15); // Always fetch from the 15-question pool

    if (response is List) {
      final allQuestions = response.cast<Map<String, dynamic>>();

      // If we don't have enough questions, return what we have
      if (allQuestions.length < questionCount) {
        return allQuestions;
      }

      // Take only the requested number of questions
      return allQuestions.take(questionCount).toList();
    } else {
      return [];
    }
  } catch (e) {
    throw Exception('Error fetching questions: $e');
  }
}

class _MCQTestScreenState extends State<MCQTestScreen>
    with WidgetsBindingObserver, WindowListener, PerformanceMixin {
  List<Map<String, dynamic>> _questions = [];
  int _currentQuestionIndex = 0;
  Map<int, String> _userAnswers = {};
  bool _isLoading = true;
  bool _initialLoading = true;
  String? _error;
  bool _isTestCompleted = false;
  bool _hasNetworkError = false;
  final ScrollController _navigatorScrollController = ScrollController();
  final NetworkService _networkService = NetworkService();
  Timer? _timer;
  int _secondsElapsed = 0;
  bool _autoSubmitted = false;
  bool get isAssignedTest => widget.assignedTest != null;
  bool get isProctored => isAssignedTest || (widget.isProctored ?? false);
  // Add question scroll controller
  final ScrollController _questionScrollController = ScrollController();
  int? _countdownSeconds; // For assigned test countdown

  @override
  void initState() {
    super.initState();
    startScreenMonitoring('mcq_test_screen');
    // Always start timer regardless of proctoring
    if (isProctored) {
      WidgetsBinding.instance.addObserver(this);
      windowManager.addListener(this);
    }
    _startTimer();
    _loadQuestions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _scrollToCurrentQuestion();
          if (isProctored) {
            _showProctoringWarning();
          }
        }
      });
    });

    // Check if assigned test is already completed
    if (isAssignedTest) {
      _checkTestCompletion();
    }
  }

  @override
  void dispose() {
    if (isProctored) {
      WidgetsBinding.instance.removeObserver(this);
      windowManager.removeListener(this);
      _timer?.cancel();
    }
    _navigatorScrollController.dispose();
    // Dispose question scroll controller
    _questionScrollController.dispose();
    stopScreenMonitoring();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (isProctored && state == AppLifecycleState.paused && !_autoSubmitted) {
      _autoSubmitted = true;
      _submitTest(auto: true);
    } else if (isProctored &&
        state == AppLifecycleState.resumed &&
        _autoSubmitted) {
      // Show modal when user returns after auto-submit
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showAutoSubmitModal();
        }
      });
    }
  }

  // Desktop proctoring: window focus/blur
  @override
  void onWindowFocus() {
    if (_autoSubmitted) {
      _showAutoSubmitModal();
    }
  }

  @override
  void onWindowBlur() {
    if (!_autoSubmitted) {
      _autoSubmitted = true;
      _submitTest(auto: true);
    }
  }

  void _startTimer() {
    if (isAssignedTest) {
      // Only use duration_minutes for assigned test timer
      int? durationSeconds;
      if (widget.assignedTest != null) {
        final rawMinutes = widget.assignedTest!['duration_minutes'];
        int? minutes;
        if (rawMinutes is int && rawMinutes > 0) {
          minutes = rawMinutes;
        } else if (rawMinutes is String) {
          final parsed = int.tryParse(rawMinutes);
          if (parsed != null && parsed > 0) minutes = parsed;
        }
        if (minutes != null) {
          durationSeconds = minutes * 60;
        }
      }
      // Default to 30 minutes if duration is missing or invalid
      if (durationSeconds == null || durationSeconds <= 0) {
        durationSeconds = 30 * 60;
      }
      _countdownSeconds = durationSeconds;
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          if (_countdownSeconds! > 0) {
            _countdownSeconds = _countdownSeconds! - 1;
            _secondsElapsed++;
          } else {
            timer.cancel();
            _submitTest(auto: true);
          }
        });
      });
    } else {
      // Practice test: count up
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _secondsElapsed++;
          });
        } else {
          timer.cancel();
        }
      });
    }
  }

  Future<void> _checkTestCompletion() async {
    try {
      final testTitle =
          widget.assignedTest!['test_name'] ??
          widget.assignedTest!['title'] ??
          '';
      if (testTitle.isNotEmpty) {
        final isCompleted = await TestResultsService.hasUserCompletedTest(
          testTitle,
        );
        if (isCompleted && mounted) {
          // Show completion message and go back
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('You have already completed this test.'),
              backgroundColor: AppTheme.primaryBlue,
              duration: const Duration(seconds: 3),
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      // Error checking test completion
    }
  }

  Future<void> _loadQuestions() async {
    await startOperationTrace('mcq_questions_loading');

    setState(() {
      _isLoading = true;
      _error = null;
      if (isAssignedTest) {
        _initialLoading = false;
        _hasNetworkError = false;
      } else {
        _hasNetworkError = false;
        _initialLoading = true;
      }
    });
    try {
      if (isAssignedTest) {
        final questions =
            await AssignedMCQSupabaseService.fetchQuestionsForTest(
              widget.assignedTest!['test_name'] ??
                  widget.assignedTest!['title'] ??
                  '',
            );
        setState(() {
          _questions = questions;
          _isLoading = false;
        });
        await stopOperationTrace('mcq_questions_loading');
      } else {
        final networkStatus = await _networkService.isConnected();
        if (!networkStatus) {
          setState(() {
            _hasNetworkError = true;
            _isLoading = false;
            _initialLoading = false;
          });
          return;
        }
        final questions = await fetchQuestionsFromSupabase(
          topicId: widget.chapter!['id'],
          difficulty: widget.difficulty!,
          questionCount: widget.questionCount!,
        );
        setState(() {
          _questions = questions;
          _isLoading = false;
          _initialLoading = false;
        });
      }
    } catch (e) {
      final message = ErrorMessageService.getFriendlyMessage(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
      setState(() {
        _error = 'Failed to load questions: $e';
        _isLoading = false;
        _hasNetworkError = !isAssignedTest;
        _initialLoading = false;
      });
    }
  }

  // Helper to get option key (A, B, C, ...) from index
  String _optionKey(int index) => String.fromCharCode(65 + index);

  void _selectAnswer(int answerIndex) {
    setState(() {
      if (isAssignedTest) {
        _userAnswers[_currentQuestionIndex] = _optionKey(answerIndex);
      } else {
        _userAnswers[_currentQuestionIndex] = answerIndex.toString();
      }
    });
  }

  void _scrollToCurrentQuestion() {
    if (!_navigatorScrollController.hasClients) {
      return;
    }

    final double buttonWidth = 44.0;
    final double spacing = 10.0;
    final double offset =
        (_currentQuestionIndex * (buttonWidth + spacing)) - 12.0;
    _navigatorScrollController.animateTo(
      offset < 0 ? 0 : offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _scrollToCurrentQuestion();
      });
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
        _scrollToCurrentQuestion();
      });
    }
  }

  void _goToQuestion(int questionIndex) {
    setState(() {
      _currentQuestionIndex = questionIndex;
      _scrollToCurrentQuestion();
    });
  }

  Future<void> _submitTest({bool auto = false}) async {
    if (_isTestCompleted) return;
    _timer?.cancel();
    setState(() {
      _isTestCompleted = true;
    });
    try {
      int correctAnswers = 0;
      int totalQuestions = _questions.length;
      for (int i = 0; i < totalQuestions; i++) {
        final userAnswer = _userAnswers[i];
        if (isAssignedTest) {
          // For assigned tests, use 'correct' field and compare as key (A/B/C/D)
          final correctAnswer = _questions[i]['correct'];
          if (userAnswer != null &&
              userAnswer.toString() == correctAnswer.toString()) {
            correctAnswers++;
          }
        } else {
          // For practice tests, use 'correctanswer' field and compare as index
          final correctAnswer = _questions[i]['correctanswer'];
          if (userAnswer != null &&
              userAnswer.toString() == correctAnswer.toString()) {
            correctAnswers++;
          }
        }
      }
      final score = (correctAnswers / totalQuestions * 100).round();
      final percentage = score.toDouble();
      final timeTaken = _secondsElapsed;
      if (isAssignedTest) {
        final testTitle =
            widget.assignedTest!['title'] ??
            widget.assignedTest!['test_name'] ??
            '';
        await TestResultsService.saveTestResult(
          subjectId: widget.assignedTest!['subject_id'] ?? '',
          subjectName: widget.assignedTest!['subject_name'] ?? '',
          chapterId: widget.assignedTest!['chapter_id'] ?? '',
          chapterName: widget.assignedTest!['chapter_name'] ?? '',
          difficulty: widget.assignedTest!['difficulty'] ?? 'not_assigned',
          totalQuestions: totalQuestions,
          correctAnswers: correctAnswers,
          score: score,
          timeTaken: timeTaken,
          testTitle: testTitle,
        );
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder:
                  (context) => TestResultsScreen(
                    testTitle: testTitle,
                    testType: 'assigned',
                    score: score,
                    percentage: percentage,
                    correctAnswers: correctAnswers,
                    totalQuestions: totalQuestions,
                    timeTaken: timeTaken,
                    userAnswers: _userAnswers,
                    questions: _questions,
                  ),
            ),
          ).then((_) {
            if (mounted) {
              // Return true to indicate test was completed
              Navigator.pop(context, true);
            }
          });
        }
      } else {
        await TestResultsService.saveTestResult(
          subjectId: widget.subject!.id,
          subjectName: widget.subject!.name,
          chapterId: widget.chapter!['id'],
          chapterName: widget.chapter!['name'],
          difficulty: widget.difficulty!,
          score: score,
          correctAnswers: correctAnswers,
          totalQuestions: totalQuestions,
          timeTaken: timeTaken,
        );
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder:
                  (context) => TestResultsScreen(
                    subject: widget.subject!,
                    chapter: widget.chapter!,
                    difficulty: widget.difficulty!,
                    score: score,
                    percentage: percentage,
                    correctAnswers: correctAnswers,
                    totalQuestions: totalQuestions,
                    timeTaken: timeTaken,
                    userAnswers: _userAnswers,
                    questions: _questions,
                  ),
            ),
          );
        }
      }
    } catch (e) {
      final message = ErrorMessageService.getFriendlyMessage(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String subtitleText = '';
    if (isAssignedTest) {
      subtitleText =
          widget.assignedTest?['title'] ??
          widget.assignedTest?['test_name'] ??
          '';
      if (widget.assignedTest?['subject_name'] != null &&
          widget.assignedTest?['chapter_name'] != null) {
        subtitleText =
            '${widget.assignedTest?['subject_name']} - ${widget.assignedTest?['chapter_name']}';
      }
    } else {
      subtitleText =
          '${widget.subject?.name ?? ''} - ${widget.chapter?['name'] ?? ''}';
    }

    final isWide = MediaQuery.of(context).size.width > 900;

    Widget proctoredBanner = Positioned(
      top: 32,
      right: 32,
      child:
          isProctored && isWide
              ? Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.primaryBlue.withOpacity(0.18),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryBlue.withOpacity(0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.security_rounded,
                        color: AppTheme.primaryBlue,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Proctored Test',
                        style: GoogleFonts.poppins(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.visibility_rounded,
                        color: Colors.grey.shade400,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Monitoring',
                        style: GoogleFonts.poppins(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              : const SizedBox.shrink(),
    );

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldExit = await _showExitDialog(context);
        if (shouldExit ?? false && mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        appBar:
            isWide
                ? CustomAppBar(
                  title: 'MCQ Test',
                  subtitle: subtitleText,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_rounded),
                    onPressed: () async {
                      final shouldExit = await _showExitDialog(context);
                      if (shouldExit ?? false && mounted) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                )
                : null,
        body: Stack(
          children: [
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isWide ? 40 : 12,
                      vertical: isWide ? 32 : 8,
                    ),
                    child:
                        isAssignedTest
                            ? _isLoading
                                ? const Center(
                                  child: CircularProgressIndicator(
                                    color: AppTheme.primaryBlue,
                                  ),
                                )
                                : _error != null
                                ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.error_outline_rounded,
                                        size: 60,
                                        color: AppTheme.error,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Error Loading Questions',
                                        style: GoogleFonts.poppins(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _error!,
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          color: Colors.grey.shade600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                )
                                : Column(
                                  children: [
                                    // Move navigator to top, closest to app bar
                                    _buildQuestionNavigator(),
                                    const SizedBox(height: 12),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        child: _buildQuestionCard(),
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    _buildNavigationButtons(),
                                  ],
                                )
                            : _initialLoading
                            ? const Center(
                              child: CircularProgressIndicator(
                                color: AppTheme.primaryBlue,
                              ),
                            )
                            : _hasNetworkError
                            ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(50),
                                      ),
                                      child: const Text(
                                        '📝',
                                        style: TextStyle(fontSize: 48),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    const Text(
                                      '📡 No Internet Connection',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Unable to load test questions. Please connect to the internet and try again.',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 32),
                                    ElevatedButton.icon(
                                      onPressed: _loadQuestions,
                                      icon: const Icon(Icons.refresh_rounded),
                                      label: const Text('Retry'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            : _isLoading
                            ? const Center(
                              child: CircularProgressIndicator(
                                color: AppTheme.primaryBlue,
                              ),
                            )
                            : _error != null
                            ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error_outline_rounded,
                                    size: 60,
                                    color: AppTheme.error,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Error Loading Questions',
                                    style: GoogleFonts.poppins(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _error!,
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                            : Column(
                              children: [
                                // Move navigator to top, closest to app bar
                                _buildQuestionNavigator(),
                                const SizedBox(height: 12),
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: _buildQuestionCard(),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                _buildNavigationButtons(),
                              ],
                            ),
                  ),
                ),
              ),
            ),
            if (isProctored && isWide) proctoredBanner,
            // Timer at top right for desktop only
            if (isWide)
              Positioned(
                top: 24,
                right: 40,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.07),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(
                      color: AppTheme.primaryBlue.withOpacity(0.13),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_rounded,
                        color: AppTheme.primaryBlue,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _getTimerDisplay(),
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard() {
    if (_questions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isAssignedTest
                  ? 'No questions available for this assigned test.'
                  : 'No questions available for this topic and difficulty.',
              style: GoogleFonts.poppins(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            if (!isAssignedTest) ...[
              const SizedBox(height: 12),
              Text(
                'Topic ID: '
                '${widget.chapter?['id'] ?? ''}\nDifficulty: ${widget.difficulty ?? ''}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade400,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      );
    }
    final question = _questions[_currentQuestionIndex];
    dynamic optionsRaw = question['options'];
    List<dynamic> options;
    if (optionsRaw is List) {
      options = optionsRaw;
    } else if (optionsRaw is Map) {
      options = optionsRaw.values.toList();
    } else {
      options = [];
    }
    final userAnswer = _userAnswers[_currentQuestionIndex];
    final bool isDesktop =
        Theme.of(context).platform == TargetPlatform.windows ||
        Theme.of(context).platform == TargetPlatform.linux ||
        Theme.of(context).platform == TargetPlatform.macOS;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF3B82F6).withValues(alpha: 0.10),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDesktop) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Color(0xFF3B82F6).withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Question ${_currentQuestionIndex + 1}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                ),
                const Spacer(),
                Expanded(
                  child: Text(
                    '${_currentQuestionIndex + 1}/${_questions.length}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
          // Scrollable question text with max height and improved style
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding:
                isDesktop
                    ? const EdgeInsets.all(18)
                    : const EdgeInsets.only(
                      top: 10,
                      left: 18,
                      right: 18,
                      bottom: 18,
                    ),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FB), // Soft light blue/gray
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _buildRichQuestionText(
              question['question'] ?? 'Question text not available',
              color: isDesktop ? const Color(0xFF222B45) : Colors.black87,
              fontWeight: isDesktop ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
          const SizedBox(height: 28),
          ...List.generate(options.length, (index) {
            final isSelected =
                isAssignedTest
                    ? userAnswer == _optionKey(index)
                    : userAnswer == index.toString();
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _selectAnswer(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? Color(0xFF3B82F6)
                              : const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            isSelected
                                ? Color(0xFF3B82F6)
                                : Colors.grey.shade200,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow:
                          isSelected
                              ? [
                                BoxShadow(
                                  color: Color(
                                    0xFF3B82F6,
                                  ).withValues(alpha: 0.10),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                              : [],
                    ),
                    child: Row(
                      children: [
                        if (!isAssignedTest) ...[
                          // Modern circular radio button for practice test
                          GestureDetector(
                            onTap: () => _selectAnswer(index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color:
                                    isSelected
                                        ? Color(0xFF3B82F6)
                                        : Colors.transparent,
                                border: Border.all(
                                  color:
                                      isSelected
                                          ? Colors.white
                                          : Colors.grey.shade400,
                                  width: 2.5,
                                ),
                              ),
                              child: Center(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  width: isSelected ? 12 : 0,
                                  height: isSelected ? 12 : 0,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color:
                                        isSelected
                                            ? Colors.white
                                            : Colors.transparent,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          // A/B/C/D label for assigned test
                          Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  isSelected ? Color(0xFF3B82F6) : Colors.white,
                              border: Border.all(
                                color:
                                    isSelected
                                        ? Colors.white
                                        : Colors.grey.shade300,
                                width: isSelected ? 2 : 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      isSelected
                                          ? Color(
                                            0xFF3B82F6,
                                          ).withValues(alpha: 0.13)
                                          : Colors.black.withValues(
                                            alpha: 0.04,
                                          ),
                                  blurRadius: isSelected ? 7 : 3,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              _optionKey(index),
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color:
                                    isSelected
                                        ? Colors.white
                                        : Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            options[index].toString(),
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color:
                                  isSelected ? Colors.white : Color(0xFF3B82F6),
                              fontWeight:
                                  isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _currentQuestionIndex > 0 ? _previousQuestion : null,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Previous'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryBlue,
              side: const BorderSide(color: AppTheme.primaryBlue),
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed:
                _currentQuestionIndex < _questions.length - 1
                    ? _nextQuestion
                    : _submitTest,
            icon: Icon(
              _currentQuestionIndex < _questions.length - 1
                  ? Icons.arrow_forward_rounded
                  : Icons.check_rounded,
            ),
            label: Text(
              _currentQuestionIndex < _questions.length - 1 ? 'Next' : 'Submit',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionNavigator() {
    final bool isDesktop =
        Theme.of(context).platform == TargetPlatform.windows ||
        Theme.of(context).platform == TargetPlatform.linux ||
        Theme.of(context).platform == TargetPlatform.macOS;
    return Container(
      margin: const EdgeInsets.only(top: 0, bottom: 4),
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          Row(
            children: [
              Icon(
                Icons.grid_view_rounded,
                color: AppTheme.primaryBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Question Navigator',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                  letterSpacing: 0.2,
                ),
              ),
              Spacer(),
              if (!isDesktop)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.07),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(
                      color: AppTheme.primaryBlue.withOpacity(0.13),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_rounded,
                        color: AppTheme.primaryBlue,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getTimerDisplay(),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: ListView.separated(
              controller: _navigatorScrollController,
              scrollDirection: Axis.horizontal,
              itemCount: _questions.length,
              separatorBuilder: (context, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final isAnswered = _userAnswers.containsKey(index);
                final isCurrent = index == _currentQuestionIndex;
                Color bgColor = Colors.grey.shade100;
                Color borderColor = Colors.transparent;
                Color textColor = Colors.grey.shade600;
                FontWeight fontWeight = FontWeight.w500;
                if (isCurrent) {
                  bgColor = AppTheme.primaryBlue;
                  borderColor = AppTheme.primaryBlue;
                  textColor = Colors.white;
                  fontWeight = FontWeight.bold;
                } else if (isAnswered) {
                  bgColor = AppTheme.success.withValues(alpha: 0.85);
                  borderColor = AppTheme.success;
                  textColor = Colors.white;
                  fontWeight = FontWeight.w600;
                }
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => _goToQuestion(index),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: borderColor,
                            width: isCurrent ? 2 : 1,
                          ),
                          boxShadow:
                              isCurrent
                                  ? [
                                    BoxShadow(
                                      color: AppTheme.primaryBlue.withValues(
                                        alpha: 0.13,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                  : [],
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: fontWeight,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showProctoringWarning() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.security_rounded,
                    color: AppTheme.primaryBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Proctored Test',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This test is being monitored for academic integrity.',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                _buildProctoringRule(
                  Icons.phone_android_rounded,
                  'Do not switch to other apps',
                ),
                const SizedBox(height: 8),
                _buildProctoringRule(
                  Icons.screenshot_rounded,
                  'Screenshots are disabled',
                ),
                const SizedBox(height: 8),
                _buildProctoringRule(
                  Icons.timer_rounded,
                  'Test will auto-submit if app is closed',
                ),
                const SizedBox(height: 8),
                _buildProctoringRule(
                  Icons.visibility_rounded,
                  'Your activity is being monitored',
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'I Understand',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildProctoringRule(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primaryBlue),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ],
    );
  }

  Future<bool?> _showExitDialog(BuildContext context) async {
    final isWide = MediaQuery.of(context).size.width > 600;
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            elevation: 0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 36 : 20,
                  vertical: isWide ? 36 : 24,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryBlue.withOpacity(0.10),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(
                    color: AppTheme.primaryBlue.withOpacity(0.18),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.error.withOpacity(0.13),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        size: 44,
                        color: AppTheme.error,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Exit Test?',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF222B45),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Are you sure you want to exit? Your progress will be lost.',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: const Color(0xFF222B45),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryBlue,
                              side: BorderSide(
                                color: AppTheme.primaryBlue,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              textStyle: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: () => Navigator.of(context).pop(false),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 17,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.error,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              elevation: 0,
                              textStyle: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: () => Navigator.of(context).pop(true),
                            child: Text(
                              'Exit',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 17,
                                color: Colors.white,
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
    );
  }

  void _showAutoSubmitModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.warning_rounded,
                    color: AppTheme.error,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Test Auto-Submitted',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your test has been automatically submitted because you switched to another app or screen during the proctored test.',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.error.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: AppTheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This action is logged for academic integrity purposes.',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppTheme.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Just close the modal
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Close',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildRichQuestionText(
    String text, {
    Color? color,
    FontWeight? fontWeight,
  }) {
    final RegExp codeReg = RegExp(r'`([^`]+)`');
    final List<InlineSpan> spans = [];
    int start = 0;
    final matches = codeReg.allMatches(text);
    final bool isDesktop =
        Theme.of(context).platform == TargetPlatform.windows ||
        Theme.of(context).platform == TargetPlatform.linux ||
        Theme.of(context).platform == TargetPlatform.macOS;
    final Color textColor =
        color ?? (isDesktop ? const Color(0xFF222B45) : Colors.black87);
    final FontWeight effectiveWeight =
        fontWeight ?? (isDesktop ? FontWeight.w700 : FontWeight.w700);
    for (final match in matches) {
      if (match.start > start) {
        spans.add(
          TextSpan(
            text: text.substring(start, match.start),
            style: GoogleFonts.poppins(
              fontSize: isDesktop ? 20 : 17,
              fontWeight: effectiveWeight,
              color: textColor,
              height: 1.6,
            ),
          ),
        );
      }
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6), // less greenish, more neutral
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              match.group(1)!,
              style: const TextStyle(
                fontFamily: 'FiraMono',
                fontSize: 17,
                color: Color(0xFF1E293B),
                letterSpacing: 0.1,
              ),
            ),
          ),
        ),
      );
      start = match.end;
    }
    if (start < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(start),
          style: GoogleFonts.poppins(
            fontSize: isDesktop ? 20 : 17,
            fontWeight: effectiveWeight,
            color: textColor,
            height: 1.6,
          ),
        ),
      );
    }
    return RichText(
      text: TextSpan(children: spans),
      textAlign: TextAlign.start,
    );
  }

  String _formatElapsedTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  String _getTimerDisplay() {
    if (isAssignedTest && _countdownSeconds != null) {
      return _formatElapsedTime(_countdownSeconds!);
    } else {
      return _formatElapsedTime(_secondsElapsed);
    }
  }
}
