import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/subject.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/app_text.dart';
import 'mcq_test_screen.dart';

class DifficultySelectionScreen extends StatefulWidget {
  final Subject subject;
  final Map<String, dynamic> chapter;

  const DifficultySelectionScreen({
    super.key,
    required this.subject,
    required this.chapter,
  });

  @override
  State<DifficultySelectionScreen> createState() =>
      _DifficultySelectionScreenState();
}

class _DifficultySelectionScreenState extends State<DifficultySelectionScreen> {
  String? selectedDifficulty;
  bool isProctored = false;

  Widget _buildDifficultyCard({
    required String title,
    required String description,
    required Color color,
    required IconData icon,
    required String difficulty,
  }) {
    final isSelected = selectedDifficulty == difficulty;

    return Container(
      margin: const EdgeInsets.only(bottom: 17),
      decoration: BoxDecoration(
        color: isSelected ? color.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 13,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: isSelected ? color : color.withValues(alpha: 0.2),
          width: isSelected ? 2.3 : 1.7,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: () {
            setState(() {
              selectedDifficulty = difficulty;
            });
            _showQuestionCountPicker(context);
          },
          child: Padding(
            padding: const EdgeInsets.all(19),
            child: Row(
              children: [
                // Difficulty Icon
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: color, size: 27),
                ),
                const SizedBox(width: 17),
                // Difficulty Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        description,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                // Arrow Icon
                Icon(Icons.arrow_forward_ios_rounded, color: color, size: 21),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showQuestionCountPicker(BuildContext context) async {
    final isWide = MediaQuery.of(context).size.width > 700;
    final int? selected = await showDialog<int>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            elevation: 20,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 32 : 20,
                  vertical: isWide ? 32 : 20,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.10),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.quiz_rounded,
                        size: 32,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Title
                    Text(
                      'Select Number of Questions',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    // Subtitle
                    Text(
                      'Choose how many questions you want to practice',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    // Question Count Buttons
                    _questionCountButton(context, 5, isWide),
                    const SizedBox(height: 10),
                    _questionCountButton(context, 10, isWide),
                    const SizedBox(height: 10),
                    _questionCountButton(context, 15, isWide),
                    const SizedBox(height: 18),
                    // Cancel Button
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.poppins(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );

    if (selected != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => MCQTestScreen(
                subject: widget.subject,
                chapter: widget.chapter,
                difficulty: selectedDifficulty!,
                questionCount: selected,
                isProctored: isProctored,
              ),
        ),
      );
    }
  }

  Widget _questionCountButton(BuildContext context, int count, bool isWide) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: isWide ? 14 : 12),
          textStyle: GoogleFonts.poppins(
            fontSize: isWide ? 16 : 15,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 1,
        ),
        onPressed: () {
          Navigator.pop(context, count);
        },
        child: Text('$count Questions'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: CustomAppBar(
        title: 'Difficulty',
        subtitle: '${widget.subject.name} - ${widget.chapter['name']}',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 40 : 16,
                vertical: 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  AppText(
                    'Choose Difficulty',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  AppText(
                    'Select the difficulty level for your practice test',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),
                  // Difficulty Options
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // Easy Difficulty
                          _buildDifficultyCard(
                            title: 'Easy',
                            description:
                                'Basic concepts and fundamental questions. Perfect for beginners.',
                            color: AppTheme.success,
                            icon: Icons.star_rounded,
                            difficulty: 'beginner',
                          ),
                          // Medium Difficulty
                          _buildDifficultyCard(
                            title: 'Medium',
                            description:
                                'Moderate complexity with mixed question types. Good for practice.',
                            color: AppTheme.warning,
                            icon: Icons.school_rounded,
                            difficulty: 'intermediate',
                          ),
                          // Hard Difficulty
                          _buildDifficultyCard(
                            title: 'Hard',
                            description:
                                'Advanced concepts and challenging questions. For experts.',
                            color: AppTheme.error,
                            icon: Icons.military_tech_rounded,
                            difficulty: 'advanced',
                          ),
                          // More vertical space before proctoring section on desktop
                          if (isWide)
                            const SizedBox(height: 36)
                          else
                            const SizedBox(height: 20),
                          // Proctoring Section Header
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryBlue,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Proctoring Options',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Proctoring Section
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withValues(alpha: 0.10),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                              border: Border.all(
                                color:
                                    isProctored
                                        ? AppTheme.primaryBlue
                                        : Colors.grey.shade300,
                                width: isProctored ? 2.5 : 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color:
                                        isProctored
                                            ? AppTheme.primaryBlue.withValues(
                                              alpha: 0.10,
                                            )
                                            : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    isProctored
                                        ? Icons.security_rounded
                                        : Icons.security_outlined,
                                    color:
                                        isProctored
                                            ? AppTheme.primaryBlue
                                            : Colors.grey.shade600,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Proctored Test',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Prevents cheating with app monitoring',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: isProctored,
                                  onChanged: (value) {
                                    setState(() {
                                      isProctored = value;
                                    });
                                  },
                                  activeColor: AppTheme.primaryBlue,
                                  activeTrackColor: AppTheme.primaryBlue
                                      .withValues(alpha: 0.3),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
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
