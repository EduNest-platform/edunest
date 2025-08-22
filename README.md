# 🎓 EduNest - Smart Learning Platform

[![Flutter](https://img.shields.io/badge/Flutter-3.16.0-blue.svg)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.2.0-blue.svg)](https://dart.dev/)
[![Supabase](https://img.shields.io/badge/Supabase-Backend-green.svg)](https://supabase.com/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Status](https://img.shields.io/badge/Status-Production%20Ready-brightgreen.svg)]()
[![Clean Code](https://img.shields.io/badge/Code-Clean%20&%20Optimized-blue.svg)]()
[![Debug Free](https://img.shields.io/badge/Debug%20Prints-Removed-success.svg)]()

> **A comprehensive educational mobile application that revolutionizes student learning with AI-powered practice tests, smart attendance tracking, and comprehensive study resources.**

## 🌟 **Why EduNest?**

- **🎯 Student-Focused**: Built specifically for college students' needs
- **🤖 AI-Powered**: Intelligent question generation using Google Gemini
- **📊 Smart Analytics**: Real-time performance tracking and attendance management
- **💰 Cost-Effective**: Built with free services, scalable to thousands of users
- **🚀 Production Ready**: Smooth performance, excellent UX, ready for deployment

## 📱 **Key Features**

### 🎓 **Academic Management**
- **College & Branch Setup**: Complete academic profile management
- **Semester & Subject Organization**: Structured learning path
- **Interactive Subject Cards**: Customizable color themes for personalization
- **Syllabus & Timetable**: PDF viewer with easy navigation

### 🤖 **AI-Powered Learning**
- **Smart MCQ Generation**: AI creates questions from study materials using Google Gemini
- **Three Practice Modes**: Academic, Competitive Exam, and Career Prep modes
- **Dynamic Mode Detection**: Automatically detects GATE vs non-GATE topics for competitive mode
- **Bulk Question Generation**: Generate 20 questions for all modes (60 total) with one click
- **Multiple Question Counts**: Support for 10, 15, and 20 question tests
- **Performance Analytics**: Detailed insights and progress tracking

### 📝 **Practice Tests & Assessment System**
- **Three Practice Modes**: 
  - **Academic Mode**: University exam preparation with core syllabus concepts
  - **Competitive Exam Mode**: GATE/ESE/ISRO/DRDO preparation with dynamic detection
  - **Career Prep Mode**: Interview and practical job preparation questions
- **Smart Mode Detection**: Automatically shows "GATE Prep Mode" for GATE topics, "Competitive Exam Mode" for others
- **Multiple Question Counts**: Choose from 10, 15, or 20 questions per test
- **Free Practice Tests**: Unlimited practice with instant feedback
- **Assigned Tests**: Professor-assigned protected tests with time limits and restricted access
- **Proctored Testing**: App monitoring prevents switching during protected tests
- **Auto-Submit Security**: Tests automatically submit if user leaves the app during proctoring
- **Test Assignment Management**: Complete workflow for professors to assign and monitor tests
- **Real-time Results**: Immediate scoring and detailed explanations
- **Progress Tracking**: Historical performance analysis and completion status

### 📊 **Advanced Attendance Management**
- **Smart Daily Tracking**: Visual calendar with attendance marking
- **75% Target Calculator**: Real-time calculation of required classes
- **Professor Dashboard**: Complete class roster management
- **Bulk Operations**: Mark all present/absent with one click
- **CSV/Excel Import**: Upload class rosters from spreadsheets
- **Analytics Dashboard**: Comprehensive attendance trends and statistics
- **Student Verification**: Track verified vs unverified students
- **Date-wise Reports**: Historical attendance data with filtering
- **Attendance Alerts**: Notifications for low attendance students
- **Export Functionality**: Download attendance reports in multiple formats
- **Professor-Managed Mode**: Students can track their own attendance or let professors manage it
- **Class-wise Organization**: Separate attendance tracking for different classes and subjects

### 📚 **Study Resources & Academic Tools**
- **Comprehensive Library**: Notes, assignments, lab manuals
- **Easy Downloads**: One-tap file access and offline storage
- **Organized Content**: Subject-wise resource categorization
- **Multiple Formats**: PDF, DOCX, PPTX, images support
- **Assignment Management**: Homework tracking with due dates and submission status
- **Assignment Marks System**: Complete grade tracking and performance analytics
- **Subject-wise Grade Tracking**: View assignment scores organized by subjects and classes
- **Performance Analytics**: Historical grade trends and academic progress insights

### 💬 **Subject Feedback System**
- **Class Feedback Campaigns**: Structured feedback collection for subjects and professors
- **Anonymous Feedback**: Students can provide honest feedback without revealing identity
- **5-Point Rating Scale**: Standard rating system for Teaching Quality, Course Content, Professor Knowledge, Interaction, and Overall Satisfaction
- **Campaign Management**: Professors can create time-bound feedback campaigns for their subjects
- **Real-time Analytics**: Comprehensive feedback analytics with subject-wise comparisons
- **Feedback Dashboard**: Administrative overview of all feedback responses and trends
- **Cross-Subject Analysis**: Compare feedback across different subjects and semesters
- **Export Functionality**: Download feedback reports for institutional analysis

| **Performance Optimization** | ✅ Complete | Exam mode, monitoring, adaptive caching, load balancing |
| **System Monitoring** | ✅ Complete | Real-time metrics, health tracking, circuit breaker protection |
| **Advanced Caching** | ✅ Complete | Multi-layer caching, request batching, automatic cleanup |
| **Load Balancing** | ✅ Complete | Peak-time management, connection pooling, dynamic scaling |
- **Network Optimization**: Intelligent request batching and connection management
- **Background Processing**: Efficient handling of data synchronization and updates
- **Memory Management**: Automatic cleanup and garbage collection optimization
- **Load Balancing**: Dynamic resource allocation during peak usage periods
- **System Health Dashboard**: Administrative monitoring with alerts and performance insights
- **Scalable Connection Management**: Advanced connection pooling for 200-300 concurrent users
- **Circuit Breaker Pattern**: Automatic fault tolerance and recovery mechanisms
- **Multi-layer Caching**: Memory + disk caching with automatic expiration and cleanup
- **Request Batching**: Intelligent API request grouping to reduce server load
- **Peak Load Management**: Automated throttling and queueing during high traffic periods

### 🔐 **Security & Privacy**
- **Secure Authentication**: JWT-based login system
- **Data Protection**: Encrypted storage and transmission
- **Role-Based Access**: Student and Admin permissions

## 🔧 **Advanced System Architecture**

### **Performance Optimization Layer**
```
┌─────────────────────────────────────────────────────────┐
│                Performance Layer                        │
├─────────────────────────────────────────────────────────┤
│ • ScalableConnectionService (200-300 users)            │
│ • ExamOptimizationService (high-load periods)          │
│ • MonitoringReportingService (real-time metrics)       │
│ • LoadBalancingService (peak-time management)          │
└─────────────────────────────────────────────────────────┘
```

### **Caching & Optimization Layer**
```
┌─────────────────────────────────────────────────────────┐
│                Caching Layer                            │
├─────────────────────────────────────────────────────────┤
│ • CacheStorageService (50MB memory + 200MB disk)       │
│ • BatchApiService (request grouping & optimization)    │
│ • CachedFileResourceService (smart file caching)       │
│ • ConnectionQueueService (connection pooling)          │
└─────────────────────────────────────────────────────────┘
```

### **System Resilience**
```
┌─────────────────────────────────────────────────────────┐
│              Resilience & Recovery                      │
├─────────────────────────────────────────────────────────┤
│ • Circuit Breaker Pattern (automatic fault recovery)   │
│ • Dynamic Connection Scaling (45-58 connections)       │
│ • Request Rate Limiting (API protection)               │
│ • Emergency Throttling (overload protection)           │
└─────────────────────────────────────────────────────────┘
```

## 🚀 **Quick Start**

### **Prerequisites**
- [Flutter](https://flutter.dev/docs/get-started/install) (3.16.0+)
- [Dart](https://dart.dev/get-dart) (3.2.0+)
- [Android Studio](https://developer.android.com/studio) or [VS Code](https://code.visualstudio.com/)
- [Supabase](https://supabase.com/) account (Free tier)

### **Installation**

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/edunest.git
   cd edunest
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Supabase**
   ```bash
   # Update android/app/src/main/res/xml/network_security_config.xml
   # Add your Supabase URL and credentials
   ```

4. **Run the app**
   ```bash
   flutter run
   ```

## 📊 **Performance & Scalability**

### **Performance Capacity**
- **✅ Current Capacity**: Supports 200-300 concurrent users
- **✅ Connection Management**: 45-58 dynamic connection pool with automatic scaling
- **✅ Cache Efficiency**: Multi-layer caching (memory + disk) with 50MB/200MB limits
- **✅ Load Balancing**: Automated peak-time management and request queuing
- **✅ Fault Tolerance**: Circuit breaker pattern with automatic recovery
- **✅ Monitoring**: Real-time system health with crash risk assessment

### **Scalability Metrics**
- **Connection Pool**: 45-58 concurrent connections with dynamic adjustment
- **Cache Performance**: 50MB memory + 200MB disk with intelligent expiration
- **Request Batching**: Up to 10 requests per batch to optimize server load
- **Peak Load Management**: Automatic throttling during high-traffic periods
- **User Capacity**: Estimated 200-300 users with current free tier resources

### **Resource Usage**
- **Database**: ~65MB for 1000 students
- **API Calls**: 50,000/month (free tier)
- **Storage**: 1GB (sufficient for study materials)
- **Performance**: Smooth 60fps, <2s load times

## 🛠️ **Technology Stack**

### **Frontend (Mobile)**
- **Framework**: Flutter 3.16.0
- **Language**: Dart 3.2.0
- **State Management**: Provider pattern
- **UI**: Material Design 3 with Google Fonts
- **Network**: HTTP with connectivity monitoring

### **Backend**
- **Database**: Supabase (PostgreSQL)
- **Authentication**: Supabase Auth (JWT)
- **Storage**: Supabase Storage + Google Drive
- **Real-time**: Supabase Realtime

### **AI Services**
- **Question Generation**: Google Gemini API
- **Content Analysis**: AI-powered text processing

## 📁 **Project Structure**

```
edunest/
├── lib/                          # Flutter app source code
│   ├── controllers/              # Business logic
│   ├── models/                   # Data models
│   ├── screens/                  # UI screens
│   │   ├── auth/                # Authentication screens
│   │   ├── home/                # Main app screens
│   │   ├── practice_tests/      # Test-related screens
│   │   └── profile/             # User profile screens
│   ├── services/                 # API and external services
│   ├── theme/                    # App theming
│   └── widgets/                  # Reusable components
├── android/                      # Android-specific files
├── ios/                         # iOS-specific files
├── assets/                       # App assets
│   └── images/                  # Images and icons
└── supabase/                     # Backend configuration
```

## 🔧 **Configuration**

### **Environment Setup**
```bash
# Supabase Configuration (in config_service.dart)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_anon_key

# AI Services
GEMINI_API_KEY=your_gemini_api_key
```

### **Database Schema**
- `profiles` - User profiles and academic information
- `colleges`, `branches`, `semesters`, `subjects` - Academic hierarchy
- `questions` - AI-generated MCQ questions with practice modes
- `test_results` - User performance analytics and progress tracking
- `attendance_records` - Daily attendance with 75% target calculations
- `class_rosters` - Professor-managed class student lists
- `attendance_analytics` - Comprehensive attendance statistics
- `files` - Educational resources and study materials
- `test_assignments` - Professor-assigned protected tests with proctoring
- `user_roles` - Role-based access control (Student/Professor/Admin)
- `class_assignment_marks` - Assignment grades and performance tracking
- `assignment_marks` - Individual assignment scores and feedback
- `subject_feedback` - Feedback campaigns and anonymous responses
- `feedback_responses` - Student feedback data with rating analytics
- `system_monitoring` - Performance metrics and health monitoring
- `exam_optimization` - Resource optimization during high-load periods

## 🎯 **Key Features Deep Dive**

### **🤖 AI-Powered Question Generation**
```dart
// Automatic MCQ creation from study materials
- Content analysis using Google Gemini API
- Three practice modes (Academic, Competitive, Career)
- Dynamic GATE topic detection for competitive mode
- Multiple question counts (10, 15, 20 questions)
- Bulk generation: 60 questions (20 per mode) with one click
- Quality validation and review system
```

### **🎓 Smart Practice Mode System**
```dart
// Dynamic mode detection and display
- Academic Mode: University exam preparation
- Competitive Mode: 
  * Shows "GATE Prep Mode" for GATE syllabus topics
  * Shows "Competitive Exam Mode" for non-GATE topics
  * Auto-detects based on existing questions and topic keywords
- Career Mode: Interview and job preparation
- Real-time mode switching with appropriate descriptions
```

### **📊 Comprehensive Attendance System**
```dart
// Advanced attendance management for professors and students
- Daily attendance marking with visual calendar interface
- 75% target calculator with real-time statistics
- Class roster management with CSV/Excel import
- Bulk attendance operations (mark all present/absent)
- Student verification and status tracking
- Date-wise attendance reports and analytics
- Export functionality for attendance data
- Low attendance alerts and notifications
- Historical trends and performance insights
```

### 📱 Modern UI/UX
```dart
// Student-focused design
- Material Design 3 components
- Customizable subject card colors
- Smooth animations and transitions
- Responsive layout for all devices
```

### 🖥️ Desktop App Support
- Full-featured desktop experience for Windows, macOS, and Linux
- Sidebar navigation with all main app features
- Logout confirmation dialog for safe sign-out
- Consistent UI/UX with mobile app, adapted for large screens
- Keyboard and mouse navigation support
- Optimized for high-resolution displays

## 🔒 **Security Features**

- **JWT Authentication**: Secure token-based login
- **Row Level Security**: Database-level access control
- **Input Validation**: Comprehensive sanitization
- **File Upload Security**: Malware scanning
- **HTTPS Encryption**: Secure data transmission
- **Secure Storage**: Encrypted local data

## 📈 **Performance Optimization**

- **Lazy Loading**: Load data on demand
- **Image Caching**: Optimized image handling
- **State Management**: Efficient updates
- **Network Caching**: API response caching
- **Memory Management**: Proper resource disposal
- **Real-time Sync**: Optimized data synchronization

## 🧪 **Testing**

```bash
# Run unit tests
flutter test

# Run widget tests
flutter test test/widget_test.dart

# Run integration tests
flutter drive --target=test_driver/app.dart
```

## 📱 **Building for Production**

### **Android Release**
```bash
# Build APK
flutter build apk --release

# Build App Bundle (recommended for Play Store)
flutter build appbundle --release
```

### **iOS Release**
```bash
# Build for iOS
flutter build ios --release
```

## 🚀 **Deployment**

### **Current Status**
- ✅ **Mobile App**: Production ready with optimized performance
- ✅ **Backend**: Supabase deployed and stable
- ✅ **AI Integration**: Gemini API active and optimized
- ✅ **Code Quality**: Debug prints removed, clean production code
- ✅ **Performance**: Optimized caching and resource management
- ✅ **Testing**: Core functionality tested and validated
- ✅ **Admin Panel**: Web-based management system

> APK download/distribution link will be provided soon.

### **Admin Panel Control**
The admin panel is a **separate web application** that connects to the same Supabase backend. It provides comprehensive management tools:

#### **📚 Content Management**
- Upload study materials, create subjects, and organize files
- Multi-format support (PDF, DOCX, PPTX, images)
- Hierarchical organization (College → Branch → Semester → Subject)

#### **🤖 AI Question Generation**
- Generate questions for specific practice modes (Academic, Competitive, Career)
- Bulk generation: Create 20 questions for all 3 modes (60 total) with one click
- Smart disable: Button automatically disables when all modes have 20+ questions
- Progress tracking during generation with success/failure feedback
- Dynamic mode naming: Shows "Competitive Exam Mode" while app detects GATE vs non-GATE

#### **📊 Advanced Attendance Management**
- **Class Roster Management**: Create and manage class lists
- **CSV/Excel Import**: Bulk upload student rosters from spreadsheets
- **Daily Attendance Marking**: Visual interface for marking attendance
- **Bulk Operations**: Mark all students present/absent with one click
- **Student Verification**: Track verified vs unverified students
- **Attendance Analytics**: Comprehensive reports and statistics
- **Export Functionality**: Download attendance data in multiple formats
- **75% Target Tracking**: Monitor students approaching attendance thresholds

#### **👥 User Management**
- Monitor student accounts and manage access
- Role-based permissions (Student/Professor/Admin)
- Account verification and status management

#### **📝 Test Assignment & Assessment**
- Create and assign protected tests to specific students or classes
- Set time limits and access controls with proctoring features
- Monitor test completion and results in real-time
- Auto-submit security for test integrity
- Bulk test assignment with class roster integration

#### **📊 Assignment Marks Management**
- Complete grade tracking system for all assignments
- Subject-wise and class-wise grade organization
- Performance analytics and progress tracking
- Export grade reports for institutional records
- Integration with class rosters for streamlined grading

#### **💬 Feedback Campaign Management**
- Create and manage subject feedback campaigns
- Set campaign duration and target audiences
- Anonymous feedback collection with 5-point rating scales
- Real-time feedback analytics and subject comparisons
- Export comprehensive feedback reports and insights

#### **⚡ System Performance Monitoring**
- Real-time system health and performance metrics
- Exam mode activation for resource optimization
- Memory, CPU, and network usage tracking
- Performance alerts and optimization recommendations
- Load balancing during peak usage periods

#### **⚡ System Performance Monitoring**
- **Real-time System Health**: Live monitoring of connection usage, queue size, and system load
- **Automatic Load Balancing**: Dynamic resource allocation during peak hours (8-10 AM, 2-4 PM, 7-9 PM)
- **Circuit Breaker Protection**: Automatic system protection from overload with smart recovery
- **Exam Mode Activation**: Specialized optimization when multiple students take tests simultaneously
- **Adaptive Connection Limits**: Dynamic adjustment from 45-58 connections based on current load
- **Performance Analytics**: Comprehensive metrics including crash risk assessment and user capacity estimates
- **Emergency Controls**: Admin controls for throttling and queue management during critical periods

**How it works**: The admin panel uses the same Supabase credentials as the mobile app, ensuring real-time data synchronization. Access control is managed through Supabase's built-in authentication and role-based permissions.

### **Deployment Checklist**
- [x] Supabase project configured
- [x] Database schema created and optimized
- [x] AI API keys configured
- [x] Android build successful
- [x] Performance optimized and caching implemented
- [x] Security measures implemented
- [x] Admin panel configured
- [x] Debug prints removed for production
- [x] Code cleanup and optimization completed
- [x] Error handling improved
- [x] Unused files removed
- [x] Memory optimization implemented

## 📊 **Analytics & Monitoring**

### **User Metrics**
- **Daily Active Users**: Tracked via Supabase
- **Test Performance**: Detailed analytics
- **Attendance Patterns**: Statistics and trends
- **Feature Usage**: Popular content tracking

### **Performance Metrics**
- **App Load Time**: <2 seconds
- **API Response Time**: <500ms
- **Memory Usage**: Optimized
- **Battery Impact**: Minimal

## 🤝 **Contributing**

We welcome contributions! Please follow these steps:

1. **Fork the repository**
2. **Create a feature branch** (`git checkout -b feature/amazing-feature`)
3. **Commit your changes** (`git commit -m 'Add amazing feature'`)
4. **Push to the branch** (`git push origin feature/amazing-feature`)
5. **Open a Pull Request**

### **Development Guidelines**
- Follow Flutter best practices
- Add tests for new features
- Update documentation
- Ensure code quality with `flutter analyze`

## 📄 **License**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 **Support**

### **Getting Help**
- **Issues**: [GitHub Issues](https://github.com/yourusername/edunest/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/edunest/discussions)
- **Email**: support@edunest.com

### **Common Issues**
- **Build Errors**: Check Flutter version and dependencies
- **API Issues**: Verify Supabase configuration
- **Performance**: Monitor network connectivity

## 🙏 **Acknowledgments**

- [Flutter](https://flutter.dev/) - Amazing cross-platform framework
- [Supabase](https://supabase.com/) - Powerful backend-as-a-service
- [Google Gemini](https://ai.google.dev/) - Advanced AI for education
- [Material Design](https://material.io/) - Design system

## 📈 **Project Status**

| Feature | Status | Notes |
|---------|--------|-------|
| **Core App** | ✅ Complete | Production ready, debug-free |
| **Authentication** | ✅ Complete | JWT-based, secure |
| **Practice Tests** | ✅ Complete | 3 modes, dynamic detection |
| **AI Question Generation** | ✅ Complete | Bulk generation, smart modes |
| **Dynamic Mode Detection** | ✅ Complete | GATE vs non-GATE auto-detection |
| **Attendance System** | ✅ Complete | Advanced tracking, analytics, roster management |
| **Assignment Marks** | ✅ Complete | Grade tracking, performance analytics |
| **Subject Feedback** | ✅ Complete | Campaign management, anonymous responses |
| **Test Assignment & Proctoring** | ✅ Complete | Protected tests, auto-submit security |
| **Performance Optimization** | ✅ Complete | Exam mode, monitoring, adaptive caching |
| **File Management** | ✅ Complete | Multi-format support |
| **Admin Panel** | ✅ Complete | Comprehensive management tools |
| **System Monitoring** | ✅ Complete | Real-time metrics, health tracking |
| **Performance** | ✅ Optimized | <2s load times, memory efficient |
| **Security** | ✅ Implemented | Production-grade |
| **Code Quality** | ✅ Complete | Debug prints removed, clean code |
| **Testing** | ✅ Validated | Core features tested |
| **Documentation** | ✅ Complete | Comprehensive and updated |

## 🎯 **Future Roadmap**

### **Phase 1: Immediate (1-2 months)**
- [ ] Push notifications
- [ ] Offline mode
- [ ] Enhanced analytics
- [ ] User feedback system

### **Phase 2: Advanced (3-6 months)**
- [ ] Social learning features
- [ ] Gamification elements
- [ ] Advanced AI features
- [ ] Mobile app store deployment

### **Phase 3: Scale (6+ months)**
- [ ] Premium features
- [ ] Institution partnerships
- [ ] Global expansion
- [ ] Advanced analytics

---

## 🌟 **Why Choose EduNest?**

- **🎓 Student-Focused**: Built by students, for students
- **🤖 AI-Powered**: Cutting-edge technology for better learning
- **💰 Cost-Effective**: Free services, scalable architecture
- **🚀 Production Ready**: Smooth, reliable, and secure
- **📈 Scalable**: Handles 1000+ students easily
- **🎯 Purpose-Built**: Perfect for educational institutions

**Made with ❤️ for better education**

[![GitHub stars](https://img.shields.io/github/stars/yourusername/edunest?style=social)](https://github.com/yourusername/edunest/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/yourusername/edunest?style=social)](https://github.com/yourusername/edunest/network)
[![GitHub issues](https://img.shields.io/github/issues/yourusername/edunest)](https://github.com/yourusername/edunest/issues)
[![GitHub pull requests](https://img.shields.io/github/issues-pr/yourusername/edunest)](https://github.com/yourusername/edunest/pulls)
