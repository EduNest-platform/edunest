import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../services/files_service.dart';
import '../../../services/error_message_service.dart';

class TimetableViewerScreen extends StatefulWidget {
  final String semesterId;
  const TimetableViewerScreen({super.key, required this.semesterId});

  @override
  State<TimetableViewerScreen> createState() => _TimetableViewerScreenState();
}

class _TimetableViewerScreenState extends State<TimetableViewerScreen> {
  String? fileUrl;
  bool loading = true;
  String? error;
  final PdfViewerController _pdfViewerController = PdfViewerController();

  @override
  void initState() {
    super.initState();
    fetchTimetableUrl();
  }

  Future<void> fetchTimetableUrl() async {
    setState(() {
      loading = true;
    });
    try {
      final timetable = await FilesService.getSyllabusTimetable(
        semesterId: widget.semesterId,
        type: 'timetable',
      );
      if (timetable != null && timetable.fileUrl.isNotEmpty) {
        fileUrl = timetable.fileUrl;
      } else {
        error = 'No timetable found.';
      }
    } catch (e) {
      final message = ErrorMessageService.getFriendlyMessage(e);
      error = message;
    }
    setState(() {
      loading = false;
    });
  }

  bool isPdf(String url) {
    return url.toLowerCase().endsWith('.pdf');
  }

  bool isImage(String url) {
    return url.toLowerCase().endsWith('.jpg') ||
        url.toLowerCase().endsWith('.jpeg') ||
        url.toLowerCase().endsWith('.png') ||
        url.toLowerCase().endsWith('.gif') ||
        url.toLowerCase().endsWith('.webp');
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;
    return Scaffold(
      appBar: AppBar(title: const Text('Timetable')),
      body:
          loading
              ? const Center(child: CircularProgressIndicator())
              : fileUrl != null
              ? Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child:
                        isPdf(fileUrl!)
                            ? SfPdfViewer.network(
                              fileUrl!,
                              controller: _pdfViewerController,
                              onDocumentLoaded: (details) {
                                _pdfViewerController.zoomLevel = 2.0;
                              },
                              enableDoubleTapZooming: true,
                              interactionMode: PdfInteractionMode.pan,
                            )
                            : isImage(fileUrl!)
                            ? InteractiveViewer(
                              child: Center(
                                child: Image.network(
                                  fileUrl!,
                                  fit: BoxFit.contain,
                                  errorBuilder:
                                      (context, error, stackTrace) =>
                                          const Text('Failed to load image.'),
                                ),
                              ),
                            )
                            : const Center(
                              child: Text('Unsupported file type.'),
                            ),
                  ),
                ),
              )
              : Center(child: Text(error ?? 'No timetable found.')),
    );
  }
}
