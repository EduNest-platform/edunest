// Attendance Tracker System
let currentUser = null;
let selectedClass = null;
let roster = [];
let attendanceData = {};
let autoSaveTimer = null;
let hasUnsavedChanges = false;

// Initialize the attendance tracker
document.addEventListener('DOMContentLoaded', async function() {
  console.log('Attendance Tracker - Starting initialization...');
  
  try {
    await checkAuthStatus();
    await loadUserInfo();
    
    // Only proceed if we have a user
    if (currentUser) {
      await loadClassFromURL();
      await loadRoster();
      setDefaultDate();
      setupBeforeUnloadHandler();
      setupDateValidation();
    }
  } catch (error) {
    console.error('Attendance Tracker - Initialization error:', error);
    showMsg('messageDisplay', 'Error initializing attendance tracker: ' + error.message, true);
  }
});

// Setup date validation and persistence
function setupDateValidation() {
  const dateInput = document.getElementById('attendanceDate');
  if (dateInput) {
    // Ensure date is set when input is focused and empty
    dateInput.addEventListener('focus', ensureDateIsSet);
    
    // Ensure date is set when input loses focus and is empty
    dateInput.addEventListener('blur', ensureDateIsSet);
    
    // Handle manual clearing of date
    dateInput.addEventListener('input', function() {
      if (!this.value) {
        console.log('Date input cleared - will reset to today');
        setTimeout(() => {
          if (!this.value) {
            setDefaultDate();
          }
        }, 500); // Small delay to allow user to type
      }
    });
  }
  
  // Check date periodically to ensure it's always set
  setInterval(ensureDateIsSet, 5000); // Check every 5 seconds
}

// Setup beforeunload handler to auto-save when navigating away
function setupBeforeUnloadHandler() {
  window.addEventListener('beforeunload', async function(event) {
    if (hasUnsavedChanges) {
      console.log('Page unloading with unsaved changes - attempting auto-save...');
      
      // Try to auto-save immediately
      try {
        await autoSaveAttendance();
        console.log('Auto-save completed before page unload');
      } catch (error) {
        console.error('Failed to auto-save before page unload:', error);
        
        // Show browser confirmation dialog
        event.preventDefault();
        event.returnValue = 'You have unsaved attendance changes. Are you sure you want to leave?';
        return 'You have unsaved attendance changes. Are you sure you want to leave?';
      }
    }
  });
  
  // Also handle visibility change (when tab becomes hidden)
  document.addEventListener('visibilitychange', async function() {
    if (document.hidden && hasUnsavedChanges) {
      console.log('Tab hidden with unsaved changes - attempting auto-save...');
      try {
        await autoSaveAttendance();
        console.log('Auto-save completed when tab hidden');
      } catch (error) {
        console.error('Failed to auto-save when tab hidden:', error);
      }
    }
  });
}

// Check authentication status
async function checkAuthStatus() {
  const isLoggedIn = sessionStorage.getItem('adminLoggedIn') === 'true';
  console.log('Attendance Tracker - Auth check:', { isLoggedIn, sessionStorage: sessionStorage.getItem('adminLoggedIn') });
  
  if (!isLoggedIn) {
    console.log('Attendance Tracker - Not logged in, redirecting to login');
    window.location.href = 'index.html';
    return;
  }
  console.log('Attendance Tracker - Auth check passed');
}

// Load user information
async function loadUserInfo() {
  try {
    console.log('Attendance Tracker - Loading user info...');
    console.log('Attendance Tracker - Supabase clients available:', { 
      supabaseAdmin: !!window.supabaseAdmin, 
      supabaseClient: !!window.supabaseClient 
    });
    
    const { data: { user } } = await window.supabaseAdmin.auth.getUser();
    console.log('Attendance Tracker - User data:', user);
    
    if (!user) {
      console.log('Attendance Tracker - No user found, redirecting to login');
      window.location.href = 'index.html';
      return;
    }
    currentUser = user;
    console.log('Attendance Tracker - User loaded successfully:', currentUser.email);
  } catch (error) {
    console.error('Attendance Tracker - Error loading user info:', error);
    window.location.href = 'index.html';
  }
}

// Load class information from URL parameters
async function loadClassFromURL() {
  const urlParams = new URLSearchParams(window.location.search);
  const classId = urlParams.get('classId');
  
  console.log('Attendance Tracker - Loading class from URL:', { classId, currentUser: currentUser?.email });
  
  if (!classId) {
    console.log('Attendance Tracker - No classId found in URL');
    showMsg('messageDisplay', 'No class selected. Redirecting...', true);
    setTimeout(() => {
      window.location.href = 'attendance.html';
    }, 2000);
    return;
  }
  
  try {
    showLoading('Loading class information...');
    
    // Get class details
    const { data: classData, error } = await window.supabaseClient
      .from('professor_classes')
      .select('*')
      .eq('id', classId)
      .eq('professor_email', currentUser.email)
      .single();
    
    if (error) throw error;
    
    if (!classData) {
      throw new Error('Class not found or access denied.');
    }
    
    selectedClass = {
      id: classData.id,
      name: classData.subject_name,
      className: classData.class_name,
      subject: classData.subject_name,
      college: classData.college_name,
      branch: classData.branch_name,
      semester: classData.semester_name,
      professorEmail: classData.professor_email
    };
    
    updateClassHeader();
    hideLoading();
    
  } catch (error) {
    console.error('Attendance Tracker - Error loading class:', error);
    showMsg('messageDisplay', 'Error loading class: ' + error.message, true);
    hideLoading();
    // Don't redirect immediately, let user see the error
    // setTimeout(() => {
    //   window.location.href = 'attendance.html';
    // }, 3000);
  }
}

// Update class header with information
function updateClassHeader() {
  if (!selectedClass) return;
  
  const classTitle = document.getElementById('classTitle');
  const classInfo = document.getElementById('classInfo');
  
  if (classTitle) {
    classTitle.textContent = `📚 ${selectedClass.subject}`;
  }
  
  if (classInfo) {
    classInfo.innerHTML = `
      <div class="info-card">
        <h4>🏫 College</h4>
        <p>${selectedClass.college || 'N/A'}</p>
      </div>
      <div class="info-card">
        <h4>🏢 Branch</h4>
        <p>${selectedClass.branch || 'N/A'}</p>
      </div>
      <div class="info-card">
        <h4>📚 Semester</h4>
        <p>${selectedClass.semester || 'N/A'}</p>
      </div>
      <div class="info-card">
        <h4>👨‍🏫 Professor</h4>
        <p>${selectedClass.professorEmail}</p>
      </div>
    `;
  }
}

// Load roster for the class
async function loadRoster() {
  if (!selectedClass) return;
  
  try {
    showTableLoading('Loading Students');
    
    // Load from class_rosters table using supabaseClient
    const { data: rosterData, error } = await window.supabaseClient
      .from('class_rosters')
      .select('id, roll_number, student_name, student_email, is_verified, student_profile_id')
      .eq('class_id', selectedClass.id)
      .order('roll_number');

    if (error) throw error;

    roster = (rosterData || []).map(s => ({
      id: s.id,
      roll_number: s.roll_number,
      student_name: s.student_name,
      student_email: s.student_email,
      is_verified: !!s.is_verified,
      has_app_account: !!s.student_profile_id
    }));
    
    // Sort roster by roll number (handle formats like 401/23, 402/23)
    roster.sort((a, b) => {
      const rollA = a.roll_number.toString();
      const rollB = b.roll_number.toString();
      
      // Extract numeric parts for proper sorting
      const numA = parseInt(rollA.replace(/\D/g, '')) || 0;
      const numB = parseInt(rollB.replace(/\D/g, '')) || 0;
      
      return numA - numB;
    });
    
    renderRosterTable();
    updateAttendanceStats();
    
  } catch (error) {
    console.error('Error loading roster:', error);
    showMsg('messageDisplay', 'Error loading roster: ' + error.message, true);
    
    // Show error state in table
    const tableBody = document.getElementById('attendanceTableBody');
    if (tableBody) {
      tableBody.innerHTML = `
        <tr>
          <td colspan="4" class="empty-state">
            <div>
              <h3>❌ Error Loading Students</h3>
              <p>Failed to load class roster. Please try refreshing the page.</p>
            </div>
          </td>
        </tr>
      `;
    }
  }
}

// Load attendance data for selected date
async function loadAttendanceData() {
  const date = document.getElementById('attendanceDate').value;
  if (!date || !selectedClass) return;

  try {
    showLoading('Loading attendance data...');
    
    // Load attendance from the new professor_attendance table
    const { data: attendanceRecords, error } = await window.supabaseClient
      .from('professor_attendance')
      .select('*')
      .eq('class_id', selectedClass.id)
      .eq('date', date);

    if (error) throw error;

    // Initialize attendance data
    attendanceData = {};
    roster.forEach(student => {
      const record = (attendanceRecords || []).find(r => r.student_roll_number === student.roll_number);
      attendanceData[student.roll_number] = record ? record.status : null;
    });

    renderRosterTable();
    updateAttendanceStats();
    hideLoading();
    
  } catch (error) {
    console.error('Error loading attendance data:', error);
    showMsg('messageDisplay', 'Error loading attendance data: ' + error.message, true);
    hideLoading();
  }
}

// Show loading state in table
function showTableLoading(message = 'Loading...') {
  const tableBody = document.getElementById('attendanceTableBody');
  if (!tableBody) return;
  
  tableBody.innerHTML = `
    <tr>
      <td colspan="4" class="empty-state">
        <div>
          <div class="loading-spinner" style="margin: 0 auto 1rem; width: 32px; height: 32px; border: 3px solid #f3f4f6; border-top: 3px solid #667eea; border-radius: 50%; animation: spin 1s linear infinite;"></div>
          <h3>📚 ${message}</h3>
          <p>Please wait...</p>
        </div>
      </td>
    </tr>
  `;
}

// Render roster table with attendance toggles
function renderRosterTable() {
  const tableBody = document.getElementById('attendanceTableBody');
  if (!tableBody) return;

  if (roster.length === 0) {
    tableBody.innerHTML = `
      <tr>
        <td colspan="4" class="empty-state">
          <div>
            <h3>📚 No Students Found</h3>
            <p>No students in the class roster. Please <a href="manage_students.html?classId=${selectedClass?.id}" style="color: #667eea; text-decoration: underline;">manage students</a> to add them.</p>
          </div>
        </td>
      </tr>
    `;
    return;
  }

  tableBody.innerHTML = roster.map(student => {
    const status = attendanceData[student.roll_number];
    const isPresent = status === 'present';
    
    return `
      <tr>
        <td><strong>${student.roll_number}</strong></td>
        <td>
          <div class="student-info">
            <div class="student-name">${student.student_name}</div>
            ${student.student_email ? `<div class="student-email mobile-hidden">${student.student_email}</div>` : ''}
          </div>
        </td>
        <td>
          <div class="attendance-toggle">
            <div class="toggle-switch ${isPresent ? 'active' : ''}" 
                 onclick="toggleAttendance('${student.roll_number}')">
              <div class="toggle-slider"></div>
            </div>
            <span class="status-text ${isPresent ? 'status-present' : 'status-absent'}">
              ${isPresent ? 'Present' : 'Absent'}
            </span>
          </div>
        </td>
        <td>${status ? 'Today' : 'Not marked'}</td>
      </tr>
    `;
  }).join('');
}

// Toggle attendance for a student
function toggleAttendance(rollNumber) {
  const currentStatus = attendanceData[rollNumber];
  const newStatus = currentStatus === 'present' ? 'absent' : 'present';
  
  // Only proceed if there's an actual change
  if (currentStatus !== newStatus) {
    attendanceData[rollNumber] = newStatus;
    
    renderRosterTable();
    updateAttendanceStats();
    
    // Mark as having unsaved changes and start auto-save timer
    hasUnsavedChanges = true;
    startAutoSaveTimer();
  }
}

// Start auto-save timer (10 seconds)
function startAutoSaveTimer() {
  // Clear existing timer
  if (autoSaveTimer) {
    clearTimeout(autoSaveTimer);
  }
  
  // Show auto-save indicator
  showAutoSaveIndicator();
  
  // Set new timer for 10 seconds
  autoSaveTimer = setTimeout(async () => {
    if (hasUnsavedChanges) {
      console.log('Auto-saving attendance after 10 seconds of inactivity...');
      await autoSaveAttendance();
    }
  }, 10000); // 10 seconds
}

// Auto-save attendance (silent save)
async function autoSaveAttendance() {
  if (!hasUnsavedChanges) return;
  
  try {
    const date = document.getElementById('attendanceDate').value;
    if (!date || !selectedClass) {
      console.log('Auto-save skipped: missing date or class');
      return;
    }

    // Check if there are any attendance records marked (not null)
    const hasMarkedAttendance = Object.values(attendanceData).some(status => status !== null);
    if (!hasMarkedAttendance) {
      console.log('Auto-save skipped: no attendance marked yet');
      hasUnsavedChanges = false;
      hideAutoSaveIndicator();
      return;
    }

    // Show subtle auto-save indicator
    showMsg('messageDisplay', '💾 Auto-saving attendance...', false, 2000);
    
    // Only include students with marked attendance
    const attendanceRecords = roster
      .filter(student => attendanceData[student.roll_number] !== null)
      .map(student => ({
        class_id: selectedClass.id,
        student_roll_number: student.roll_number,
        student_name: student.student_name,
        date: date,
        status: attendanceData[student.roll_number],
        subject_name: selectedClass.subject,
        college_name: selectedClass.college,
        branch_name: selectedClass.branch,
        semester_name: selectedClass.semester,
        class_number: 1
      }));

    if (attendanceRecords.length === 0) {
      console.log('Auto-save skipped: no records to save');
      hasUnsavedChanges = false;
      hideAutoSaveIndicator();
      return;
    }

    // Delete existing records for this date and class
    const { error: deleteError } = await window.supabaseClient
      .from('professor_attendance')
      .delete()
      .eq('class_id', selectedClass.id)
      .eq('date', date);

    if (deleteError) {
      console.warn('Auto-save: Error deleting existing records:', deleteError);
    }

    // Insert new records
    const { error: insertError } = await window.supabaseClient
      .from('professor_attendance')
      .insert(attendanceRecords);

    if (insertError) {
      console.error('Auto-save failed:', insertError);
      showMsg('messageDisplay', '⚠️ Auto-save failed. Please save manually.', true, 3000);
      return;
    }

    hasUnsavedChanges = false;
    hideAutoSaveIndicator();
    showMsg('messageDisplay', '✅ Attendance auto-saved successfully', false, 2000);
    console.log('Auto-save completed successfully');

  } catch (error) {
    console.error('Auto-save error:', error);
    showMsg('messageDisplay', '⚠️ Auto-save error. Please save manually.', true, 3000);
  }
}

// Show auto-save indicator
function showAutoSaveIndicator() {
  const saveButton = document.querySelector('.save-btn');
  if (saveButton) {
    saveButton.style.background = 'linear-gradient(135deg, #f59e0b 0%, #d97706 100%)';
    saveButton.innerHTML = '<span class="btn-icon">⏱️</span>Auto-saving in 10s...';
  }
}

// Hide auto-save indicator
function hideAutoSaveIndicator() {
  const saveButton = document.querySelector('.save-btn');
  if (saveButton) {
    saveButton.style.background = 'linear-gradient(135deg, #10b981 0%, #059669 100%)';
    saveButton.innerHTML = '<span class="btn-icon">💾</span>Save Attendance';
  }
}

// Update attendance statistics
function updateAttendanceStats() {
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
  
  renderRosterTable();
  updateAttendanceStats();
  
  // Mark as having unsaved changes and start auto-save timer
  hasUnsavedChanges = true;
  startAutoSaveTimer();
  
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
  
  renderRosterTable();
  updateAttendanceStats();
  
  // Mark as having unsaved changes and start auto-save timer
  hasUnsavedChanges = true;
  startAutoSaveTimer();
  
  showMsg('messageDisplay', 'All students marked as absent.', false);
}

// Open student management page
function openStudentManagement() {
  console.log('openStudentManagement clicked', { selectedClass });
  
  if (!selectedClass) {
    console.error('No class selected for student management');
    showMsg('messageDisplay', 'No class selected.', true);
    return;
  }
  
  console.log('Opening student management for class:', selectedClass.id);
  
  // Test if we can access the page first
  const url = `manage_students.html?classId=${selectedClass.id}`;
  console.log('Navigating to:', url);
  
  // Show a loading message
  showMsg('messageDisplay', 'Opening student management...', false);
  
  // Navigate to student management page
  setTimeout(() => {
    window.location.href = url;
  }, 100);
}

// Manage students (add/remove students from class) - v2.0
function manageStudents() {
  // Call the new function
  openStudentManagement();
}

// Save attendance data
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
      .map(([rollNumber, status]) => {
        // Find the student name from roster
        const student = roster.find(s => s.roll_number === rollNumber);
        return {
          class_id: selectedClass.id,
          student_roll_number: rollNumber,
          student_name: student ? student.student_name : 'Unknown Student',
          date: date,
          status: status,
          subject_name: selectedClass.subject,
          college_name: selectedClass.college,
          branch_name: selectedClass.branch,
          semester_name: selectedClass.semester,
          class_number: 1
        };
      });

    if (attendanceRecords.length === 0) {
      showMsg('messageDisplay', 'No attendance data to save.', true);
      hideLoading();
      return;
    }

    // Save to the new professor_attendance table
    const { error } = await window.supabaseClient
      .from('professor_attendance')
      .upsert(attendanceRecords, { onConflict: 'class_id,student_roll_number,date,class_number' });

    if (error) throw error;

    if (error) throw error;

    showMsg('messageDisplay', 'Attendance saved successfully!', false);
    hideLoading();
    
  } catch (error) {
    console.error('Error saving attendance:', error);
    showMsg('messageDisplay', 'Error saving attendance: ' + error.message, true);
    hideLoading();
  }
}

// Set default date to today
function setDefaultDate() {
  const today = new Date().toISOString().split('T')[0];
  const dateInput = document.getElementById('attendanceDate');
  
  if (dateInput) {
    dateInput.value = today;
    console.log('Default date set to:', today);
    loadAttendanceData();
  } else {
    console.warn('Date input element not found - retrying in 100ms');
    // Retry after DOM is fully loaded
    setTimeout(setDefaultDate, 100);
  }
}

// Ensure date is always set when needed
function ensureDateIsSet() {
  const dateInput = document.getElementById('attendanceDate');
  if (dateInput && !dateInput.value) {
    console.log('Date input found empty - setting default date');
    setDefaultDate();
  }
}

// Show message
function showMsg(id, msg, isError = false, duration = 3000) {
  const el = document.getElementById(id);
  if (!el) return;
  
  el.textContent = msg;
  el.style.color = isError ? '#dc2626' : '#22c55e';
  el.style.fontWeight = isError ? '500' : '400';
  
  setTimeout(() => { 
    el.textContent = '';
    el.style.color = '';
    el.style.fontWeight = '';
  }, duration);
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

// View Analytics function
function viewAnalytics() {
  if (!selectedClass || !selectedClass.id) {
    showMsg('messageDisplay', 'No class selected for analytics', true);
    return;
  }
  
  // Navigate to attendance analytics page with class ID
  const analyticsUrl = `attendance_analytics.html?classId=${encodeURIComponent(selectedClass.id)}&className=${encodeURIComponent(selectedClass.subject_name || 'Class')}`;
  window.location.href = analyticsUrl;
}