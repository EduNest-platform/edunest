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
  // Students cannot change status; keep UI read-only
  int _markingMode = 0; // 0 = Quick Mark, 1 = Calendar Mark, 2 = What If Mode
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
  
  // What-if mode variables
  String? _whatIfStatus; // 'present' or 'absent' for today's simulation
  bool _isWhatIfMode = false;
  
  // Professor management status with caching
  bool _isProfessorManaged = false;
  bool? _isProfessorManagedCache;
  
  // Intelligent refresh tracking
  DateTime? _lastRefreshTime;
  static const Duration _cacheValidityDuration = Duration(minutes: 5);

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
    
    // Update last refresh time
    _lastRefreshTime = DateTime.now();

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
      // First check if this subject is professor-managed
      await _checkIfProfessorManaged();
      
      // Load attendance records with proper prioritization based on subject management
      List<AttendanceRecord> allRecords = [];
      
      if (_userProfile?.college != null ||
          _userProfile?.branch != null ||
          _userProfile?.semester != null) {
        // Load professor-managed attendance records
        List<AttendanceRecord> professorRecords = [];
        try {
          professorRecords = await _attendanceService.getStudentAttendanceByContext(
            _userProfile?.studentId ?? user.id,
            college: _userProfile?.college,
            branch: _userProfile?.branch,
            semester: _userProfile?.semester,
          );

        } catch (e) {
          // Silently handle professor-managed records error
        }
        
        // Load student self-tracked attendance records
        List<AttendanceRecord> studentRecords = [];
        try {
          studentRecords = await _attendanceService.getStudentAttendanceWithSubjectNames(
            user.id, // Always use auth user ID for the new attendance table
          );

        } catch (e) {
          // Silently handle student self-tracked records error
        }
        
        // Filter records for the current subject and prioritize based on management type
        final currentSubjectName = widget.subject['name'] ?? '';
        final professorRecordsForSubject = professorRecords.where((r) => r.subjectName == currentSubjectName).toList();
        final studentRecordsForSubject = studentRecords.where((r) => 
          r.subjectName == currentSubjectName || r.subjectName == widget.subject['code']
        ).toList();
        

        
        if (_isProfessorManaged && professorRecordsForSubject.isNotEmpty) {
          // For professor-managed subjects with professor data, use professor data only
          allRecords.addAll(professorRecords); // Add all professor records
          // Add student records for other subjects only
          allRecords.addAll(studentRecords.where((sr) => 
            sr.subjectName != currentSubjectName && sr.subjectName != widget.subject['code']
          ));
        } else {
          // For non-professor-managed subjects or when no professor data exists, use student data
          allRecords.addAll(studentRecords); // Add all student records
          // Add professor records for other subjects only
          allRecords.addAll(professorRecords.where((pr) => pr.subjectName != currentSubjectName));
        }
      } else {
        // Fallback to all records if no context info
        allRecords = await _attendanceService.getStudentAttendanceWithSubjectNames(
          user.id, // Always use auth user ID for the new attendance table
        );
      }
      
      List<AttendanceRecord> records = allRecords;

      // Try multiple matching strategies
      final subjectName = widget.subject['name'] ?? '';
      final subjectCode = widget.subject['code'] ?? '';
      
      final subjectRecords = records.where((r) => 
          r.subjectName == subjectName || 
          r.subjectName == subjectCode ||
          r.subjectName.toLowerCase() == subjectName.toLowerCase() ||
          r.subjectName.toLowerCase() == subjectCode.toLowerCase()
      ).toList();


      
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

  Future<void> _checkIfProfessorManaged() async {
    // Return cached result if available
    if (_isProfessorManagedCache != null) {
      _isProfessorManaged = _isProfessorManagedCache!;
      return;
    }
    
    try {
      // Check if this subject exists in professor_classes table
      final response = await Supabase.instance.client
          .from('professor_classes')
          .select('id')
          .eq('subject_name', widget.subject['name'] ?? '')
          .eq('college_name', _userProfile?.college ?? '')
          .eq('branch_name', _userProfile?.branch ?? '')
          .eq('semester_name', _userProfile?.semester ?? '');

      // In newer Supabase versions, response is directly the data
      _isProfessorManaged = (response as List).isNotEmpty;
      _isProfessorManagedCache = _isProfessorManaged; // Cache the result
    } catch (e) {
      _isProfessorManaged = false;
      _isProfessorManagedCache = false; // Cache the failure result too
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


    
    // Force UI update
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _markSingleAttendance(int classIdx, String status) async {
    if (!mounted) return;
    
    if (_isProfessorManaged) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attendance is managed by professors'),
          backgroundColor: AppTheme.primaryBlue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(milliseconds: 1400),
        ),
      );
      return;
    }

    // Subject not professor-managed - allow students to track their own attendance
    try {
      setState(() {
        _buttonLoadingStates[classIdx] = true;
      });

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Save to regular attendance table (not professor_attendance)
      final studentId = user.id; // Always use the auth user ID (UUID)
      final subjectId = widget.subject['code'] ?? widget.subject['name'] ?? '';
      
      // Optimistically update UI first for better UX
      setState(() {
        _classStatuses[classIdx] = status;
      });
      
      await _attendanceService.markAttendance(
        studentId: studentId,
        subjectId: subjectId,
        date: _selectedDate,
        status: status,
        college: _userProfile?.college,
        branch: _userProfile?.branch,
        semester: _userProfile?.semester,
        classNumber: classIdx + 1,
      );

      // Create optimistic record and update local records list
      final newRecord = AttendanceRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        classId: subjectId,
        studentRollNumber: _userProfile?.studentId ?? studentId,
        studentName: _userProfile?.fullName ?? '',
        date: _selectedDate,
        status: status,
        professorEmail: '',
        subjectName: widget.subject['name'] ?? '',
        collegeName: _userProfile?.college,
        branchName: _userProfile?.branch,
        semesterName: _userProfile?.semester,
        classNumber: classIdx + 1,
        createdAt: DateTime.now(),
      );
      
      // Update local records optimistically
      final existingIndex = _attendanceRecords.indexWhere(
        (r) => DateFormat('yyyy-MM-dd').format(r.date) == DateFormat('yyyy-MM-dd').format(_selectedDate) && 
               (r.classNumber ?? 1) == classIdx + 1
      );
      
      if (existingIndex >= 0) {
        _attendanceRecords[existingIndex] = newRecord;
      } else {
        _attendanceRecords.add(newRecord);
      }

      // Update final state
      setState(() {
        _buttonLoadingStates[classIdx] = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Attendance marked as $status'),
            backgroundColor: status == 'present' ? AppTheme.secondaryGreen : AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(milliseconds: 1500),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _buttonLoadingStates[classIdx] = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark attendance: ${e.toString()}'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

    // Remove from UI state and local records optimistically
    setState(() {
      _classStatuses.removeAt(classIdx);
      _classRecordIds.removeAt(classIdx);
      
      // Also remove from local attendance records if exists
      if (recordId != null) {
        _attendanceRecords.removeWhere((record) => record.id == recordId);
      }
    });
  }

  // What If calculation engine
  Map<String, dynamic> _calculateWhatIf(String simulatedStatus) {
    try {
      // Validate input
      if (simulatedStatus != 'present' && simulatedStatus != 'absent') {
        throw ArgumentError('Invalid status: $simulatedStatus');
      }
      
      // Create temporary record list with simulation
      final tempRecords = List<AttendanceRecord>.from(_attendanceRecords);
      final today = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(today);
      
      // Check if record exists for today
      final existingIndex = tempRecords.indexWhere(
        (r) => DateFormat('yyyy-MM-dd').format(r.date) == todayStr
      );
    
    if (existingIndex >= 0) {
      // Replace existing record with simulated status
      tempRecords[existingIndex] = AttendanceRecord(
        id: tempRecords[existingIndex].id,
        classId: tempRecords[existingIndex].classId,
        studentRollNumber: tempRecords[existingIndex].studentRollNumber,
        studentName: tempRecords[existingIndex].studentName,
        date: tempRecords[existingIndex].date,
        status: simulatedStatus,
        professorEmail: tempRecords[existingIndex].professorEmail,
        subjectName: tempRecords[existingIndex].subjectName,
        collegeName: tempRecords[existingIndex].collegeName,
        branchName: tempRecords[existingIndex].branchName,
        semesterName: tempRecords[existingIndex].semesterName,
        classNumber: tempRecords[existingIndex].classNumber,
        createdAt: tempRecords[existingIndex].createdAt,
      );
    } else {
      // Add new simulated record for today
      tempRecords.add(AttendanceRecord(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        classId: 'temp_class',
        studentRollNumber: _userProfile?.studentId ?? '',
        studentName: _userProfile?.fullName ?? '',
        date: today,
        status: simulatedStatus,
        professorEmail: 'temp_professor',
        subjectName: widget.subject['name'] ?? '',
        collegeName: _userProfile?.college,
        branchName: _userProfile?.branch,
        semesterName: _userProfile?.semester,
        classNumber: 1,
        createdAt: DateTime.now(),
      ));
    }
    
    // Calculate new statistics
    final totalClasses = tempRecords.length;
    final presentCount = tempRecords.where((r) => r.status == 'present').length;
    final absentCount = totalClasses - presentCount;
    final newPercentage = totalClasses > 0 ? (presentCount / totalClasses) * 100 : 0;
    
    // Calculate current statistics for comparison
    final currentTotal = _attendanceRecords.length;
    final currentPresent = _attendanceRecords.where((r) => r.status == 'present').length;
    final currentPercentage = currentTotal > 0 ? (currentPresent / currentTotal) * 100 : 0;
    
    final percentageChange = newPercentage - currentPercentage;
    final isImprovement = percentageChange > 0;
    final isBelow75Percent = newPercentage < 75.0;
    
    // Calculate classes needed for 75%
    int classesNeededFor75 = 0;
    if (newPercentage < 75.0) {
      // Formula: (presentCount + x) / (totalClasses + x) = 0.75
      // Solving for x: x = (0.75 * totalClasses - presentCount) / 0.25
      final numerator = (0.75 * totalClasses) - presentCount;
      final denominator = 0.25;
      classesNeededFor75 = (numerator / denominator).ceil().clamp(0, 100);
    }
    
      return {
        'currentPercentage': currentPercentage,
        'projectedPercentage': newPercentage,
        'percentageChange': percentageChange,
        'totalClasses': totalClasses,
        'presentCount': presentCount,
        'absentCount': absentCount,
        'isImprovement': isImprovement,
        'isBelow75Percent': isBelow75Percent,
        'classesNeededFor75': classesNeededFor75,
      };
    } catch (e) {
      // Return safe defaults on error
      return {
        'currentPercentage': 0.0,
        'projectedPercentage': 0.0,
        'percentageChange': 0.0,
        'totalClasses': 0,
        'presentCount': 0,
        'absentCount': 0,
        'isImprovement': false,
        'isBelow75Percent': true,
        'error': e.toString(),
      };
    }
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
    final shortCode = code.length > 8 ? '${code.substring(0, 8)}...' : code;
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
            SizedBox(height: isDesktop ? 16 : 10),
            isDesktop 
                ? Row(
                    children: [
                      Expanded(
                        child: _buildStatChip(
                          Icons.calendar_today,
                          '$totalClasses',
                          'Total',
                          AppTheme.primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatChip(
                          Icons.check_circle,
                          '$presentCount',
                          'Present',
                          AppTheme.secondaryGreen,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatChip(
                          Icons.cancel,
                          '$absentCount',
                          'Absent',
                          AppTheme.error,
                        ),
                      ),
                    ],
                  )
                : Wrap(
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
                    ],
                  ),
            SizedBox(height: isDesktop ? 16 : 12),
            _buildAttendanceProgressChip(
              percentValue,
              percent,
              progressColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkAttendanceSection() {
    final isWide = MediaQuery.of(context).size.width > 900;
    final bool isDesktop = isWide;
    
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isDesktop ? 20 : 16, 
        vertical: isDesktop ? 16 : 14
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isDesktop ? 24 : 22),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withValues(alpha: 0.10),
            blurRadius: isDesktop ? 20 : 18,
            offset: const Offset(0, 8),
          ),
          if (isDesktop) ...[
            BoxShadow(
              color: AppTheme.primaryBlue.withValues(alpha: 0.05),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
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
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 24 : 18, 
              vertical: isDesktop ? 24 : 18
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Segmented toggle
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundLight,
                      borderRadius: BorderRadius.circular(isDesktop ? 18 : 16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.07),
                          blurRadius: isDesktop ? 12 : 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: isDesktop 
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildSegmentedButton('Quick Mark', 0),
                              _buildSegmentedButton('Calendar Mark', 1),
                              _buildSegmentedButton('What If', 2),
                            ],
                          )
                        : Wrap(
                            children: [
                              _buildSegmentedButton('Quick Mark', 0),
                              _buildSegmentedButton('Calendar Mark', 1),
                              _buildSegmentedButton('What If', 2),
                            ],
                          ),
                  ),
                ),
                SizedBox(height: isDesktop ? 24 : 18),
                if (_markingMode == 0)
                  _buildQuickMarkSection()
                else if (_markingMode == 1)
                  _buildCalendarMarkSection()
                else
                  _buildWhatIfSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedButton(String label, int mode) {
    final selected = _markingMode == mode;
    final isWide = MediaQuery.of(context).size.width > 900;
    final bool isDesktop = isWide;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _markingMode = mode;
          if (mode == 2) {
            _isWhatIfMode = true;
            _whatIfStatus = null; // Reset what-if status
          } else {
            _isWhatIfMode = false;
            _whatIfStatus = null;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 20 : 16, 
          vertical: isDesktop ? 12 : 10
        ),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(isDesktop ? 16 : 14),
          boxShadow: selected ? [
            BoxShadow(
              color: AppTheme.primaryBlue.withValues(alpha: 0.3),
              blurRadius: isDesktop ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: selected ? Colors.white : AppTheme.primaryBlue,
            fontWeight: FontWeight.w600,
            fontSize: isDesktop ? 14 : 13,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickMarkSection() {
    final isWide = MediaQuery.of(context).size.width > 900;
    final bool isDesktop = isWide;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show management status indicator
        Container(
          padding: EdgeInsets.all(isDesktop ? 16 : 12),
          margin: EdgeInsets.only(bottom: isDesktop ? 20 : 16),
          decoration: BoxDecoration(
            color: _isProfessorManaged 
                ? AppTheme.primaryBlue.withValues(alpha: 0.08)
                : AppTheme.secondaryGreen.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(isDesktop ? 12 : 8),
            border: Border.all(
              color: _isProfessorManaged 
                  ? AppTheme.primaryBlue.withValues(alpha: 0.2)
                  : AppTheme.secondaryGreen.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _isProfessorManaged ? Icons.school : Icons.edit_note,
                color: _isProfessorManaged ? AppTheme.primaryBlue : AppTheme.secondaryGreen,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isProfessorManaged 
                      ? 'This subject is managed by professors (read-only)'
                      : 'You can track your own attendance for this subject',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: _isProfessorManaged ? AppTheme.primaryBlue : AppTheme.secondaryGreen,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        
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
                    padding: EdgeInsets.symmetric(
                      vertical: isDesktop ? 16 : 12,
                      horizontal: isDesktop ? 18 : 14,
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
        if (_markingMode == 0) SizedBox(height: isDesktop ? 24 : 18),
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
                margin: EdgeInsets.symmetric(vertical: isDesktop ? 12 : 8),
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 20 : 16,
                  vertical: isDesktop ? 20 : 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
                  border: Border.all(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.06),
                      blurRadius: isDesktop ? 12 : 8,
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

    // REPLACE the old handleSelectedButtonTap function with this new one.
// This new version now accepts the class index `idx`.
    Future<void> handleSelectedButtonTap(int idx) async {
      if (!mounted) return;

      // If the subject is professor-managed, show a snackbar and do nothing else.
      if (_isProfessorManaged) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Attendance is managed by professors and is read-only.'),
            backgroundColor: AppTheme.primaryBlue,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(milliseconds: 1500),
          ),
        );
        return;
      }

      // If student-managed, show the confirmation dialog to change attendance.
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
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

      // If the user tapped "Change", proceed to delete the record.
      if (result == true) {
        final recordId = _classRecordIds[idx];
        if (recordId != null) {
          // Set a loading state if desired
          setState(() {
            _buttonLoadingStates[idx] = true;
          });

          await _attendanceService.deleteAttendance(recordId);

          // Optimistically update local state instead of full reload
          setState(() {
            _classStatuses[idx] = null;
            _classRecordIds[idx] = null;
            _buttonLoadingStates[idx] = false;
            
            // Also remove from local attendance records
            _attendanceRecords.removeWhere((record) => record.id == recordId);
          });
        }
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
            child: GestureDetector(
              onTap: isMarked
                  ? (isPresent ? () => handleSelectedButtonTap(idx) : null) // If already present, call the dialog.
                  : () => _markSingleAttendance(idx, 'present'), // Otherwise, mark as present.
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: isPresent ? AppTheme.secondaryGreen : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isPresent
                        ? AppTheme.secondaryGreen
                        : AppTheme.secondaryGreen.withValues(alpha: 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isPresent
                          ? AppTheme.secondaryGreen.withValues(alpha: 0.3)
                          : Colors.black.withValues(alpha: 0.1),
                      blurRadius: isPresent ? 8 : 2,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: isPresent ? Colors.white : AppTheme.secondaryGreen,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Present',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isPresent ? Colors.white : AppTheme.secondaryGreen,
                      ),
                    ),
                  ],
                ),
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
            child: GestureDetector(
              onTap: isMarked
                  ? (isAbsent ? () => handleSelectedButtonTap(idx) : null) // If already absent, call the dialog.
                  : () => _markSingleAttendance(idx, 'absent'), // Otherwise, mark as absent.
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: isAbsent ? AppTheme.error : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isAbsent
                        ? AppTheme.error
                        : AppTheme.error.withValues(alpha: 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isAbsent
                          ? AppTheme.error.withValues(alpha: 0.3)
                          : Colors.black.withValues(alpha: 0.1),
                      blurRadius: isAbsent ? 8 : 2,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cancel,
                      color: isAbsent ? Colors.white : AppTheme.error,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Absent',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isAbsent ? Colors.white : AppTheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWhatIfSection() {
    final isWide = MediaQuery.of(context).size.width > 900;
    final bool isDesktop = isWide;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Info card explaining the feature
        Container(
          padding: EdgeInsets.all(isDesktop ? 20 : 16),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
            border: Border.all(
              color: AppTheme.primaryBlue.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: AppTheme.primaryBlue,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What If Mode',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'See how your attendance percentage would change if you were present or absent today. This is just a preview - no data is saved.',
                      style: GoogleFonts.poppins(
                        color: AppTheme.primaryBlue,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        
        // Current stats
        _buildCurrentStatsCard(),
        SizedBox(height: isDesktop ? 20 : 16),
        
        // What-if buttons
        Text(
          'What if you were...',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: isDesktop ? 18 : 16,
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: isDesktop ? 16 : 12),
        
        isDesktop 
            ? Row(
                children: [
                  Expanded(
                    child: _buildWhatIfButton('Present', 'present', AppTheme.secondaryGreen),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildWhatIfButton('Absent', 'absent', AppTheme.error),
                  ),
                ],
              )
            : Column(
                children: [
                  _buildWhatIfButton('Present', 'present', AppTheme.secondaryGreen),
                  const SizedBox(height: 12),
                  _buildWhatIfButton('Absent', 'absent', AppTheme.error),
                ],
              ),
        
        if (_whatIfStatus != null) ...[
          SizedBox(height: isDesktop ? 24 : 20),
          _buildWhatIfResultCard(),
        ],
      ],
    );
  }

  Widget _buildCurrentStatsCard() {
    final totalClasses = _attendanceRecords.length;
    final presentCount = _attendanceRecords.where((r) => r.status == 'present').length;
    final absentCount = _attendanceRecords.where((r) => r.status == 'absent').length;
    
    double currentPercentage = 0;
    if (totalClasses > 0) {
      currentPercentage = (presentCount / totalClasses) * 100;
    }

    // Handle case with no attendance records
    if (totalClasses == 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.dividerLight),
        ),
        child: Column(
          children: [
            Icon(
              Icons.info_outline,
              color: AppTheme.textSecondary,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'No Attendance Records',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your attendance will be recorded by professors during classes.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dividerLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Attendance',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatChip(
                  Icons.check_circle,
                  '$presentCount',
                  'Present',
                  AppTheme.secondaryGreen,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatChip(
                  Icons.cancel,
                  '$absentCount',
                  'Absent',
                  AppTheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${currentPercentage.toStringAsFixed(1)}% Attendance',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhatIfButton(String label, String status, Color color) {
    final isSelected = _whatIfStatus == status;
    final isWide = MediaQuery.of(context).size.width > 900;
    final bool isDesktop = isWide;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _whatIfStatus = status;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          vertical: isDesktop ? 20 : 16, 
          horizontal: isDesktop ? 16 : 12
        ),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
          border: Border.all(
            color: color,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: isDesktop ? 12 : 8,
              offset: const Offset(0, 4),
            ),
          ] : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              status == 'present' ? Icons.check_circle : Icons.cancel,
              color: isSelected ? Colors.white : color,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : color,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWhatIfResultCard() {
    if (_whatIfStatus == null) return const SizedBox.shrink();
    
    final result = _calculateWhatIf(_whatIfStatus!);
    
    // Check for calculation errors
    if (result.containsKey('error')) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.error.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: AppTheme.error, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Unable to calculate projection. Please try again.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppTheme.error,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final currentPercentage = (result['currentPercentage'] as num).toDouble();
    final projectedPercentage = (result['projectedPercentage'] as num).toDouble();
    final percentageChange = (result['percentageChange'] as num).toDouble();
    final isImprovement = result['isImprovement'] as bool;
    final isBelow75Percent = result['isBelow75Percent'] as bool;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isBelow75Percent 
          ? AppTheme.error.withValues(alpha: 0.05)
          : isImprovement 
            ? AppTheme.secondaryGreen.withValues(alpha: 0.05)
            : AppTheme.primaryBlue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBelow75Percent 
            ? AppTheme.error.withValues(alpha: 0.3)
            : isImprovement 
              ? AppTheme.secondaryGreen.withValues(alpha: 0.3)
              : AppTheme.primaryBlue.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.preview,
                color: AppTheme.primaryBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Projected Result',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      '${currentPercentage.toStringAsFixed(1)}%',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward,
                color: AppTheme.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Projected',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      '${projectedPercentage.toStringAsFixed(1)}%',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: isBelow75Percent 
                          ? AppTheme.error
                          : isImprovement 
                            ? AppTheme.secondaryGreen
                            : AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  isImprovement ? Icons.trending_up : Icons.trending_down,
                  color: isImprovement ? AppTheme.secondaryGreen : AppTheme.error,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  '${isImprovement ? '+' : ''}${percentageChange.toStringAsFixed(1)}% change',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                    color: isImprovement ? AppTheme.secondaryGreen : AppTheme.error,
                  ),
                ),
              ],
            ),
          ),
          
          if (isBelow75Percent) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    color: AppTheme.error,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Below 75% attendance threshold',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppTheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.school,
                    color: AppTheme.primaryBlue,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Need ${result['classesNeededFor75']} more classes present to reach 75%',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppTheme.primaryBlue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
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
              color: isPresent
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
                          icon: _loading
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
                          onPressed: _loading
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
                    child: _initialLoading
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
                icon: _loading
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
                onPressed: _loading
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
        body: _initialLoading
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
