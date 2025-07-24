# EduNest Admin Panel

A professional administrative dashboard for managing educational institutions, branches, semesters, subjects, topics, files, and AI-powered test assignment.

## Features

- **Secure Login System** - Supabase Auth-based admin access
- **College Management** - Add, view, and delete colleges
- **Branch Management** - Organize branches under colleges
- **Semester Management** - Manage semesters under branches
- **Subject Management** - Add, view, and manage subjects under semesters
- **Topic Management** - Add, edit, and organize topics under subjects
- **File Management** - Upload, view, and organize study resources (notes, assignments, lab manuals, etc.)
- **AI-Powered Test Assignment** - Assign and manage practice tests using AI-generated questions
- **Hierarchical View** - Visual representation of the complete academic structure
- **Responsive Design** - Works on desktop, tablet, and mobile
- **Real-time Updates** - All changes reflect immediately
- **Session Management** - Secure session, automatic logout, protected routes

## Setup

1. **Database Setup**
   - Ensure your Supabase database has the following tables:
     - `colleges` (id, name)
     - `branches` (id, name, college_id)
     - `semesters` (id, name, branch_id)
     - `subjects` (id, name, code, description, semester_id)
     - `topics` (id, name, content, subject_id)
     - `files` (id, name, file_type, file_url, subject_id, uploaded_by, created_at)
     - `assigned_tests` (id, name, subject_id, assigned_to, due_date, etc.)

2. **Configuration**
   - Update your Supabase project URL and anon/public key in `supabaseClient.js`.
   - No hardcoded admin credentials are required; authentication is handled by Supabase Auth.

3. **Deployment**
   - Upload all files to your web server or deploy to GitHub Pages.
   - Ensure `index.html` is accessible as the entry point.
   - All asset and script paths are relative for static hosting compatibility.

## Usage

1. **Access** - Navigate to `index.html` (login page)
2. **Login** - Use your Supabase admin credentials
3. **Manage** - Use the sidebar to navigate between modules:
   - Colleges, Branches, Semesters, Subjects, Topics, Files, Assigned Tests, AI Config
4. **Add/Edit Data** - Use forms and tables to add, edit, or delete records
5. **View Structure** - Use the "Structure" or "Hierarchy" tab for a visual overview
6. **Logout** - Click the logout button to securely exit

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
├── dashboard.html            # Main dashboard
├── app.js                    # Application logic
├── style.css                 # Styling
├── supabaseClient.js         # Supabase client config
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
 
 
 
 