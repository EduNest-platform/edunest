# File Management System Guide

## Overview
The EduNest admin panel includes a comprehensive file management system that allows you to upload, organize, and manage files by type. Files are automatically categorized and can be fetched separately by type.

## File Types
The system supports the following file types:
- **📝 Notes** - Study notes and materials
- **📋 PYQ** - Previous Year Questions
- **📚 Syllabus** - Course syllabus and curriculum
- **📄 Assignment** - Assignments and projects
- **📁 Other** - Miscellaneous files

## How Files Are Stored

### Database Structure
Files are stored in the `files` table with the following key fields:
- `id` - Unique identifier
- `name` - File name
- `description` - Optional description
- `file_type` - Type of file (notes, pyq, syllabus, assignment, other)
- `file_url` - URL to the actual file
- `file_size` - File size in bytes
- `storage_provider` - Where file is stored (supabase/google-drive)
- `subject_id` - Associated subject
- `uploaded_by` - Who uploaded the file
- `created_at` - Upload timestamp

### Storage Providers
- **Supabase Storage**: For files < 5MB (fast access)
- **Google Drive**: For files 5MB-10MB (large files)

## How to Fetch Files by Type

### 1. In the Admin Panel
The admin panel automatically organizes files by type and provides:
- **Filter tabs** to view files by type
- **Statistics** showing counts for each type
- **Search functionality** within each type
- **Real-time updates** when files are added/removed

### 2. In Your Flutter App
You can fetch files by type using these functions:

```javascript
// Get all files for a subject
const allFiles = await getAllFilesForSubject(subjectId);

// Get only notes
const notes = await getNotes(subjectId);

// Get only PYQ files
const pyqFiles = await getPYQFiles(subjectId);

// Get only syllabus files
const syllabusFiles = await getSyllabusFiles(subjectId);

// Get only assignment files
const assignmentFiles = await getAssignmentFiles(subjectId);

// Get other files
const otherFiles = await getOtherFiles(subjectId);

// Get file counts by type
const counts = await getFileCountsByType(subjectId);
console.log(`Total: ${counts.total}, Notes: ${counts.notes}, PYQ: ${counts.pyq}`);
```

### 3. Advanced Queries

```javascript
// Search files by name or description
const searchResults = await searchFiles(subjectId, 'chapter 1');

// Search within a specific type
const notesSearch = await searchFiles(subjectId, 'chapter 1', 'notes');

// Get paginated results
const page1Notes = await getFilesWithPagination(subjectId, 1, 10, 'notes');
```

## File Organization Features

### Automatic Categorization
- Files are automatically categorized based on the `file_type` field
- Each type has its own icon and styling
- Statistics are updated in real-time

### Filtering System
- **All Files**: Shows all files for the subject
- **Notes**: Shows only study notes
- **PYQ**: Shows only previous year questions
- **Syllabus**: Shows only syllabus files
- **Other**: Shows miscellaneous files

### Search Functionality
- Search by file name or description
- Works within the current filter
- Highlights search terms in results
- Real-time search as you type

## Integration with Flutter App

### Step 1: Include the Integration File
Add `files-integration-example.js` to your Flutter web app:

```html
<script src="files-integration-example.js"></script>
```

### Step 2: Use the Functions
```javascript
// Example: Load notes for a subject
async function loadSubjectNotes(subjectId) {
    try {
        const { data, error } = await window.FileManager.getNotes(subjectId);
        if (error) throw error;
        
        // Process the notes data
        console.log('Notes loaded:', data);
        return data;
    } catch (error) {
        console.error('Error loading notes:', error);
    }
}

// Example: Get file statistics
async function getSubjectFileStats(subjectId) {
    try {
        const counts = await window.FileManager.getFileCountsByType(subjectId);
        return counts;
    } catch (error) {
        console.error('Error getting file stats:', error);
    }
}
```

### Step 3: Display in Flutter
```dart
// In your Flutter widget
class FileListWidget extends StatefulWidget {
  final String subjectId;
  
  @override
  _FileListWidgetState createState() => _FileListWidgetState();
}

class _FileListWidgetState extends State<FileListWidget> {
  List<dynamic> notes = [];
  List<dynamic> pyqFiles = [];
  
  @override
  void initState() {
    super.initState();
    loadFiles();
  }
  
  Future<void> loadFiles() async {
    // Load notes
    final notesData = await context.read<FileService>().getNotes(widget.subjectId);
    setState(() {
      notes = notesData;
    });
    
    // Load PYQ files
    final pyqData = await context.read<FileService>().getPYQFiles(widget.subjectId);
    setState(() {
      pyqFiles = pyqData;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Notes section
        Text('Notes (${notes.length})'),
        ...notes.map((note) => FileCard(file: note)),
        
        // PYQ section
        Text('PYQ Files (${pyqFiles.length})'),
        ...pyqFiles.map((pyq) => FileCard(file: pyq)),
      ],
    );
  }
}
```

## Benefits of Separate File Types

### 1. Better Organization
- Students can easily find specific types of materials
- Clear categorization improves user experience
- Reduces clutter and confusion

### 2. Targeted Search
- Search within specific file types
- More relevant search results
- Faster file discovery

### 3. Analytics and Insights
- Track which types of content are most popular
- Understand student needs better
- Optimize content strategy

### 4. Performance
- Load only needed file types
- Reduce bandwidth usage
- Faster page loads

## Best Practices

### 1. File Naming
- Use descriptive names (e.g., "Chapter 1 - Introduction Notes")
- Include relevant keywords for better search
- Use consistent naming conventions

### 2. File Types
- Choose the most appropriate type for each file
- Use "Other" sparingly
- Be consistent with categorization

### 3. Descriptions
- Add helpful descriptions for better search
- Include key topics or chapters covered
- Mention file format if relevant

### 4. File Sizes
- Keep files under 5MB for Supabase storage
- Use Google Drive for larger files
- Consider compressing files when possible

## Troubleshooting

### Common Issues
1. **Files not showing**: Check if the subject ID is correct
2. **Wrong file type**: Verify the `file_type` field in the database
3. **Search not working**: Ensure the search query is not empty
4. **Upload failures**: Check file size limits and storage provider availability

### Debug Tips
- Use browser console to check for JavaScript errors
- Verify Supabase connection and permissions
- Check file URLs for accessibility
- Monitor network requests for API calls

This file management system provides a robust foundation for organizing and accessing educational content efficiently in your EduNest application. 