# EduNest Mobile App Documentation

## Overview
EduNest is a comprehensive educational mobile application built with Flutter that provides students with access to study materials, practice tests, attendance tracking, and AI-powered learning features.

## App Architecture

### Technology Stack
- **Framework:** Flutter 3.x
- **Language:** Dart
- **Backend:** Supabase (PostgreSQL + Real-time)
- **Authentication:** Supabase Auth
- **Storage:** Supabase Storage + Google Drive
- **AI Services:** Hugging Face API
- **State Management:** GetX Controllers

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

### 4. Practice Tests
- **MCQ Tests:** Multiple choice questions
- **Difficulty Levels:** Easy, Medium, Hard
- **Topic-based:** Subject-specific questions
- **AI-Generated:** Dynamic question creation
- **Results Tracking:** Performance analytics

### 5. Attendance Tracking
- **Daily Logging:** Mark attendance for subjects
- **Visual Calendar:** Monthly attendance view
- **Statistics:** Attendance percentage
- **Export:** Attendance reports

### 6. AI-Powered Features
- **Question Generation:** AI creates MCQs from topics
- **Content Analysis:** Intelligent content processing
- **Personalized Learning:** Adaptive difficulty

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
  - Assignment list
  - Due date tracking
  - Submission status
  - File downloads
- **Organization:**
  - By subject
  - By due date
  - By completion status

#### Lab Manuals Screen (`lab_manuals_screen.dart`)
- **Purpose:** Laboratory instructions
- **Features:**
  - Manual downloads
  - Experiment procedures
  - Safety guidelines
  - Equipment lists

### Practice Test Screens

#### Practice Tests Screen (`practice_tests_screen.dart`)
- **Purpose:** Test selection and management
- **Features:**
  - Available tests list
  - Difficulty selection
  - Progress tracking
  - Test history
- **Network Handling:**
  - Full-page network error overlay
  - Retry functionality
  - Loading states

#### MCQ Test Screen (`mcq_test_screen.dart`)
- **Purpose:** Take practice tests
- **Features:**
  - Question navigation
  - Timer functionality
  - Answer selection
  - Progress tracking
- **UI Elements:**
  - Question display
  - Multiple choice options
  - Navigation buttons
  - Timer display

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
- **Purpose:** AI-powered question generation
- **Features:**
  - Question creation
  - Content analysis
  - Difficulty adjustment
  - Quality control

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
  final DateTime date;
  final String status;
  final DateTime createdAt;
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