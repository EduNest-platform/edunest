import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../models/subject.dart';
import '../../../services/files_service.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../widgets/app_text.dart';
import '../../common/pdf_viewer_screen.dart';

class PYQScreen extends StatefulWidget {
  final Subject subject;
  final bool showAppBar;

  const PYQScreen({super.key, required this.subject, this.showAppBar = false});

  @override
  State<PYQScreen> createState() => _PYQScreenState();
}

class _PYQScreenState extends State<PYQScreen> {
  String _searchQuery = '';
  String _selectedYear = 'All';
  bool _isLoading = true;
  List<FileResource> _allPYQs = [];

  @override
  void initState() {
    super.initState();
    _fetchPYQs();
    // Removed MOCK DATA block
  }

  Future<void> _fetchPYQs() async {
    setState(() => _isLoading = true);
    final files = await FilesService.getFiles(widget.subject.id, 'pyq');
    setState(() {
      _allPYQs = files;
      _isLoading = false;
    });
  }

  List<String> get _years {
    final years =
        _allPYQs
            .map((pyq) => pyq.metadata['year']?.toString() ?? '')
            .where((y) => y.isNotEmpty)
            .toSet()
            .toList();
    years.sort((a, b) => b.compareTo(a));
    return ['All', ...years];
  }

  List<FileResource> get _filteredPYQs {
    return _allPYQs.where((pyq) {
      final name = pyq.name.toLowerCase();
      final desc = pyq.description.toLowerCase();
      final tags = pyq.tags;
      final matchesSearch =
          name.contains(_searchQuery.toLowerCase()) ||
          desc.contains(_searchQuery.toLowerCase()) ||
          tags.any((tag) => tag.contains(_searchQuery.toLowerCase()));
      final year = pyq.metadata['year']?.toString() ?? '';
      final matchesYear = _selectedYear == 'All' || year == _selectedYear;
      return matchesSearch && matchesYear;
    }).toList();
  }

  Color _getDifficultyColor(String? difficulty) {
    switch (difficulty?.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'hard':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getExamTypeColor(String? examType) {
    switch (examType?.toLowerCase()) {
      case 'final':
        return Colors.red;
      case 'mid':
        return Colors.orange;
      case 'practice':
        return Colors.blue;
      case 'mock':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.shade400, width: 1.3),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withValues(alpha: 0.13),
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
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Icon(
                  Icons.quiz_rounded,
                  color: Colors.purple.shade600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      'Previous Year Questions',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    AppText(
                      '${_allPYQs.length} papers available',
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

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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
        },
        decoration: InputDecoration(
          hintText: 'Search PYQs...',
          hintStyle: GoogleFonts.poppins(
            color: Colors.grey.shade500,
            fontSize: 14,
          ),
          prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade600),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            'Filter by Year:',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _years.length,
              itemBuilder: (context, index) {
                final year = _years[index];
                final isSelected = _selectedYear == year;
                return Container(
                  margin: const EdgeInsets.only(right: 12),
                  child: FilterChip(
                    label: AppText(
                      year,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedYear = year;
                      });
                    },
                    backgroundColor: Colors.grey.shade100,
                    selectedColor: Colors.blue.shade600,
                    checkmarkColor: Colors.white,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
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

  Widget _buildPYQCard(FileResource pyq) {
    final meta = pyq.metadata;
    final examType = meta['examType']?.toString() ?? '';
    final year = meta['year']?.toString() ?? '';
    final difficulty = meta['difficulty']?.toString() ?? '';
    final hasSolutions =
        meta['hasSolutions'] == true || meta['hasSolutions'] == 'true';
    final tags = pyq.tags;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: Colors.purple.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.quiz_rounded,
                    color: Colors.purple.shade400,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        pyq.name,
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
                          if (examType.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: AppText(
                                examType,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          if (year.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: AppText(
                                year,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.deepPurple,
                                ),
                              ),
                            ),
                          ],
                          if (difficulty.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: AppText(
                                difficulty,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                          ],
                          if (hasSolutions) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: AppText(
                                'Solutions',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AppText(
                      _formatFileSize(pyq.fileSize),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (pyq.description.trim().isNotEmpty)
              AppText(
                pyq.description,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children:
                    tags.map<Widget>((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: AppText(
                          tag,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.person_rounded,
                  size: 15,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 4),
                AppText(
                  pyq.uploadedBy,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.calendar_today_rounded,
                  size: 15,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 4),
                AppText(
                  _formatDate(pyq.uploadDate),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () {
                    if (pyq.fileUrl.isNotEmpty) {
                      _openFile(pyq);
                    }
                  },
                  icon: const Icon(Icons.visibility_rounded, size: 18),
                  label: const Text('View'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade400,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                    textStyle: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _openFile(FileResource pyq) async {
    try {
      String url = pyq.fileUrl;

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

      // Check if it's a PDF file
      final fileName = pyq.name.toLowerCase();
      final isPdf =
          fileName.endsWith('.pdf') ||
          pyq.fileType == 'application/pdf' ||
          url.toLowerCase().contains('.pdf');

      if (isPdf) {
        // For PDF files, open in the PDF viewer
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder:
                  (context) => PdfViewerScreen(pdfUrl: url, title: pyq.name),
            ),
          );
        }
        return;
      }

      // For non-PDF files, use external application
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: AppText('Could not open ${pyq.name}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: AppText('Failed to open file: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.purple),
      );
    }

    final isDesktop = MediaQuery.of(context).size.width > 900;
    final maxContentWidth = 900.0;

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        _buildSearchBar(),
        _buildFilterChips(),
        const SizedBox(height: 8),
        _filteredPYQs.isEmpty
            ? Container(
              height: 300,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.quiz_outlined,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    AppText(
                      'No PYQs found',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AppText(
                      'Try adjusting your filters',
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
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
                childAspectRatio: 1.8,
              ),
              itemCount: _filteredPYQs.length,
              itemBuilder:
                  (context, index) => _buildPYQCard(_filteredPYQs[index]),
            )
            : Column(
              children: _filteredPYQs.map((pyq) => _buildPYQCard(pyq)).toList(),
            ),
        const SizedBox(height: 20),
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
                        color: Colors.purple.withOpacity(0.08),
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
                            color: Colors.purple,
                            size: 26,
                          ),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'PYQs -  ${widget.subject.name}',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple,
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
            child: SingleChildScrollView(child: content),
          ),
        ),
      ),
    );
  }
}
