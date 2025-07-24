# 🖥️ EduNest Desktop App: A Screen-by-Screen and Service-by-Service Development Book

This book is a comprehensive, deep-dive guide to the EduNest desktop app. Each section details the purpose, widgets, properties, logic, backend, and best practices for every screen, widget, and service, with code snippets and learning tips. Use this as a reference and learning tool for Flutter desktop development!

---

## **Introduction: EduNest Desktop App Overview**

EduNest is a smart learning platform for students, built with Flutter for desktop (Windows, macOS, Linux). It features:
- Secure authentication (Supabase)
- Practice tests (AI-powered)
- Attendance tracking
- Study resources
- Modern UI/UX
- Desktop-specific enhancements (scrollbars, window management, etc.)
- Robust error handling and performance

The app is organized into screens, each with a clear purpose and structure. Let’s dive into each one!

---

## 1. **SplashScreen (Desktop)**

**Purpose:**
- Show a branded loading screen while initializing services and checking authentication.
- Route the user to the correct next screen (login, profile setup, or home).

**Main Widgets:**
- `Scaffold`, `Center`, `Column`, `CircularProgressIndicator`, `Text`

**Key Code:**
```dart
class SplashScreen extends StatefulWidget { ... }

@override
void initState() {
  super.initState();
  _navigateAfterSplash();
}

Future<void> _navigateAfterSplash() async {
  await Future.delayed(const Duration(seconds: 2));
  // ... check auth, then:
  Navigator.pushReplacementNamed(context, '/login');
}
```

**Packages Used:**
- `supabase_flutter` (for auth check)
- `google_fonts` (for branding)

**Learning Tips:**
- Use `Future.delayed` for splash timing.
- Always check `if (!mounted) return;` before navigation in async.
- Use `Navigator.pushReplacementNamed` to prevent back navigation to splash.

---

## 2. **LoginScreen (Desktop)**

**Purpose:**
- Allow users to log in securely with email/password.
- Handle errors, show loading, and navigate to home/profile setup.

**Main Widgets:**
- `Scaffold`, `TextFormField`, `ElevatedButton`, `TextButton`, `Form`, `ChangeNotifierProvider` (Provider pattern)

**Key Code:**
```dart
class LoginScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LoginController(),
      child: const _LoginScreenBody(),
    );
  }
}

// In _LoginScreenBody:
TextFormField(
  controller: _emailController,
  decoration: InputDecoration(labelText: 'Email'),
)
ElevatedButton(
  onPressed: _login,
  child: Text('Login'),
)
```

**Packages Used:**
- `provider` (for state management)
- `supabase_flutter` (for login)
- `google_fonts` (for text)

**State Management:**
- `LoginController` (extends `ChangeNotifier`) holds form state, loading, and error messages.

**Navigation:**
- On success: `Navigator.pushReplacementNamed(context, '/home');`
- On error: Show `SnackBar` with error message.

**Learning Tips:**
- Use `Form` and `TextFormField` for validation.
- Use Provider for clean separation of UI and logic.
- Always show loading indicators during async login.

---

## 3. **HomeDesktop (Screen)**

**Purpose:**
- The main dashboard after login. Shows welcome, quick actions, current subjects, recent activity, and navigation to all major features.

**UI Breakdown:**
- `Scaffold` with custom sidebar (`DesktopSidebar`).
- `Row` for sidebar + main content.
- `ListView` for sidebar navigation.
- `Column` for main content layout.
- **Widgets:**
  - `_SidebarSectionLabel`, `_SidebarButton` for navigation
  - `_buildWelcomeSection()` – greeting, user name, avatar
  - `_buildQuickActions()` – `Row` of action cards
  - `_buildMyCurrentSubjects()` – horizontal `ListView` of subject cards
  - `_buildRecentActivity()` – vertical list of recent files/resources

**State Management:**
- `StatefulWidget` with local state for loading, subjects, recent files, onboarding, etc.
- Uses `setState` for updates.
- Animation: `AnimationController` for onboarding/tutorial.

**Service Calls:**
- **UserProfileService.getCurrentUserProfile()**
- **SubjectsService.getSubjectsByCollegeAndSemester()**
- **FilesService.getRecentFiles(subjectId, limit)**
- **SupabaseService.client.auth.currentUser**

**Backend Interaction:**
- **Supabase tables:** `profiles`, `subjects`, `files`
- **Example query:**
  ```dart
  final response = await SupabaseService.client
      .from('subjects')
      .select()
      .eq('college', userProfile.college)
      .eq('semester', userProfile.semester);
  ```
- **Data flow:**
  - On init, loads user profile → loads subjects → loads recent files.

**Error Handling:**
- Try/catch around all async service calls.
- Shows `SnackBar` for errors (e.g., network, Supabase errors).
- Shows loading indicators (`CircularProgressIndicator`) while fetching.

**Async/Performance:**
- Uses `Future.delayed` for splash/onboarding timing.
- Loads data in parallel where possible.
- Uses `setState` to trigger UI updates after data loads.

**Navigation:**
- Uses `Navigator.pushNamed` and `MaterialPageRoute` to move to other screens (e.g., `/subjects`, `/practice-tests`).
- Passes subject data as arguments where needed.

**Security:**
- Checks authentication status before showing content.
- Uses secure storage for tokens (via Supabase).

**Packages Used:**
- `google_fonts`, `supabase_flutter`, `provider`, `shared_preferences`, `flutter_secure_storage`

**Learning Tips:**
- Always check for network and auth before loading data.
- Use `setState` carefully to avoid unnecessary rebuilds.
- Modularize UI into small builder methods for readability.
- Use async/await for all service calls, and show loading indicators.
- Use `SnackBar` for user feedback on errors.

---

## 4. **DesktopSidebar (Widget)**

**Purpose:**
- Persistent navigation for desktop, with sections and buttons.

**Key Properties:**
- `selected`, `onNavigate`, `onLogout`

**UI Breakdown:**
- `ListView` for navigation items
- `_SidebarSectionLabel` for section headers
- `_SidebarButton` for navigation and logout

**Learning Tips:**
- Use `ListTile` for navigation items.
- Use `showDialog` for logout confirmation.

---

## 5. **CustomAppBar (Widget)**

**Purpose:**
- Provides a consistent, customizable app bar across all screens.

**Key Properties:**
- `title`, `subtitle`, `leading`, `actions`, `borderRadius`, `padding`

**Usage Example:**
```dart
CustomAppBar(
  title: 'Practice Tests',
  subtitle: 'Your assigned and practice tests',
  leading: IconButton(
    icon: Icon(Icons.arrow_back),
    onPressed: () => Navigator.pop(context),
  ),
)
```

**Learning Tips:**
- Use `PreferredSizeWidget` for custom app bars.
- Adjust padding and font size for desktop vs mobile.

---

## 6. **AppText (Widget)**

**Purpose:**
- DRY utility for displaying text with consistent style and overflow handling.

**Key Properties:**
- `text`, `style`, `maxLines`, `overflow`, `textAlign`, etc.

**Usage Example:**
```dart
AppText(
  'Welcome to EduNest!',
  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20),
  maxLines: 2,
  overflow: TextOverflow.ellipsis,
)
```

**Learning Tips:**
- Use custom text widgets to enforce style consistency.
- Add rich text support for future extensibility.

---

## 7. **Backend Services (Desktop)**

### AuthService
**Purpose:** Handles all authentication logic: login, logout, session check, and password management.
**Key Methods:**
- `Future<AuthStatus> checkAuthStatus()`
- `Future<void> signIn(String email, String password)`
- `Future<void> signOut()`
- `Future<void> resetPassword(String email)`
**Backend (Supabase) Interaction:** Uses Supabase Auth for JWT-based authentication. Stores tokens securely using `flutter_secure_storage`. Reads/writes to the `profiles` table for user info.
**Example:**
```dart
final response = await SupabaseService.client.auth.signInWithPassword(
  email: email,
  password: password,
);
```
**Error Handling:** All methods use try/catch and throw user-friendly errors. Uses `ErrorMessageService.getFriendlyMessage(e)` for display.
**Security:** Tokens are never stored in plain text. Always checks for valid session before sensitive actions.
**Learning Tips:** Always handle errors and show user feedback. Use secure storage for tokens. Use enums for auth status for clarity.

### UserProfileService
**Purpose:** Manages user profile data: fetch, update, and sync with backend.
**Key Methods:**
- `Future<UserProfile?> getCurrentUserProfile()`
- `Future<void> updateUserProfile(Map<String, dynamic> data)`
- `Future<void> createUserProfile(Map<String, dynamic> data)`
**Backend (Supabase) Interaction:** Reads/writes to the `profiles` table. Uses user ID as the primary key.
**Example:**
```dart
final response = await SupabaseService.client
    .from('profiles')
    .select()
    .eq('id', userId)
    .single();
```
**Error Handling:** All methods use try/catch and throw user-friendly errors. Validates data before sending to backend.
**Security:** Only allows updates for the authenticated user. Sanitizes all input before saving.
**Learning Tips:** Use `fromJson`/`toJson` for model conversion. Always validate and sanitize user input.

### FilesService
**Purpose:** Handles fetching, uploading, and managing study resources/files.
**Key Methods:**
- `Future<List<FileResource>> getFiles(String subjectId, String type)`
- `Future<List<FileResource>> getRecentFiles(String subjectId, int limit)`
- `Future<void> uploadFile(File file, String subjectId, String type)`
**Backend (Supabase) Interaction:** Reads from and writes to the `files` table. Uses Supabase Storage for file uploads.
**Example:**
```dart
final files = await SupabaseService.client
    .from('files')
    .select()
    .eq('subject_id', subjectId)
    .eq('type', type);
```
**Error Handling:** All methods use try/catch and show user-friendly errors. Validates file type and size before upload.
**Security:** Only allows access to files for enrolled subjects. Scans files for malware (if supported by backend).
**Learning Tips:** Use caching for frequently accessed files. Use `url_launcher` for file downloads.

### NetworkService
**Purpose:** Checks network connectivity and handles offline scenarios.
**Key Methods:**
- `Future<bool> isConnected()`
**Backend Interaction:** None (uses platform APIs).
**Error Handling:** Returns false on network error.
**Learning Tips:** Always check network before making API calls. Show offline UI if not connected.

### ErrorMessageService
**Purpose:** Converts technical errors into user-friendly messages.
**Key Methods:**
- `static String getFriendlyMessage(dynamic error)`
**Usage Example:**
```dart
try {
  await AuthService.signIn(email, password);
} catch (e) {
  final message = ErrorMessageService.getFriendlyMessage(e);
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
```
**Learning Tips:** Centralize error messages for consistency. Always show actionable feedback.

### FileValidationService
**Purpose:** Validates files before upload/download.
**Key Methods:**
- `static bool isValidFileType(String fileName)`
- `static bool isValidFileSize(int size)`
**Learning Tips:** Always validate files on both client and server.

### SecureStorageService
**Purpose:** Handles secure storage of sensitive data (tokens, keys).
**Key Methods:**
- `Future<void> write(String key, String value)`
- `Future<String?> read(String key)`
- `Future<void> delete(String key)`
**Backend Interaction:** None (local only, uses `flutter_secure_storage`).
**Learning Tips:** Never store tokens in plain text or shared preferences.

---

## 8. **Mixins and Utilities (Desktop)**

- **PerformanceMixin:** Adds reusable logic for performance monitoring.
- **NetworkAwareMixin:** Adds network awareness to screens.
- **SessionTrackingService:** Manages user sessions, active devices, and session timeouts.
- **RateLimiterService:** Prevents abuse by limiting API call frequency.
- **HybridAIService:** Handles AI-powered features (e.g., question generation).
- **TestResultsService:** Manages test result storage and analytics.

**Learning Tips:**
- Use mixins to avoid code duplication across screens.
- Keep utility services modular and single-responsibility.
- Document all public methods for maintainability.

---

## 9. **Models and Theme (Desktop)**

- **Models:** `Subject`, `UserProfile`, `AttendanceRecord`, etc. Define data structures for app entities. Use `fromJson`/`toJson` for serialization.
- **Theme:** `app_theme.dart` centralizes all color, font, and style definitions. Use color and font constants throughout the app.

**Usage Example:**
```dart
Container(
  color: AppTheme.primaryBlue,
  child: Text('EduNest', style: TextStyle(color: AppTheme.textInverse)),
)
```

**Learning Tips:**
- Keep models in sync with backend schema.
- Use a theme file for easy global style changes.

---

**This completes the deep-dive for all major files, widgets, services, and backend logic in EduNest Desktop.**

**Happy learning and building!** 