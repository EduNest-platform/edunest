# EduNest Super Admin Panel

## Overview
The EduNest Super Admin Panel is a web-based dashboard for managing all colleges, communities, branches, semesters, subjects, users, and educational resources in the EduNest platform. It provides full control for super administrators, including user and role management, hierarchy management, file uploads, and more.

## Features
- **Authentication:** Secure login for super admins
- **Dashboard:** Quick access to all major management features
- **Community & Admin Management:** Add, edit, and remove communities and their admins; manage roles (admin, moderator, professor)
- **Hierarchy Management:** Manage colleges, branches, semesters, and subjects with drill-down navigation
- **Syllabus & Timetable Management:** Upload, replace, and manage syllabus and timetable files for each semester
- **File Management:** Upload and manage files for subjects and other resources
- **Question Entry & Test Management:** Manual question entry and assigned test management
- **AI Config:** Configure AI-related settings
- **Responsive Design:** Works on desktop, tablet, and mobile

## Setup
1. **Clone the repository** and navigate to the `Super Admin` folder:
   ```sh
   git clone <your-repo-url>
   cd Super\ Admin
   ```
2. **Install dependencies** (if any are required for your workflow):
   - This panel is static HTML/JS/CSS and does not require a build step.
   - If you use a local server, you can run:
     ```sh
     npx serve .
     # or
     python -m http.server
     ```
3. **Configure Supabase:**
   - Update `supabaseClient.js` and `supabaseAdmin.js` with your Supabase project URL and keys.
   - Ensure your Supabase tables and storage buckets are set up as described in the code comments.

## Usage
- Open `index.html` in your browser to access the login page.
- After logging in, use the sidebar to navigate between dashboard, communities, colleges, branches, semesters, subjects, files, and more.
- Use the "Manage Admins" button in communities to add or update community admins and their roles.
- Use the "Syllabus & Timetable" section to upload or replace files for each semester.
- All changes are reflected in real-time via Supabase.

## File Structure
- `dashboard.html` - Main dashboard
- `communities.html`, `community_admins.html` - Community and admin management
- `colleges.html`, `branches.html`, `semesters.html`, `subjects.html` - Hierarchy management
- `syllabus_timetable.html` - Syllabus and timetable management
- `files.html` - File management
- `question_entry.html`, `assigned_tests.html` - Question and test management
- `ai-config.html` - AI configuration
- `style.css`, `mobile-nav.css`, `drilldown.css` - Styling
- `supabaseClient.js`, `supabaseAdmin.js` - Supabase configuration

## Security Notes
- Do **not** expose your Supabase service role key in public repositories.
- Use environment variables or server-side functions for sensitive operations if deploying publicly.

## License
MIT or your chosen license. 
 
 
 
 