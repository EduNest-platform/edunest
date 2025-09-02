// Attendance Management System with Caching
let currentUser = null;
let currentUserRole = null;
let selectedClass = null;
let classes = [];
let roster = [];
let attendanceData = {};
let assignedCollege = { id: null, name: null };
let cacheEnabled = true; // Enable caching by default

// Cache configuration
const CACHE_CONFIG = {
  CLASSES_KEY: 'attendance_classes_cache',
  CLASSES_TTL: 7 * 24 * 60 * 60 * 1000, // 7 days in milliseconds
  TIMESTAMP_KEY: 'attendance_classes_timestamp'
};

// Initialize the attendance system
document.addEventListener('DOMContentLoaded', async function() {
  // Show skeleton cards immediately
  showSkeletonCards();
  
  // Run auth and user info loading first, then check role
  await Promise.all([
    checkAuthStatus(),
    loadUserInfo()
  ]);
  
  // Check professor role after user info is loaded
  await checkProfessorRole();
  
  // Wait for cache manager to be available (non-blocking)
  if (cacheEnabled) {
    let attempts = 0;
    while (!window.adminCache && attempts < 10) {
      await new Promise(resolve => setTimeout(resolve, 50));
      attempts++;
    }
    if (window.adminCache) {
      console.log('Cache manager ready for attendance system');
    }
  }
  
  await initializeAttendanceSystem();
});

// Check authentication status
async function checkAuthStatus() {
  const isLoggedIn = sessionStorage.getItem('adminLoggedIn') === 'true';
  if (!isLoggedIn) {
    window.location.href = 'index.html';
    return;
  }
}

// Load user information
async function loadUserInfo() {
  try {
    const user = await window.authManager.getCurrentUser();
    if (!user) {
      window.location.href = 'index.html';
      return;
    }
    
    currentUser = user;
    console.log('User loaded:', user.email);
    
    // Check if user is a professor after loading user info
    await checkProfessorRole();
    if (userEmail) userEmail.textContent = user.email;
    if (userAvatar) userAvatar.textContent = user.email.charAt(0).toUpperCase();
    if (mobileUserName) mobileUserName.textContent = user.email.split('@')[0];
    if (mobileUserEmail) mobileUserEmail.textContent = user.email;
    if (mobileUserAvatar) mobileUserAvatar.textContent = user.email.charAt(0).toUpperCase();
    
  } catch (error) {
    console.error('Error loading user info:', error);
    window.location.href = 'index.html';
  }
}

// Check if user is a professor
async function checkProfessorRole() {
  try {
    // Ensure currentUser is loaded before proceeding
    if (!currentUser || !currentUser.id) {
      console.error('currentUser not loaded yet, skipping role check');
      return;
    }
    
    const { data: adminData, error: roleError } = await window.supabaseAdmin
      .from('community_admins')
      .select('role')
      .eq('user_id', currentUser.id)
      .single();

    if (!roleError && adminData) {
      currentUserRole = adminData.role;
      const isProfessor = currentUserRole.toLowerCase() === 'professor';
      
      // Update role display
      const userRole = document.getElementById('userRole');
      const mobileUserRole = document.getElementById('mobileUserRole');
      
      if (userRole) userRole.textContent = currentUserRole.charAt(0).toUpperCase() + currentUserRole.slice(1);
      if (mobileUserRole) mobileUserRole.textContent = currentUserRole.charAt(0).toUpperCase() + currentUserRole.slice(1);
      
      // Redirect if not professor
      if (!isProfessor) {
        showMsg('messageDisplay', 'Access denied. Only professors can access attendance management.', true);
        setTimeout(() => {
          window.location.href = 'dashboard.html';
        }, 2000);
        return;
      }
    } else {
      showMsg('messageDisplay', 'Error loading user role.', true);
      setTimeout(() => {
        window.location.href = 'dashboard.html';
      }, 2000);
    }
  } catch (error) {
    console.error('Error checking professor role:', error);
    showMsg('messageDisplay', 'Error loading user role.', true);
  }
}

// Show skeleton loading cards immediately
function showSkeletonCards() {
  const classesGrid = document.getElementById('classesGrid');
  if (!classesGrid) return;
  
  const skeletonCards = Array(3).fill(0).map(() => `
    <div class="class-card skeleton-card">
      <div class="class-header">
        <div class="skeleton-title"></div>
      </div>
      <div class="class-details">
        <div class="class-detail">
          <span>🏢</span>
          <div class="skeleton-text"></div>
        </div>
        <div class="class-detail">
          <span>📚</span>
          <div class="skeleton-text"></div>
        </div>
        <div class="class-detail">
          <span>🏫</span>
          <div class="skeleton-text"></div>
        </div>
      </div>
      <div class="class-actions-grid">
        <div class="skeleton-button"></div>
        <div class="skeleton-button"></div>
        <div class="skeleton-button"></div>
      </div>
    </div>
  `).join('');
  
  classesGrid.innerHTML = skeletonCards;
}

// Initialize attendance system
async function initializeAttendanceSystem() {
  await resolveAssignedCollege();
  await loadClasses();
  setDefaultDate();
}

// Resolve professor's assigned college via community_admins → communities → colleges
async function resolveAssignedCollege() {
  try {
    const { data: adminRows } = await window.supabaseAdmin
      .from('community_admins')
      .select('community_id')
      .eq('user_id', currentUser.id);

    if (!adminRows || adminRows.length === 0) return;

    const communityIds = adminRows.map(r => r.community_id);
    const { data: communities } = await window.supabaseAdmin
      .from('communities')
      .select('name')
      .in('id', communityIds);

    if (!communities || communities.length === 0) return;

    const allowedNames = communities.map(c => c.name);
    const { data: colleges } = await window.supabaseClient
      .from('colleges')
      .select('id, name');

    if (!colleges || colleges.length === 0) return;

    const filtered = colleges.filter(c => allowedNames.includes(c.name));
    if (filtered.length > 0) {
      assignedCollege = { id: filtered[0].id, name: filtered[0].name };
      const fixedName = document.getElementById('fixedCollegeNameText');
      const modalName = document.getElementById('classCollegeName');
      if (fixedName) fixedName.textContent = assignedCollege.name;
      if (modalName) modalName.textContent = assignedCollege.name;
    }
  } catch (e) {
    console.error('Error resolving assigned college', e);
  }
}

// Cache utility functions
function getCachedClasses() {
  try {
    const cachedData = localStorage.getItem(CACHE_CONFIG.CLASSES_KEY);
    const timestamp = localStorage.getItem(CACHE_CONFIG.TIMESTAMP_KEY);
    
    if (!cachedData || !timestamp) return null;
    
    const now = Date.now();
    const cacheAge = now - parseInt(timestamp);
    
    if (cacheAge > CACHE_CONFIG.CLASSES_TTL) {
      // Cache expired
      localStorage.removeItem(CACHE_CONFIG.CLASSES_KEY);
      localStorage.removeItem(CACHE_CONFIG.TIMESTAMP_KEY);
      return null;
    }
    
    return JSON.parse(cachedData);
  } catch (error) {
    console.error('Error reading classes cache:', error);
    return null;
  }
}

function setCachedClasses(classesData) {
  try {
    localStorage.setItem(CACHE_CONFIG.CLASSES_KEY, JSON.stringify(classesData));
    localStorage.setItem(CACHE_CONFIG.TIMESTAMP_KEY, Date.now().toString());
    console.log('Classes cached successfully');
  } catch (error) {
    console.error('Error caching classes:', error);
  }
}

function clearClassesCache() {
  localStorage.removeItem(CACHE_CONFIG.CLASSES_KEY);
  localStorage.removeItem(CACHE_CONFIG.TIMESTAMP_KEY);
  console.log('Classes cache cleared');
}

// Load classes for the professor with caching
async function loadClasses(forceRefresh = false) {
  try {
    // Try to load from cache first (unless force refresh)
    if (!forceRefresh && cacheEnabled) {
      const cachedClasses = getCachedClasses();
      if (cachedClasses && cachedClasses.length > 0) {
        console.log('Loading classes from cache');
        classes = cachedClasses.filter(classItem => !assignedCollege.name || classItem.college === assignedCollege.name);
        renderClasses();
        
        // Background refresh - update cache silently (immediate)
        loadClassesFromDatabase(true);
        
        return;
      }
    }
    
    // Load from database
    await loadClassesFromDatabase(false);
    
  } catch (error) {
    console.error('Error loading classes:', error);
    showMsg('messageDisplay', 'Error loading classes: ' + error.message, true);
    hideLoading();
  }
}

// Load classes from database
async function loadClassesFromDatabase(isBackgroundRefresh = false) {
  try {
    if (!isBackgroundRefresh) {
      showLoading('Loading classes...');
    }
    
    // Get classes created by this professor using simplified structure
    const { data: professorClasses, error } = await window.supabaseClient
      .from('professor_classes')
      .select('*')
      .eq('professor_email', currentUser.email);

    if (error) throw error;

    // Map the simplified data to the expected format
    const fetchedClasses = (professorClasses || [])
      .map(professorClass => ({
        id: professorClass.id, // This is the professor_class id
        name: professorClass.subject_name, // Use subject name as main title
        college: professorClass.college_name || 'Unknown College',
        collegeId: null, // No longer needed
        branch: professorClass.branch_name || 'Unknown Branch',
        branchId: null, // No longer needed
        semester: professorClass.semester_name || 'Unknown Semester',
        semesterId: null, // No longer needed
        subject: professorClass.subject_name,
        subjectId: professorClass.subject_id || null, // Get actual subject ID
        className: professorClass.class_name
      }));

    // Cache the fetched classes
    if (cacheEnabled) {
      setCachedClasses(fetchedClasses);
    }

    // Filter and update classes
    classes = fetchedClasses.filter(classItem => !assignedCollege.name || classItem.college === assignedCollege.name);

    if (!isBackgroundRefresh) {
      renderClasses();
      hideLoading();
    } else {
      // Silent background update - only re-render if data changed
      const currentClassIds = classes.map(c => c.id).sort();
      const newClassIds = fetchedClasses.filter(classItem => !assignedCollege.name || classItem.college === assignedCollege.name).map(c => c.id).sort();
      
      if (JSON.stringify(currentClassIds) !== JSON.stringify(newClassIds)) {
        console.log('Classes updated in background, refreshing UI');
        renderClasses();
      }
    }
    
  } catch (error) {
    if (!isBackgroundRefresh) {
      console.error('Error loading classes:', error);
      showMsg('messageDisplay', 'Error loading classes: ' + error.message, true);
      hideLoading();
    } else {
      console.warn('Background refresh failed:', error);
    }
  }
}

// Render classes grid
function renderClasses() {
  const classesGrid = document.getElementById('classesGrid');
  if (!classesGrid) return;

  if (classes.length === 0) {
    classesGrid.innerHTML = `
      <div class="empty-state">
        <div style="text-align: center; padding: 3rem; color: #64748b;">
          <div style="font-size: 3rem; margin-bottom: 1rem;">📚</div>
          <h3 style="margin-bottom: 0.5rem;">No Classes Yet</h3>
          <p>Click "Add New Class" to create your first class and start marking attendance.</p>
        </div>
      </div>
    `;
    return;
  }

  classesGrid.innerHTML = classes.map(classItem => `
    <div class="class-card" data-class-id="${classItem.id}" data-class-name="${classItem.subject}" onclick="handleClassCardClick(event, this)">
      <div class="class-header">
        <h3 class="class-title">${classItem.subject}</h3>
      </div>
      <div class="class-details">
        <div class="class-detail">
          <span>🏢</span>
          <span>${classItem.branch}</span>
        </div>
        <div class="class-detail">
          <span>📚</span>
          <span>${classItem.semester}</span>
        </div>
        <div class="class-detail">
          <span>🏫</span>
          <span>${classItem.college}</span>
        </div>
      </div>
      <div class="class-actions-grid">
        <button class="action-btn attendance-btn" onclick="event.stopPropagation(); openAttendanceTracker('${classItem.id}')" title="Track Attendance">
          <span class="btn-icon">📅</span>
          <span class="btn-text">Track Attendance</span>
        </button>
        <button class="action-btn analytics-btn" onclick="event.stopPropagation(); openAttendanceAnalytics('${classItem.id}')" title="View Analytics">
          <span class="btn-icon">📊</span>
          <span class="btn-text">View Analytics</span>
        </button>
        <button class="action-btn question-btn" onclick="event.stopPropagation(); openQuestionEntry('${classItem.id}', '${classItem.subject}', '${classItem.subjectId}', '${classItem.college}', '${classItem.branch}', '${classItem.semester}')" title="Manual Question Entry">
          <span class="btn-icon">📝</span>
          <span class="btn-text">Question Entry</span>
        </button>
        <button class="action-btn tests-btn" onclick="event.stopPropagation(); openAssignedTests('${classItem.id}', '${classItem.subject}', '${classItem.subjectId}', '${classItem.college}', '${classItem.branch}', '${classItem.semester}')" title="Show Assigned Tests">
          <span class="btn-icon">📋</span>
          <span class="btn-text">Assigned Tests</span>
        </button>
        <button class="action-btn marks-btn" onclick="event.stopPropagation(); openAssignmentMarks('${classItem.id}', '${classItem.subject}', '${classItem.college}', '${classItem.branch}', '${classItem.semester}')" title="Assignment Marks">
          <span class="btn-icon">✏️</span>
          <span class="btn-text">Assignment Marks</span>
        </button>
        <button class="action-btn midsem-btn" onclick="event.stopPropagation(); openMidsemMarks('${classItem.id}', '${classItem.subject}', '${classItem.college}', '${classItem.branch}', '${classItem.semester}')" title="Midsem Marks">
          <span class="btn-icon">📝</span>
          <span class="btn-text">Midsem Marks</span>
        </button>
        <button class="action-btn feedback-btn" onclick="event.stopPropagation(); openFeedbackAnalytics('${classItem.id}', '${classItem.subject}', '${classItem.subjectId}', '${classItem.college}', '${classItem.branch}', '${classItem.semester}')" title="View Feedback">
          <span class="btn-icon">💬</span>
          <span class="btn-text">Feedback</span>
        </button>
        <button class="action-btn students-btn" onclick="event.stopPropagation(); openManageStudents('${classItem.id}', '${classItem.subject}', '${classItem.college}', '${classItem.branch}', '${classItem.semester}')" title="Manage Students">
          <span class="btn-icon">👥</span>
          <span class="btn-text">Manage Students</span>
        </button>
      </div>
    </div>
  `).join('');
}

// Load filters
async function loadFilters() {
  try {
    // Load branches
    const { data: branches } = await window.supabaseAdmin
      .from('branches')
      .select('id, name, college_id')
      .order('name');

    const branchFilter = document.getElementById('branchFilter');
    if (branchFilter && branches) {
      const filteredBranches = assignedCollege.id ? branches.filter(b => b.college_id === assignedCollege.id) : branches;
      branchFilter.innerHTML = '<option value="">All Branches</option>' +
        filteredBranches.map(branch => `<option value="${branch.id}" data-college="${branch.college_id}">${branch.name}</option>`).join('');
    }

    // Load semesters
    const { data: semesters } = await window.supabaseAdmin
      .from('semesters')
      .select('id, name, branch_id')
      .order('name');

    const semesterFilter = document.getElementById('semesterFilter');
    if (semesterFilter && semesters) {
      semesterFilter.innerHTML = '<option value="">All Semesters</option>' +
        semesters.map(semester => `<option value="${semester.id}" data-branch="${semester.branch_id}">${semester.name}</option>`).join('');
    }

    // Load subjects
    const { data: subjects } = await window.supabaseAdmin
      .from('subjects')
      .select('id, name, semester_id')
      .order('name');

    const subjectFilter = document.getElementById('subjectFilter');
    if (subjectFilter && subjects) {
      subjectFilter.innerHTML = '<option value="">All Subjects</option>' +
        subjects.map(subject => `<option value="${subject.id}" data-semester="${subject.semester_id}">${subject.name}</option>`).join('');
    }

  } catch (error) {
    console.error('Error loading filters:', error);
  }
}

// Filter classes
function filterClasses() {
  const branchFilter = document.getElementById('branchFilter').value;
  const semesterFilter = document.getElementById('semesterFilter').value;
  const subjectFilter = document.getElementById('subjectFilter').value;

  const filteredClasses = classes.filter(classItem => {
    if (branchFilter && classItem.branchId !== branchFilter) return false;
    if (semesterFilter && classItem.semesterId !== semesterFilter) return false;
    if (subjectFilter && classItem.subjectId !== subjectFilter) return false;
    return true;
  });

  renderFilteredClasses(filteredClasses);
}

// Render filtered classes
function renderFilteredClasses(filteredClasses) {
  const classesGrid = document.getElementById('classesGrid');
  if (!classesGrid) return;

  if (filteredClasses.length === 0) {
    classesGrid.innerHTML = `
      <div class="empty-state">
        <p>No classes match the selected filters.</p>
      </div>
    `;
    return;
  }

  classesGrid.innerHTML = filteredClasses.map(classItem => `
    <div class="class-card clickable-card" data-class-id="${classItem.id}" data-class-name="${classItem.subject}" onclick="handleClassCardClick(event, this)" style="cursor: pointer;">
      <div class="class-header">
        <h3 class="class-title">${classItem.subject}</h3>
      </div>
      <div class="class-details">
        <div class="class-detail">
          <span>🏢</span>
          <span>${classItem.branch}</span>
        </div>
        <div class="class-detail">
          <span>📚</span>
          <span>${classItem.semester}</span>
        </div>
      </div>
      <div class="class-actions">
        <button class="attendance-btn" onclick="event.stopPropagation(); openAttendanceTracker('${classItem.id}')">
          📅 Track Attendance
        </button>
        <button class="analytics-btn" onclick="event.stopPropagation(); openAttendanceAnalytics('${classItem.id}')">
          📊 View Analytics
        </button>
        <button class="feedback-btn" onclick="event.stopPropagation(); openFeedbackAnalytics('${classItem.id}', '${classItem.subject}', '${classItem.subjectId}', '${classItem.college}', '${classItem.branch}', '${classItem.semester}')">
          💬 Feedback
        </button>
      </div>
    </div>
  `).join('');
}

// Manage roster for a class
async function manageRoster(classId) {
  selectedClass = classes.find(c => c.id === classId);
  if (!selectedClass) return;

  // Hide other sections
  document.getElementById('rosterSection').classList.remove('hidden');
  document.getElementById('attendanceSection').classList.add('hidden');
  
  // Update roster title
  document.getElementById('rosterTitle').textContent = `📚 ${selectedClass.subject} - Class Roster`;
  
  await loadRoster(classId);
}

// Load roster for a class
async function loadRoster(classId) {
  try {
    showLoading('Loading roster...');
    // Load roster from class_rosters (uploaded by professor) so it includes non-app users too
    const { data: rosterData, error } = await window.supabaseAdmin
      .from('class_rosters')
      .select('id, roll_number, student_name, student_email, is_verified, student_profile_id')
      .eq('class_id', classId)
      .order('student_name');

    if (error) throw error;

    roster = (rosterData || []).map(s => ({
      id: s.id,
      roll_number: s.roll_number,
      student_name: s.student_name,
      student_email: s.student_email,
      is_verified: !!s.is_verified,
      has_app_account: !!s.student_profile_id
    }));
    
    renderRoster();
    updateRosterStats();
    hideLoading();
    
  } catch (error) {
    console.error('Error loading roster:', error);
    showMsg('messageDisplay', 'Error loading roster: ' + error.message, true);
    hideLoading();
  }
}

// Render roster table
function renderRoster() {
  const rosterTableBody = document.getElementById('rosterTableBody');
  if (!rosterTableBody) return;

  if (roster.length === 0) {
    rosterTableBody.innerHTML = `
      <tr>
        <td colspan="4" style="text-align: center; padding: 2rem; color: #64748b;">
          No students in roster. Upload a roster file to get started.
        </td>
      </tr>
    `;
    return;
  }

  rosterTableBody.innerHTML = roster.map(student => `
    <tr>
      <td>${student.roll_number}</td>
      <td>
        <div>
          <div style="font-weight: 500;">${student.student_name}</div>
          ${student.student_email ? `<div style="font-size: 0.85em; color: #64748b;">${student.student_email}</div>` : ''}
        </div>
      </td>
      <td>
        <div style="display: flex; flex-direction: column; gap: 4px;">
          <span class="status-badge ${student.is_verified ? 'verified' : 'unverified'}">
            ${student.is_verified ? '✓ Verified' : '⚠ Unverified'}
          </span>
          ${student.has_app_account ? 
            '<span class="status-badge" style="background: #dbeafe; color: #1e40af; font-size: 0.75em;">📱 Has App</span>' : 
            '<span class="status-badge" style="background: #fef3c7; color: #92400e; font-size: 0.75em;">📝 Roster Only</span>'
          }
        </div>
      </td>
      <td>
        <button class="class-action-btn" onclick="removeStudent('${student.id}')">
          🗑️ Remove
        </button>
      </td>
    </tr>
  `).join('');
}

// Update roster statistics
function updateRosterStats() {
  const totalStudents = document.getElementById('totalStudents');
  const verifiedStudents = document.getElementById('verifiedStudents');
  const lastUpdated = document.getElementById('lastUpdated');

  if (totalStudents) totalStudents.textContent = roster.length;
  if (verifiedStudents) verifiedStudents.textContent = roster.filter(s => s.is_verified).length;
  if (lastUpdated) {
    const now = new Date();
    lastUpdated.textContent = now.toLocaleString();
  }
}

// Remove student from roster
async function removeStudent(studentId) {
  if (!confirm('Are you sure you want to remove this student from the roster?')) {
    return;
  }

  try {
    showLoading('Removing student...');

    const { error } = await window.supabaseAdmin
      .from('class_rosters')
      .delete()
      .eq('id', studentId);

    if (error) throw error;

    showMsg('messageDisplay', 'Student removed successfully!', false);
    
    // Reload roster
    await loadRoster(selectedClass.id);
    
    hideLoading();
    
  } catch (error) {
    console.error('Error removing student:', error);
    showMsg('messageDisplay', 'Error removing student: ' + error.message, true);
    hideLoading();
  }
}

// Open attendance tracker page
function openAttendanceTracker(classId) {
  console.log('Opening attendance tracker for class:', classId);
  window.location.href = `attendance_tracker.html?classId=${classId}`;
}

// Open attendance analytics page
function openAttendanceAnalytics(classId) {
  console.log('Opening attendance analytics for class:', classId);
  window.location.href = `attendance_analytics.html?classId=${classId}`;
}

// Open manage students page
function openManageStudents(classId, subject, college, branch, semester) {
  console.log('Opening manage students for class:', classId);
  const params = new URLSearchParams({
    classId: classId,
    subject: subject,
    college: college,
    branch: branch,
    semester: semester
  });
  window.location.href = `manage_students.html?${params.toString()}`;
}

// Mark attendance for a class
async function markAttendance(classId) {
  selectedClass = classes.find(c => c.id === classId);
  if (!selectedClass) return;

  // Hide other sections
  document.getElementById('attendanceSection').classList.remove('hidden');
  document.getElementById('rosterSection').classList.add('hidden');
  
  // Load roster first if not loaded
  if (roster.length === 0) {
    await loadRoster(classId);
  }
  
  // Load attendance data for the selected date
  await loadAttendanceData();
}

// Load attendance data
async function loadAttendanceData() {
  const date = document.getElementById('attendanceDate').value;
  if (!date || !selectedClass) return;

  try {
    showLoading('Loading attendance data...');
    const { data: attendanceRecords, error } = await window.supabaseClient
      .from('attendance')
      .select('*')
      .eq('class_id', selectedClass.id) // Use the professor_class ID
      .eq('date', date);

    if (error) throw error;

    // Initialize attendance data
    attendanceData = {};
    roster.forEach(student => {
      // student_id stores roll_number for non-app users; for app users it can be their UUID if you migrate later
      const record = (attendanceRecords || []).find(r => r.student_id === student.roll_number);
      attendanceData[student.roll_number] = record ? record.status : null;
    });

    renderAttendanceTable();
    updateAttendanceSummary();
    hideLoading();
    
  } catch (error) {
    console.error('Error loading attendance data:', error);
    showMsg('messageDisplay', 'Error loading attendance data: ' + error.message, true);
    hideLoading();
  }
}

// Render attendance table
function renderAttendanceTable() {
  const attendanceTableBody = document.getElementById('attendanceTableBody');
  if (!attendanceTableBody) return;

  attendanceTableBody.innerHTML = roster.map(student => `
    <tr>
      <td>${student.roll_number}</td>
      <td>${student.student_name}</td>
      <td>
        <div class="attendance-toggle">
          <div class="toggle-switch ${attendanceData[student.roll_number] === 'present' ? 'active' : ''}" 
               onclick="toggleAttendance('${student.roll_number}')">
            <div class="toggle-slider"></div>
          </div>
          <span>${attendanceData[student.roll_number] === 'present' ? 'Present' : 'Absent'}</span>
        </div>
      </td>
       <td>${attendanceData[student.roll_number] ? 'Today' : 'Not marked'}</td>
    </tr>
  `).join('');
}

// Toggle attendance for a student
function toggleAttendance(rollNumber) {
  const currentStatus = attendanceData[rollNumber];
  attendanceData[rollNumber] = currentStatus === 'present' ? 'absent' : 'present';
  
  renderAttendanceTable();
  updateAttendanceSummary();
}

// Update attendance summary
function updateAttendanceSummary() {
  const presentCount = document.getElementById('presentCount');
  const absentCount = document.getElementById('absentCount');
  const totalCount = document.getElementById('totalCount');

  const present = Object.values(attendanceData).filter(status => status === 'present').length;
  const absent = Object.values(attendanceData).filter(status => status === 'absent').length;
  const total = roster.length;

  if (presentCount) presentCount.textContent = present;
  if (absentCount) absentCount.textContent = absent;
  if (totalCount) totalCount.textContent = total;
}

// Mark all students as present
function markAllPresent() {
  if (!confirm('Mark all students as present for this date?')) {
    return;
  }
  
  roster.forEach(student => {
    attendanceData[student.roll_number] = 'present';
  });
  
  renderAttendanceTable();
  updateAttendanceSummary();
  showMsg('messageDisplay', 'All students marked as present.', false);
}

// Mark all students as absent
function markAllAbsent() {
  if (!confirm('Mark all students as absent for this date?')) {
    return;
  }
  
  roster.forEach(student => {
    attendanceData[student.roll_number] = 'absent';
  });
  
  renderAttendanceTable();
  updateAttendanceSummary();
  showMsg('messageDisplay', 'All students marked as absent.', false);
}

// Save attendance
async function saveAttendance() {
  const date = document.getElementById('attendanceDate').value;
  if (!date || !selectedClass) {
    showMsg('messageDisplay', 'Please select a date and class.', true);
    return;
  }

  try {
    showLoading('Saving attendance...');
    
    const attendanceRecords = Object.entries(attendanceData)
      .filter(([rollNumber, status]) => status)
      .map(([rollNumber, status]) => ({
        // Store roll_number in student_id field so attendance exists even if student hasn't signed up yet
        student_id: rollNumber,
        subject_id: null, // No longer using subject_id
        class_id: selectedClass.id, // Reference to professor_classes
        date: date,
        status: status,
        college: selectedClass.college,
        branch: selectedClass.branch,
        semester: selectedClass.semester,
        class_number: 1,
        subject_name: selectedClass.subject // Store subject name instead
      }));

    if (attendanceRecords.length === 0) {
      showMsg('messageDisplay', 'No attendance data to save.', true);
      hideLoading();
      return;
    }

    // Upsert attendance to avoid duplicates (using class_id instead of subject_id)
    const { error } = await window.supabaseClient
      .from('attendance')
      .upsert(attendanceRecords, { onConflict: 'student_id,class_id,date,class_number' });

    if (error) throw error;

    showMsg('messageDisplay', 'Attendance saved successfully!', false);
    hideLoading();
    
  } catch (error) {
    console.error('Error saving attendance:', error);
    showMsg('messageDisplay', 'Error saving attendance: ' + error.message, true);
    hideLoading();
  }
}

// Show add class form
function showAddClassForm() {
  console.log('showAddClassForm called'); // Debug log
  try {
    const modal = document.getElementById('addClassModal');
    if (modal) {
      modal.classList.remove('hidden');
      loadAddClassFormData();
      console.log('Modal opened successfully'); // Debug log
    } else {
      console.error('Modal not found');
    }
  } catch (error) {
    console.error('Error opening modal:', error);
  }
}

// Load add class form data
async function loadAddClassFormData() {
  try {
    // Set college name
    const modalName = document.getElementById('classCollegeName');
    if (modalName && assignedCollege.name) modalName.textContent = assignedCollege.name;

    // Load branches for assigned college
    const { data: branches } = await window.supabaseClient
      .from('branches')
      .select('id, name')
      .eq('college_id', assignedCollege.id)
      .order('name');

    const classBranch = document.getElementById('classBranch');
    if (classBranch && branches) {
      classBranch.innerHTML = '<option value="">Select Branch</option>' +
        branches.map(branch => `<option value="${branch.id}">${branch.name}</option>`).join('');
    }

    // Clear dependent selects
    const classSemester = document.getElementById('classSemester');
    if (classSemester) classSemester.innerHTML = '<option value="">Select Semester</option>';
    const classSubject = document.getElementById('classSubject');
    if (classSubject) classSubject.innerHTML = '<option value="">Select Subject</option>';

    // Bind submit handler once
    const form = document.getElementById('addClassForm');
    if (form && !form.dataset.bound) {
      form.addEventListener('submit', async (e) => {
        e.preventDefault();
        await createClass();
      });
      form.dataset.bound = 'true';
    }
  } catch (error) {
    console.error('Error loading add class form data:', error);
  }
}

// Load branches for add class form
async function loadBranches() {
  try {
    const { data: branches } = await window.supabaseClient
      .from('branches')
      .select('id, name')
      .eq('college_id', assignedCollege.id)
      .order('name');

    const classBranch = document.getElementById('classBranch');
    if (classBranch && branches) {
      classBranch.innerHTML = '<option value="">Select Branch</option>' +
        branches.map(branch => `<option value="${branch.id}">${branch.name}</option>`).join('');
    }
  } catch (error) {
    console.error('Error loading branches:', error);
  }
}

// Load semesters for add class form
async function loadSemesters() {
  const branchId = document.getElementById('classBranch').value;
  if (!branchId) return;

  try {
    const { data: semesters } = await window.supabaseClient
      .from('semesters')
      .select('id, name')
      .eq('branch_id', branchId)
      .order('name');

    const classSemester = document.getElementById('classSemester');
    if (classSemester && semesters) {
      classSemester.innerHTML = '<option value="">Select Semester</option>' +
        semesters.map(semester => `<option value="${semester.id}">${semester.name}</option>`).join('');
    }
  } catch (error) {
    console.error('Error loading semesters:', error);
  }
}

// Load subjects for add class form
async function loadSubjects() {
  const semesterId = document.getElementById('classSemester').value;
  if (!semesterId) return;

  try {
    const { data: subjects } = await window.supabaseClient
      .from('subjects')
      .select('id, name')
      .eq('semester_id', semesterId)
      .order('name');

    const classSubject = document.getElementById('classSubject');
    if (classSubject && subjects) {
      classSubject.innerHTML = '<option value="">Select Subject</option>' +
        subjects.map(subject => `<option value="${subject.id}">${subject.name}</option>`).join('');
    }
  } catch (error) {
    console.error('Error loading subjects:', error);
  }
}

// Create a new class
async function createClass() {
  const branchSelect = document.getElementById('classBranch');
  const semesterSelect = document.getElementById('classSemester');
  const subjectSelect = document.getElementById('classSubject');
  
  const branchId = branchSelect.value;
  const semesterId = semesterSelect.value;
  const subjectId = subjectSelect.value;

  if (!branchId || !semesterId || !subjectId) {
    showMsg('messageDisplay', 'Please select branch, semester, and subject.', true);
    return;
  }

  // Get the text values (names) instead of IDs
  const branchName = branchSelect.options[branchSelect.selectedIndex].text;
  const semesterName = semesterSelect.options[semesterSelect.selectedIndex].text;
  const subjectName = subjectSelect.options[subjectSelect.selectedIndex].text;

  try {
    showLoading('Creating class...');

    // Check if class already exists for this professor and subject
    const { data: existingClasses, error: checkError } = await window.supabaseClient
      .from('professor_classes')
      .select('id')
      .eq('professor_email', currentUser.email)
      .eq('subject_name', subjectName);

    if (checkError) throw checkError;

    if (existingClasses && existingClasses.length > 0) {
      showMsg('messageDisplay', 'You already have a class for this subject.', true);
      hideLoading();
      return;
    }

    // Create the class record with simplified data
    console.log('Current user email:', currentUser.email); // Debug log
    
    const classData = {
      professor_email: currentUser.email,
      class_name: subjectName, // Use subject name as class name
      subject_name: subjectName,
      college_name: assignedCollege.name,
      branch_name: branchName,
      semester_name: semesterName,
      created_at: new Date().toISOString()
    };
    console.log('Class data to insert:', classData); // Debug log

    // Insert the class record
    const { data: newClass, error: createError } = await window.supabaseClient
      .from('professor_classes')
      .insert([classData])
      .select()
      .single();

    if (createError) throw createError;

    showMsg('messageDisplay', 'Class created successfully!', false);
    
    // Clear cache and refresh the classes list
    clearClassesCache();
    await loadClasses(true); // Force refresh from database
    
    // Close modal and reset form
    closeModal('addClassModal');
    document.getElementById('addClassForm').reset();
    
    hideLoading();
    
  } catch (error) {
    console.error('Error creating class:', error);
    showMsg('messageDisplay', 'Error creating class: ' + error.message, true);
    hideLoading();
  }
}

// Show upload roster form
function showUploadRosterForm() {
  if (!selectedClass) {
    showMsg('messageDisplay', 'Please select a class first.', true);
    return;
  }
  
  document.getElementById('uploadRosterModal').classList.remove('hidden');
  
  // Bind upload form handler
  const uploadForm = document.getElementById('uploadRosterForm');
  if (uploadForm && !uploadForm.dataset.bound) {
    uploadForm.addEventListener('submit', async (e) => {
      e.preventDefault();
      await uploadRoster();
    });
    uploadForm.dataset.bound = 'true';
  }
}

// Upload roster from CSV file
async function uploadRoster() {
  const fileInput = document.getElementById('rosterFile');
  const overwriteCheckbox = document.getElementById('overwriteRoster');
  
  if (!fileInput.files || fileInput.files.length === 0) {
    showMsg('messageDisplay', 'Please select a file to upload.', true);
    return;
  }
  
  const file = fileInput.files[0];
  const overwrite = overwriteCheckbox.checked;
  
  try {
    showLoading('Uploading roster...');
    
    // Read file content
    const text = await file.text();
    const lines = text.split('\n').filter(line => line.trim());
    
    if (lines.length < 2) {
      throw new Error('File must contain at least a header row and one data row.');
    }
    
    // Parse CSV (simple parsing - assumes comma-separated)
    const headers = lines[0].split(',').map(h => h.trim().toLowerCase());
    const rollIndex = headers.findIndex(h => h.includes('roll') || h.includes('number'));
    const nameIndex = headers.findIndex(h => h.includes('name') || h.includes('student'));
    const emailIndex = headers.findIndex(h => h.includes('email') || h.includes('mail'));
    
    if (rollIndex === -1 || nameIndex === -1) {
      throw new Error('File must contain "Roll Number" and "Student Name" columns.');
    }
    
    // Parse student data
    const students = [];
    for (let i = 1; i < lines.length; i++) {
      const columns = lines[i].split(',').map(c => c.trim());
      if (columns.length >= Math.max(rollIndex, nameIndex) + 1) {
        const rollNumber = columns[rollIndex];
        const studentName = columns[nameIndex];
        const studentEmail = emailIndex >= 0 ? columns[emailIndex] : null;
        
        if (rollNumber && studentName) {
          students.push({
            roll_number: rollNumber,
            student_name: studentName,
            student_email: studentEmail || null,
            class_id: selectedClass.id,
            is_verified: false
          });
        }
      }
    }
    
    if (students.length === 0) {
      throw new Error('No valid student data found in file.');
    }
    
    // Clear existing roster if overwrite is selected
    if (overwrite) {
      const { error: deleteError } = await window.supabaseAdmin
        .from('class_rosters')
        .delete()
        .eq('class_id', selectedClass.id);
        
      if (deleteError) throw deleteError;
    }
    
    // Insert new students
    const { error: insertError } = await window.supabaseAdmin
      .from('class_rosters')
      .insert(students);
      
    if (insertError) throw insertError;
    
    showMsg('messageDisplay', `Successfully uploaded ${students.length} students!`, false);
    
    // Reload roster
    await loadRoster(selectedClass.id);
    
    // Close modal and reset form
    closeModal('uploadRosterModal');
    document.getElementById('uploadRosterForm').reset();
    
    hideLoading();
    
  } catch (error) {
    console.error('Error uploading roster:', error);
    showMsg('messageDisplay', 'Error uploading roster: ' + error.message, true);
    hideLoading();
  }
}

// Close modal
function closeModal(modalId) {
  document.getElementById(modalId).classList.add('hidden');
}

// Set default date to today
function setDefaultDate() {
  const today = new Date().toISOString().split('T')[0];
  const dateInput = document.getElementById('attendanceDate');
  if (dateInput) {
    dateInput.value = today;
  }
}

// Download roster
function downloadRoster() {
  if (roster.length === 0) {
    showMsg('messageDisplay', 'No roster data to download.', true);
    return;
  }

  const csvContent = [
    ['Roll Number', 'Student Name', 'Status'],
    ...roster.map(student => [
      student.roll_number,
      student.student_name,
      student.is_verified ? 'Verified' : 'Unverified'
    ])
  ].map(row => row.join(',')).join('\n');

  const blob = new Blob([csvContent], { type: 'text/csv' });
  const url = window.URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `${selectedClass.subject}_roster.csv`;
  a.click();
  window.URL.revokeObjectURL(url);
}

// Show message
function showMsg(id, msg, isError = false) {
  const el = document.getElementById(id);
  if (!el) return;
  
  el.textContent = msg;
  el.style.color = isError ? '#dc2626' : '#22c55e';
  el.style.fontWeight = isError ? '500' : '400';
  
  setTimeout(() => { 
    el.textContent = '';
    el.style.color = '';
    el.style.fontWeight = '';
  }, 3000);
}

// Show loading overlay
function showLoading(text = 'Loading...') {
  const overlay = document.getElementById('loadingOverlay');
  const loadingText = document.getElementById('loadingText');
  
  if (overlay) overlay.classList.remove('hidden');
  if (loadingText) loadingText.textContent = text;
}

// Hide loading overlay
function hideLoading() {
  const overlay = document.getElementById('loadingOverlay');
  if (overlay) overlay.classList.add('hidden');
}

// Mobile menu functions
function toggleMobileMenu() {
  console.log('Toggle mobile menu clicked');
  const container = document.getElementById('mobileNavContainer');
  const hamburger = document.querySelector('.hamburger-btn');
  
  if (container) {
    container.classList.toggle('active');
    if (hamburger) {
      hamburger.classList.toggle('active');
    }
    console.log('Mobile menu toggled, active:', container.classList.contains('active'));
  } else {
    console.error('Mobile nav container not found');
  }
}

function closeMobileMenu() {
  console.log('Close mobile menu called');
  const container = document.getElementById('mobileNavContainer');
  const hamburger = document.querySelector('.hamburger-btn');
  
  if (container) {
    container.classList.remove('active');
    if (hamburger) {
      hamburger.classList.remove('active');
    }
    console.log('Mobile menu closed');
  } else {
    console.error('Mobile nav container not found');
  }
}

// New Functions for Enhanced Class Management

// Open Question Entry for specific class
function openQuestionEntry(classId, subjectName, subjectId, collegeName, branchName, semesterName) {
  // Store complete class context in sessionStorage
  sessionStorage.setItem('selectedClassId', classId);
  sessionStorage.setItem('selectedSubjectName', subjectName);
  sessionStorage.setItem('selectedSubjectId', subjectId);
  sessionStorage.setItem('selectedCollegeName', collegeName);
  sessionStorage.setItem('selectedBranchName', branchName);
  sessionStorage.setItem('selectedSemesterName', semesterName);
  sessionStorage.setItem('questionEntryContext', 'class');
  
  // Redirect to question entry page with full context
  const params = new URLSearchParams({
    classId: classId,
    subject: subjectName,
    college: collegeName,
    branch: branchName,
    semester: semesterName
  });
  window.location.href = `question_entry.html?${params.toString()}`;
}

// Open Assigned Tests for specific class
function openAssignedTests(classId, subjectName, subjectId, collegeName, branchName, semesterName) {
  // Store complete class context in sessionStorage
  sessionStorage.setItem('selectedClassId', classId);
  sessionStorage.setItem('selectedSubjectName', subjectName);
  sessionStorage.setItem('selectedSubjectId', subjectId);
  sessionStorage.setItem('selectedCollegeName', collegeName);
  sessionStorage.setItem('selectedBranchName', branchName);
  sessionStorage.setItem('selectedSemesterName', semesterName);
  sessionStorage.setItem('assignedTestsContext', 'class');
  
  // Redirect to assigned tests page with full context
  const params = new URLSearchParams({
    classId: classId,
    subject: subjectName,
    college: collegeName,
    branch: branchName,
    semester: semesterName
  });
  window.location.href = `assigned_tests.html?${params.toString()}`;
}

// Open Assignment Marks for specific class
function openAssignmentMarks(classId, subjectName, collegeName, branchName, semesterName) {
  // Store complete class context in sessionStorage
  sessionStorage.setItem('selectedClassId', classId);
  sessionStorage.setItem('selectedSubjectName', subjectName);
  sessionStorage.setItem('selectedCollegeName', collegeName);
  sessionStorage.setItem('selectedBranchName', branchName);
  sessionStorage.setItem('selectedSemesterName', semesterName);
  
  // Navigate to assignment marks page
  window.location.href = `assignment_marks.html?classId=${classId}&subject=${encodeURIComponent(subjectName)}`;
}

// Open Midsem Marks for specific class
function openMidsemMarks(classId, subjectName, collegeName, branchName, semesterName) {
  // Store complete class context in sessionStorage
  sessionStorage.setItem('selectedClassId', classId);
  sessionStorage.setItem('selectedSubjectName', subjectName);
  sessionStorage.setItem('selectedCollegeName', collegeName);
  sessionStorage.setItem('selectedBranchName', branchName);
  sessionStorage.setItem('selectedSemesterName', semesterName);
  
  // Navigate to midsem marks page
  window.location.href = `midsem_marks.html?classId=${classId}&subject=${encodeURIComponent(subjectName)}`;
}

function openFeedbackAnalytics(classId, subjectName, subjectId, collegeName, branchName, semesterName) {
  // Store complete class context in sessionStorage for feedback analytics
  sessionStorage.setItem('feedbackClassId', classId);
  sessionStorage.setItem('feedbackSubjectName', subjectName);
  sessionStorage.setItem('feedbackSubjectId', subjectId);
  sessionStorage.setItem('feedbackCollegeName', collegeName);
  sessionStorage.setItem('feedbackBranchName', branchName);
  sessionStorage.setItem('feedbackSemesterName', semesterName);
  
  // Redirect to subject feedback analytics page
  const params = new URLSearchParams({
    classId: classId,
    subjectId: subjectId,
    subject: subjectName,
    college: collegeName,
    branch: branchName,
    semester: semesterName
  });
  window.location.href = `subject_feedback_analytics.html?${params.toString()}`;
}

// Logout function
function logout() {
  sessionStorage.removeItem('adminLoggedIn');
  sessionStorage.removeItem('redirecting');
  window.location.href = 'index.html';
}

// Delete mode functionality
let deleteMode = false;
let selectedClassesForDeletion = [];

function toggleDeleteMode() {
  // Open delete classes modal instead of toggling cards
  openDeleteClassesModal();
}

async function openDeleteClassesModal() {
  const modal = document.getElementById('deleteClassesModal');
  const deleteClassesList = document.getElementById('deleteClassesList');
  
  console.log('Opening delete modal with classes:', classes);
  
  // Reset selection
  selectedClassesForDeletion = [];
  updateDeleteButton();
  
  // Load current classes into the modal
  if (classes.length === 0) {
    deleteClassesList.innerHTML = `
      <div class="empty-state" style="text-align: center; padding: 2rem; color: #6b7280;">
        <p>No classes available to delete.</p>
      </div>
    `;
  } else {
    deleteClassesList.innerHTML = classes.map(classItem => {
      console.log('Creating delete item for class:', classItem);
      return `
        <div class="delete-class-item" data-class-id="${classItem.id}">
          <input type="checkbox" class="delete-class-checkbox" 
                 id="delete-${classItem.id}" 
                 onchange="toggleClassSelection('${classItem.id}')">
          <div class="delete-class-info">
            <div class="delete-class-name">${classItem.subject || classItem.name}</div>
            <div class="delete-class-details">
              ${classItem.college} → ${classItem.branch} → ${classItem.semester}
            </div>
          </div>
        </div>
      `;
    }).join('');
  }
  
  modal.classList.remove('hidden');
}

function closeDeleteModal() {
  const modal = document.getElementById('deleteClassesModal');
  modal.classList.add('hidden');
  selectedClassesForDeletion = [];
}

function toggleClassSelection(classId) {
  console.log('Toggling selection for class:', classId);
  
  const checkbox = document.getElementById(`delete-${classId}`);
  const classItem = document.querySelector(`[data-class-id="${classId}"]`);
  
  if (checkbox.checked) {
    selectedClassesForDeletion.push(classId);
    classItem.classList.add('selected');
    console.log('Added class to selection:', classId);
  } else {
    selectedClassesForDeletion = selectedClassesForDeletion.filter(id => id !== classId);
    classItem.classList.remove('selected');
    console.log('Removed class from selection:', classId);
  }
  
  console.log('Current selection:', selectedClassesForDeletion);
  updateDeleteButton();
}

function updateDeleteButton() {
  const deleteBtn = document.getElementById('deleteSelectedBtn');
  const count = selectedClassesForDeletion.length;
  
  deleteBtn.disabled = count === 0;
  deleteBtn.textContent = count === 0 
    ? '🗑️ Delete Selected Classes' 
    : `🗑️ Delete ${count} Selected Class${count > 1 ? 'es' : ''}`;
}

async function confirmDeleteSelectedClasses() {
  console.log('Starting deletion process for classes:', selectedClassesForDeletion);
  
  if (selectedClassesForDeletion.length === 0) {
    console.log('No classes selected for deletion');
    showMsg('messageDisplay', 'Please select at least one class to delete', true);
    return;
  }

  // Create a copy of the selection BEFORE closing modal (which clears the array)
  const classesToDelete = [...selectedClassesForDeletion];
  console.log('Classes to delete (copy):', classesToDelete);

  const classNames = classesToDelete.map(classId => {
    const classItem = classes.find(c => c.id === classId);
    return classItem ? (classItem.subject || classItem.name) : classId;
  });

  console.log('Class names to delete:', classNames);

  const confirmMessage = `Are you sure you want to delete ${classesToDelete.length} class${classesToDelete.length > 1 ? 'es' : ''}?\n\nClasses to delete:\n${classNames.map(name => `• ${name}`).join('\n')}\n\nThis will permanently remove:\n- Class information\n- All attendance records\n- Class rosters\n- Assignment marks\n- All related data\n\nThis action cannot be undone!`;

  if (!confirm(confirmMessage)) {
    console.log('User cancelled deletion');
    return;
  }

  // Now close the modal (this will clear selectedClassesForDeletion, but we have our copy)
  closeDeleteModal();
  showLoading(`Deleting ${classesToDelete.length} class${classesToDelete.length > 1 ? 'es' : ''} and all related data...`);

  try {
    let successCount = 0;
    let errorCount = 0;
    const errors = [];

    console.log(`Starting to delete ${classesToDelete.length} classes`);

    for (let i = 0; i < classesToDelete.length; i++) {
      const classId = classesToDelete[i];
      console.log(`Processing deletion ${i + 1}/${classesToDelete.length} for class ID: ${classId}`);
      
      try {
        console.log(`About to call deleteClassData for: ${classId}`);
        await deleteClassData(classId);
        successCount++;
        console.log(`Successfully deleted class: ${classId}`);
      } catch (error) {
        errorCount++;
        const className = classNames[i];
        errors.push(`${className}: ${error.message}`);
        console.error(`Error deleting class ${classId}:`, error);
      }
    }

    console.log(`Loop completed. Processing ${classesToDelete.length} classes resulted in ${successCount} successes and ${errorCount} errors`);

    hideLoading();

    console.log(`Deletion complete. Success: ${successCount}, Errors: ${errorCount}`);

    if (errorCount === 0) {
      showMsg('messageDisplay', `Successfully deleted ${successCount} class${successCount > 1 ? 'es' : ''} and all related data!`, false);
    } else {
      showMsg('messageDisplay', `Deleted ${successCount} class${successCount > 1 ? 'es' : ''} successfully. ${errorCount} failed: ${errors.join(', ')}`, true);
    }

    // Clear cache and refresh the classes list
    console.log('Clearing cache and refreshing classes list...');
    clearClassesCache();
    await loadClasses(true); // Force refresh from database

  } catch (error) {
    hideLoading();
    console.error('Error in batch deletion:', error);
    showMsg('messageDisplay', `Error deleting classes: ${error.message}`, true);
  }
}

async function deleteClassData(classId) {
  console.log(`Starting deletion for class ID: ${classId}`);
  
  // Test if Supabase client is working
  if (!window.supabaseClient) {
    throw new Error('Supabase client is not initialized');
  }
  console.log('Supabase client is available');
  
  // Test connection by trying to select the class first
  console.log('Testing database connection and checking if class exists...');
  const { data: existingClass, error: selectError } = await window.supabaseClient
    .from('professor_classes')
    .select('*')
    .eq('id', classId);
  
  if (selectError) {
    console.error('Error checking class existence:', selectError);
    throw new Error(`Cannot connect to database: ${selectError.message}`);
  }
  
  if (!existingClass || existingClass.length === 0) {
    console.error('Class not found with ID:', classId);
    throw new Error(`Class with ID ${classId} not found in database`);
  }
  
  console.log('Class found in database:', existingClass[0]);
  
  // Start transaction-like deletions
  const errors = [];

  try {
    // 1. Delete from class_assignment_marks
    console.log('Deleting class assignment marks...');
    const { error: assignmentError } = await window.supabaseClient
      .from('class_assignment_marks')
      .delete()
      .eq('class_id', classId);
    
    if (assignmentError) {
      if (assignmentError.code === '42P01') {
        console.log('Class assignment marks table does not exist - skipping');
      } else {
        errors.push(`Class assignment marks: ${assignmentError.message}`);
        console.error('Error deleting class assignment marks:', assignmentError);
      }
    } else {
      console.log('Class assignment marks deleted successfully');
    }

    // 2. Delete from class_rosters
    console.log('Deleting class roster...');
    const { error: rosterError } = await window.supabaseClient
      .from('class_rosters')
      .delete()
      .eq('class_id', classId);
    
    if (rosterError) {
      if (rosterError.code === '42P01') {
        console.log('Class rosters table does not exist - skipping');
      } else {
        errors.push(`Class roster: ${rosterError.message}`);
        console.error('Error deleting class roster:', rosterError);
      }
    } else {
      console.log('Class roster deleted successfully');
    }

    // 3. Delete from professor_attendance (legacy attendance table)
    console.log('Deleting professor attendance...');
    const { error: profAttendanceError } = await window.supabaseClient
      .from('professor_attendance')
      .delete()
      .eq('class_id', classId);
    
    if (profAttendanceError) {
      if (profAttendanceError.code === '42P01') {
        console.log('Professor attendance table does not exist - skipping');
      } else {
        console.warn('Professor attendance deletion warning:', profAttendanceError);
      }
    } else {
      console.log('Professor attendance deleted successfully');
    }

    // 4. Delete from class_attendance_sessions (new optimized attendance table)
    console.log('Deleting class attendance sessions...');
    const { error: sessionsError } = await window.supabaseClient
      .from('class_attendance_sessions')
      .delete()
      .eq('class_id', classId);
    
    if (sessionsError) {
      if (sessionsError.code === '42P01') {
        console.log('Class attendance sessions table does not exist - skipping');
      } else {
        console.warn('Class attendance sessions deletion warning:', sessionsError);
      }
    } else {
      console.log('Class attendance sessions deleted successfully');
    }

    // 5. Delete midsem marks (separate from regular assignment marks)
    console.log('Deleting midsem marks...');
    const { error: midsemError } = await window.supabaseClient
      .from('class_assignment_marks')
      .delete()
      .eq('class_id', classId)
      .like('assignment_name', 'Midsem:%');
    
    if (midsemError) {
      if (midsemError.code === '42P01') {
        console.log('Midsem marks table does not exist - skipping');
      } else {
        console.warn('Midsem marks deletion warning:', midsemError);
      }
    } else {
      console.log('Midsem marks deleted successfully');
    }

    // 6. Delete assigned tests from Questions database
    console.log('Deleting assigned tests...');
    try {
      // Initialize Questions Supabase client if not already done
      const SUPABASE_QUESTIONS_URL = 'https://pfuzvpihupvhjshxiofn.supabase.co';
      const SUPABASE_QUESTIONS_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBmdXp2cGlodXB2aGpzaHhpb2ZuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE1Mjg1MjIsImV4cCI6MjA2NzEwNDUyMn0.WAPJG6iaxuCAM75yCRu6UOcck37XuilVoDJK3uwyx-k';
      
      if (!window.supabaseQuestions) {
        window.supabaseQuestions = window.supabase.createClient(SUPABASE_QUESTIONS_URL, SUPABASE_QUESTIONS_KEY, {
          auth: { storageKey: 'supabase.questions.temp' }
        });
      }

      const { error: testsError } = await window.supabaseQuestions
        .from('assigned_tests')
        .delete()
        .eq('class_id', classId);
      
      if (testsError) {
        if (testsError.code === '42P01') {
          console.log('Assigned tests table does not exist - skipping');
        } else {
          console.warn('Assigned tests deletion warning:', testsError);
        }
      } else {
        console.log('Assigned tests deleted successfully');
      }
    } catch (testsError) {
      console.warn('Could not delete assigned tests:', testsError.message);
    }

    // 7. Delete feedback data
    console.log('Deleting feedback data...');
    const { error: feedbackError } = await window.supabaseClient
      .from('class_feedback')
      .delete()
      .eq('class_id', classId);
    
    if (feedbackError) {
      if (feedbackError.code === '42P01') {
        console.log('Class feedback table does not exist - skipping');
      } else {
        console.warn('Class feedback deletion warning:', feedbackError);
      }
    } else {
      console.log('Class feedback deleted successfully');
    }

    // 8. Finally, delete the main class record
    console.log('Deleting main class record...');
    const { error: classError, data: deletedData } = await window.supabaseClient
      .from('professor_classes')
      .delete()
      .eq('id', classId)
      .select(); // Add select to see what was deleted
    
    console.log('Delete operation result:', { error: classError, deletedData });
    
    if (classError) {
      errors.push(`Main class record: ${classError.message}`);
      console.error('Error deleting main class:', classError);
      throw new Error(`Failed to delete main class record: ${classError.message}`);
    }

    if (!deletedData || deletedData.length === 0) {
      console.warn('No rows were deleted. Class might not exist or ID might be wrong.');
      throw new Error(`No class found with ID: ${classId}`);
    }

    console.log(`Successfully deleted class record:`, deletedData);

    if (errors.length > 0) {
      console.warn('Some related data could not be deleted (but class was removed):', errors);
      // Don't throw error here - the main class was deleted successfully
      // Just log the warnings about optional tables
    }

    console.log(`Class ${classId} deleted successfully`);
    
  } catch (error) {
    console.error(`Error in deleteClassData for class ${classId}:`, error);
    throw error;
  }
}

function handleClassCardClick(event, classElement) {
  // Normal click behavior - open attendance tracker
  const classId = classElement.dataset.classId;
  if (classId) {
    openAttendanceTracker(classId);
  }
}

// Show loading overlay
function showLoading(text = 'Loading...') {
  const overlay = document.getElementById('loadingOverlay');
  const loadingText = document.getElementById('loadingText');
  
  if (overlay) overlay.classList.remove('hidden');
  if (loadingText) loadingText.textContent = text;
}

// Hide loading overlay
function hideLoading() {
  const overlay = document.getElementById('loadingOverlay');
  if (overlay) overlay.classList.add('hidden');
}
