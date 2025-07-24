# EduNest Admin Panel Documentation

## Overview
The EduNest Admin Panel is a web-based interface for managing educational content, user data, and system configuration. It provides comprehensive tools for administrators to manage colleges, branches, subjects, topics, and AI-powered question generation.

## Access & Authentication

### Login
- **URL:** `/admin_panel/index.html`
- **Credentials:** Admin email and password
- **Session:** Stored in browser sessionStorage

### Security Features
- JWT-based authentication
- Session timeout after 24 hours
- Role-based access control
- Secure API communication

## Dashboard (`dashboard.html`)

### Overview Statistics
- Total colleges, branches, semesters, subjects
- Recent activity feed
- System health indicators
- Quick action buttons

### Navigation
- **Colleges** - Manage educational institutions
- **Branches** - Manage departments/streams
- **Semesters** - Manage academic periods
- **Subjects** - Manage course subjects
- **Topics** - Manage subject topics
- **Files** - Manage educational resources
- **AI Config** - Configure AI settings

## College Management (`colleges.html`)

### Features
- **Add College:** Create new educational institutions
- **View Colleges:** List all colleges with details
- **Edit College:** Modify college information
- **Delete College:** Remove colleges (with confirmation)

### Data Fields
- **Name:** College name
- **Code:** Unique college identifier
- **Description:** Additional information

### Operations
```javascript
// Add college
const collegeData = {
  name: "Engineering College",
  code: "EC001",
  description: "Premier engineering institution"
};

// View colleges
const colleges = await supabase
  .from('colleges')
  .select('*')
  .order('name');
```

## Branch Management (`branches.html`)

### Features
- **Add Branch:** Create new departments/streams
- **Filter by College:** View branches by college
- **Edit Branch:** Modify branch information
- **Delete Branch:** Remove branches

### Data Fields
- **Name:** Branch/department name
- **College:** Associated college
- **Description:** Additional information

### Hierarchy
```
College → Branch → Semester → Subject → Topic
```

## Semester Management (`semesters.html`)

### Features
- **Add Semester:** Create new academic periods
- **Filter by Branch:** View semesters by branch
- **Edit Semester:** Modify semester information
- **Delete Semester:** Remove semesters

### Data Fields
- **Name:** Semester name (e.g., "1st Semester", "2nd Semester")
- **Branch:** Associated branch
- **Description:** Additional information

## Subject Management (`subjects.html`)

### Features
- **Add Subject:** Create new course subjects
- **Filter by Semester:** View subjects by semester
- **Edit Subject:** Modify subject information
- **Delete Subject:** Remove subjects
- **Upload Syllabus:** Upload and manage syllabus files

### Data Fields
- **Name:** Subject name
- **Code:** Subject code
- **Semester:** Associated semester
- **Description:** Subject description
- **Syllabus:** Syllabus file and extracted text

### Syllabus Management
- **File Upload:** PDF/DOCX files
- **Text Extraction:** AI-powered text extraction
- **Version Control:** Multiple syllabus versions
- **Preview:** Built-in file viewer

## Topic Management (`topics.html`)

### Features
- **Add Topic:** Create new subject topics
- **Filter by Subject:** View topics by subject
- **Edit Topic:** Modify topic content
- **Delete Topic:** Remove topics
- **AI Question Generation:** Generate MCQ questions

### Data Fields
- **Name:** Topic name
- **Subject:** Associated subject
- **Content:** Topic content (rich text)
- **Tags:** Topic tags for organization

### AI Question Generation
- **Difficulty Levels:** Easy, Medium, Hard
- **Question Count:** 5-20 questions per generation
- **Content Analysis:** AI analyzes topic content
- **Quality Control:** Review before saving

## File Management (`files.html`)

### Features
- **Upload Files:** Notes, assignments, lab manuals
- **File Organization:** By subject and type
- **File Preview:** Built-in viewer
- **Download Management:** Track downloads
- **Storage Management:** Monitor storage usage

### File Types
- **Notes:** Lecture notes and study materials
- **Assignments:** Homework and projects
- **Lab Manuals:** Laboratory instructions
- **Syllabus:** Course outlines
- **Timetables:** Class schedules

### Storage Integration
- **Supabase Storage:** Primary storage
- **Google Drive:** Backup storage
- **File Compression:** Automatic optimization
- **CDN:** Fast global delivery

## AI Configuration (`ai-config.html`)

### Features
- **Hugging Face Token:** Configure AI API access
- **Token Validation:** Test API connectivity
- **Usage Monitoring:** Track API usage
- **Cost Management:** Monitor API costs

### AI Services
- **Question Generation:** MCQ creation
- **Text Extraction:** PDF/DOCX processing
- **Content Analysis:** Topic understanding
- **Quality Assessment:** Question validation

### Configuration
```javascript
// Test AI configuration
const testResult = await testAIConfiguration();

// Generate questions
const questions = await generateQuestions({
  topicId: "uuid",
  questionCount: 10,
  difficulty: "medium"
});
```

## Topic Editor (`topic_edit.html`)

### Features
- **Rich Text Editor:** WYSIWYG content creation
- **Question Management:** View and edit questions
- **AI Integration:** Generate questions from content
- **Preview Mode:** Preview topic appearance

### Question Management
- **View Questions:** List all questions for topic
- **Edit Questions:** Modify question content
- **Delete Questions:** Remove questions
- **Bulk Operations:** Mass question operations

### AI Question Generation
- **Content Analysis:** AI reads topic content
- **Question Types:** Multiple choice questions
- **Difficulty Control:** Adjust question complexity
- **Quality Review:** Preview before saving

## User Management

### Features
- **User List:** View all registered users
- **User Details:** Profile information
- **Activity Tracking:** User engagement metrics
- **Account Management:** Password reset, account status

### User Roles
- **Students:** Regular users
- **Teachers:** Content creators
- **Admins:** Full system access

## System Configuration

### Settings
- **Database Configuration:** Connection settings
- **Storage Settings:** File storage configuration
- **AI Settings:** API keys and limits
- **Security Settings:** Authentication configuration

### Monitoring
- **System Health:** Database and storage status
- **Performance Metrics:** Response times and usage
- **Error Logging:** System error tracking
- **User Analytics:** Usage statistics

## API Integration

### Supabase Client
```javascript
// Initialize client
const supabase = createClient(url, key);

// Database operations
const { data, error } = await supabase
  .from('table_name')
  .select('*')
  .eq('column', 'value');
```

### File Operations
```javascript
// Upload file
const { data, error } = await supabase.storage
  .from('bucket_name')
  .upload('path/to/file', file);

// Download file
const { data, error } = await supabase.storage
  .from('bucket_name')
  .download('path/to/file');
```

## Security Features

### Authentication
- **JWT Tokens:** Secure session management
- **Session Timeout:** Automatic logout
- **Password Policies:** Strong password requirements
- **Two-Factor Authentication:** Enhanced security

### Data Protection
- **Row Level Security:** Database-level access control
- **Input Validation:** XSS and injection protection
- **File Upload Security:** Malware scanning
- **API Rate Limiting:** Prevent abuse

### Audit Logging
- **User Actions:** Track all admin actions
- **Data Changes:** Log all modifications
- **Access Logs:** Monitor system access
- **Error Logs:** Track system errors

## Troubleshooting

### Common Issues

#### 1. Login Problems
- **Issue:** Cannot log in
- **Solution:** Check credentials and session storage
- **Debug:** Clear browser cache and cookies

#### 2. File Upload Failures
- **Issue:** Files not uploading
- **Solution:** Check file size and format
- **Debug:** Verify storage bucket permissions

#### 3. AI Generation Errors
- **Issue:** Questions not generating
- **Solution:** Verify API token and limits
- **Debug:** Check network connectivity

#### 4. Database Connection Issues
- **Issue:** Data not loading
- **Solution:** Check Supabase connection
- **Debug:** Verify API keys and permissions

### Error Messages
- **"Unauthorized"** - Check authentication
- **"Not Found"** - Verify resource exists
- **"Rate Limited"** - Wait before retrying
- **"Storage Error"** - Check file permissions

## Performance Optimization

### Best Practices
- **Lazy Loading:** Load data on demand
- **Caching:** Cache frequently accessed data
- **Image Optimization:** Compress images
- **Code Splitting:** Load only needed features

### Monitoring
- **Response Times:** Track API performance
- **Memory Usage:** Monitor browser memory
- **Network Requests:** Optimize API calls
- **User Experience:** Track user interactions

## Deployment

### Requirements
- **Web Server:** Apache/Nginx
- **HTTPS:** SSL certificate required
- **Browser Support:** Modern browsers only
- **Storage:** Adequate file storage

### Configuration
- **Environment Variables:** API keys and URLs
- **CORS Settings:** Cross-origin configuration
- **Security Headers:** Content security policy
- **Backup Strategy:** Regular data backups

## Support

### Documentation
- **User Guide:** Step-by-step instructions
- **API Reference:** Technical documentation
- **Video Tutorials:** Visual learning resources
- **FAQ:** Common questions and answers

### Contact
- **Email:** admin@edunest.com
- **Support Portal:** https://support.edunest.com
- **GitHub Issues:** https://github.com/edunest/admin/issues
- **Live Chat:** Available during business hours

## Updates & Maintenance

### Version Control
- **Git Repository:** Source code management
- **Release Notes:** Feature updates and fixes
- **Backup Strategy:** Regular system backups
- **Rollback Plan:** Emergency recovery procedures

### Maintenance Schedule
- **Daily:** System health checks
- **Weekly:** Performance optimization
- **Monthly:** Security updates
- **Quarterly:** Feature updates 