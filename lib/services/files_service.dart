import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/error_message_service.dart';
import 'free_plan_optimizer_service.dart';

class FileResource {
  final String id;
  final String name;
  final String description;
  final String fileUrl;
  final String fileType;
  final int fileSize;
  final DateTime uploadDate;
  final String uploadedBy;
  final String subjectId;
  final String? thumbnailUrl;
  final Map<String, dynamic> metadata;
  final List<String> tags;

  FileResource({
    required this.id,
    required this.name,
    required this.description,
    required this.fileUrl,
    required this.fileType,
    required this.fileSize,
    required this.uploadDate,
    required this.uploadedBy,
    required this.subjectId,
    this.thumbnailUrl,
    this.metadata = const {},
    this.tags = const [],
  });

  factory FileResource.fromJson(Map<String, dynamic> json) {
    return FileResource(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      fileUrl: json['file_url'] ?? '',
      fileType: json['file_type'] ?? '',
      fileSize:
          json['file_size'] is int
              ? json['file_size']
              : int.tryParse(json['file_size'].toString()) ?? 0,
      uploadDate: DateTime.parse(json['created_at']),
      uploadedBy: json['uploaded_by'] ?? '',
      subjectId: json['subject_id'].toString(),
      thumbnailUrl: json['thumbnail_url'],
      metadata: json['metadata'] ?? {},
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'file_url': fileUrl,
      'file_type': fileType,
      'file_size': fileSize,
      'created_at': uploadDate.toIso8601String(),
      'uploaded_by': uploadedBy,
      'subject_id': subjectId,
      'thumbnail_url': thumbnailUrl,
      'metadata': metadata,
      'tags': tags,
    };
  }
}

// Add this model for syllabus_timetable entries
class SyllabusTimetableResource {
  final String id;
  final String name;
  final String description;
  final String fileUrl;
  final String type;
  final int fileSize;
  final String mimeType;
  final String uploadedBy;
  final DateTime createdAt;
  final String semesterId;
  final String? storageKey;

  SyllabusTimetableResource({
    required this.id,
    required this.name,
    required this.description,
    required this.fileUrl,
    required this.type,
    required this.fileSize,
    required this.mimeType,
    required this.uploadedBy,
    required this.createdAt,
    required this.semesterId,
    this.storageKey,
  });

  factory SyllabusTimetableResource.fromJson(Map<String, dynamic> json) {
    return SyllabusTimetableResource(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      fileUrl: json['file_url'] ?? '',
      type: json['type'] ?? '',
      fileSize:
          json['file_size'] is int
              ? json['file_size']
              : int.tryParse(json['file_size'].toString()) ?? 0,
      mimeType: json['mime_type'] ?? '',
      uploadedBy: json['uploaded_by'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      semesterId: json['semester_id'] ?? '',
      storageKey: json['storage_key'],
    );
  }
}

class FilesService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Get files by subject and type
  static Future<List<FileResource>> getFiles(
    String subjectId,
    String fileType,
  ) async {
    return FreePlanOptimizerService.optimizedDatabaseOperation(
      'get_files_${subjectId}_$fileType',
      () async {
        try {
          final response = await _supabase
              .from('files')
              .select()
              .eq('subject_id', subjectId)
              .eq('file_type', fileType)
              .order('created_at', ascending: false);

          return (response as List)
              .map((file) => FileResource.fromJson(file))
              .toList();
        } catch (e) {
          return <FileResource>[];
        }
      },
      cacheDuration: const Duration(minutes: 10), // Cache file lists
    );
  }

  /// Get file statistics for a subject
  static Future<Map<String, int>> getFileStats(String subjectId) async {
    return FreePlanOptimizerService.optimizedDatabaseOperation(
      'get_file_stats_$subjectId',
      () async {
        try {
          final response = await _supabase
              .from('files')
              .select('file_type')
              .eq('subject_id', subjectId);

          final Map<String, int> stats = {};
          for (final file in response as List) {
            final fileType = file['file_type'];
            stats[fileType] = (stats[fileType] ?? 0) + 1;
          }

          return stats;
        } catch (e) {
          return <String, int>{};
        }
      },
      cacheDuration: const Duration(minutes: 10), // Cache file stats
    );
  }

  /// Upload a file
  ///
  /// Note: For Google Drive files, ensure they are shared with "Anyone with the link can view"
  /// to avoid access issues when users try to view them.
  static Future<FileResource?> uploadFile({
    required File file,
    required String fileName,
    required String description,
    required String fileType,
    required String subjectId,
    required String uploadedBy,
  }) async {
    try {
      // Generate unique file name
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = fileName.split('.').last;
      final uniqueFileName = '${timestamp}_$fileName';

      // Upload to Supabase Storage
      final filePath = 'files/$subjectId/$fileType/$uniqueFileName';

      await _supabase.storage.from('files').upload(filePath, file);

      // Get public URL
      final fileUrl = _supabase.storage.from('files').getPublicUrl(filePath);

      // Create file record in database
      final response =
          await _supabase
              .from('files')
              .insert({
                'name': fileName,
                'description': description,
                'file_url': fileUrl,
                'file_type': fileType,
                'file_size': await file.length(),
                'created_at': DateTime.now().toIso8601String(),
                'uploaded_by': uploadedBy,
                'subject_id': subjectId,
              })
              .select()
              .single();

      return FileResource.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Delete a file
  static Future<bool> deleteFile(String fileId) async {
    try {
      // Get file info first
      final response =
          await _supabase
              .from('files')
              .select('file_url')
              .eq('id', fileId)
              .single();

      final fileUrl = response['file_url'];

      // Extract file path from URL
      final uri = Uri.parse(fileUrl);
      final pathSegments = uri.pathSegments;
      final filePath = pathSegments
          .sublist(2)
          .join('/'); // Remove 'storage/v1/object/public/files'

      // Delete from storage
      await _supabase.storage.from('files').remove([filePath]);

      // Delete from database
      await _supabase.from('files').delete().eq('id', fileId);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Search files by name or description
  static Future<List<FileResource>> searchFiles(
    String subjectId,
    String query,
  ) async {
    try {
      final response = await _supabase
          .from('files')
          .select()
          .eq('subject_id', subjectId)
          .or('name.ilike.%$query%,description.ilike.%$query%')
          .order('created_at', ascending: false);

      return (response as List)
          .map((file) => FileResource.fromJson(file))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get file by ID
  static Future<FileResource?> getFileById(String fileId) async {
    try {
      final response =
          await _supabase.from('files').select().eq('id', fileId).single();

      return FileResource.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Update file metadata
  static Future<bool> updateFileMetadata(
    String fileId,
    Map<String, dynamic> metadata,
  ) async {
    try {
      await _supabase
          .from('files')
          .update({'metadata': metadata})
          .eq('id', fileId);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get files by uploader
  static Future<List<FileResource>> getFilesByUploader(
    String subjectId,
    String uploadedBy,
  ) async {
    try {
      final response = await _supabase
          .from('files')
          .select()
          .eq('subject_id', subjectId)
          .eq('uploaded_by', uploadedBy)
          .order('created_at', ascending: false);

      return (response as List)
          .map((file) => FileResource.fromJson(file))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get recent files
  static Future<List<FileResource>> getRecentFiles(
    String subjectId, {
    int limit = 10,
  }) async {
    try {
      final response = await _supabase
          .from('files')
          .select()
          .eq('subject_id', subjectId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((file) => FileResource.fromJson(file))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get files by date range
  static Future<List<FileResource>> getFilesByDateRange(
    String subjectId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final response = await _supabase
          .from('files')
          .select()
          .eq('subject_id', subjectId)
          .gte('created_at', startDate.toIso8601String())
          .lte('created_at', endDate.toIso8601String())
          .order('created_at', ascending: false);

      return (response as List)
          .map((file) => FileResource.fromJson(file))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get file count by type
  static Future<Map<String, int>> getFileCountByType(String subjectId) async {
    try {
      final response = await _supabase
          .from('files')
          .select('file_type')
          .eq('subject_id', subjectId);

      final Map<String, int> counts = {};
      for (final file in response as List) {
        final fileType = file['file_type'];
        counts[fileType] = (counts[fileType] ?? 0) + 1;
      }

      return counts;
    } catch (e) {
      return {};
    }
  }

  /// Get total file size by subject
  static Future<int> getTotalFileSize(String subjectId) async {
    try {
      final response = await _supabase
          .from('files')
          .select('file_size')
          .eq('subject_id', subjectId);

      int totalSize = 0;
      for (final file in response as List) {
        totalSize += (file['file_size'] ?? 0) as int;
      }

      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  /// Format file size in human readable format
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// Get file extension from URL
  static String getFileExtension(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      final extension = path.split('.').last.toLowerCase();
      return extension;
    } catch (e) {
      return 'unknown';
    }
  }

  /// Check if file is an image
  static bool isImage(String fileType) {
    final imageTypes = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'];
    return imageTypes.contains(fileType.toLowerCase());
  }

  /// Check if file is a document
  static bool isDocument(String fileType) {
    final documentTypes = ['pdf', 'doc', 'docx', 'txt', 'rtf'];
    return documentTypes.contains(fileType.toLowerCase());
  }

  /// Check if file is a video
  static bool isVideo(String fileType) {
    final videoTypes = ['mp4', 'avi', 'mov', 'wmv', 'flv', 'webm'];
    return videoTypes.contains(fileType.toLowerCase());
  }

  /// Check if file is an audio
  static bool isAudio(String fileType) {
    final audioTypes = ['mp3', 'wav', 'aac', 'ogg', 'flac'];
    return audioTypes.contains(fileType.toLowerCase());
  }

  /// Get appropriate icon for file type
  static String getFileIcon(String fileType) {
    if (isImage(fileType)) return 'image';
    if (isDocument(fileType)) return 'description';
    if (isVideo(fileType)) return 'video_library';
    if (isAudio(fileType)) return 'audiotrack';
    return 'insert_drive_file';
  }

  /// Generate thumbnail URL for image files
  static String? generateThumbnailUrl(String fileUrl, {int width = 200}) {
    try {
      final uri = Uri.parse(fileUrl);
      final path = uri.path;

      // For Supabase storage, we can use transformations
      if (path.contains('/storage/v1/object/public/')) {
        return '$fileUrl?width=$width&height=$width&resize=cover';
      }

      return fileUrl;
    } catch (e) {
      return null;
    }
  }

  /// Validate file upload
  static bool validateFileUpload(File file, String fileName) {
    // Check file size (max 100MB)
    if (file.lengthSync() > 100 * 1024 * 1024) {
      return false;
    }

    // Check file extension
    final extension = fileName.split('.').last.toLowerCase();
    final allowedExtensions = [
      'pdf',
      'doc',
      'docx',
      'txt',
      'rtf',
      'jpg',
      'jpeg',
      'png',
      'gif',
      'bmp',
      'mp4',
      'avi',
      'mov',
      'wmv',
      'mp3',
      'wav',
      'aac',
      'ogg',
      'zip',
      'rar',
      '7z',
    ];

    return allowedExtensions.contains(extension);
  }

  /// Get upload progress for multiple files
  static Stream<double> getUploadProgress(List<File> files) async* {
    int totalSize = 0;
    int uploadedSize = 0;

    for (final file in files) {
      totalSize += file.lengthSync();
    }

    for (final file in files) {
      final fileSize = file.lengthSync();
      uploadedSize += fileSize;
      yield uploadedSize / totalSize;
    }
  }

  /// Batch upload files
  static Future<List<FileResource>> batchUploadFiles({
    required List<File> files,
    required List<String> fileNames,
    required List<String> descriptions,
    required String fileType,
    required String subjectId,
    required String uploadedBy,
  }) async {
    final List<FileResource> uploadedFiles = [];
    int uploadedCount = 0;

    for (int i = 0; i < files.length; i++) {
      try {
        final file = files[i];
        final fileName = fileNames[i];
        final description = descriptions[i];

        final uploadedFile = await uploadFile(
          file: file,
          fileName: fileName,
          description: description,
          fileType: fileType,
          subjectId: subjectId,
          uploadedBy: uploadedBy,
        );

        if (uploadedFile != null) {
          uploadedFiles.add(uploadedFile);
        }

        uploadedCount++;
      } catch (e) {
        // Error handling with user-friendly message
        if (kDebugMode) {
          print('Error uploading file: $e');
        }
      }
    }

    return uploadedFiles;
  }

  /// Get file analytics
  static Future<Map<String, dynamic>> getFileAnalytics(String subjectId) async {
    try {
      final response = await _supabase
          .from('files')
          .select('file_type, file_size, created_at')
          .eq('subject_id', subjectId);

      final Map<String, dynamic> analytics = {
        'totalFiles': 0,
        'totalSize': 0,
        'fileTypes': {},
        'uploadTrend': {},
      };

      for (final file in response as List) {
        analytics['totalFiles']++;
        analytics['totalSize'] += file['file_size'] ?? 0;

        final fileType = file['file_type'];
        analytics['fileTypes'][fileType] =
            (analytics['fileTypes'][fileType] ?? 0) + 1;

        final uploadDate = DateTime.parse(file['created_at']);
        final monthKey =
            '${uploadDate.year}-${uploadDate.month.toString().padLeft(2, '0')}';
        analytics['uploadTrend'][monthKey] =
            (analytics['uploadTrend'][monthKey] ?? 0) + 1;
      }

      return analytics;
    } catch (e) {
      return {};
    }
  }

  /// Download a file
  static Future<bool> downloadFile(FileResource file) async {
    try {
      final url = file.fileUrl;

      // Convert Google Drive view links to download links
      String downloadUrl = url;
      if (url.contains('drive.google.com/file/d/')) {
        downloadUrl = _convertGoogleDriveToDownloadLink(url);
      }

      // Use url_launcher to download the file
      final uri = Uri.parse(downloadUrl);
      final canLaunch = await canLaunchUrl(uri);

      if (canLaunch) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Convert Google Drive view link to download link
  static String _convertGoogleDriveToDownloadLink(String originalUrl) {
    // Check if it's a Google Drive view link
    final driveViewPattern = RegExp(
      r'https://drive\.google\.com/file/d/([a-zA-Z0-9_-]+)/view',
    );
    final match = driveViewPattern.firstMatch(originalUrl);

    if (match != null) {
      final fileId = match.group(1);
      return 'https://drive.google.com/uc?export=download&id=$fileId';
    }

    // Check if it's already a download link
    if (originalUrl.contains('drive.google.com/uc?export=download')) {
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
        return 'https://drive.google.com/uc?export=download&id=$fileId';
      }
    }

    // If it's already a direct link, return as is
    return originalUrl;
  }

  /// Fetch syllabus or timetable for a semester from syllabus_timetable table
  static Future<SyllabusTimetableResource?> getSyllabusTimetable({
    required String semesterId,
    required String type, // 'syllabus' or 'timetable'
  }) async {
    try {
      final response =
          await _supabase
              .from('syllabus_timetable')
              .select()
              .eq('semester_id', semesterId)
              .eq('type', type)
              .maybeSingle();
      if (response == null) return null;
      return SyllabusTimetableResource.fromJson(response);
    } catch (e) {
      return null;
    }
  }
}
