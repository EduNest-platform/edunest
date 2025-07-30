# EduNest Admin Panel

A modern administrative dashboard for managing educational institutions, branches, semesters, subjects, topics, files, and AI-powered test assignment. This panel is designed for admins to manage their assigned college and its academic hierarchy.

## Features

- **Secure Login System** - Supabase Auth-based admin access
- **College Management** - Add, view, and manage your assigned college
- **Branch, Semester, Subject Management** - Drill-down navigation for managing branches, semesters, and subjects within your college
- **Role Management** - Admins have full control over their assigned college
- **File Management** - Upload, view, and organize study resources (notes, assignments, lab manuals, etc.)
- **Syllabus & Timetable Management** - Upload and replace syllabus/timetable files for each semester
- **Manual Question Entry & Test Assignment** - Add questions and manage assigned tests
- **Responsive Design** - Works on desktop, tablet, and mobile
- **Real-time Updates** - All changes reflect immediately
- **Session Management** - Secure session, automatic logout, protected routes

## How It Works

- **Each admin only sees and manages the college they belong to.**
- **Drill-down navigation:**
  - Colleges → Branches → Semesters → Subjects
  - Context is passed via sessionStorage and URL parameters

## Setup

1. **Database Setup**
   - Ensure your Supabase database has the following tables:
     - `colleges` (id, name)
     - `branches` (id, name, college_id)
     - `semesters` (id, name, branch_id)
     - `subjects` (id, name, code, description, semester_id)
     - `files`, `syllabus_timetable`, `assigned_tests`, etc.

2. **Configuration**
   - Update your Supabase project URL and anon/public key in `supabaseClient.js` and `supabaseAdmin.js`.
   - No hardcoded admin credentials are required; authentication is handled by Supabase Auth.

3. **Deployment**
   - Upload all files to your web server or deploy to GitHub Pages.
   - Ensure `index.html` is accessible as the entry point.
   - All asset and script paths are relative for static hosting compatibility.

## Usage

1. **Access** - Navigate to `index.html` (login page)
2. **Login** - Use your Supabase admin credentials
3. **Manage** - Use the sidebar to navigate between modules:
   - My College, Branches, Semesters, Subjects, Files, Syllabus/Timetable, Assigned Tests, Manual Question Entry
4. **Drill-down Navigation** - Click "Manage Branches" on your college card to view and manage branches, then drill down to semesters and subjects
5. **Add/Edit Data** - Use forms and tables to add, edit, or delete records
6. **Syllabus/Timetable** - Use the dedicated section to upload or replace files for each semester
7. **Logout** - Click the logout button to securely exit

## Security

- Supabase Auth-based session management
- Protected routes (direct dashboard access blocked)
- Secure credential validation
- Automatic session cleanup on logout
- No hardcoded admin credentials in any JS file
- Only Supabase anon/public keys are used in the frontend

## File Structure

```
admin_panel/
├── index.html                # Login page
├── signup.html, signup.js    # Signup page and logic
├── dashboard.html            # Main dashboard
├── app.js                    # Application logic
├── style.css                 # Styling
├── supabaseClient.js         # Supabase client config
├── supabaseAdmin.js          # Supabase admin config
├── colleges.html/js/css      # College management
├── branches.html/js/css      # Branch management
├── semesters.html/js/css     # Semester management
├── subjects.html/js/css      # Subject management
├── syllabus_timetable.html/css # Syllabus & timetable management
├── files.html/js/css         # File management
├── question_entry.html/js/css # Manual question entry
├── assigned_tests.html/js/css # Test management
├── ai-config.html/js/css     # AI configuration
├── [other modules: *.js, *.css, *.html] # All feature modules
├── README.md                 # This file
```

## Browser Support

- Chrome 80+
- Firefox 75+
- Safari 13+
- Edge 80+

## Accessibility & UX

- Responsive and mobile-friendly design
- Loading indicators and user feedback for all actions
- User-friendly error messages
- Basic accessibility (labels, roles); further improvements recommended

## Support

For technical support or questions, contact your system administrator or project maintainer.

---

**Note:**
- This admin panel is designed for static hosting (GitHub Pages, Netlify, Vercel, etc.).
- Do not expose Supabase service role or secret keys in the frontend.
- For advanced features (AI, file uploads), ensure your Supabase backend and storage are properly configured.