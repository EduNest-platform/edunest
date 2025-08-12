import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../models/subject.dart';
import '../../../services/files_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../../widgets/app_text.dart';
import '../../common/pdf_viewer_screen.dart';
// import '../../../mixins/performance_mixin.dart';

class NotesScreen extends StatefulWidget {
  final Subject subject;
  final bool showAppBar;

  const NotesScreen({
    super.key,
    required this.subject,
    this.showAppBar = false,
  });

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen>
    with TickerProviderStateMixin {
  String _searchQuery = '';
  String _sortBy = 'Date';
  bool _isLoading = false;
  List<FileResource> _allNotes = [];
  List<FileResource> _notes = [];

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    // startScreenMonitoring('notes_screen');
    _initializeAnimations();
    _loadNotes();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    // stopScreenMonitoring();
    super.dispose();
  }

  Color _getSubjectColor() {
    final subjectName = widget.subject.name.toLowerCase();
    if (subjectName.contains('dsa') || subjectName.contains('algorithm')) {
      return Colors.orange;
    } else if (subjectName.contains('database') || subjectName.contains('db')) {
      return Colors.green;
    } else if (subjectName.contains('network') ||
        subjectName.contains('networking')) {
      return Colors.purple;
    } else if (subjectName.contains('web') ||
        subjectName.contains('frontend')) {
      return Colors.blue;
    } else if (subjectName.contains('mobile') || subjectName.contains('app')) {
      return Colors.teal;
    } else if (subjectName.contains('ai') || subjectName.contains('machine')) {
      return Colors.indigo;
    } else if (subjectName.contains('security') ||
        subjectName.contains('cyber')) {
      return Colors.red;
    } else if (subjectName.contains('cloud') || subjectName.contains('aws')) {
      return Colors.cyan;
    } else {
      // Default color based on subject name hash
      final colors = [
        Colors.blue,
        Colors.green,
        Colors.orange,
        Colors.purple,
        Colors.teal,
        Colors.indigo,
        Colors.pink,
        Colors.amber,
      ];
      final index = subjectName.hashCode.abs() % colors.length;
      return colors[index];
    }
  }

  IconData _getSubjectIcon() {
    final subjectName = widget.subject.name.toLowerCase();
    if (subjectName.contains('dsa') || subjectName.contains('algorithm')) {
      return Icons.code_rounded;
    } else if (subjectName.contains('database') || subjectName.contains('db')) {
      return Icons.storage_rounded;
    } else if (subjectName.contains('network') ||
        subjectName.contains('networking')) {
      return Icons.wifi_rounded;
    } else if (subjectName.contains('web') ||
        subjectName.contains('frontend')) {
      return Icons.web_rounded;
    } else if (subjectName.contains('mobile') || subjectName.contains('app')) {
      return Icons.phone_android_rounded;
    } else if (subjectName.contains('ai') || subjectName.contains('machine')) {
      return Icons.psychology_rounded;
    } else if (subjectName.contains('security') ||
        subjectName.contains('cyber')) {
      return Icons.security_rounded;
    } else if (subjectName.contains('cloud') || subjectName.contains('aws')) {
      return Icons.cloud_rounded;
    } else {
      return Icons.book_rounded;
    }
  }

  Future<void> _loadNotes() async {
    // await startOperationTrace('notes_data_loading');

    try {
      setState(() {
        _isLoading = true;
      });

      final notes = await FilesService.getFiles(widget.subject.id, 'notes');

      setState(() {
        _allNotes = notes;
        _notes = notes;
        _isLoading = false;
      });

      // Start animations after data is loaded
      _fadeController.forward();
      _slideController.forward();
      // await stopOperationTrace('notes_data_loading');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: AppText('Failed to load notes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      // await stopOperationTrace('notes_data_loading');
    }
  }

  void _filterNotes() {
    setState(() {
      _notes =
          _allNotes.where((note) {
            return note.name.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                (note.description.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ??
                    false);
          }).toList();
    });
  }

  List<FileResource> get _sortedNotes {
    final filteredNotes =
        _notes.where((note) {
          if (_searchQuery.isEmpty) return true;
          return note.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (note.description.isNotEmpty &&
                  note.description.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ));
        }).toList();

    switch (_sortBy) {
      case 'Date':
        filteredNotes.sort((a, b) => b.uploadDate.compareTo(a.uploadDate));
        break;
      case 'Name':
        filteredNotes.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'Size':
        filteredNotes.sort((a, b) => b.fileSize.compareTo(a.fileSize));
        break;
    }

    return filteredNotes;
  }

  Future<void> _openFile(FileResource note) async {
    try {
      String url = note.fileUrl;

      // Convert Google Drive view/download links to preview links
      if (url.contains('drive.google.com')) {
        final driveViewPattern = RegExp(
          r'https://drive\.google\.com/file/d/([a-zA-Z0-9_-]+)',
        );
        final match = driveViewPattern.firstMatch(url);
        if (match != null) {
          final fileId = match.group(1);
          url = 'https://drive.google.com/file/d/$fileId/preview';
        } else if (url.contains('uc?export=download&id=')) {
          final downloadPattern = RegExp(r'id=([a-zA-Z0-9_-]+)');
          final downloadMatch = downloadPattern.firstMatch(url);
          if (downloadMatch != null) {
            final fileId = downloadMatch.group(1);
            url = 'https://drive.google.com/file/d/$fileId/preview';
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: AppText('Opening ${note.name}...'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Check if it's a PDF file
      final fileName = note.name.toLowerCase();
      final isPdf =
          fileName.endsWith('.pdf') ||
          note.fileType == 'application/pdf' ||
          url.toLowerCase().contains('.pdf');

      if (isPdf) {
        // For PDF files, open in the PDF viewer
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder:
                  (context) => PdfViewerScreen(pdfUrl: url, title: note.name),
            ),
          );
        }
        return;
      }

      // Actually open the URL using url_launcher for non-PDF files
      final uri = Uri.parse(url);

      // For Google Drive links, show special handling
      if (url.contains('drive.google.com')) {
        if (await canLaunchUrl(uri)) {
          try {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } catch (e) {
            _showGoogleDriveAccessDialog(note.name, url);
          }
        } else {
          _showGoogleDriveAccessDialog(note.name, url);
        }
      } else if (url.contains('supabase.co')) {
        // For Supabase storage links, try to open in browser first
        if (await canLaunchUrl(uri)) {
          try {
            await launchUrl(uri, mode: LaunchMode.inAppWebView);
          } catch (e) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        } else {
          try {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: AppText(
                    'Could not open ${note.name}. Please try opening the link manually.',
                  ),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 4),
                  action: SnackBarAction(
                    label: 'Copy Link',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: url));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: AppText('Link copied to clipboard'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
              );
            }
          }
        }
      } else {
        // For other links, use external application
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: AppText('Could not open ${note.name}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: AppText('Failed to open note: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showGoogleDriveAccessDialog(String fileName, String fileUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              const SizedBox(width: 8),
              AppText('Access Required'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                'The file "$fileName" requires access permission.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              AppText(
                'To fix this issue:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              AppText(
                '1. Ask the file owner to:\n'
                '   • Right-click the file in Google Drive\n'
                '   • Select "Share" → "Change to anyone with the link"\n'
                '   • Set permission to "Viewer"\n'
                '   • Click "Done"\n\n'
                '2. Or try opening in browser (may work better)',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: AppText('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Try opening in browser
                launchUrl(
                  Uri.parse(fileUrl),
                  mode: LaunchMode.externalApplication,
                );
              },
              child: AppText('Open in Browser'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Copy link
                Clipboard.setData(ClipboardData(text: fileUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: AppText('Link copied to clipboard'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: AppText('Copy Link'),
            ),
          ],
        );
      },
    );
  }

  /// Convert Google Drive view link to direct view link
  String _convertGoogleDriveViewLink(String originalUrl) {
    // Check if it's a Google Drive view link
    final driveViewPattern = RegExp(
      r'https://drive\.google\.com/file/d/([a-zA-Z0-9_-]+)/view',
    );
    final match = driveViewPattern.firstMatch(originalUrl);

    if (match != null) {
      final fileId = match.group(1);
      // Use a direct preview link that works better for public files
      return 'https://drive.google.com/file/d/$fileId/preview';
    }

    // Check if it's already a download link
    if (originalUrl.contains('drive.google.com/uc?export=download')) {
      // Convert download link to preview link for better viewing
      final downloadPattern = RegExp(
        r'https://drive\.google\.com/uc\?export=download&id=([a-zA-Z0-9_-]+)',
      );
      final downloadMatch = downloadPattern.firstMatch(originalUrl);
      if (downloadMatch != null) {
        final fileId = downloadMatch.group(1);
        return 'https://drive.google.com/file/d/$fileId/preview';
      }
      return originalUrl;
    }

    // Check if it's a direct file link
    if (originalUrl.contains('drive.google.com/file/d/')) {
      final fileIdPattern = RegExp(
        r'https://drive\.google\.com/file/d/([a-zA-Z0-9_-]+)',
      );
      final fileIdMatch = fileIdPattern.firstMatch(originalUrl);
      if (fileIdMatch != null) {
        final fileId = fileIdMatch.group(1);
        return 'https://drive.google.com/file/d/$fileId/preview';
      }
    }

    // If it's already a direct link, return as is
    return originalUrl;
  }

  Color _getNoteCardColor(FileResource note, int index) {
    // Generate color based on note name hash
    final noteName = note.name.toLowerCase();

    // Specific colors for common note types
    if (noteName.contains('lecture') || noteName.contains('class')) {
      return Colors.blue;
    } else if (noteName.contains('assignment') ||
        noteName.contains('homework')) {
      return Colors.orange;
    } else if (noteName.contains('exam') ||
        noteName.contains('test') ||
        noteName.contains('quiz')) {
      return Colors.red;
    } else if (noteName.contains('lab') || noteName.contains('practical')) {
      return Colors.green;
    } else if (noteName.contains('project') || noteName.contains('final')) {
      return Colors.purple;
    } else if (noteName.contains('summary') || noteName.contains('review')) {
      return Colors.teal;
    } else if (noteName.contains('tutorial') || noteName.contains('guide')) {
      return Colors.indigo;
    } else if (noteName.contains('reference') || noteName.contains('book')) {
      return Colors.amber;
    } else {
      // Fallback to index-based colors
      final colors = [
        Colors.blue,
        Colors.green,
        Colors.orange,
        Colors.purple,
        Colors.teal,
        Colors.indigo,
        Colors.pink,
        Colors.amber,
        Colors.cyan,
        Colors.deepOrange,
        Colors.lightBlue,
        Colors.lime,
      ];
      final colorIndex = (noteName.hashCode.abs() + index) % colors.length;
      return colors[colorIndex];
    }
  }

  IconData _getNoteIcon(FileResource note) {
    final noteName = note.name.toLowerCase();

    if (noteName.contains('lecture') || noteName.contains('class')) {
      return Icons.school_rounded;
    } else if (noteName.contains('assignment') ||
        noteName.contains('homework')) {
      return Icons.assignment_rounded;
    } else if (noteName.contains('exam') ||
        noteName.contains('test') ||
        noteName.contains('quiz')) {
      return Icons.quiz_rounded;
    } else if (noteName.contains('lab') || noteName.contains('practical')) {
      return Icons.science_rounded;
    } else if (noteName.contains('project') || noteName.contains('final')) {
      return Icons.work_rounded;
    } else if (noteName.contains('summary') || noteName.contains('review')) {
      return Icons.summarize_rounded;
    } else if (noteName.contains('tutorial') || noteName.contains('guide')) {
      return Icons.help_rounded;
    } else if (noteName.contains('reference') || noteName.contains('book')) {
      return Icons.book_rounded;
    } else {
      return Icons.description_rounded;
    }
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade400, width: 1.3),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.13),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Icon(
                  Icons.description_rounded,
                  color: Colors.blue.shade600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      'Notes',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    AppText(
                      '${_allNotes.length} notes available',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppText(
            'Subject: ${widget.subject.name}',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndSort() {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // Search Bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                    _filterNotes();
                  },
                  decoration: InputDecoration(
                    hintText: 'Search notes...',
                    hintStyle: GoogleFonts.poppins(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: Colors.grey.shade600,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Sort Row
              Row(
                children: [
                  AppText(
                    'Sort by: ',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButton<String>(
                      value: _sortBy,
                      underline: const SizedBox(),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                      items:
                          ['Date', 'Name', 'Size'].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: AppText(value),
                            );
                          }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _sortBy = newValue!;
                        });
                      },
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: AppText(
                      '${_allNotes.length} notes',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoteCard(FileResource note, int index) {
    final noteColor = _getNoteCardColor(note, index);
    final tags = note.tags;

    return Container(
      key: ValueKey(note.id),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: noteColor.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: noteColor.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openFile(note),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row with Icon and Title
                Row(
                  children: [
                    // Note Icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: noteColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: noteColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        _getNoteIcon(note),
                        color: noteColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Title and Basic Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            note.name,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.person_rounded,
                                size: 14,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: AppText(
                                  note.uploadedBy,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 14,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              AppText(
                                _formatDate(note.uploadDate),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // File Size
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: noteColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: noteColor.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: AppText(
                        FilesService.formatFileSize(note.fileSize),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: noteColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Action Buttons
                Row(
                  children: [
                    // View Button
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _openFile(note),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: noteColor,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: noteColor.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.visibility_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              AppText(
                                'View',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children:
                        tags.map<Widget>((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: AppText(
                              tag,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.teal.shade700,
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryBlue),
      );
    }

    final isDesktop = MediaQuery.of(context).size.width > 900;
    final maxContentWidth = 1000.0;

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        _buildSearchAndSort(),
        const SizedBox(height: 20),
        Expanded(
          child:
              _sortedNotes.isEmpty
                  ? FadeTransition(
                    opacity: _fadeAnimation,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          AppText(
                            'No notes found',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          AppText(
                            'Try adjusting your search',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  : isDesktop
                  ? GridView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 20,
                          crossAxisSpacing: 20,
                          childAspectRatio: 2.2,
                        ),
                    itemCount: _sortedNotes.length,
                    itemBuilder:
                        (context, index) =>
                            _buildNoteCard(_sortedNotes[index], index),
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _sortedNotes.length,
                    itemBuilder: (context, index) {
                      return _buildNoteCard(_sortedNotes[index], index);
                    },
                  ),
        ),
      ],
    );

    return Scaffold(
      appBar:
          widget.showAppBar
              ? PreferredSize(
                preferredSize: const Size.fromHeight(64),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.arrow_back_rounded,
                            color: AppTheme.primaryBlue,
                            size: 26,
                          ),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Notes - ${widget.subject.name}',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryBlue,
                              letterSpacing: -0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                    ),
                  ),
                ),
              )
              : null,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            constraints:
                isDesktop ? BoxConstraints(maxWidth: maxContentWidth) : null,
            padding:
                isDesktop
                    ? const EdgeInsets.symmetric(vertical: 24)
                    : EdgeInsets.zero,
            child:
                isDesktop
                    ? SizedBox(
                      height:
                          MediaQuery.of(context).size.height -
                          (widget.showAppBar ? 64 : 0),
                      child: content,
                    )
                    : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [Expanded(child: content)],
                    ),
          ),
        ),
      ),
    );
  }
}
