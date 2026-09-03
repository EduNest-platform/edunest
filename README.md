# 🎓 EduNest - Smart Learning Platform

> A Flutter-based educational platform that combines AI-powered practice tests, attendance management, academic resources, performance tracking, and professor/admin tools in one application.

## ✨ Key Features

### 🤖 AI-Powered Learning
- AI-generated MCQs using Google Gemini
- 3 practice modes:
  - Academic
  - Competitive / GATE
  - Career Preparation
- Automatic GATE topic detection
- 10, 15, or 20-question tests
- Bulk question generation
- Instant results and explanations
- Performance tracking

### 📝 Practice Tests
- Unlimited student practice tests
- Professor-assigned protected tests
- Time-limited examinations
- Proctored test mode
- Auto-submit when leaving protected tests
- Real-time results and progress tracking

### 📊 Attendance Management
- Daily attendance tracking
- Visual attendance calendar
- 75% attendance target calculator
- Professor-managed class rosters
- CSV/Excel roster import
- Bulk attendance marking
- Student verification
- Attendance analytics and reports
- Low-attendance alerts
- Export attendance data

### 📚 Academic Resources
- Subject-wise study materials
- Notes, assignments, and lab manuals
- PDF, DOCX, PPTX and image support
- File downloads and offline access
- Assignment tracking
- Assignment marks
- Mid-semester marks
- Subject-wise performance tracking

### 💬 Subject Feedback
- Professor/subject feedback campaigns
- Anonymous student feedback
- 5-point rating system
- Time-limited campaigns
- Real-time feedback analytics
- Cross-subject comparison
- Feedback report export

### 🔔 Notifications
- Firebase Cloud Messaging (FCM)
- Assignment mark notifications
- Mid-semester result notifications
- Read/unread management
- Notification history
- Pull-to-refresh
- Cross-platform support

### 🖥️ Admin Panel
A separate web-based admin panel connected to the same Supabase backend.

- User and role management
- College/branch/semester/subject management
- Study material management
- AI question generation
- Attendance management
- Test assignment and monitoring
- Assignment and midsem marks
- Feedback campaigns
- System monitoring

## 🏗️ Technology Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter |
| Language | Dart |
| State Management | Provider |
| UI | Material Design 3 |
| Backend | Supabase |
| Database | PostgreSQL |
| Authentication | Supabase Auth / JWT |
| Storage | Supabase Storage + Google Drive |
| Real-time | Supabase Realtime |
| AI | Google Gemini |
| Notifications | Firebase Cloud Messaging |

## ⚡ Performance & Reliability

EduNest includes several optimization mechanisms designed for high-load scenarios:

- Multi-layer caching
- Request batching
- Connection management
- Smart request queuing
- Lazy/progressive loading
- Memory management
- Circuit breaker protection
- Load balancing
- Exam-mode optimization
- Real-time system monitoring

The current implementation is designed around the project's tested capacity and available backend resources.

## 🔐 Security

- JWT-based authentication
- Supabase Row Level Security
- Role-based access control
- HTTPS communication
- Secure local storage
- Input validation
- Session isolation
- Cache clearing on logout
- Protected professor-assigned tests

## 📁 Project Structure

```text
edunest/
├── lib/
│   ├── controllers/
│   ├── models/
│   ├── screens/
│   │   ├── auth/
│   │   ├── home/
│   │   ├── practice_tests/
│   │   └── profile/
│   ├── services/
│   ├── theme/
│   └── widgets/
├── android/
├── ios/
├── assets/
│   └── images/
└── supabase/
