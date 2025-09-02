import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../services/midsem_marks_service.dart';
import '../../../models/subject.dart';
import '../../../widgets/custom_app_bar.dart';
import '../../../services/network_service.dart';
import 'package:flutter/foundation.dart';
import '../../../widgets/desktop_sidebar.dart';
import 'subject_midsem_marks_screen.dart';

class MidsemSubjectsScreen extends StatefulWidget {
  const MidsemSubjectsScreen({super.key});

  @override
  State<MidsemSubjectsScreen> createState() => _MidsemSubjectsScreenState();
}

class _MidsemSubjectsScreenState extends State<MidsemSubjectsScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final NetworkService _networkService = NetworkService();
  bool _isLoading = true;
  bool _hasNetworkError = false;
  List<Subject> _subjects = [];
  Map<String, int> _midsemCounts = {};
  DateTime? _lastLoadTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Register cache invalidation callback
    MidsemMarksService.registerCacheInvalidationCallback(_onCacheInvalidated);
    _loadSubjects();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    MidsemMarksService.unregisterCacheInvalidationCallback();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Check if we need to refresh data when app resumes
      _checkAndRefreshIfNeeded();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check if we need to refresh when returning to this screen
    _checkAndRefreshIfNeeded();
  }

  /// Callback for when midsem marks cache is invalidated
  void _onCacheInvalidated() {
    if (mounted) {
      _loadSubjects();
    }
  }

  /// Check if data needs refresh and reload if necessary
  void _checkAndRefreshIfNeeded() {
    if (_lastLoadTime == null) return;
    
    // Refresh if data is older than 1 minute or if cache is invalid
    final now = DateTime.now();
    final timeSinceLastLoad = now.difference(_lastLoadTime!);
    
    if (timeSinceLastLoad.inMinutes > 1) {
      if (kDebugMode) {
        // Midsem subjects: Refreshing due to stale data (${timeSinceLastLoad.inMinutes} minutes old)
      }
      _loadSubjects();
    }
  }

  /// Handle edge case: User changes academic path while on this screen
  void _handleProfileChange() {
    if (mounted) {
      // Clear current data and reload with new academic context
      setState(() {
        _subjects = [];
        _midsemCounts = {};
        _isLoading = true;
      });
      _loadSubjects();
    }
  }

  Future<void> _loadSubjects() async {
    setState(() {
      _isLoading = true;
      _hasNetworkError = false;
    });

    _lastLoadTime = DateTime.now();

    try {
      final networkStatus = await _networkService.isConnected();
      if (!networkStatus) {
        setState(() {
          _hasNetworkError = true;
          _isLoading = false;
        });
        return;
      }

      // Get all midsem marks grouped by class ID
      final marksByClassId = await MidsemMarksService.getAllMidsemMarks();
      final classIds = marksByClassId.keys.toList();
      
      // Edge case: Handle empty response due to network issues or data corruption
      if (marksByClassId.isEmpty && _subjects.isNotEmpty) {
        // Potential data inconsistency - keep existing subjects but show warning
        if (kDebugMode) {
          // Warning: No midsem marks found but subjects exist - potential cache inconsistency
        }
      }
      
      if (classIds.isEmpty) {
        setState(() {
          _subjects = [];
          _midsemCounts = {};
          _isLoading = false;
          _hasNetworkError = false;
        });
        return;
      }

      // Get class and subject information
      final classSubjectInfo = await MidsemMarksService.getClassSubjectInfo(classIds);
      
      final subjects = <Subject>[];
      final midsemCounts = <String, int>{};
      
      for (final classId in classIds) {
        final info = classSubjectInfo[classId];
        if (info != null) {
          // Create a Subject object from the class info
          subjects.add(Subject(
            id: classId,
            name: info['subject_name'],
            code: info['subject_code'],
            semesterId: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ));
          // Count unique midsem exams for this subject
          final uniqueExams = marksByClassId[classId]!
              .map((mark) => mark.assignmentName)
              .toSet()
              .length;
          midsemCounts[classId] = uniqueExams;
        } else {
          // Fallback if no info found
          subjects.add(Subject(
            id: classId,
            name: 'Unknown Subject',
            code: '',
            semesterId: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ));
          // Count unique midsem exams for this subject
          final uniqueExams = marksByClassId[classId]!
              .map((mark) => mark.assignmentName)
              .toSet()
              .length;
          midsemCounts[classId] = uniqueExams;
        }
      }

      setState(() {
        _subjects = subjects;
        _midsemCounts = midsemCounts;
        _isLoading = false;
      });

    } catch (e) {
      if (kDebugMode) {
        print('Error loading midsem subjects: $e');
      }
      
      if (mounted) {
        // Edge case: Distinguish between network errors and data errors
        final isNetworkError = e.toString().contains('network') || 
                              e.toString().contains('connection') ||
                              e.toString().contains('timeout');
        
        setState(() {
          _hasNetworkError = isNetworkError;
          _isLoading = false;
          
          // If not network error but we have cached data, keep it
          if (!isNetworkError && _subjects.isNotEmpty) {
            // Keep existing subjects on non-network errors
          } else {
            _subjects = [];
            _midsemCounts = {};
          }
        });
        
        if (kDebugMode) {
          // Midsem subjects error: $e (Network: $isNetworkError)
        }
      }
    }
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
    return Column(
      children: [
        CustomAppBar(
          title: 'Midsem Marks',
          subtitle: 'Select a subject to view midsem exams',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadSubjects,
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
                    'Loading midsem subjects...',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (_subjects.isEmpty)
          Expanded(
            child: _buildEmptyState(),
          )
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadSubjects,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _subjects.length,
                itemBuilder: (context, index) {
                  final subject = _subjects[index];
                  final midsemCount = _midsemCounts[subject.id] ?? 0;
                  
                  return _buildSubjectCard(subject, midsemCount);
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSubjectCard(Subject subject, int midsemCount) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 800;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          color: Colors.grey.shade200,
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          splashColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
          highlightColor: AppTheme.primaryBlue.withValues(alpha: 0.05),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SubjectMidsemMarksScreen(subject: subject),
              ),
            );
          },
          child: Padding(
            padding: EdgeInsets.all(isWide ? 24 : 20),
            child: isWide 
                ? _buildDesktopSubjectCard(subject, midsemCount)
                : _buildMobileSubjectCard(subject, midsemCount),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopSubjectCard(Subject subject, int midsemCount) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Enhanced icon with gradient background
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryBlue.withValues(alpha: 0.15),
                AppTheme.primaryBlue.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.primaryBlue.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Icon(
            Icons.quiz_rounded,
            size: 32,
            color: AppTheme.primaryBlue,
          ),
        ),
        const SizedBox(height: 16),
        
        // Subject name
        Text(
          subject.name,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        
        // Subject code
        if (subject.code != null && subject.code!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Colors.grey.shade300,
                width: 0.5,
              ),
            ),
            child: Text(
              subject.code!,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ] else ...[
          const SizedBox(height: 8),
        ],
        
        // Midsem count with enhanced styling
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: midsemCount > 0 
                ? LinearGradient(
                    colors: [
                      Colors.green.shade100,
                      Colors.green.shade50,
                    ],
                  )
                : LinearGradient(
                    colors: [
                      Colors.grey.shade100,
                      Colors.grey.shade50,
                    ],
                  ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: midsemCount > 0 ? [
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ] : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.quiz_rounded,
                size: 14,
                color: midsemCount > 0 
                    ? Colors.green.shade700
                    : Colors.grey.shade600,
              ),
              const SizedBox(width: 4),
              Text(
                '$midsemCount exam${midsemCount != 1 ? 's' : ''}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: midsemCount > 0 
                      ? Colors.green.shade700
                      : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        
        // Action indicator with animation hint
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: AppTheme.primaryBlue,
          ),
        ),
      ],
    );
  }

  Widget _buildMobileSubjectCard(Subject subject, int midsemCount) {
    return Row(
      children: [
        // Enhanced icon container
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryBlue.withValues(alpha: 0.15),
                AppTheme.primaryBlue.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.primaryBlue.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Icon(
            Icons.quiz_rounded,
            size: 28,
            color: AppTheme.primaryBlue,
          ),
        ),
        const SizedBox(width: 18),
        
        // Content section
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Subject name
              Text(
                subject.name,
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              // Subject code
              if (subject.code != null && subject.code!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    subject.code!,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 8),
              
              // Midsem count with icon
              Row(
                children: [
                  Icon(
                    Icons.quiz_rounded,
                    size: 14,
                    color: midsemCount > 0 
                        ? Colors.green.shade700
                        : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$midsemCount exam${midsemCount != 1 ? 's' : ''}',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: midsemCount > 0 
                          ? Colors.green.shade700
                          : Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(width: 12),
        
        // Action indicator
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: AppTheme.primaryBlue,
          ),
        ),
      ],
    );
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
            'No Midsem Marks Available',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your midsem exam results will appear here\nonce they are published by your professors.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadSubjects,
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
          ElevatedButton(
            onPressed: () => _loadSubjects(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.refresh),
                SizedBox(width: 8),
                Text('Retry'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
