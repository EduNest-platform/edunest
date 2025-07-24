# 📖 EduNest Android App: A Screen-by-Screen Development Book

This book is a comprehensive, screen-by-screen guide to the EduNest Android app. Each section details the purpose, widgets, properties, logic, and best practices for every screen, with code snippets and learning tips. Use this as a reference and learning tool for Flutter app development!

---

## **Introduction: EduNest Android App Overview**

EduNest is a smart learning platform for students, built with Flutter for Android (and other platforms). It features:
- Secure authentication (Supabase)
- Practice tests (AI-powered)
- Attendance tracking
- Study resources
- Modern UI/UX
- Robust error handling and performance

The app is organized into screens, each with a clear purpose and structure. Let’s dive into each one!

---

## 1. **SplashScreen**

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

## 2. **LoginScreen**

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

## 3. **ProfileSetupScreen**

**Purpose:**
- Collect user academic info after signup (college, branch, semester, etc.).
- Ensure profile is complete before accessing the app.

**Main Widgets:**
- `Scaffold`, `DropdownButtonFormField`, `TextFormField`, `ElevatedButton`, `Form`, `Provider`

**Key Code:**
```dart
DropdownButtonFormField<String>(
  value: controller.selectedCollege,
  items: controller.colleges.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
  onChanged: controller.setCollege,
)
ElevatedButton(
  onPressed: controller.isValid ? controller.submitProfile : null,
  child: Text('Continue'),
)
```

**Packages Used:**
- `provider` (for state)
- `supabase_flutter` (for saving profile)
- `google_fonts`

**State Management:**
- `ProfileSetupController` (ChangeNotifier) manages form state, validation, and submission.

**Navigation:**
- On success: `Navigator.pushReplacementNamed(context, '/home');`

**Learning Tips:**
- Use `DropdownButtonFormField` for selection lists.
- Disable the submit button until the form is valid.
- Use Provider to keep logic out of the widget tree.

---

## 4. **HomeScreen**

**Purpose:**
- The main dashboard after login. Shows welcome, quick actions, current subjects, recent activity, and navigation to all major features.

**UI Breakdown:**
- `Scaffold` with `AppBar` (mobile) or `HomeDesktop` (desktop).
- `DrawerMenu` for navigation on mobile.
- `SingleChildScrollView` for vertical scrolling.
- `Column` for vertical layout.
- **Widgets:**
  - `_buildHomeSearchBar()` – search field, uses `TextField`, `IconButton`.
  - `_buildWelcomeSection()` – greeting, user name, avatar.
  - `_buildQuickActions()` – `Row` of action cards (Browse Subjects, Academic Info, etc.).
  - `_buildMyCurrentSubjects()` – horizontal `ListView` of subject cards.
  - `_buildRecentActivity()` – vertical list of recent files/resources.

**State Management:**
- `StatefulWidget` with local state for loading, subjects, recent files, onboarding, etc.
- Uses `setState` for updates.
- Animation: `AnimationController` for onboarding/tutorial.

**Service Calls:**
- **UserProfileService.getCurrentUserProfile()**  
  - Loads user info from Supabase `profiles` table.
- **SubjectsService.getSubjectsByCollegeAndSemester()**  
  - Loads subjects for the user’s college/semester.
- **FilesService.getRecentFiles(subjectId, limit)**  
  - Loads recent files/resources for each subject.
- **SupabaseService.client.auth.currentUser**  
  - Checks current authentication status.

**Backend Interaction:**
- **Supabase tables used:**  
  - `profiles` (user info)
  - `subjects` (subject list)
  - `files` (resources)
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
- `google_fonts` – for modern typography.
- `supabase_flutter` – for backend/auth.
- `provider` – for state management (in some screens).
- `shared_preferences` – for onboarding/tutorial state.
- `flutter_secure_storage` – for secure data.

**Learning Tips:**
- Always check for network and auth before loading data.
- Use `setState` carefully to avoid unnecessary rebuilds.
- Modularize UI into small builder methods for readability.
- Use async/await for all service calls, and show loading indicators.
- Use `SnackBar` for user feedback on errors.

---

## 5. **AttendanceScreen**

**Purpose:**
- Track and display student attendance, show analytics, and allow marking attendance.

**UI Breakdown:**
- `Scaffold` with `CustomAppBar`.
- `SingleChildScrollView` for vertical scrolling.
- `Column` for layout.
- `TableCalendar` or custom calendar widget for attendance visualization.
- `ListView` for daily attendance records.
- `ElevatedButton` for marking attendance.
- `SnackBar` for feedback.

**State Management:**
- `StatefulWidget` with local state for attendance records, loading, selected date, etc.
- Uses `setState` for updates.
- Animation: `AnimationController` for fade-in effects.

**Service Calls:**
- **AttendanceService.getAttendanceRecords(subjectId)**
- **AttendanceService.markAttendance(subjectId, date, status)**
- **UserProfileService.getCurrentUserProfile()**

**Backend Interaction:**
- **Supabase tables:** `attendance_records`, `profiles`, `subjects`
- **Example query:**
  ```dart
  final records = await SupabaseService.client
      .from('attendance_records')
      .select()
      .eq('subject_id', subjectId);
  ```

**Error Handling:**
- Try/catch for all service calls.
- Shows `SnackBar` for errors.
- Loading indicators during fetch/marking.

**Async/Performance:**
- Loads attendance and profile in parallel.
- Uses `setState` to update UI after data loads.

**Navigation:**
- Navigates to `AttendanceTrackingScreen` for detailed marking.

**Security:**
- Checks user authentication before loading data.

**Packages Used:**
- `table_calendar` (if used), `google_fonts`, `supabase_flutter`, `provider` (optional)

**Learning Tips:**
- Use calendar widgets for date-based data.
- Always show feedback for user actions.
- Modularize logic for fetching/marking attendance.

---

## 6. **PracticeTestsScreen**

**Purpose:**
- List available practice tests, allow starting new tests, and show assigned tests.

**UI Breakdown:**
- `Scaffold` with `CustomAppBar`.
- `ListView` for test cards.
- `ElevatedButton` to start a new test.
- `SnackBar` for feedback.

**State Management:**
- `StatefulWidget` with local state for test list, loading, etc.
- Uses `setState` for updates.

**Service Calls:**
- **SubjectsService.getSubjects()**
- **AssignedMCQSupabaseService.fetchQuestionsForTest(testName)**
- **TestResultsService.hasUserCompletedTest(testTitle)**

**Backend Interaction:**
- **Supabase tables:** `questions`, `test_assignments`, `test_results`
- **Example query:**
  ```dart
  final questions = await SupabaseService.client
      .from('questions')
      .select()
      .eq('topic_id', topicId)
      .eq('difficulty', difficulty);
  ```

**Error Handling:**
- Try/catch for all service calls.
- Shows `SnackBar` for errors.
- Loading indicators during fetch.

**Async/Performance:**
- Loads tests and questions in parallel where possible.

**Navigation:**
- Navigates to `MCQTestScreen` for taking a test.
- Navigates to `TestResultsScreen` for results.

**Security:**
- Checks if test is already completed before allowing retake.

**Packages Used:**
- `google_fonts`, `supabase_flutter`, `provider` (optional)

**Learning Tips:**
- Use separate widgets for test cards.
- Always check if a test is already completed.

---

## 7. **ResourcesScreen**

**Purpose:**
- Show all study resources (notes, assignments, lab manuals, code, etc.) for a subject.

**UI Breakdown:**
- `Scaffold` with `CustomAppBar`.
- `TabBar`/`TabBarView` or segmented control for resource categories.
- `ListView` for resource files.
- `Card`, `Image`, `IconButton` for file display and actions.
- `SnackBar` for feedback.

**State Management:**
- `StatefulWidget` with local state for selected tab, files, loading, etc.
- Uses `setState` for updates.

**Service Calls:**
- **FilesService.getFiles(subjectId, type)**
- **UserProfileService.getCurrentUserProfile()**

**Backend Interaction:**
- **Supabase tables:** `files`, `subjects`, `profiles`
- **Example query:**
  ```dart
  final files = await SupabaseService.client
      .from('files')
      .select()
      .eq('subject_id', subjectId)
      .eq('type', type);
  ```

**Error Handling:**
- Try/catch for all service calls.
- Shows `SnackBar` for errors.
- Loading indicators during fetch.

**Async/Performance:**
- Loads files for each tab/category as needed.

**Navigation:**
- Navigates to `PDFViewerScreen` or file preview on tap.

**Security:**
- Checks user authentication before loading files.

**Packages Used:**
- `google_fonts`, `supabase_flutter`, `url_launcher`, `provider` (optional)

**Learning Tips:**
- Use `TabBar` for category navigation.
- Use `url_launcher` for file downloads.

---

## 8. **ProfileScreen**

**Purpose:**
- Show and edit user profile, including academic info and profile picture.

**UI Breakdown:**
- `Scaffold` with `CustomAppBar`.
- `Column` for profile info.
- `CircleAvatar` or `Image` for profile picture.
- `TextFormField`, `DropdownButtonFormField` for editing.
- `ElevatedButton` for save.
- `SnackBar` for feedback.

**State Management:**
- `StatefulWidget` with local state for profile fields, loading, etc.
- Uses `setState` for updates.
- May use Provider for more complex state.

**Service Calls:**
- **UserProfileService.getCurrentUserProfile()**
- **UserProfileService.updateUserProfile(data)**

**Backend Interaction:**
- **Supabase tables:** `profiles`
- **Example query:**
  ```dart
  final response = await SupabaseService.client
      .from('profiles')
      .update(data)
      .eq('id', userId);
  ```

**Error Handling:**
- Try/catch for all service calls.
- Shows `SnackBar` for errors.
- Loading indicators during fetch/save.

**Async/Performance:**
- Loads and saves profile data asynchronously.

**Navigation:**
- Navigates to `ChangePasswordScreen` or other account actions.

**Security:**
- Validates user input before saving.
- Checks authentication before loading/saving.

**Packages Used:**
- `google_fonts`, `supabase_flutter`, `provider`, `image_picker`, `permission_handler`

**Learning Tips:**
- Use `CircleAvatar` for profile images.
- Use Provider for complex profile state.
- Always validate and sanitize user input.

---

## 9. **SettingsScreen**

**Purpose:**
- Allow users to configure app preferences (notifications, theme, language, etc.).

**UI Breakdown:**
- `Scaffold` with `CustomAppBar`.
- `ListView` or `Column` for settings options.
- `SwitchListTile`, `DropdownButtonFormField` for toggles and selections.
- `SnackBar` for feedback.

**State Management:**
- `StatefulWidget` with local state for settings.
- Uses `setState` for updates.
- May use Provider for persistent settings.

**Service Calls:**
- **SharedPreferences** for local settings storage.

**Backend Interaction:**
- None (unless syncing settings to backend).

**Error Handling:**
- Try/catch for settings save/load.
- Shows `SnackBar` for errors.

**Async/Performance:**
- Loads and saves settings asynchronously.

**Navigation:**
- None (settings are in-app only).

**Security:**
- None (local settings only).

**Packages Used:**
- `google_fonts`, `shared_preferences`, `provider` (optional)

**Learning Tips:**
- Use `SwitchListTile` for toggles.
- Use `SharedPreferences` for persistent local settings.

---

## 10. **SecurityScreen**

**Purpose:**
- Manage security settings (biometrics, 2FA, session management).

**UI Breakdown:**
- `Scaffold` with `CustomAppBar`.
- `ListView` or `Column` for security options.
- `SwitchListTile`, `DropdownButtonFormField` for toggles and selections.
- `ListView` for active sessions.
- `ElevatedButton` for actions (e.g., logout others).
- `SnackBar` for feedback.

**State Management:**
- `StatefulWidget` with local state for security options and sessions.
- Uses `setState` for updates.

**Service Calls:**
- **SessionTrackingService.getActiveSessions()**
- **SessionTrackingService.logoutOtherSessions()**

**Backend Interaction:**
- **Supabase tables:** `sessions`, `profiles`
- **Example query:**
  ```dart
  final sessions = await SupabaseService.client
      .from('sessions')
      .select()
      .eq('user_id', userId);
  ```

**Error Handling:**
- Try/catch for all service calls.
- Shows `SnackBar` for errors.
- Loading indicators during fetch/actions.

**Async/Performance:**
- Loads sessions and security options asynchronously.

**Navigation:**
- Navigates to `ChangePasswordScreen` or session details.

**Security:**
- Validates user before showing/changing security settings.
- Handles session timeouts and 2FA securely.

**Packages Used:**
- `google_fonts`, `supabase_flutter`, `provider`, `permission_handler`

**Learning Tips:**
- Use `SwitchListTile` for security toggles.
- Always validate user before sensitive actions.

---

## 11. **NotificationsScreen**

**Purpose:**
- Show app notifications (test results, reminders, etc.).

**UI Breakdown:**
- `Scaffold` with `CustomAppBar`.
- `ListView` for notifications.
- `Card`, `ListTile` for each notification.
- `SnackBar` for feedback.

**State Management:**
- `StatefulWidget` with local state for notifications.
- Uses `setState` for updates.

**Service Calls:**
- **SupabaseService.client.from('notifications').select().eq('user_id', userId)**

**Backend Interaction:**
- **Supabase tables:** `notifications`
- **Example query:**
  ```dart
  final notifications = await SupabaseService.client
      .from('notifications')
      .select()
      .eq('user_id', userId);
  ```

**Error Handling:**
- Try/catch for all service calls.
- Shows `SnackBar` for errors.
- Loading indicators during fetch.

**Async/Performance:**
- Loads notifications asynchronously.

**Navigation:**
- None (notifications are in-app only).

**Security:**
- Checks user authentication before loading notifications.

**Packages Used:**
- `google_fonts`, `supabase_flutter`, `provider` (optional)

**Learning Tips:**
- Use `ListTile` for notification items.
- Always show loading and error states.

---

## 12. **HelpSupportScreen**

**Purpose:**
- Provide help, FAQs, and support contact options.

**UI Breakdown:**
- `Scaffold` with `CustomAppBar`.
- `ListView` or `Column` for help topics.
- `ExpansionTile` for FAQs.
- `ElevatedButton` for contact/support.

**State Management:**
- `StatefulWidget` with local state for help topics.
- Uses `setState` for updates.

**Service Calls:**
- None (static content or links).

**Backend Interaction:**
- None (unless submitting support tickets).

**Error Handling:**
- Try/catch for support actions.
- Shows `SnackBar` for errors.

**Async/Performance:**
- Loads help topics asynchronously if from backend.

**Navigation:**
- Navigates to support/contact form if needed.

**Security:**
- None (public info).

**Packages Used:**
- `google_fonts`, `url_launcher`, `provider` (optional)

**Learning Tips:**
- Use `ExpansionTile` for FAQs.
- Use `url_launcher` for support links.

---

## 13. **AboutScreen**

**Purpose:**
- Show app info, version, credits, and acknowledgments.

**UI Breakdown:**
- `Scaffold` with `CustomAppBar`.
- `Column` for app info.
- `Text`, `ListTile` for credits.
- `Image` for logo.

**State Management:**
- `StatelessWidget` or simple `StatefulWidget`.

**Service Calls:**
- None (static content).

**Backend Interaction:**
- None.

**Error Handling:**
- None needed.

**Async/Performance:**
- None needed.

**Navigation:**
- None.

**Security:**
- None.

**Packages Used:**
- `google_fonts`, `package_info_plus` (for version info)

**Learning Tips:**
- Use `package_info_plus` to show app version.
- Keep about/credits up to date.

---

## 14. **CustomAppBar (Widget)**

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

## 15. **AppText (Widget)**

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

## 16. **DrawerMenu (Widget)**

**Purpose:**
- Provides navigation drawer for mobile screens.

**Key Features:**
- User profile header
- Navigation items (Home, Attendance, Practice Tests, etc.)
- Logout button with confirmation dialog

**Usage Example:**
```dart
Scaffold(
  drawer: DrawerMenu(),
  // ...
)
```

**Learning Tips:**
- Use `ListTile` for navigation items.
- Use `showDialog` for logout confirmation.

---

## 17. **AuthService (Service)**

**Purpose:**
- Handles all authentication logic: login, logout, session check, and password management.

**Key Methods:**
- `Future<AuthStatus> checkAuthStatus()`
  - Checks if the user is logged in, needs setup, or session expired.
  - Returns an enum: `fullyAuthenticated`, `needsSetup`, `notLoggedIn`, `sessionExpired`, `error`.
- `Future<void> signIn(String email, String password)`
  - Signs in the user using Supabase Auth.
  - Throws on error (invalid credentials, network, etc.).
- `Future<void> signOut()`
  - Signs out the user and clears secure storage.
- `Future<void> resetPassword(String email)`
  - Sends a password reset email via Supabase.

**Backend (Supabase) Interaction:**
- Uses Supabase Auth for JWT-based authentication.
- Stores tokens securely using `flutter_secure_storage`.
- Reads/writes to the `profiles` table for user info.

**Example:**
```dart
final response = await SupabaseService.client.auth.signInWithPassword(
  email: email,
  password: password,
);
```

**Error Handling:**
- All methods use try/catch and throw user-friendly errors.
- Uses `ErrorMessageService.getFriendlyMessage(e)` for display.

**Security:**
- Tokens are never stored in plain text.
- Always checks for valid session before sensitive actions.

**Learning Tips:**
- Always handle errors and show user feedback.
- Use secure storage for tokens.
- Use enums for auth status for clarity.

---

## 18. **UserProfileService (Service)**

**Purpose:**
- Manages user profile data: fetch, update, and sync with backend.

**Key Methods:**
- `Future<UserProfile?> getCurrentUserProfile()`
  - Fetches the current user's profile from Supabase `profiles` table.
- `Future<void> updateUserProfile(Map<String, dynamic> data)`
  - Updates the user's profile fields in Supabase.
- `Future<void> createUserProfile(Map<String, dynamic> data)`
  - Creates a new profile entry after signup.

**Backend (Supabase) Interaction:**
- Reads/writes to the `profiles` table.
- Uses user ID as the primary key.

**Example:**
```dart
final response = await SupabaseService.client
    .from('profiles')
    .select()
    .eq('id', userId)
    .single();
```

**Error Handling:**
- All methods use try/catch and throw user-friendly errors.
- Validates data before sending to backend.

**Security:**
- Only allows updates for the authenticated user.
- Sanitizes all input before saving.

**Learning Tips:**
- Use `fromJson`/`toJson` for model conversion.
- Always validate and sanitize user input.

---

## 19. **FilesService (Service)**

**Purpose:**
- Handles fetching, uploading, and managing study resources/files.

**Key Methods:**
- `Future<List<FileResource>> getFiles(String subjectId, String type)`
  - Fetches files for a subject and type (notes, assignments, etc.).
- `Future<List<FileResource>> getRecentFiles(String subjectId, int limit)`
  - Fetches the most recent files for a subject.
- `Future<void> uploadFile(File file, String subjectId, String type)`
  - Uploads a file to Supabase Storage and creates a record in `files` table.

**Backend (Supabase) Interaction:**
- Reads from and writes to the `files` table.
- Uses Supabase Storage for file uploads.

**Example:**
```dart
final files = await SupabaseService.client
    .from('files')
    .select()
    .eq('subject_id', subjectId)
    .eq('type', type);
```

**Error Handling:**
- All methods use try/catch and show user-friendly errors.
- Validates file type and size before upload.

**Security:**
- Only allows access to files for enrolled subjects.
- Scans files for malware (if supported by backend).

**Learning Tips:**
- Use caching for frequently accessed files.
- Use `url_launcher` for file downloads.

---

## 20. **NetworkService (Service)**

**Purpose:**
- Checks network connectivity and handles offline scenarios.

**Key Methods:**
- `Future<bool> isConnected()`
  - Returns true if the device is online.

**Backend Interaction:**
- None (uses platform APIs).

**Error Handling:**
- Returns false on network error.

**Learning Tips:**
- Always check network before making API calls.
- Show offline UI if not connected.

---

## 21. **ErrorMessageService (Service)**

**Purpose:**
- Converts technical errors into user-friendly messages.

**Key Methods:**
- `static String getFriendlyMessage(dynamic error)`
  - Maps exceptions to readable messages.

**Usage Example:**
```dart
try {
  await AuthService.signIn(email, password);
} catch (e) {
  final message = ErrorMessageService.getFriendlyMessage(e);
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
```

**Learning Tips:**
- Centralize error messages for consistency.
- Always show actionable feedback.

---

## 22. **FileValidationService (Service)**

**Purpose:**
- Validates files before upload/download.

**Key Methods:**
- `static bool isValidFileType(String fileName)`
- `static bool isValidFileSize(int size)`

**Learning Tips:**
- Always validate files on both client and server.

---

## 23. **SecureStorageService (Service)**

**Purpose:**
- Handles secure storage of sensitive data (tokens, keys).

**Key Methods:**
- `Future<void> write(String key, String value)`
- `Future<String?> read(String key)`
- `Future<void> delete(String key)`

**Backend Interaction:**
- None (local only, uses `flutter_secure_storage`).

**Learning Tips:**
- Never store tokens in plain text or shared preferences.

---

## 24. **Mixins (PerformanceMixin, NetworkAwareMixin)**

**Purpose:**
- Add reusable logic for performance monitoring and network awareness.

**Usage Example:**
```dart
class MyScreenState extends State<MyScreen> with PerformanceMixin, NetworkAwareMixin { ... }
```

**Learning Tips:**
- Use mixins to avoid code duplication across screens.

---

## 25. **Models (Subject, UserProfile, AttendanceRecord, etc.)**

**Purpose:**
- Define data structures for app entities.

**Key Properties:**
- `Subject`: id, name, code, etc.
- `UserProfile`: id, fullName, email, college, branch, etc.
- `AttendanceRecord`: id, subjectId, date, status, etc.

**Usage Example:**
```dart
final subject = Subject.fromJson(jsonData);
final map = subject.toJson();
```

**Learning Tips:**
- Use `fromJson` and `toJson` methods for easy serialization.
- Keep models in sync with backend schema.

---

## 26. **Theme (app_theme.dart)**

**Purpose:**
- Centralizes all color, font, and style definitions.

**Key Properties:**
- `primaryBlue`, `backgroundLight`, `success`, `error`, etc.

**Usage Example:**
```dart
Container(
  color: AppTheme.primaryBlue,
  child: Text('EduNest', style: TextStyle(color: AppTheme.textInverse)),
)
```

**Learning Tips:**
- Use a theme file for easy global style changes.
- Use color and font constants throughout the app.

---

## 27. **Other Utilities**

- **SessionTrackingService:** Manages user sessions, active devices, and session timeouts.
- **RateLimiterService:** Prevents abuse by limiting API call frequency.
- **HybridAIService:** Handles AI-powered features (e.g., question generation).
- **TestResultsService:** Manages test result storage and analytics.

**Learning Tips:**
- Keep utility services modular and single-responsibility.
- Document all public methods for maintainability.

---

**This completes the deep-dive for all major files, widgets, services, and backend logic in EduNest.**

**Happy learning and building!** 