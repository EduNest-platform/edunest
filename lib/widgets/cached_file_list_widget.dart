import 'package:flutter/material.dart';
import '../services/cached_file_resource_service.dart';
import '../services/files_service.dart';

class CachedFileListWidget extends StatefulWidget {
  final String subjectId;
  final FileResourceType fileType;
  final Widget Function(FileResource file) itemBuilder;
  final Widget? emptyWidget;
  final Widget? errorWidget;
  final Widget? loadingWidget;
  final ScrollController? scrollController;
  final EdgeInsetsGeometry? padding;
  final int pageSize;
  final bool enablePullToRefresh;
  final bool enableInfiniteScroll;
  final Function(FileResource)? onFileTap;
  final Function(String)? onError;

  const CachedFileListWidget({
    Key? key,
    required this.subjectId,
    required this.fileType,
    required this.itemBuilder,
    this.emptyWidget,
    this.errorWidget,
    this.loadingWidget,
    this.scrollController,
    this.padding,
    this.pageSize = 20,
    this.enablePullToRefresh = true,
    this.enableInfiniteScroll = true,
    this.onFileTap,
    this.onError,
  }) : super(key: key);

  @override
  State<CachedFileListWidget> createState() => _CachedFileListWidgetState();
}

class _CachedFileListWidgetState extends State<CachedFileListWidget> {
  final CachedFileResourceService _service = CachedFileResourceService.instance;
  late ScrollController _scrollController;
  
  List<FileResource> _files = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _hasMore = true;
  int _currentPage = 0;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    
    if (widget.enableInfiniteScroll) {
      _scrollController.addListener(_onScroll);
    }
    
    _loadInitialData();
  }

  @override
  void dispose() {
    if (widget.scrollController == null) {
      _scrollController.dispose();
    } else {
      _scrollController.removeListener(_onScroll);
    }
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore && !_isLoading) {
        _loadMoreData();
      }
    }
  }

  Future<void> _loadInitialData() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final result = await _service.getFiles(
        subjectId: widget.subjectId,
        type: widget.fileType,
        page: 0,
        pageSize: widget.pageSize,
      );

      if (mounted) {
        setState(() {
          _files = result.files;
          _hasMore = result.hasMore;
          _currentPage = 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isLoading = false;
        });
        widget.onError?.call(e.toString());
      }
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final result = await _service.loadNextPage(
        subjectId: widget.subjectId,
        type: widget.fileType,
        currentPage: _currentPage,
        pageSize: widget.pageSize,
      );

      if (mounted) {
        setState(() {
          _files.addAll(result.files);
          _hasMore = result.hasMore;
          _currentPage++;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
        widget.onError?.call(e.toString());
      }
    }
  }

  Future<void> _onRefresh() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      final result = await _service.refreshFiles(
        subjectId: widget.subjectId,
        type: widget.fileType,
        page: 0,
        pageSize: widget.pageSize,
      );

      if (mounted) {
        setState(() {
          _files = result.files;
          _hasMore = result.hasMore;
          _currentPage = 0;
          _hasError = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isRefreshing = false;
        });
        widget.onError?.call(e.toString());
      }
    }
  }

  Widget _buildLoadingWidget() {
    return widget.loadingWidget ??
        const Center(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: CircularProgressIndicator(),
          ),
        );
  }

  Widget _buildEmptyWidget() {
    return widget.emptyWidget ??
        const Center(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.folder_open,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  'No files found',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        );
  }

  Widget _buildErrorWidget() {
    return widget.errorWidget ??
        Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading files',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadInitialData,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
  }

  Widget _buildFileList() {
    return ListView.builder(
      controller: _scrollController,
      padding: widget.padding,
      itemCount: _files.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < _files.length) {
          final file = _files[index];
          return InkWell(
            onTap: () => widget.onFileTap?.call(file),
            child: widget.itemBuilder(file),
          );
        } else {
          // Loading more indicator
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (_isLoading) {
      content = _buildLoadingWidget();
    } else if (_hasError) {
      content = _buildErrorWidget();
    } else if (_files.isEmpty) {
      content = _buildEmptyWidget();
    } else {
      content = _buildFileList();
    }

    if (widget.enablePullToRefresh) {
      return RefreshIndicator(
        onRefresh: _onRefresh,
        child: content,
      );
    }

    return content;
  }
}

// File item widget for consistent file display
class FileItemWidget extends StatelessWidget {
  final FileResource file;
  final VoidCallback? onTap;
  final VoidCallback? onDownload;
  final bool showThumbnail;
  final bool showFileSize;
  final bool showUploadDate;

  const FileItemWidget({
    Key? key,
    required this.file,
    this.onTap,
    this.onDownload,
    this.showThumbnail = true,
    this.showFileSize = true,
    this.showUploadDate = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: _buildLeading(),
        title: Text(
          file.name,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: _buildSubtitle(),
        trailing: _buildTrailing(),
        onTap: onTap,
      ),
    );
  }

  Widget? _buildLeading() {
    if (!showThumbnail) return null;

    if (file.thumbnailUrl != null && FilesService.isImage(file.fileType)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          file.thumbnailUrl!,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildFileIcon(),
        ),
      );
    }

    return _buildFileIcon();
  }

  Widget _buildFileIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: _getFileTypeColor().withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        _getFileIcon(),
        color: _getFileTypeColor(),
        size: 24,
      ),
    );
  }

  Widget? _buildSubtitle() {
    final subtitleParts = <String>[];
    
    if (file.description.isNotEmpty) {
      subtitleParts.add(file.description);
    }
    
    final metaParts = <String>[];
    
    if (showFileSize) {
      metaParts.add(FilesService.formatFileSize(file.fileSize));
    }
    
    if (showUploadDate) {
      metaParts.add(_formatDate(file.uploadDate));
    }
    
    if (metaParts.isNotEmpty) {
      subtitleParts.add(metaParts.join(' • '));
    }

    if (subtitleParts.isEmpty) return null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (file.description.isNotEmpty)
          Text(
            file.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey[600]),
          ),
        if (metaParts.isNotEmpty)
          Text(
            metaParts.join(' • '),
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
      ],
    );
  }

  Widget? _buildTrailing() {
    if (onDownload == null) return null;

    return IconButton(
      icon: const Icon(Icons.download),
      onPressed: onDownload,
      tooltip: 'Download',
    );
  }

  IconData _getFileIcon() {
    if (FilesService.isImage(file.fileType)) return Icons.image;
    if (FilesService.isDocument(file.fileType)) return Icons.description;
    if (FilesService.isVideo(file.fileType)) return Icons.video_library;
    if (FilesService.isAudio(file.fileType)) return Icons.audiotrack;
    return Icons.insert_drive_file;
  }

  Color _getFileTypeColor() {
    if (FilesService.isImage(file.fileType)) return Colors.blue;
    if (FilesService.isDocument(file.fileType)) return Colors.red;
    if (FilesService.isVideo(file.fileType)) return Colors.purple;
    if (FilesService.isAudio(file.fileType)) return Colors.orange;
    return Colors.grey;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
