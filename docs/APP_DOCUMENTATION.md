# EduNest Mobile App Documentation

## Overview
EduNest is a comprehensive educational mobile application built with Flutter that provides students with access to study materials, practice tests, attendance tracking, and AI-powered learning features.

## App Architecture

### Technology Stack
- **Framework:** Flutter 3.16.0+
- **Language:** Dart 3.2.0+
- **Backend:** Supabase (PostgreSQL + Real-time)
- **Authentication:** Supabase Auth (JWT)
- **Storage:** Supabase Storage + Google Drive
- **AI Services:** Google Gemini API
- **State Management:** Provider pattern
- **UI:** Material Design 3 with Google Fonts

### Project Structure
```
lib/
├── main.dart                 # App entry point
├── controllers/              # Business logic
├── models/                   # Data models
├── screens/                  # UI screens
├── services/                 # API and external services
├── theme/                    # App theming
└── widgets/                  # Reusable components
```

## Core Features

### 1. Authentication System
- **Sign Up:** Email-based registration
- **Login:** Secure authentication
- **Profile Setup:** Academic information collection
- **Password Management:** Change password functionality
- **Session Management:** Automatic token refresh

### 2. Academic Information
- **College Selection:** Choose from available colleges
- **Branch Management:** Select department/stream
- **Semester Tracking:** Current semester information
- **Subject Overview:** Enrolled subjects list

### 3. Study Resources
- **Notes:** Lecture notes and study materials
- **Assignments:** Homework and project files
- **Lab Manuals:** Laboratory instructions
- **Syllabus:** Course outlines and objectives
- **Timetables:** Class schedules

### 4. Practice Tests & Assessment System
- **Three Practice Modes:** Academic, Competitive Exam, and Career Prep modes
- **Smart Mode Detection:** Automatically shows "GATE Prep Mode" for GATE topics, "Competitive Exam Mode" for others
- **Multiple Question Counts:** Choose from 10, 15, or 20 questions per test
- **AI-Generated:** Dynamic question creation with bulk generation (60 questions across all modes)
- **Assigned Tests:** Professor-assigned protected tests with time limits and restricted access
- **Proctored Testing:** App monitoring prevents switching during protected tests
- **Auto-Submit Security:** Tests automatically submit if user leaves the app during proctoring
- **Results Tracking:** Performance analytics and completion status tracking

### 5. Attendance Management System
- **Smart Daily Tracking:** Visual calendar with attendance marking
- **75% Target Calculator:** Real-time calculation of required classes
- **Professor Dashboard:** Complete class roster management
- **Bulk Operations:** Mark all present/absent with one click
- **CSV/Excel Import:** Upload class rosters from spreadsheets
- **Analytics Dashboard:** Comprehensive attendance trends and statistics
- **Student Verification:** Track verified vs unverified students
- **Date-wise Reports:** Historical attendance data with filtering
- **Export Functionality:** Download attendance reports in multiple formats
- **Professor-Managed Mode:** Students can track their own attendance or let professors manage it

### 6. AI-Powered Features
- **Question Generation:** AI creates MCQs from study materials using Google Gemini API
- **Bulk Generation:** Create 20 questions for all 3 modes (60 total) with one click
- **Content Analysis:** Intelligent content processing and topic detection
- **Dynamic Mode Detection:** Automatically detects GATE vs non-GATE topics for competitive mode
- **Personalized Learning:** Adaptive difficulty and mode suggestions

### 7. Assignment Marks System
- **Complete Grade Tracking:** Comprehensive assignment score management
- **Subject-wise Organization:** Grades organized by subjects and classes
- **Performance Analytics:** Historical grade trends and academic progress insights
- **Class Integration:** Seamless integration with class rosters
- **Export Functionality:** Download grade reports for institutional records

### 8. Subject Feedback System
- **Feedback Campaigns:** Structured feedback collection for subjects and professors
- **Anonymous Responses:** Students can provide honest feedback without revealing identity
- **5-Point Rating Scale:** Standard rating system for Teaching Quality, Course Content, Professor Knowledge, Interaction, and Overall Satisfaction
- **Campaign Management:** Time-bound feedback campaigns with target audiences
- **Real-time Analytics:** Comprehensive feedback analytics with subject-wise comparisons
- **Export Reports:** Download feedback data for institutional analysis

### 9. Performance Optimization & System Monitoring
- **Exam Mode Optimization:** Automatic resource optimization when multiple students take tests
- **Real-time Monitoring:** System health tracking with memory, CPU, and network metrics
- **Adaptive Caching:** Smart caching strategies that adjust based on usage patterns
- **Load Balancing:** Dynamic resource allocation during peak usage periods
- **Performance Dashboard:** Administrative monitoring with alerts and insights

## Screen Documentation

### Authentication Screens

#### Login Screen (`login_screen.dart`)
- **Purpose:** User authentication
- **Features:**
  - Email and password input
  - Remember me functionality
  - Forgot password link
  - Sign up navigation
  - Network connectivity check
- **UI Elements:**
  - Logo and branding
  - Input validation
  - Loading states
  - Error messages with emojis

#### Signup Screen (`signup_screen.dart`)
- **Purpose:** New user registration
- **Features:**
  - Email and password creation
  - Password strength validation
  - Email confirmation
  - Terms and conditions
- **Validation:**
  - Email format validation
  - Password requirements
  - Duplicate email check

#### Profile Setup Screen (`profile_setup_screen.dart`)
- **Purpose:** Complete user profile
- **Features:**
  - Personal information collection
  - Academic details setup
  - Profile picture upload
  - College and branch selection
- **Data Collection:**
  - Full name
  - College selection
  - Branch/department
  - Semester information

### Main App Screens

#### Home Screen (`home_screen.dart`)
- **Purpose:** Main navigation hub
- **Features:**
  - Quick access to all features
  - Recent activity feed
  - Notifications center
  - User profile summary
- **Navigation:**
  - Drawer menu
  - Bottom navigation
  - Quick action buttons

#### Academic Info Screen (`academic_info_screen.dart`)
- **Purpose:** Display academic information
- **Features:**
  - College and branch details
  - Current semester info
  - Subject list
  - Academic progress
- **Network Handling:**
  - Full-page network error overlay
  - Retry functionality
  - Loading states

#### Subject View Screen (`subject_view_screen.dart`)
- **Purpose:** Subject-specific content
- **Features:**
  - Subject details
  - Resource tabs (notes, assignments, etc.)
  - Topic list
  - Practice test access
- **Content Organization:**
  - Tabbed interface
  - File categorization
  - Search functionality

### Resource Screens

#### Notes Screen (`notes_screen.dart`)
- **Purpose:** Access study materials
- **Features:**
  - File list with previews
  - Download functionality
  - Search and filter
  - Offline access
- **File Types:**
  - PDF documents
  - Word documents
  - PowerPoint presentations

#### Assignments Screen (`assignments_screen.dart`)
- **Purpose:** Homework and project access
- **Features:**
  - Assignment list with due date tracking
  - Submission status and progress tracking
  - File downloads and offline access
  - Search and filter functionality
  - Grade display and performance metrics
- **Organization:**
  - By subject and class
  - By due date and priority
  - By completion status and grades

#### Lab Manuals Screen (`lab_manuals_screen.dart`)
- **Purpose:** Laboratory instructions
- **Features:**
  - Manual downloads
  - Experiment procedures
  - Safety guidelines
  - Equipment lists

### Assignment Marks Screens

#### Assignment Subjects Screen (`assignment_subjects_screen.dart`)
- **Purpose:** View assignment grades by subject
- **Features:**
  - Subject-wise grade organization
  - Assignment count per subject
  - Performance overview
  - Class-wise grade filtering
- **Navigation:**
  - Subject selection for detailed grades
  - Integration with academic info

#### Subject Assignment Marks Screen (`subject_assignment_marks_screen.dart`)
- **Purpose:** Detailed assignment grades for specific subjects
- **Features:**
  - Individual assignment scores
  - Grade history and trends
  - Performance analytics
  - Export functionality

### Subject Feedback Screens

#### Subject Feedback List Screen (`subject_feedback_list_screen.dart`)
- **Purpose:** List subjects available for feedback
- **Features:**
  - Subject selection for feedback
  - Active campaign indicators
  - Feedback completion status
  - Subject-wise organization

#### Feedback Form Screen (`feedback_form_screen.dart`)
- **Purpose:** Submit feedback for specific subjects
- **Features:**
  - 5-point rating scale questions
  - Anonymous submission option
  - Comment fields for detailed feedback
  - Campaign-specific questions
- **Validation:**
  - Required rating validation
  - Comment length limits
  - Submission confirmation

### Practice Test Screens

#### Practice Tests Screen (`practice_tests_screen.dart`)
- **Purpose:** Test selection and management
- **Features:**
  - Available tests list with three practice modes
  - Assigned tests section with professor-managed tests
  - Difficulty selection and question count options
  - Progress tracking and completion status
  - Test history and performance analytics
- **Network Handling:**
  - Full-page network error overlay
  - Retry functionality
  - Loading states

#### Assigned Test Card Screen (`assigned_test_card_screen.dart`)
- **Purpose:** Display and manage assigned tests
- **Features:**
  - Professor-assigned test list
  - Test status and deadlines
  - Completion tracking
  - Access controls and restrictions

#### MCQ Test Screen (`mcq_test_screen.dart`)
- **Purpose:** Take practice and assigned tests
- **Features:**
  - Question navigation with progress tracking
  - Timer functionality for assigned tests
  - Answer selection and review
  - Proctoring features for assigned tests
  - Auto-submit security for protected tests
- **UI Elements:**
  - Question display with mode indicators
  - Multiple choice options
  - Navigation buttons
  - Timer display for assigned tests
  - Proctoring warnings and alerts

#### Test Results Screen (`test_results_screen.dart`)
- **Purpose:** View test performance
- **Features:**
  - Score display
  - Question review
  - Performance analytics
  - Share results
- **Analytics:**
  - Correct/incorrect answers
  - Time taken
  - Difficulty breakdown
  - Improvement suggestions

### Attendance Screens

#### Attendance Screen (`attendance_screen.dart`)
- **Purpose:** Track daily attendance
- **Features:**
  - Subject list
  - Attendance marking
  - Calendar view
  - Statistics display
- **Network Handling:**
  - Full-page network error overlay
  - Retry functionality
  - Loading states

#### Attendance Tracking Screen (`attendance_tracking_screen.dart`)
- **Purpose:** Detailed attendance management
- **Features:**
  - Monthly calendar
  - Attendance percentage
  - Subject-wise breakdown
  - Export functionality

### Profile & Settings Screens

#### Profile Screen (`profile_screen.dart`)
- **Purpose:** User profile management
- **Features:**
  - Profile information display
  - Edit profile functionality
  - Profile picture management
  - Account settings
- **Actions:**
  - Update personal info
  - Change profile picture
  - View academic details
  - Account preferences

#### Settings Screen (`settings_screen.dart`)
- **Purpose:** App configuration
- **Features:**
  - Theme selection
  - Notification settings
  - Privacy options
  - About information
- **Options:**
  - Dark/Light mode
  - Push notifications
  - Data usage
  - App version

## Services Architecture

### Network Service (`network_service.dart`)
- **Purpose:** Internet connectivity management
- **Features:**
  - Real-time connectivity monitoring
  - Multiple endpoint testing
  - Automatic retry mechanism
  - User-friendly error messages
- **Implementation:**
  - Singleton pattern
  - Connectivity plus package
  - HTTP package for testing
  - Timeout handling

### Authentication Service (`auth_service.dart`)
- **Purpose:** User authentication management
- **Features:**
  - Sign up and login
  - Session management
  - Password operations
  - Profile management
- **Security:**
  - JWT token handling
  - Secure storage
  - Token refresh
  - Session validation

### Supabase Service (`supabase_service.dart`)
- **Purpose:** Database operations
- **Features:**
  - CRUD operations
  - Real-time subscriptions
  - File storage
  - Query optimization
- **Tables:**
  - User profiles
  - Academic data
  - Test results
  - Attendance records

### AI Services
#### AI Config Service (`ai_config_service.dart`)
- **Purpose:** AI configuration management
- **Features:**
  - API token management
  - Service availability check
  - Usage monitoring
  - Configuration validation

#### Hybrid AI Service (`hybrid_ai_service.dart`)
- **Purpose:** AI-powered question generation using Google Gemini
- **Features:**
  - Question creation across three practice modes
  - Bulk generation (60 questions with one click)
  - Content analysis and topic detection
  - Dynamic GATE vs non-GATE mode detection
  - Quality control and validation

### Assessment Services
#### Test Results Service (`test_results_service.dart`)
- **Purpose:** Test performance and results management
- **Features:**
  - Test completion tracking
  - Performance analytics
  - Historical data storage
  - Progress calculations

#### Assigned MCQ Supabase Service (`assigned_mcq_supabase_service.dart`)
- **Purpose:** Manage professor-assigned tests
- **Features:**
  - Assigned test retrieval
  - Access control validation
  - Completion status tracking
  - Proctoring support

### Grade Management Services
#### Assignment Marks Service (`assignment_marks_service.dart`)
- **Purpose:** Assignment grade management
- **Features:**
  - Grade data retrieval
  - Subject-wise organization
  - Performance calculations
  - Class integration

### Feedback Services
#### Subject Feedback Service (`subject_feedback_service.dart`)
- **Purpose:** Feedback campaign and response management
- **Features:**
  - Campaign retrieval
  - Anonymous feedback submission
  - Response validation
  - Analytics data preparation

### Performance Services
#### Exam Optimization Service (`exam_optimization_service.dart`)
- **Purpose:** System optimization during high-load periods
- **Features:**
  - Exam mode activation/deactivation
  - Resource allocation optimization
  - Performance monitoring
  - Load balancing

#### Monitoring Integration Helper (`monitoring_integration_helper.dart`)
- **Purpose:** System health and performance tracking
- **Features:**
  - Real-time metrics collection
  - Performance alerts
  - Usage analytics
  - System health reporting

## State Management

### Controllers
- **Login Controller:** Authentication state
- **Profile Setup Controller:** Profile creation
- **Signup Controller:** Registration process

### Models
- **User Profile:** User information
- **Subject:** Academic subjects
- **Attendance Record:** Attendance data

## UI/UX Design

### Theme System (`app_theme.dart`)
- **Color Scheme:**
  - Primary colors
  - Secondary colors
  - Background colors
  - Text colors
- **Typography:**
  - Font families
  - Font sizes
  - Font weights
- **Components:**
  - Button styles
  - Input fields
  - Cards
  - Navigation

### Custom Widgets
- **Custom App Bar:** Consistent navigation
- **Drawer Menu:** Side navigation
- **Network Error Widget:** Connectivity issues
- **Loading Widgets:** Loading states

## Network Connectivity

### NetworkAwareMixin
- **Purpose:** Network-aware screen behavior
- **Features:**
  - Automatic network detection
  - Error overlay display
  - Retry functionality
  - Context-specific messages
- **Implementation:**
  - Mixin pattern
  - Reusable components
  - Emoji-based messaging
  - Full-page overlays

### Error Handling
- **Network Errors:**
  - No internet connection
  - Server unavailable
  - Timeout errors
  - API errors
- **User Experience:**
  - Friendly error messages
  - Retry options
  - Offline indicators
  - Loading states

## Data Models

### User Profile
```dart
class UserProfile {
  final String id;
  final String fullName;
  final String email;
  final String college;
  final String branch;
  final String semester;
  final String? profileImageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

### Subject
```dart
class Subject {
  final String id;
  final String name;
  final String code;
  final String semesterId;
  final String description;
  final DateTime createdAt;
}
```

### Attendance Record
```dart
class AttendanceRecord {
  final String id;
  final String userId;
  final String subjectId;
  final String subjectName;
  final DateTime date;
  final String status; // 'present' or 'absent'
  final DateTime createdAt;
}
```

### Assignment Mark
```dart
class AssignmentMark {
  final String id;
  final String studentId;
  final String assignmentId;
  final String assignmentName;
  final double marks;
  final double maxMarks;
  final String subjectId;
  final String subjectName;
  final DateTime submissionDate;
  final String? feedback;
}
```

## Performance Optimization

### Best Practices
- **Lazy Loading:** Load data on demand
- **Image Caching:** Optimize image loading
- **State Management:** Efficient state updates
- **Memory Management:** Proper disposal

### Network Optimization
- **Request Caching:** Cache API responses
- **Image Compression:** Optimize file sizes
- **Batch Operations:** Reduce API calls
- **Offline Support:** Local data storage

## Security Features

### Authentication
- **JWT Tokens:** Secure session management
- **Token Refresh:** Automatic renewal
- **Secure Storage:** Encrypted local storage
- **Session Validation:** Regular checks

### Data Protection
- **Input Validation:** Sanitize user inputs
- **HTTPS:** Secure communication
- **File Validation:** Safe file uploads
- **Privacy Controls:** User data protection

## Testing

### Unit Tests
- **Service Tests:** API service testing
- **Controller Tests:** Business logic testing
- **Model Tests:** Data model validation

### Widget Tests
- **UI Tests:** Component testing
- **Integration Tests:** Screen flow testing
- **Network Tests:** Connectivity testing

## Deployment

### Build Configuration
- **Android:** APK and AAB builds
- **iOS:** IPA builds
- **Web:** Progressive Web App
- **Desktop:** Windows, macOS, Linux

### Release Process
- **Version Management:** Semantic versioning
- **Code Signing:** Digital certificates
- **Store Deployment:** App store submission
- **OTA Updates:** Over-the-air updates

## Support & Maintenance

### Error Tracking
- **Crash Reporting:** Automatic error collection
- **Analytics:** User behavior tracking
- **Performance Monitoring:** App performance metrics
- **User Feedback:** In-app feedback system

### Updates
- **Feature Updates:** Regular feature releases
- **Bug Fixes:** Issue resolution
- **Security Patches:** Security updates
- **Performance Improvements:** Optimization updates

## Future Enhancements

### Planned Features
- **Offline Mode:** Full offline functionality
- **Push Notifications:** Real-time alerts
- **Social Features:** Student collaboration
- **Advanced Analytics:** Detailed performance insights

### Technical Improvements
- **Performance Optimization:** Faster loading times
- **UI/UX Enhancements:** Better user experience
- **Accessibility:** Improved accessibility features
- **Internationalization:** Multi-language support

// [APK download/distribution link will be provided soon.] 