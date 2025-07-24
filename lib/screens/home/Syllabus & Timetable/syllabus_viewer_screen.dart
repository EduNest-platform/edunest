import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../services/files_service.dart';
import '../../../services/error_message_service.dart';

class SyllabusViewerScreen extends StatefulWidget {
  final String semesterId;
  const SyllabusViewerScreen({super.key, required this.semesterId});

  @override
  State<SyllabusViewerScreen> createState() => _SyllabusViewerScreenState();
}

class _SyllabusViewerScreenState extends State<SyllabusViewerScreen> {
  String? fileUrl;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    fetchSyllabusUrl();
  }

  Future<void> fetchSyllabusUrl() async {
    setState(() {
      loading = true;
    });
    try {
      final syllabus = await FilesService.getSyllabusTimetable(
        semesterId: widget.semesterId,
        type: 'syllabus',
      );
      if (syllabus != null && syllabus.fileUrl.isNotEmpty) {
        fileUrl = syllabus.fileUrl;
      } else {
        error = 'No syllabus found.';
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
      appBar: AppBar(title: const Text('Syllabus')),
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
                            ? SfPdfViewer.network(fileUrl!)
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
              : Center(child: Text(error ?? 'No syllabus found.')),
    );
  }
}
