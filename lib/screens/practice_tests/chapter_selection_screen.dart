import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/subject.dart';
import '../../widgets/custom_app_bar.dart';
import 'difficulty_selection_screen.dart';
import '../../services/supabase_service.dart';
import '../../services/network_service.dart';
import '../../widgets/app_text.dart';
import '../../services/error_message_service.dart';
import '../../widgets/desktop_sidebar.dart';

Future<List<Map<String, dynamic>>> fetchTopicsFromSupabase(
  String subjectId,
) async {
  final client = SupabaseService.client;
  try {
    final response = await client
        .from('topics')
        .select()
        .eq('subject_id', subjectId)
        .order('created_at', ascending: true);
    return response.cast<Map<String, dynamic>>();
    } catch (e) {
    throw Exception('Error fetching topics: $e');
  }
}

class ChapterSelectionScreen extends StatefulWidget {
  final Subject subject;

  const ChapterSelectionScreen({super.key, required this.subject});

  @override
  State<ChapterSelectionScreen> createState() => _ChapterSelectionScreenState();
}

class _ChapterSelectionScreenState extends State<ChapterSelectionScreen> {
  List<Map<String, dynamic>> _topics = [];
  bool _isLoading = true;
  bool _initialLoading = true;
  String? _error;
  bool _hasNetworkError = false;
  final NetworkService _networkService = NetworkService();

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  Future<void> _loadTopics() async {
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
      final topics = await fetchTopicsFromSupabase(widget.subject.id);
      setState(() {
        _topics = topics;
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
        _error = 'Failed to load topics: $e';
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
      await _loadTopics();
    } else {
      setState(() {
        _hasNetworkError = true;
        _initialLoading = false;
      });
    }
  }

  Widget _buildTopicCard(Map<String, dynamic> topic, int index) {
    // Color palette for topic icons
    final List<Color> topicColors = [
      AppTheme.primaryBlue,
      AppTheme.secondaryGreen,
      AppTheme.accentOrange,
      AppTheme.codeIcon,
      AppTheme.labManualsIcon,
      AppTheme.pyqIcon,
      AppTheme.primaryLight,
      AppTheme.secondaryLight,
      AppTheme.accentLight,
    ];
    final color = topicColors[index % topicColors.length];
    return Container(
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withValues(alpha: 0.1), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => DifficultySelectionScreen(
                      subject: widget.subject,
                      chapter: topic,
                    ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Topic Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.book_rounded, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                // Topic Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        topic['name'] ?? 'Topic',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: Platform.isAndroid ? FontWeight.w600 : FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                // Arrow Icon
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
              ],
            ),
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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(
              Icons.book_rounded,
              size: 60,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 24),
          AppText(
            'No Topics Available',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          AppText(
            'Topics will be available once they are added to this subject.',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 60,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 24),
          AppText(
            'Error Loading Topics',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          AppText(
            _error ?? 'An error occurred while loading topics.',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
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
    final isWide = MediaQuery.of(context).size.width > 900;
    final isDesktop = isWide;
    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        body: Row(
          children: [
            DesktopSidebar(
              selected: 'practice-tests',
              onNavigate: (route) => Navigator.pushNamed(context, route),
            ),
            Expanded(
              child: Column(
                children: [
                  CustomAppBar(
                    title: 'Topics',
                    subtitle: widget.subject.name,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 900),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isWide ? 40 : 16,
                            vertical: 24,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText(
                                'Select a Topic',
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                maxLines: 2,
                              ),
                              const SizedBox(height: 8),
                              AppText(
                                'Choose a topic to start your practice test',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 2,
                              ),
                              const SizedBox(height: 24),
                              Expanded(
                                child:
                                    _initialLoading
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
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(
                                                    20,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red
                                                        .withValues(alpha: 0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          50,
                                                        ),
                                                  ),
                                                  child: const Text(
                                                    '📚',
                                                    style: TextStyle(
                                                      fontSize: 48,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 24),
                                                AppText(
                                                  '📡 No Internet Connection',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black87,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                  maxLines: 2,
                                                ),
                                                const SizedBox(height: 12),
                                                AppText(
                                                  'Unable to load topics. Please connect to the internet and try again.',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 16,
                                                    color: Colors.grey,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                  maxLines: 2,
                                                ),
                                                const SizedBox(height: 32),
                                                ElevatedButton.icon(
                                                  onPressed:
                                                      _retryWithNetworkCheck,
                                                  icon: const Icon(
                                                    Icons.refresh_rounded,
                                                  ),
                                                  label: const Text('Retry'),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.blue,
                                                    foregroundColor:
                                                        Colors.white,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 24,
                                                          vertical: 12,
                                                        ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
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
                                        ? _buildErrorState()
                                        : _topics.isEmpty
                                        ? _buildEmptyState()
                                        : RefreshIndicator(
                                          onRefresh: _retryWithNetworkCheck,
                                          child: ListView.builder(
                                            itemCount: _topics.length,
                                            itemBuilder: (context, index) {
                                              return Padding(
                                                padding: EdgeInsets.only(
                                                  bottom: isWide ? 12 : 20,
                                                ),
                                                child: _buildTopicCard(
                                                  _topics[index],
                                                  index,
                                                ),
                                              );
                                            },
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
          ],
        ),
      );
    } else {
      return Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        appBar: CustomAppBar(
          title: 'Topics',
          subtitle: widget.subject.name,
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
                  horizontal: isWide ? 40 : 16,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      'Select a Topic',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    AppText(
                      'Choose a topic to start your practice test',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child:
                          _initialLoading
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
                                          borderRadius: BorderRadius.circular(
                                            50,
                                          ),
                                        ),
                                        child: const Text(
                                          '📚',
                                          style: TextStyle(fontSize: 48),
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      AppText(
                                        '📡 No Internet Connection',
                                        style: GoogleFonts.poppins(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                      ),
                                      const SizedBox(height: 12),
                                      AppText(
                                        'Unable to load topics. Please connect to the internet and try again.',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          color: Colors.grey,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
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
                              : _isLoading
                              ? const Center(
                                child: CircularProgressIndicator(
                                  color: AppTheme.primaryBlue,
                                ),
                              )
                              : _error != null
                              ? _buildErrorState()
                              : _topics.isEmpty
                              ? _buildEmptyState()
                              : RefreshIndicator(
                                onRefresh: _retryWithNetworkCheck,
                                child: ListView.builder(
                                  itemCount: _topics.length,
                                  itemBuilder: (context, index) {
                                    return Padding(
                                      padding: EdgeInsets.only(
                                        bottom: isWide ? 12 : 20,
                                      ),
                                      child: _buildTopicCard(
                                        _topics[index],
                                        index,
                                      ),
                                    );
                                  },
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
}
