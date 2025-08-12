import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../models/attendance_record.dart';
import '../../../services/attendance_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../services/user_profile_service.dart';
import '../../../models/user_profile.dart';
import '../../../services/network_service.dart';
import '../../../services/error_message_service.dart';
// import '../../../mixins/performance_mixin.dart';
import '../../../widgets/custom_app_bar.dart'; // Added import for CustomAppBar
import '../../../widgets/desktop_sidebar.dart';

// HeaderCard widget for section containers
class HeaderCard extends StatelessWidget {
  final String title;
  final Widget child;
  const HeaderCard({required this.title, required this.child, super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
          Text(
            title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class AttendanceTrackingScreen extends StatefulWidget {
  final Map<String, String> subject;

  const AttendanceTrackingScreen({super.key, required this.subject});

  @override
  State<AttendanceTrackingScreen> createState() =>
      _AttendanceTrackingScreenState();
}

class _AttendanceTrackingScreenState extends State<AttendanceTrackingScreen>
    with TickerProviderStateMixin {
  final AttendanceService _attendanceService = AttendanceService();
  final NetworkService _networkService = NetworkService();
  List<AttendanceRecord> _attendanceRecords = [];
  bool _loading = true;
  bool _initialLoading = true;
  DateTime _selectedDate = DateTime.now();
  String? _selectedStatus;
  int _markingMode = 0; // 0 = Quick Mark, 1 = Calendar Mark
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  List<String?> _classStatuses = [
    null,
  ]; // default one class, no status selected
  List<String?> _classRecordIds = [null]; // Track record IDs for undo
  CalendarFormat _calendarFormat = CalendarFormat.week;
  UserProfile? _userProfile;
  bool _hasNetworkError = false;

  // Add loading states for individual buttons
  final Map<int, bool> _buttonLoadingStates = {};
  bool _isMarkingAttendance = false; // Global marking state

  @override
  void initState() {
    super.initState();
    // startScreenMonitoring('attendance_tracking_screen');
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _loadUserProfileAndAttendance();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    // stopScreenMonitoring();
    super.dispose();
  }

  Future<void> _loadUserProfileAndAttendance() async {
    // Check network connectivity first
    final networkStatus = await _networkService.isConnected();

    if (!networkStatus) {
      setState(() {
        _hasNetworkError = true;
        _loading = false;
        _initialLoading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _initialLoading = false;
      _hasNetworkError = false;
    });

    // Load user profile first
    _userProfile = await UserProfileService.getCurrentUserProfile();

    // Then load attendance records
    await _loadAttendanceRecords();

    setState(() {
      _loading = false;
    });
  }

  Future<void> _retryWithNetworkCheck() async {
    setState(() {
      _initialLoading = true;
      _hasNetworkError = false;
    });

    final networkStatus = await _networkService.isConnected();

    if (networkStatus) {
      await _loadUserProfileAndAttendance();
    } else {
      setState(() {
        _hasNetworkError = true;
        _initialLoading = false;
      });
    }
  }

  Future<void> _loadAttendanceRecords() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      List<AttendanceRecord> records;

      // If user profile has college/branch/semester info, filter by context
      if (_userProfile?.college != null ||
          _userProfile?.branch != null ||
          _userProfile?.semester != null) {
        // Use roll number as key; fallback to user.id if missing
        records = await _attendanceService.getStudentAttendanceByContext(
          _userProfile?.studentId ?? user.id,
          college: _userProfile?.college,
          branch: _userProfile?.branch,
          semester: _userProfile?.semester,
        );
      } else {
        // Fallback to all records if no context info
        records = await _attendanceService.getStudentAttendance(
          _userProfile?.studentId ?? user.id,
        );
      }

      final subjectRecords =
          records.where((r) => r.subjectId == widget.subject['code']).toList();

      // Only update state if the widget is still mounted
      if (mounted) {
        setState(() {
          _attendanceRecords = subjectRecords;
        });

        // Sync current attendance status with loaded records
        _syncCurrentAttendanceStatus();
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

  // Validate user profile data
  bool _validateUserProfile() {
    if (_userProfile == null) return false;

    // Check if essential profile fields are filled
    final hasCollege =
        _userProfile!.college != null &&
        _userProfile!.college!.trim().isNotEmpty;
    final hasBranch =
        _userProfile!.branch != null && _userProfile!.branch!.trim().isNotEmpty;
    final hasSemester =
        _userProfile!.semester != null &&
        _userProfile!.semester!.toString().trim().isNotEmpty;

    return hasCollege && hasBranch && hasSemester;
  }

  // Sync current attendance status with loaded records
  void _syncCurrentAttendanceStatus() {
    final todayString = DateFormat('yyyy-MM-dd').format(_selectedDate);

    // Find attendance records for today's date
    final todayRecords =
        _attendanceRecords.where((record) {
          final recordDateString = DateFormat('yyyy-MM-dd').format(record.date);
          return recordDateString == todayString;
        }).toList();

    // Reset current status
    _classStatuses = [null];
    _classRecordIds = [null];

    // Update status based on loaded records
    for (final record in todayRecords) {
      final classNumber = record.classNumber ?? 1;
      final classIndex = classNumber - 1; // Convert to 0-based index

      // Ensure we have enough slots in the arrays
      while (_classStatuses.length <= classIndex) {
        _classStatuses.add(null);
        _classRecordIds.add(null);
      }

      // Set the status and record ID
      _classStatuses[classIndex] = record.status;
      _classRecordIds[classIndex] = record.id;
    }

    // Trigger UI update - no state changes needed here
  }

  Future<void> _markSingleAttendance(int classIdx, String status) async {
    // Prevent multiple simultaneous calls
    if (_isMarkingAttendance || _buttonLoadingStates[classIdx] == true) {
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please login to mark attendance'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    // Validate user profile data before marking attendance
    if (!_validateUserProfile()) {
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text(
                'Incomplete Profile',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
              content: Text(
                'Your profile information (college, branch, semester) is incomplete. This may cause attendance marking to fail. Do you want to continue anyway?',
                style: GoogleFonts.poppins(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Cancel', style: GoogleFonts.poppins()),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    'Continue',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
      );

      if (shouldContinue != true) {
        return;
      }
    }

    // Set loading states
    setState(() {
      _isMarkingAttendance = true;
      _buttonLoadingStates[classIdx] = true;
    });

    try {
      final recordId = await _attendanceService.markAttendance(
        studentId: user.id,
        subjectId: widget.subject['code']!,
        date: _selectedDate,
        status: status,
        college: _userProfile?.college,
        branch: _userProfile?.branch,
        semester: _userProfile?.semester,
        classNumber: classIdx + 1,
      );

      // Update UI immediately for better responsiveness
      setState(() {
        _classStatuses[classIdx] = status;
        _classRecordIds[classIdx] = recordId;
        _buttonLoadingStates[classIdx] = false;
        _isMarkingAttendance = false;
      });

      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Marked $status for Class ${classIdx + 1}'),
            backgroundColor:
                status == 'present' ? AppTheme.secondaryGreen : AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(milliseconds: 900),
          ),
        );
      }

      // Refresh attendance records in background
      _loadAttendanceRecords();
    } catch (e) {
      // Enhanced error handling for attendance marking
      String message;
      if (e.toString().contains('400')) {
        message =
            'Invalid data format. Please check your profile information and try again.';
      } else if (e.toString().contains('duplicate key') ||
          e.toString().contains('unique constraint')) {
        message = 'Attendance record already exists for this class.';
      } else if (e.toString().contains('network') ||
          e.toString().contains('connection')) {
        message =
            'Network error. Please check your internet connection and try again.';
      } else {
        message = ErrorMessageService.getFriendlyMessage(e);
      }

      setState(() {
        _buttonLoadingStates[classIdx] = false;
        _isMarkingAttendance = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _markSingleAttendance(classIdx, status),
            ),
          ),
        );
      }
    }
  }

  Future<void> _removeClass(int classIdx) async {
    // Show confirmation dialog
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Remove Class?',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            content: Text(
              'This will remove Class ${classIdx + 1} and delete any attendance record for this class. This action cannot be undone.',
              style: GoogleFonts.poppins(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel', style: GoogleFonts.poppins()),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  'Remove',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.error,
                  ),
                ),
              ),
            ],
          ),
    );

    if (shouldRemove != true) return;

    // Check if there's an attendance record to delete
    final recordId = _classRecordIds[classIdx];

    if (recordId != null) {
      // Delete attendance record from backend
      try {
        await _attendanceService.deleteAttendance(recordId);

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Class ${classIdx + 1} and attendance record removed',
              ),
              backgroundColor: AppTheme.secondaryGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(milliseconds: 1500),
            ),
          );
        }
      } catch (e) {
        final message = ErrorMessageService.getFriendlyMessage(e);
        // Show error message if deletion fails
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.red),
          );
        }
        return; // Don't remove from UI if backend deletion failed
      }
    }

    // Remove from UI state
    setState(() {
      _classStatuses.removeAt(classIdx);
      _classRecordIds.removeAt(classIdx);
    });

    // Refresh attendance records to sync with backend
    await _loadAttendanceRecords();
  }

  Widget _buildStatChip(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 17,
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.poppins(fontSize: 13, color: color)),
        ],
      ),
    );
  }

  Widget _buildAttendanceProgressChip(
    double percentValue,
    String percent,
    Color progressColor,
  ) {
    final totalClasses = _attendanceRecords.length;
    final motivationalText = _getClassesNeededFor75Percent(
      percentValue,
      totalClasses,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: progressColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: progressColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: progressColor.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.how_to_reg, color: progressColor, size: 22),
              const SizedBox(width: 8),
              Text(
                percent == '--' ? '--' : '$percent%',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: progressColor,
                  fontSize: 17,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Attendance',
                style: GoogleFonts.poppins(fontSize: 13, color: progressColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Integrated progress bar
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: percentValue),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder:
                (context, value, child) => Container(
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.grey.shade200,
                    border: Border.all(color: Colors.grey.shade300, width: 0.5),
                  ),
                  child: Stack(
                    children: [
                      // Progress fill with enhanced design
                      FractionallySizedBox(
                        widthFactor: value,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            gradient: LinearGradient(
                              colors: [
                                progressColor.withValues(alpha: 0.8),
                                progressColor,
                                progressColor.withValues(alpha: 0.9),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: progressColor.withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.2),
                                  Colors.transparent,
                                  Colors.white.withValues(alpha: 0.1),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
          const SizedBox(height: 4),
          // Status indicator
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: progressColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: progressColor.withValues(alpha: 0.4),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _getProgressStatus(percentValue),
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: progressColor,
                ),
              ),
            ],
          ),
          // Motivational text (only shown when below 75%)
          if (motivationalText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: progressColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: progressColor.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Text(
                motivationalText,
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: progressColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    final totalClasses = _attendanceRecords.length;
    final presentCount =
        _attendanceRecords.where((r) => r.status == 'present').length;
    final absentCount =
        _attendanceRecords.where((r) => r.status == 'absent').length;
    String percent = '--';
    double percentValue = 0;
    if (totalClasses > 0) {
      percentValue = presentCount / totalClasses;
      percent = (percentValue * 100).toStringAsFixed(1);
    }
    final code = widget.subject['code'] ?? '';
    final shortCode = code.length > 6 ? '${code.substring(0, 6)}...' : code;
    Color progressColor;
    if (percentValue < 0.3) {
      progressColor = AppTheme.error; // Red for below 30%
    } else if (percentValue < 0.5) {
      progressColor = AppTheme.accentOrange; // Orange for 30-50%
    } else if (percentValue < 0.75) {
      progressColor = Colors.amber; // Yellow/Amber for 50-75%
    } else if (percentValue < 0.9) {
      progressColor = Colors.lightGreen; // Light green for 75-90%
    } else {
      progressColor = AppTheme.secondaryGreen; // Dark green for above 90%
    }
    final isWide = MediaQuery.of(context).size.width > 900;
    final bool isDesktop = isWide;
    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeIn,
      child: Container(
        margin: EdgeInsets.symmetric(
          vertical: isDesktop ? 16 : 6,
          horizontal: 20,
        ),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Colors.white,
          boxShadow: [
            // 3D effect with multiple shadows
            BoxShadow(
              color: AppTheme.primaryBlue.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: AppTheme.primaryBlue.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: AppTheme.primaryBlue.withValues(alpha: 0.16),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: AppTheme.primaryBlue.withValues(alpha: 0.20),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.menu_book_rounded,
                    color: AppTheme.primaryBlue,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.subject['name'] ?? '',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          letterSpacing: 0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Code: $shortCode',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                _buildStatChip(
                  Icons.calendar_today,
                  '$totalClasses',
                  'Total',
                  AppTheme.primaryBlue,
                ),
                _buildStatChip(
                  Icons.check_circle,
                  '$presentCount',
                  'Present',
                  AppTheme.secondaryGreen,
                ),
                _buildStatChip(
                  Icons.cancel,
                  '$absentCount',
                  'Absent',
                  AppTheme.error,
                ),
                _buildAttendanceProgressChip(
                  percentValue,
                  percent,
                  progressColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkAttendanceSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: AppTheme.primaryBlue.withValues(alpha: 0.13),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Accent bar
          Container(
            height: 5,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Segmented toggle
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundLight,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.07),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSegmentedButton('Quick Mark', 0),
                        _buildSegmentedButton('Calendar Mark', 1),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                if (_markingMode == 0)
                  _buildQuickMarkSection()
                else
                  _buildCalendarMarkSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedButton(String label, int mode) {
    final selected = _markingMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _markingMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: selected ? Colors.white : AppTheme.primaryBlue,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickMarkSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_markingMode == 0) // Only show date picker in Quick Mark mode
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => _selectedDate = date);
                      // Sync attendance status for the new date
                      _syncCurrentAttendanceStatus();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: AppTheme.primaryBlue,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('MMM dd, yyyy').format(_selectedDate),
                          style: GoogleFonts.poppins(
                            color: AppTheme.primaryBlue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        if (_markingMode == 0) const SizedBox(height: 18),
        // Main class (no label)
        _buildAnimatedAttendanceButtons(0),
        // Extra classes (Class 2, 3, ...)
        if (_classStatuses.length > 1)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _classStatuses.length - 1,
            itemBuilder: (context, idx) {
              final realIdx = idx + 1;
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Class ${realIdx + 1}',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.error.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.remove_circle_outline,
                              color: AppTheme.error,
                              size: 22,
                            ),
                            tooltip: 'Remove class',
                            onPressed: () => _removeClass(realIdx),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Present and Absent buttons - same as main class
                    _buildAnimatedAttendanceButtons(realIdx),
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: 16),
        Center(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed:
                  _classStatuses.length < 6
                      ? () => setState(() {
                        _classStatuses.add(null);
                        _classRecordIds.add(null);
                      })
                      : null,
              icon: Icon(Icons.add_circle_outline, size: 20),
              label: Text(
                'Add Class',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shadowColor: AppTheme.primaryBlue.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarMarkSection() {
    // Build a map of date strings to status for quick lookup
    final Map<String, String> dateStatus = {};
    for (final record in _attendanceRecords) {
      final dateStr = DateFormat('yyyy-MM-dd').format(record.date);
      dateStatus[dateStr] = record.status;
    }
    return Column(
      children: [
        // Calendar Card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppTheme.primaryBlue.withValues(alpha: 0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Calendar Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Calendar View',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ),
                  // Toggle button for week/month view
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _calendarFormat =
                            _calendarFormat == CalendarFormat.month
                                ? CalendarFormat.week
                                : CalendarFormat.month;
                      });
                    },
                    icon: Icon(
                      _calendarFormat == CalendarFormat.month
                          ? Icons.view_week
                          : Icons.calendar_month,
                      color: AppTheme.primaryBlue,
                      size: 18,
                    ),
                    label: Text(
                      _calendarFormat == CalendarFormat.month
                          ? 'Week'
                          : 'Month',
                      style: GoogleFonts.poppins(
                        color: AppTheme.primaryBlue,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Calendar
              TableCalendar(
                firstDay: DateTime(2020),
                lastDay: DateTime.now(),
                focusedDay: _selectedDate,
                calendarFormat: _calendarFormat,
                onFormatChanged: (format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                },
                selectedDayPredicate: (day) => isSameDay(day, _selectedDate),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDate = selectedDay;
                  });
                },
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: AppTheme.accentOrange,
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: AppTheme.primaryBlue,
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: BoxDecoration(
                    color: AppTheme.secondaryGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, focusedDay) {
                    final dateStr = DateFormat('yyyy-MM-dd').format(day);
                    if (dateStatus[dateStr] == 'present') {
                      return Container(
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryGreen,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${day.day}',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    } else if (dateStatus[dateStr] == 'absent') {
                      return Container(
                        decoration: BoxDecoration(
                          color: AppTheme.error,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${day.day}',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }
                    return null;
                  },
                  todayBuilder: (context, day, focusedDay) {
                    final dateStr = DateFormat('yyyy-MM-dd').format(day);
                    if (dateStatus[dateStr] == 'present') {
                      return Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryGreen,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${day.day}',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    } else if (dateStatus[dateStr] == 'absent') {
                      return Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.error,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${day.day}',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }
                    // Today (not present/absent)
                    return Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppTheme.accentOrange,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${day.day}',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                  selectedBuilder: (context, day, focusedDay) {
                    final dateStr = DateFormat('yyyy-MM-dd').format(day);
                    if (dateStatus[dateStr] == 'present') {
                      return Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryGreen,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${day.day}',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    } else if (dateStatus[dateStr] == 'absent') {
                      return Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.error,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${day.day}',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    } else if (isSameDay(day, DateTime.now())) {
                      // Today and selected, but not present/absent
                      return Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.accentOrange,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${day.day}',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }
                    // Selected but not today/present/absent
                    return Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${day.day}',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Attendance Marking Section (same as quick mark, no card wrapper)
        _buildQuickMarkSection(),
      ],
    );
  }

  Widget _buildAnimatedAttendanceButtons(int idx) {
    final isPresent = _classStatuses[idx] == 'present';
    final isAbsent = _classStatuses[idx] == 'absent';
    final isMarked = isPresent || isAbsent;
    final isLoading = _buttonLoadingStates[idx] == true;

    Future<void> handleSelectedButtonTap() async {
      if (isLoading) return; // Prevent multiple taps

      final result = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text(
                'Change Attendance?',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
              content: Text(
                'Do you want to change your attendance for this class?',
                style: GoogleFonts.poppins(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Cancel', style: GoogleFonts.poppins()),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    'Change',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
      );
      if (result == true) {
        // Remove attendance record and reset selection
        final recordId = _classRecordIds[idx];
        if (recordId != null) {
          await _attendanceService.deleteAttendance(recordId);
          await _loadAttendanceRecords();
        }
        setState(() {
          _classStatuses[idx] = null;
          _classRecordIds[idx] = null;
        });
      }
    }

    return Row(
      children: [
        // Present Button
        Expanded(
          child: AnimatedScale(
            scale: isPresent ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutBack,
            child: ElevatedButton.icon(
              onPressed:
                  isLoading
                      ? null // Disable button when loading
                      : isMarked
                      ? (isPresent ? handleSelectedButtonTap : null)
                      : () => _markSingleAttendance(idx, 'present'),
              icon: Icon(
                Icons.check_circle,
                color: isPresent ? Colors.white : AppTheme.secondaryGreen,
                size: 22,
              ),
              label: Text(
                'Present',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isPresent ? AppTheme.secondaryGreen : Colors.white,
                foregroundColor:
                    isPresent ? Colors.white : AppTheme.secondaryGreen,
                minimumSize: const Size(0, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color:
                        isPresent
                            ? AppTheme.secondaryGreen
                            : AppTheme.secondaryGreen.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                elevation: isPresent ? 8 : 2,
                shadowColor:
                    isPresent
                        ? AppTheme.secondaryGreen.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.1),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Absent Button
        Expanded(
          child: AnimatedScale(
            scale: isAbsent ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutBack,
            child: ElevatedButton.icon(
              onPressed:
                  isLoading
                      ? null // Disable button when loading
                      : isMarked
                      ? (isAbsent ? handleSelectedButtonTap : null)
                      : () => _markSingleAttendance(idx, 'absent'),
              icon: Icon(
                Icons.cancel,
                color: isAbsent ? Colors.white : AppTheme.error,
                size: 22,
              ),
              label: Text(
                'Absent',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isAbsent ? AppTheme.error : Colors.white,
                foregroundColor: isAbsent ? Colors.white : AppTheme.error,
                minimumSize: const Size(0, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color:
                        isAbsent
                            ? AppTheme.error
                            : AppTheme.error.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                elevation: isAbsent ? 8 : 2,
                shadowColor:
                    isAbsent
                        ? AppTheme.error.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.1),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceHistory() {
    if (_attendanceRecords.isEmpty) {
      return HeaderCard(
        title: 'History',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Text(
              'No attendance records yet',
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ),
      );
    }
    final sorted = [..._attendanceRecords]
      ..sort((a, b) => b.date.compareTo(a.date));
    // Group by month
    final Map<String, List<AttendanceRecord>> grouped = {};
    for (final record in sorted) {
      final key = DateFormat('MMMM yyyy').format(record.date);
      grouped.putIfAbsent(key, () => []).add(record);
    }
    return HeaderCard(
      title: 'History',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...grouped.entries.map(
            (entry) => _buildMonthHistory(entry.key, entry.value),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthHistory(String month, List<AttendanceRecord> records) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            month,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: AppTheme.primaryBlue,
            ),
          ),
        ),
        ...records.map((record) => _buildHistoryRow(record)),
        Divider(color: AppTheme.dividerLight, height: 1),
      ],
    );
  }

  Widget _buildHistoryRow(AttendanceRecord record) {
    final isPresent = record.status == 'present';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              DateFormat('MMM dd, yyyy').format(record.date),
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color:
                  isPresent
                      ? AppTheme.secondaryGreen.withValues(alpha: 0.13)
                      : AppTheme.error.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isPresent ? 'Present' : 'Absent',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                color: isPresent ? AppTheme.secondaryGreen : AppTheme.error,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getProgressStatus(double percentValue) {
    if (percentValue < 0.3) {
      return 'Critical';
    } else if (percentValue < 0.5) {
      return 'Very Low';
    } else if (percentValue < 0.75) {
      return 'Needs Improvement';
    } else if (percentValue < 0.9) {
      return 'Good';
    } else {
      return 'Excellent';
    }
  }

  // Calculate classes needed to reach 75% attendance
  // This assumes the student will attend ALL future classes consecutively
  // Formula: (presentCount + x) / (totalClasses + x) = 0.75
  // Where x is the number of consecutive classes needed to reach 75%
  String _getClassesNeededFor75Percent(double percentValue, int totalClasses) {
    if (percentValue >= 0.75) return ''; // Already at or above 75%
    if (totalClasses == 0) return ''; // No classes yet

    final presentCount = (percentValue * totalClasses).round();

    // To reach 75%: (presentCount + x) / (totalClasses + x) = 0.75
    // Solving for x: presentCount + x = 0.75 * (totalClasses + x)
    // presentCount + x = 0.75 * totalClasses + 0.75 * x
    // x - 0.75 * x = 0.75 * totalClasses - presentCount
    // 0.25 * x = 0.75 * totalClasses - presentCount
    // x = (0.75 * totalClasses - presentCount) / 0.25
    // x = 3 * totalClasses - 4 * presentCount

    final classesNeeded = (3 * totalClasses - 4 * presentCount).ceil();

    // Handle edge cases
    if (classesNeeded <= 0) return '';
    if (classesNeeded > 20) {
      return 'Attend consistently to improve'; // Too many classes needed
    }

    return 'Need $classesNeeded more class${classesNeeded > 1 ? 'es' : ''} for 75%';
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;
    final isDesktop = isWide;
    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        body: Row(
          children: [
            DesktopSidebar(
              selected: 'attendance',
              onNavigate: (route) => Navigator.pushNamed(context, route),
            ),
            Expanded(
              child: Column(
                children: [
                  PreferredSize(
                    preferredSize: const Size.fromHeight(72),
                    child: CustomAppBar(
                      title: 'Attendance',
                      subtitle: 'Track your attendance easily',
                      leading: IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: AppTheme.primaryBlue,
                          size: 20,
                        ),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      actions: [
                        IconButton(
                          icon:
                              _loading
                                  ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppTheme.primaryBlue,
                                      ),
                                    ),
                                  )
                                  : Icon(
                                    Icons.refresh_rounded,
                                    color: AppTheme.primaryBlue,
                                    size: 22,
                                  ),
                          onPressed:
                              _loading
                                  ? null
                                  : () async {
                                    setState(() {
                                      _loading = true;
                                    });
                                    await _retryWithNetworkCheck();
                                    setState(() {
                                      _loading = false;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Attendance data refreshed',
                                        ),
                                        backgroundColor:
                                            AppTheme.secondaryGreen,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        duration: const Duration(
                                          milliseconds: 1500,
                                        ),
                                      ),
                                    );
                                  },
                          tooltip: 'Refresh attendance data',
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child:
                        _initialLoading
                            ? const Center(child: CircularProgressIndicator())
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
                                        '📊',
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
                                      'Unable to load attendance tracking data. Please connect to the internet and try again.',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 32),
                                    ElevatedButton.icon(
                                      onPressed: _retryWithNetworkCheck,
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
                            : FadeTransition(
                              opacity: _fadeAnimation,
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 900,
                                  ),
                                  child: ListView(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isWide ? 32 : 0,
                                      vertical: 18,
                                    ),
                                    children: [
                                      _buildHeaderCard(),
                                      _buildMarkAttendanceSection(),
                                      _buildAttendanceHistory(),
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
    } else {
      return Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: CustomAppBar(
            title: 'Attendance',
            subtitle: 'Track your attendance easily',
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppTheme.primaryBlue,
                size: 20,
              ),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            actions: [
              IconButton(
                icon:
                    _loading
                        ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.primaryBlue,
                            ),
                          ),
                        )
                        : Icon(
                          Icons.refresh_rounded,
                          color: AppTheme.primaryBlue,
                          size: 22,
                        ),
                onPressed:
                    _loading
                        ? null
                        : () async {
                          setState(() {
                            _loading = true;
                          });
                          await _retryWithNetworkCheck();
                          setState(() {
                            _loading = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Attendance data refreshed'),
                              backgroundColor: AppTheme.secondaryGreen,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              duration: const Duration(milliseconds: 1500),
                            ),
                          );
                        },
                tooltip: 'Refresh attendance data',
              ),
            ],
          ),
        ),
        body:
            _initialLoading
                ? const Center(child: CircularProgressIndicator())
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
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: const Text(
                            '📊',
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
                          'Unable to load attendance tracking data. Please connect to the internet and try again.',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: _retryWithNetworkCheck,
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
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                : FadeTransition(
                  opacity: _fadeAnimation,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: ListView(
                        padding: EdgeInsets.symmetric(
                          horizontal: isWide ? 32 : 0,
                          vertical: 10,
                        ),
                        children: [
                          _buildHeaderCard(),
                          _buildMarkAttendanceSection(),
                          _buildAttendanceHistory(),
                        ],
                      ),
                    ),
                  ),
                ),
      );
    }
  }
}
