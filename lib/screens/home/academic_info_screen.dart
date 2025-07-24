import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import 'Syllabus & Timetable/syllabus_viewer_screen.dart';
import 'Syllabus & Timetable/timetable_viewer_screen.dart';
import '../../services/subjects_service.dart';
import '../../models/subject.dart';
import '../../widgets/custom_app_bar.dart';
import '../../services/network_service.dart';
import 'package:flutter/foundation.dart';
import '../../widgets/desktop_sidebar.dart';

class AcademicInfoScreen extends StatefulWidget {
  final String subjectId;
  const AcademicInfoScreen({super.key, required this.subjectId});

  @override
  State<AcademicInfoScreen> createState() => _AcademicInfoScreenState();
}

class _AcademicInfoScreenState extends State<AcademicInfoScreen>
    with NetworkAwareMixin {
  Future<Subject?>? _subjectFuture;
  bool _hasNetworkError = false;
  final NetworkService _networkService = NetworkService();

  @override
  void initState() {
    super.initState();
    _loadSubjectData();
  }

  Future<void> _loadSubjectData() async {
    // Check network connectivity first
    final networkStatus = await _networkService.isConnected();

    if (!networkStatus) {
      setState(() {
        _hasNetworkError = true;
        _subjectFuture = null;
      });
      return;
    }

    setState(() {
      _hasNetworkError = false;
      _subjectFuture = SubjectsService.getSubjectById(widget.subjectId);
    });
  }

  Future<void> _retryWithNetworkCheck() async {
    await refreshNetworkStatus();
    final networkStatus = await _networkService.isConnected();

    if (networkStatus) {
      _loadSubjectData();
    } else {
      setState(() {
        _hasNetworkError = true;
        _subjectFuture = null;
      });
    }
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
        backgroundColor: Colors.grey.shade50,
        body: Row(
          children: [
            DesktopSidebar(
              selected: 'academic-info',
              onNavigate: (route) => Navigator.pushNamed(context, route),
            ),
            Expanded(
              child:
                  _hasNetworkError
                      ? buildNetworkErrorWidget(
                        title: '📡 No Internet Connection',
                        message:
                            'Unable to load academic information. Please connect to the internet and try again.',
                        customEmoji: '📚',
                        onRetry: _retryWithNetworkCheck,
                      )
                      : Column(
                        children: [
                          CustomAppBar(
                            title: 'Academic Info',
                            subtitle: 'Syllabus and Timetable',
                            leading: IconButton(
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 20,
                              ),
                              onPressed: () => Navigator.of(context).maybePop(),
                            ),
                          ),
                          Expanded(
                            child:
                                _subjectFuture == null
                                    ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                    : FutureBuilder<Subject?>(
                                      future: _subjectFuture!,
                                      builder: (context, snapshot) {
                                        final isLoading =
                                            snapshot.connectionState ==
                                            ConnectionState.waiting;
                                        final subject = snapshot.data;
                                        final semesterId = subject?.semesterId;
                                        return Center(
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxWidth: 900,
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 32,
                                                    vertical: 32,
                                                  ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  // Remove header and subtitle for Android/iOS
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          32,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            24,
                                                          ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black
                                                              .withOpacity(
                                                                0.06,
                                                              ),
                                                          blurRadius: 18,
                                                          offset: const Offset(
                                                            0,
                                                            8,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    child:
                                                        isWide
                                                            ? Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .center,
                                                              children: [
                                                                Expanded(
                                                                  child: _AcademicInfoCard(
                                                                    icon:
                                                                        Icons
                                                                            .menu_book_rounded,
                                                                    title:
                                                                        'Syllabus',
                                                                    subtitle:
                                                                        'Check your semester syllabus',
                                                                    color:
                                                                        AppTheme
                                                                            .primaryBlue,
                                                                    onTap:
                                                                        semesterId !=
                                                                                null
                                                                            ? () {
                                                                              Navigator.push(
                                                                                context,
                                                                                MaterialPageRoute(
                                                                                  builder:
                                                                                      (
                                                                                        context,
                                                                                      ) => SyllabusViewerScreen(
                                                                                        semesterId:
                                                                                            semesterId!,
                                                                                      ),
                                                                                ),
                                                                              );
                                                                            }
                                                                            : () {
                                                                              ScaffoldMessenger.of(
                                                                                context,
                                                                              ).showSnackBar(
                                                                                const SnackBar(
                                                                                  content: Text(
                                                                                    'Syllabus not available for your academic path yet.',
                                                                                  ),
                                                                                  backgroundColor:
                                                                                      Colors.orange,
                                                                                ),
                                                                              );
                                                                            },
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  width: 48,
                                                                ),
                                                                Expanded(
                                                                  child: _AcademicInfoCard(
                                                                    icon:
                                                                        Icons
                                                                            .schedule_rounded,
                                                                    title:
                                                                        'Timetable',
                                                                    subtitle:
                                                                        'View your class schedule',
                                                                    color:
                                                                        AppTheme
                                                                            .primaryLight,
                                                                    onTap:
                                                                        semesterId !=
                                                                                null
                                                                            ? () {
                                                                              Navigator.push(
                                                                                context,
                                                                                MaterialPageRoute(
                                                                                  builder:
                                                                                      (
                                                                                        context,
                                                                                      ) => TimetableViewerScreen(
                                                                                        semesterId:
                                                                                            semesterId!,
                                                                                      ),
                                                                                ),
                                                                              );
                                                                            }
                                                                            : () {
                                                                              ScaffoldMessenger.of(
                                                                                context,
                                                                              ).showSnackBar(
                                                                                const SnackBar(
                                                                                  content: Text(
                                                                                    'Timetable not available for your academic path yet.',
                                                                                  ),
                                                                                  backgroundColor:
                                                                                      Colors.orange,
                                                                                ),
                                                                              );
                                                                            },
                                                                  ),
                                                                ),
                                                              ],
                                                            )
                                                            : Column(
                                                              children: [
                                                                _AcademicInfoCard(
                                                                  icon:
                                                                      Icons
                                                                          .menu_book_rounded,
                                                                  title:
                                                                      'Syllabus',
                                                                  subtitle:
                                                                      'Check your semester syllabus',
                                                                  color:
                                                                      AppTheme
                                                                          .primaryBlue,
                                                                  onTap:
                                                                      semesterId !=
                                                                              null
                                                                          ? () {
                                                                            Navigator.push(
                                                                              context,
                                                                              MaterialPageRoute(
                                                                                builder:
                                                                                    (
                                                                                      context,
                                                                                    ) => SyllabusViewerScreen(
                                                                                      semesterId:
                                                                                          semesterId!,
                                                                                    ),
                                                                              ),
                                                                            );
                                                                          }
                                                                          : () {
                                                                            ScaffoldMessenger.of(
                                                                              context,
                                                                            ).showSnackBar(
                                                                              const SnackBar(
                                                                                content: Text(
                                                                                  'Syllabus not available for your academic path yet.',
                                                                                ),
                                                                                backgroundColor:
                                                                                    Colors.orange,
                                                                              ),
                                                                            );
                                                                          },
                                                                ),
                                                                const SizedBox(
                                                                  height: 28,
                                                                ),
                                                                _AcademicInfoCard(
                                                                  icon:
                                                                      Icons
                                                                          .schedule_rounded,
                                                                  title:
                                                                      'Timetable',
                                                                  subtitle:
                                                                      'View your class schedule',
                                                                  color:
                                                                      AppTheme
                                                                          .primaryLight,
                                                                  onTap:
                                                                      semesterId !=
                                                                              null
                                                                          ? () {
                                                                            Navigator.push(
                                                                              context,
                                                                              MaterialPageRoute(
                                                                                builder:
                                                                                    (
                                                                                      context,
                                                                                    ) => TimetableViewerScreen(
                                                                                      semesterId:
                                                                                          semesterId!,
                                                                                    ),
                                                                              ),
                                                                            );
                                                                          }
                                                                          : () {
                                                                            ScaffoldMessenger.of(
                                                                              context,
                                                                            ).showSnackBar(
                                                                              const SnackBar(
                                                                                content: Text(
                                                                                  'Timetable not available for your academic path yet.',
                                                                                ),
                                                                                backgroundColor:
                                                                                    Colors.orange,
                                                                              ),
                                                                            );
                                                                          },
                                                                ),
                                                              ],
                                                            ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                          ),
                        ],
                      ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body:
          _hasNetworkError
              ? buildNetworkErrorWidget(
                title: '📡 No Internet Connection',
                message:
                    'Unable to load academic information. Please connect to the internet and try again.',
                customEmoji: '📚',
                onRetry: _retryWithNetworkCheck,
              )
              : Column(
                children: [
                  CustomAppBar(
                    title: 'Academic Info',
                    subtitle: 'Syllabus and Timetable',
                    leading: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                      ),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  Expanded(
                    child:
                        _subjectFuture == null
                            ? const Center(child: CircularProgressIndicator())
                            : FutureBuilder<Subject?>(
                              future: _subjectFuture!,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                                if (!snapshot.hasData ||
                                    snapshot.data == null) {
                                  return Center(
                                    child: buildNetworkErrorWidget(
                                      title: '📚 Subject Not Found',
                                      message:
                                          'The requested subject could not be found. Please check your connection and try again.',
                                      customEmoji: '🔍',
                                      onRetry: _retryWithNetworkCheck,
                                    ),
                                  );
                                }
                                final subject = snapshot.data!;
                                final semesterId = subject.semesterId;
                                return Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 900,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 32,
                                        vertical: 32,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          // Remove header and subtitle for Android/iOS
                                          Container(
                                            padding: const EdgeInsets.all(32),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(24),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.06),
                                                  blurRadius: 18,
                                                  offset: const Offset(0, 8),
                                                ),
                                              ],
                                            ),
                                            child:
                                                isWide
                                                    ? Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Expanded(
                                                          child: _AcademicInfoCard(
                                                            icon:
                                                                Icons
                                                                    .menu_book_rounded,
                                                            title: 'Syllabus',
                                                            subtitle:
                                                                'Check your semester syllabus',
                                                            color:
                                                                AppTheme
                                                                    .primaryBlue,
                                                            onTap:
                                                                semesterId !=
                                                                        null
                                                                    ? () {
                                                                      Navigator.push(
                                                                        context,
                                                                        MaterialPageRoute(
                                                                          builder:
                                                                              (
                                                                                context,
                                                                              ) => SyllabusViewerScreen(
                                                                                semesterId:
                                                                                    semesterId,
                                                                              ),
                                                                        ),
                                                                      );
                                                                    }
                                                                    : () {
                                                                      ScaffoldMessenger.of(
                                                                        context,
                                                                      ).showSnackBar(
                                                                        const SnackBar(
                                                                          content: Text(
                                                                            'Syllabus not available for your academic path yet.',
                                                                          ),
                                                                          backgroundColor:
                                                                              Colors.orange,
                                                                        ),
                                                                      );
                                                                    },
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 48,
                                                        ),
                                                        Expanded(
                                                          child: _AcademicInfoCard(
                                                            icon:
                                                                Icons
                                                                    .schedule_rounded,
                                                            title: 'Timetable',
                                                            subtitle:
                                                                'View your class schedule',
                                                            color:
                                                                AppTheme
                                                                    .primaryLight,
                                                            onTap:
                                                                semesterId !=
                                                                        null
                                                                    ? () {
                                                                      Navigator.push(
                                                                        context,
                                                                        MaterialPageRoute(
                                                                          builder:
                                                                              (
                                                                                context,
                                                                              ) => TimetableViewerScreen(
                                                                                semesterId:
                                                                                    semesterId,
                                                                              ),
                                                                        ),
                                                                      );
                                                                    }
                                                                    : () {
                                                                      ScaffoldMessenger.of(
                                                                        context,
                                                                      ).showSnackBar(
                                                                        const SnackBar(
                                                                          content: Text(
                                                                            'Timetable not available for your academic path yet.',
                                                                          ),
                                                                          backgroundColor:
                                                                              Colors.orange,
                                                                        ),
                                                                      );
                                                                    },
                                                          ),
                                                        ),
                                                      ],
                                                    )
                                                    : Column(
                                                      children: [
                                                        _AcademicInfoCard(
                                                          icon:
                                                              Icons
                                                                  .menu_book_rounded,
                                                          title: 'Syllabus',
                                                          subtitle:
                                                              'Check your semester syllabus',
                                                          color:
                                                              AppTheme
                                                                  .primaryBlue,
                                                          onTap:
                                                              semesterId != null
                                                                  ? () {
                                                                    Navigator.push(
                                                                      context,
                                                                      MaterialPageRoute(
                                                                        builder:
                                                                            (
                                                                              context,
                                                                            ) => SyllabusViewerScreen(
                                                                              semesterId:
                                                                                  semesterId,
                                                                            ),
                                                                      ),
                                                                    );
                                                                  }
                                                                  : () {
                                                                    ScaffoldMessenger.of(
                                                                      context,
                                                                    ).showSnackBar(
                                                                      const SnackBar(
                                                                        content:
                                                                            Text(
                                                                              'Syllabus not available for your academic path yet.',
                                                                            ),
                                                                        backgroundColor:
                                                                            Colors.orange,
                                                                      ),
                                                                    );
                                                                  },
                                                        ),
                                                        const SizedBox(
                                                          height: 28,
                                                        ),
                                                        _AcademicInfoCard(
                                                          icon:
                                                              Icons
                                                                  .schedule_rounded,
                                                          title: 'Timetable',
                                                          subtitle:
                                                              'View your class schedule',
                                                          color:
                                                              AppTheme
                                                                  .primaryLight,
                                                          onTap:
                                                              semesterId != null
                                                                  ? () {
                                                                    Navigator.push(
                                                                      context,
                                                                      MaterialPageRoute(
                                                                        builder:
                                                                            (
                                                                              context,
                                                                            ) => TimetableViewerScreen(
                                                                              semesterId:
                                                                                  semesterId,
                                                                            ),
                                                                      ),
                                                                    );
                                                                  }
                                                                  : () {
                                                                    ScaffoldMessenger.of(
                                                                      context,
                                                                    ).showSnackBar(
                                                                      const SnackBar(
                                                                        content:
                                                                            Text(
                                                                              'Timetable not available for your academic path yet.',
                                                                            ),
                                                                        backgroundColor:
                                                                            Colors.orange,
                                                                      ),
                                                                    );
                                                                  },
                                                        ),
                                                      ],
                                                    ),
                                          ),
                                        ],
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
}

class _AcademicInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;
  final bool enabled;
  const _AcademicInfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: color.withValues(alpha: 0.13), width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 22),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.arrow_forward_ios_rounded, color: color, size: 22),
          ],
        ),
      ),
    );
  }
}
