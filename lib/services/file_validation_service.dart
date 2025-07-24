import 'dart:io';
import 'dart:typed_data';
import 'config_service.dart';

class FileValidationService {
  // Dangerous file extensions that should be blocked
  static const List<String> _dangerousExtensions = [
    'exe',
    'bat',
    'cmd',
    'com',
    'pif',
    'scr',
    'vbs',
    'js',
    'jar',
    'msi',
    'dmg',
    'app',
    'deb',
    'rpm',
    'sh',
    'bash',
    'ps1',
    'py',
    'php',
    'asp',
    'aspx',
    'jsp',
    'pl',
    'cgi',
    'htaccess',
    'htpasswd',
  ];

  // Maximum file size (50MB)
  static const int _maxFileSize = 50 * 1024 * 1024;

  /// Validate file before upload
  static Future<FileValidationResult> validateFile(File file) async {
    try {
      // Check file size
      final fileSize = await file.length();
      if (fileSize > _maxFileSize) {
        return FileValidationResult(
          isValid: false,
          error: 'File size exceeds maximum limit of 50MB',
        );
      }

      // Check file extension
      final fileName = file.path.split('/').last;
      final extension = fileName.split('.').last.toLowerCase();

      if (_dangerousExtensions.contains(extension)) {
        return FileValidationResult(
          isValid: false,
          error: 'File type not allowed for security reasons',
        );
      }

      // Check if file type is in allowed list
      if (!ConfigService.isValidFileType(fileName)) {
        return FileValidationResult(
          isValid: false,
          error:
              'File type not supported. Allowed types: ${ConfigService.allowedFileTypes.join(', ')}',
        );
      }

      // Validate file name
      final sanitizedName = ConfigService.sanitizeFileName(fileName);
      if (sanitizedName != fileName) {
        return FileValidationResult(
          isValid: false,
          error: 'File name contains invalid characters',
        );
      }

      // Check file header (basic magic number validation)
      final headerValidation = await _validateFileHeader(file);
      if (!headerValidation.isValid) {
        return headerValidation;
      }

      return FileValidationResult(isValid: true);
    } catch (e) {
      return FileValidationResult(
        isValid: false,
        error: 'Error validating file: $e',
      );
    }
  }

  /// Validate file header to detect file type mismatch
  static Future<FileValidationResult> _validateFileHeader(File file) async {
    try {
      final bytesList = await file.openRead(0, 16).first;
      final bytes = Uint8List.fromList(bytesList);
      final extension = file.path.split('.').last.toLowerCase();

      // Check for executable files
      if (_isExecutableFile(bytes)) {
        return FileValidationResult(
          isValid: false,
          error: 'Executable files are not allowed',
        );
      }

      // Check for script files
      if (_isScriptFile(bytes, extension)) {
        return FileValidationResult(
          isValid: false,
          error: 'Script files are not allowed',
        );
      }

      // Validate common file types
      if (!_validateFileType(bytes, extension)) {
        return FileValidationResult(
          isValid: false,
          error: 'File type mismatch detected',
        );
      }

      return FileValidationResult(isValid: true);
    } catch (e) {
      return FileValidationResult(
        isValid: false,
        error: 'Error reading file header: $e',
      );
    }
  }

  /// Check if file is executable
  static bool _isExecutableFile(Uint8List bytes) {
    // Check for MZ header (Windows executables)
    if (bytes.length >= 2 && bytes[0] == 0x4D && bytes[1] == 0x5A) {
      return true;
    }

    // Check for ELF header (Linux executables)
    if (bytes.length >= 4 &&
        bytes[0] == 0x7F &&
        bytes[1] == 0x45 &&
        bytes[2] == 0x4C &&
        bytes[3] == 0x46) {
      return true;
    }

    // Check for Mach-O header (macOS executables)
    if (bytes.length >= 4 &&
            (bytes[0] == 0xFE &&
                bytes[1] == 0xED &&
                bytes[2] == 0xFA &&
                bytes[3] == 0xCE) ||
        (bytes[0] == 0xFE &&
            bytes[1] == 0xED &&
            bytes[2] == 0xFA &&
            bytes[3] == 0xCF)) {
      return true;
    }

    return false;
  }

  /// Check if file is a script
  static bool _isScriptFile(Uint8List bytes, String extension) {
    // Check for shebang
    if (bytes.length >= 2 && bytes[0] == 0x23 && bytes[1] == 0x21) {
      return true;
    }

    // Check for script extensions
    return ['sh', 'bash', 'ps1', 'py', 'php', 'js', 'vbs'].contains(extension);
  }

  /// Validate file type based on header
  static bool _validateFileType(Uint8List bytes, String extension) {
    switch (extension) {
      case 'pdf':
        // Check for PDF header
        return bytes.length >= 4 &&
            bytes[0] == 0x25 &&
            bytes[1] == 0x50 &&
            bytes[2] == 0x44 &&
            bytes[3] == 0x46;

      case 'jpg':
      case 'jpeg':
        // Check for JPEG header
        return bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;

      case 'png':
        // Check for PNG header
        return bytes.length >= 8 &&
            bytes[0] == 0x89 &&
            bytes[1] == 0x50 &&
            bytes[2] == 0x4E &&
            bytes[3] == 0x47;

      case 'gif':
        // Check for GIF header
        return bytes.length >= 6 &&
            bytes[0] == 0x47 &&
            bytes[1] == 0x49 &&
            bytes[2] == 0x46;

      case 'doc':
      case 'docx':
      case 'ppt':
      case 'pptx':
      case 'xls':
      case 'xlsx':
        // Office files have complex headers, just check extension
        return true;

      default:
        // For other file types, just check extension
        return true;
    }
  }

  /// Sanitize file name
  static String sanitizeFileName(String fileName) {
    return ConfigService.sanitizeFileName(fileName);
  }

  /// Check if file type is allowed
  static bool isFileTypeAllowed(String fileName) {
    return ConfigService.isValidFileType(fileName);
  }

  /// Check if file size is within limits
  static bool isFileSizeValid(int fileSize) {
    return ConfigService.isValidFileSize(fileSize);
  }
}

class FileValidationResult {
  final bool isValid;
  final String? error;

  FileValidationResult({required this.isValid, this.error});
}
