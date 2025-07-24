import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../models/subject.dart';
import '../../../services/files_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../widgets/app_text.dart';
import 'package:flutter/services.dart'; // Added for canLaunchUrl
import 'package:flutter/material.dart'; // Added for ScaffoldMessenger
import 'package:flutter/material.dart'; // Added for MaterialPageRoute
import 'package:flutter/material.dart'; // Added for PdfViewerScreen
import '../../common/pdf_viewer_screen.dart';

class LabManualsScreen extends StatefulWidget {
  final Subject subject;
  final bool showAppBar;

  const LabManualsScreen({
    super.key,
    required this.subject,
    this.showAppBar = false,
  });

  @override
  State<LabManualsScreen> createState() => _LabManualsScreenState();
}

class _LabManualsScreenState extends State<LabManualsScreen> {
  String _searchQuery = '';
  String _selectedExperiment = 'All';
  bool _isLoading = true;
  List<FileResource> _allLabManuals = [];

  List<String> get _experimentOptions => [
    'All',
    'Complete Manual',
    'Individual Experiments',
  ];

  @override
  void initState() {
    super.initState();
    _fetchLabManuals();
  }

  Future<void> _fetchLabManuals() async {
    setState(() => _isLoading = true);
    final files = await FilesService.getFiles(widget.subject.id, 'lab_manuals');
    setState(() {
      _allLabManuals = files;
      _isLoading = false;
    });
  }

  List<FileResource> get _filteredLabManuals {
    return _allLabManuals.where((manual) {
      final name = manual.name.toLowerCase();
      final desc = manual.description.toLowerCase();
      final tags =
          (manual.metadata['tags'] as List?)?.map(
            (e) => e.toString().toLowerCase(),
          ) ??
          [];
      final matchesSearch =
          name.contains(_searchQuery.toLowerCase()) ||
          desc.contains(_searchQuery.toLowerCase()) ||
          tags.any((tag) => tag.contains(_searchQuery.toLowerCase()));
      final experiments = manual.metadata['experiments'];
      final matchesExperiment =
          _selectedExperiment == 'All' ||
          (_selectedExperiment == 'Complete Manual' &&
              (experiments is int && experiments > 1)) ||
          (_selectedExperiment == 'Individual Experiments' &&
              (experiments == 1));
      return matchesSearch && matchesExperiment;
    }).toList();
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return Colors.green;
      case 'intermediate':
        return Colors.orange;
      case 'advanced':
        return Colors.red;
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
        border: Border.all(color: Colors.green.shade900, width: 1.3),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade900.withOpacity(0.13),
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
                  color: Colors.green.shade900.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.shade900.withOpacity(0.18),
                  ),
                ),
                child: Icon(
                  Icons.science_rounded,
                  color: Colors.green.shade900,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      'Lab Manuals',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    AppText(
                      '${_allLabManuals.length} manuals available',
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
          hintText: 'Search lab manuals...',
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

  Widget _buildExperimentFilter() {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _experimentOptions.length,
        itemBuilder: (context, index) {
          final experiment = _experimentOptions[index];
          final isSelected = _selectedExperiment == experiment;

          return Container(
            margin: const EdgeInsets.only(right: 12),
            child: FilterChip(
              label: AppText(
                experiment,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedExperiment = experiment;
                });
              },
              backgroundColor: Colors.grey.shade100,
              selectedColor: Colors.green.shade600,
              checkmarkColor: Colors.white,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLabManualCard(FileResource manual) {
    final meta = manual.metadata;
    final experiments = meta['experiments'];
    final difficulty = meta['difficulty']?.toString() ?? '';
    final duration = meta['duration']?.toString() ?? '';
    final tags = manual.tags;
    final downloads = meta['downloads']?.toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: Colors.green.withValues(alpha: 0.08),
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
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.science_rounded,
                    color: Colors.green.shade400,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        manual.name,
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
                          if (experiments != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: AppText(
                                experiments is int && experiments > 1
                                    ? '$experiments exps'
                                    : experiments is int && experiments == 1
                                    ? '1 exp'
                                    : experiments.toString(),
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.purple,
                                ),
                              ),
                            ),
                          if (difficulty.isNotEmpty) ...[
                            const SizedBox(width: 4),
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
                          if (duration.isNotEmpty) ...[
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
                                duration,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue,
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
                      _formatFileSize(manual.fileSize),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (downloads != null)
                      AppText(
                        '$downloads downloads',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (manual.description.trim().isNotEmpty)
              AppText(
                manual.description,
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
                  manual.uploadedBy,
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
                  _formatDate(manual.uploadDate),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () {
                    _openFile(manual);
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

  Future<void> _openFile(FileResource manual) async {
    try {
      String url = manual.fileUrl;

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
      final fileName = manual.name.toLowerCase();
      final isPdf =
          fileName.endsWith('.pdf') ||
          manual.fileType == 'application/pdf' ||
          url.toLowerCase().contains('.pdf');

      if (isPdf) {
        // For PDF files, open in the PDF viewer
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder:
                  (context) => PdfViewerScreen(pdfUrl: url, title: manual.name),
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
              content: AppText('Could not open ${manual.name}'),
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
        child: CircularProgressIndicator(color: Colors.green),
      );
    }
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
                        color: AppTheme.labManualsIcon.withOpacity(0.08),
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
                            color: AppTheme.labManualsIcon,
                            size: 26,
                          ),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Lab Manuals - ${widget.subject.name}',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.labManualsIcon,
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
        onTap: () {
          // Dismiss keyboard when tapping outside
          FocusScope.of(context).unfocus();
        },
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              _buildSearchBar(),
              _buildExperimentFilter(),
              const SizedBox(height: 8),
              _filteredLabManuals.isEmpty
                  ? Container(
                    height: 300,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.science_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          AppText(
                            'No lab manuals found',
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
                  : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children:
                          _filteredLabManuals
                              .map((manual) => _buildLabManualCard(manual))
                              .toList(),
                    ),
                  ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
