import 'package:flutter/material.dart';
import '../../../services/attendance_service.dart';
import '../../../models/attendance_record.dart';
import '../../../services/subjects_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/user_profile_service.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import 'attendance_tracking_screen.dart';
import '../../../widgets/custom_app_bar.dart';
import '../../../services/network_service.dart';
import '../../../services/error_message_service.dart';
import 'package:flutter/foundation.dart';
import '../../../widgets/desktop_sidebar.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with SingleTickerProviderStateMixin, NetworkAwareMixin {
  final AttendanceService _attendanceService = AttendanceService();
  final NetworkService _networkService = NetworkService();
  bool _loading = false;
  bool _initialLoading = true;
  List<AttendanceRecord> _attendanceRecords = [];
  List<Map<String, String>> _subjects = [];
  String? _semesterFromProfile;
  bool _hasNetworkError = false;

  @override
  void initState() {
    super.initState();
    _fetchAttendanceAndSubjects();
  }

  Future<void> _fetchAttendanceAndSubjects() async {
    setState(() {
      _initialLoading = true;
      _hasNetworkError = false;
    });

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

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final profile = await UserProfileService.getCurrentUserProfile();
      if (profile == null || profile.semester == null) {
        setState(() {
          _loading = false;
        });
        return;
      }

      _semesterFromProfile = profile.semester.toString();
      final allSubjects = await SubjectsService.getAllSubjects();
      final filtered =
          allSubjects.where((s) {
            final subjectCollege =
                s.semester?.branch?.college?.name.toLowerCase() ?? '';
            final userCollege = (profile.college ?? '').toLowerCase();
            final subjectBranch = s.semester?.branch?.name.toLowerCase() ?? '';
            final userBranch = (profile.branch ?? '').toLowerCase();
            final subjectSemester = s.semester?.name.toLowerCase() ?? '';
            final userSemester = (profile.semester ?? '').toLowerCase();
            return (subjectCollege.contains(userCollege) ||
                    userCollege.contains(subjectCollege)) &&
                (subjectBranch.contains(userBranch) ||
                    userBranch.contains(subjectBranch)) &&
                (subjectSemester.contains(userSemester) ||
                    userSemester.contains(subjectSemester));
          }).toList();
      _subjects = filtered.map((s) => {'name': s.name, 'code': s.id}).toList();

      List<AttendanceRecord> records;
      if (profile.college != null ||
          profile.branch != null ||
          profile.semester != null) {
        // Use roll number as the key for fetching attendance
        records = await _attendanceService.getStudentAttendanceByContext(
          profile.studentId ?? user.id,
          college: profile.college,
          branch: profile.branch,
          semester: profile.semester,
        );
      } else {
        records = await _attendanceService.getStudentAttendance(
          profile.studentId ?? user.id,
        );
      }

      setState(() {
        _attendanceRecords = records;
        _loading = false;
        _hasNetworkError = false;
      });
    } catch (e) {
      final message = ErrorMessageService.getFriendlyMessage(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _retryWithNetworkCheck() async {
    setState(() {
      _initialLoading = true;
      _hasNetworkError = false;
    });

    await refreshNetworkStatus();
    final networkStatus = await _networkService.isConnected();

    if (networkStatus) {
      await _fetchAttendanceAndSubjects();
    } else {
      setState(() {
        _hasNetworkError = true;
        _initialLoading = false;
      });
    }
  }

  void _removeSubject(int index) {
    setState(() {
      _subjects.removeAt(index);
    });
  }

  bool _isDuplicateCode(String code) {
    return _subjects.any((s) => s['code'] == code);
  }

  void _addSubjectDialog() {
    String name = '';
    String code = '';
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder:
          (context) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400, maxHeight: 350),
              child: Material(
                color: Colors.white,
                elevation: 16,
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 28,
                  ),
                  child: StatefulBuilder(
                    builder:
                        (context, setStateDialog) => SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Text(
                                  'Add Subject',
                                  style: GoogleFonts.poppins(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryBlue,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              TextField(
                                decoration: InputDecoration(
                                  labelText: 'Subject Name',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: AppTheme.primaryBlue,
                                    ),
                                  ),
                                ),
                                onChanged: (value) => name = value,
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                decoration: InputDecoration(
                                  labelText: 'Subject Code',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: AppTheme.primaryBlue,
                                    ),
                                  ),
                                ),
                                onChanged: (value) => code = value,
                              ),
                              const SizedBox(height: 22),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppTheme.textSecondary,
                                      textStyle: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    child: const Text('Cancel'),
                                  ),
                                  const SizedBox(width: 10),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryBlue,
                                      foregroundColor: AppTheme.textInverse,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                      textStyle: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                      ),
                                      elevation: 0,
                                    ),
                                    onPressed: () {
                                      if (name.trim().isNotEmpty &&
                                          code.trim().isNotEmpty &&
                                          !_isDuplicateCode(code.trim())) {
                                        setState(() {
                                          _subjects.add({
                                            'name': name.trim(),
                                            'code': code.trim(),
                                          });
                                        });
                                        Navigator.pop(context);
                                      }
                                    },
                                    child: const Text('Add'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                  ),
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildSubjectCard(Map<String, String> subject, int index) {
    final subjectRecords =
        _attendanceRecords
            .where((r) => r.subjectId == subject['code'])
            .toList();
    final presentCount =
        subjectRecords.where((r) => r.status == 'present').length;
    final absentCount =
        subjectRecords.where((r) => r.status == 'absent').length;
    final total = subjectRecords.length;
    final percent =
        total > 0 ? (presentCount / total * 100).toStringAsFixed(1) : '0';
    final Color accentColor =
        [
          AppTheme.primaryBlue,
          AppTheme.secondaryGreen,
          AppTheme.accentOrange,
          AppTheme.codeIcon,
          AppTheme.labManualsIcon,
          AppTheme.pyqIcon,
          AppTheme.primaryLight,
          AppTheme.secondaryLight,
          AppTheme.accentLight,
        ][index % 9];

    final isWide = MediaQuery.of(context).size.width > 900;
    final bool isDesktop =
        kIsWeb ||
        Theme.of(context).platform == TargetPlatform.windows ||
        Theme.of(context).platform == TargetPlatform.linux ||
        Theme.of(context).platform == TargetPlatform.macOS;

    Widget presentChip =
        isDesktop
            ? Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryGreen.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: AppTheme.secondaryGreen,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$presentCount',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.secondaryGreen,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'Present',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppTheme.secondaryGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
            : Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.secondaryGreen.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: AppTheme.secondaryGreen,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$presentCount',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.secondaryGreen,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'Present',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppTheme.secondaryGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );

    Widget absentChip =
        isDesktop
            ? Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cancel, color: AppTheme.error, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '$absentCount',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.error,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'Absent',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppTheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
            : Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cancel, color: AppTheme.error, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '$absentCount',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.error,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'Absent',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppTheme.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );

    Widget percentChip =
        isDesktop
            ? Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calculate,
                      color: AppTheme.primaryBlue,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      percent,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '% Attendance',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.primaryBlue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
            : Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calculate, color: AppTheme.primaryBlue, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    percent,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '% Attendance',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AttendanceTrackingScreen(subject: subject),
          ),
        );
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          margin:
              isDesktop
                  ? const EdgeInsets.only(bottom: 16)
                  : const EdgeInsets.only(bottom: 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Accent bar
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.book_rounded,
                        color: accentColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subject['name'] ?? '',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Code: ${(subject['code'] ?? '').length > 8 ? ('${subject['code']!.substring(0, 8)}...') : (subject['code'] ?? '')}',
                            style: GoogleFonts.poppins(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Delete button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _removeSubject(index),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.delete_outline,
                            color: AppTheme.error,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(
                  color: AppTheme.dividerLight,
                  thickness: 0.5,
                  height: 1,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child:
                    isDesktop || isWide
                        ? Row(
                          children: [
                            presentChip,
                            const SizedBox(width: 8),
                            absentChip,
                            const SizedBox(width: 8),
                            percentChip,
                          ],
                        )
                        : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: presentChip),
                                const SizedBox(width: 8),
                                Expanded(child: absentChip),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Center(child: percentChip),
                          ],
                        ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book_rounded,
            size: 80,
            color: Colors.blueAccent.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 24),
          Text(
            'No subjects found for your semester.',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Contact your admin if this is unexpected.',
            style: GoogleFonts.poppins(fontSize: 16, color: Colors.black38),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceAppBar(BuildContext context) {
    return CustomAppBar(
      title: 'My Attendance',
      subtitle: 'Track your academic progress',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      actions: [
        IconButton(
          icon:
              _loading
                  ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryBlue,
                      ),
                    ),
                  )
                  : const Icon(Icons.refresh_rounded, size: 18),
          onPressed:
              _loading
                  ? null
                  : () async {
                    setState(() {
                      _loading = true;
                    });
                    await _retryWithNetworkCheck();

                    if (!mounted) return;

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
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;
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
              selected: 'attendance',
              onNavigate: (route) => Navigator.pushNamed(context, route),
            ),
            Expanded(
              child:
                  _initialLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _hasNetworkError
                      ? buildNetworkErrorWidget(
                        title: '📡 No Internet Connection',
                        message:
                            'Unable to load attendance data. Please connect to the internet and try again.',
                        customEmoji: '📊',
                        onRetry: _retryWithNetworkCheck,
                      )
                      : Column(
                        children: [
                          _buildAttendanceAppBar(context),
                          Expanded(
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 900,
                                ),
                                child:
                                    _loading
                                        ? const Center(
                                          child: CircularProgressIndicator(),
                                        )
                                        : _subjects.isEmpty
                                        ? _buildEmptyState()
                                        : ListView.builder(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: isWide ? 40 : 16,
                                            vertical: 24,
                                          ),
                                          itemCount: _subjects.length,
                                          itemBuilder:
                                              (context, index) => Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 24,
                                                ),
                                                child: _buildSubjectCard(
                                                  _subjects[index],
                                                  index,
                                                ),
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
        floatingActionButton:
            _initialLoading || _hasNetworkError
                ? null
                : Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.18),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: FloatingActionButton(
                    onPressed: _addSubjectDialog,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    tooltip: 'Add Subject',
                    child: const Icon(Icons.add, size: 32, color: Colors.white),
                  ),
                ),
      );
    }
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body:
          _initialLoading
              ? const Center(child: CircularProgressIndicator())
              : _hasNetworkError
              ? buildNetworkErrorWidget(
                title: '📡 No Internet Connection',
                message:
                    'Unable to load attendance data. Please connect to the internet and try again.',
                customEmoji: '📊',
                onRetry: _retryWithNetworkCheck,
              )
              : Column(
                children: [
                  _buildAttendanceAppBar(context),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 900),
                        child:
                            _loading
                                ? const Center(
                                  child: CircularProgressIndicator(),
                                )
                                : _subjects.isEmpty
                                ? _buildEmptyState()
                                : ListView.builder(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isWide ? 40 : 16,
                                    vertical: 24,
                                  ),
                                  itemCount: _subjects.length,
                                  itemBuilder:
                                      (context, index) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 24,
                                        ),
                                        child: _buildSubjectCard(
                                          _subjects[index],
                                          index,
                                        ),
                                      ),
                                ),
                      ),
                    ),
                  ),
                ],
              ),
      floatingActionButton:
          _initialLoading || _hasNetworkError
              ? null
              : Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: FloatingActionButton(
                  onPressed: _addSubjectDialog,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  tooltip: 'Add Subject',
                  child: const Icon(Icons.add, size: 32, color: Colors.white),
                ),
              ),
    );
  }
}
