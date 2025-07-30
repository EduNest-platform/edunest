import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../services/supabase_service.dart';

class PdfViewerScreen extends StatefulWidget {
  final String pdfUrl;
  final String title;

  const PdfViewerScreen({
    Key? key,
    required this.pdfUrl,
    this.title = 'PDF Viewer',
  }) : super(key: key);

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  String? _authenticatedUrl;
  final PdfViewerController _pdfController = PdfViewerController();
  double _zoomLevel = 0.9;

  @override
  void initState() {
    super.initState();
    _preparePdfUrl();
  }

  Future<void> _preparePdfUrl() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      String finalUrl = widget.pdfUrl;

      // Google Drive: convert download/view links to preview links
      if (finalUrl.contains('drive.google.com')) {
        final driveViewPattern = RegExp(
          r'https://drive\.google\.com/file/d/([a-zA-Z0-9_-]+)',
        );
        final match = driveViewPattern.firstMatch(finalUrl);
        if (match != null) {
          final fileId = match.group(1);
          finalUrl = 'https://drive.google.com/file/d/$fileId/preview';
        } else if (finalUrl.contains('uc?export=download&id=')) {
          final downloadPattern = RegExp(r'id=([a-zA-Z0-9_-]+)');
          final downloadMatch = downloadPattern.firstMatch(finalUrl);
          if (downloadMatch != null) {
            final fileId = downloadMatch.group(1);
            finalUrl = 'https://drive.google.com/file/d/$fileId/preview';
          }
        }
      }

      // Handle Supabase URLs
      if (finalUrl.contains('supabase.co')) {
        try {
          final session = SupabaseService.currentSession;
          if (session != null) {
            final uri = Uri.parse(finalUrl);
            final authenticatedUri = uri.replace(
              queryParameters: {
                ...uri.queryParameters,
                'access_token': session.accessToken,
              },
            );
            finalUrl = authenticatedUri.toString();
          }
        } catch (e) {
          finalUrl = widget.pdfUrl;
        }
      }

      setState(() {
        _authenticatedUrl = finalUrl;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Failed to prepare PDF URL: $e';
      });
    }
  }

  void _zoomIn() {
    setState(() {
      _zoomLevel = (_zoomLevel + 0.25).clamp(1.0, 4.0);
      _pdfController.zoomLevel = _zoomLevel;
    });
  }

  void _zoomOut() {
    setState(() {
      _zoomLevel = (_zoomLevel - 0.25).clamp(1.0, 4.0);
      _pdfController.zoomLevel = _zoomLevel;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF23272F),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                  tooltip: 'Back',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.zoom_out, color: Colors.white),
                  tooltip: 'Zoom Out',
                  onPressed: _zoomLevel > 1.0 ? _zoomOut : null,
                ),
                Center(
                  child: Text(
                    '${_zoomLevel.toStringAsFixed(2)}x',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.zoom_in, color: Colors.white),
                  tooltip: 'Zoom In',
                  onPressed: _zoomLevel < 4.0 ? _zoomIn : null,
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
      backgroundColor: const Color(0xFF23272F),
      body:
          _isLoading
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading PDF...'),
                  ],
                ),
              )
              : _hasError
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Error Loading PDF',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        _errorMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _preparePdfUrl,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
              : _authenticatedUrl != null
              ? Center(
                child: Container(
                  constraints:
                      isDesktop ? const BoxConstraints(maxWidth: 900) : null,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: Colors.grey[100],
                  child: SfPdfViewer.network(
                    _authenticatedUrl!,
                    controller: _pdfController,
                    canShowPaginationDialog: true,
                    canShowScrollHead: true,
                    canShowScrollStatus: true,
                    enableDoubleTapZooming: true,
                    enableTextSelection: true,
                    onZoomLevelChanged: (details) {
                      setState(() {
                        _zoomLevel = details.newZoomLevel;
                      });
                    },
                    onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                      _pdfController.zoomLevel = _zoomLevel;
                    },
                    onDocumentLoadFailed: (
                      PdfDocumentLoadFailedDetails details,
                    ) {
                      setState(() {
                        _hasError = true;
                        _errorMessage = 'Failed to load PDF: ${details.error}';
                      });
                    },
                  ),
                ),
              )
              : const Center(child: Text('No PDF URL available')),
    );
  }
}
