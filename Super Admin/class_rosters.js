// Super Admin Class Rosters Management System
let allClasses = [];
let filteredClasses = [];
let currentClass = null;
let currentStudents = [];

// Initialize the application
document.addEventListener('DOMContentLoaded', async function() {
  console.log('Super Admin Class Rosters - Starting initialization...');
  
  try {
    await checkAuthStatus();
    await loadInitialData();
    setupEventListeners();
  } catch (error) {
    console.error('Initialization error:', error);
    showMessage('Error initializing class rosters management: ' + error.message, true);
  }
});

// Check authentication status
async function checkAuthStatus() {
  try {
    const { data: { user } } = await window.supabaseAdmin.auth.getUser();
    if (!user) {
      window.location.href = 'index.html';
      return;
    }
    console.log('Super Admin authenticated:', user.email);
  } catch (error) {
    console.error('Auth check failed:', error);
    window.location.href = 'index.html';
  }
}

// Load initial data
async function loadInitialData() {
  showLoading('Loading class data...');
  
  try {
    // Load all classes with student counts
    await loadAllClasses();
    
    // Load filter options
    await loadFilterOptions();
    
    // Apply initial filtering
    applyFilters();
    
    // Update statistics
    updateStatistics();
    
    hideLoading();
  } catch (error) {
    console.error('Error loading initial data:', error);
    showMessage('Error loading data: ' + error.message, true);
    hideLoading();
  }
}

// Load all classes from professor_classes table
async function loadAllClasses() {
  try {
    console.log('Loading all classes...');
    
    // Get all professor classes (use supabaseClient since professor_classes is in the main database)
    const { data: classes, error: classesError } = await window.supabaseClient
      .from('professor_classes')
      .select('*')
      .order('created_at', { ascending: false });
    
    if (classesError) throw classesError;
    
    // Get student counts for each class
    const classesWithCounts = await Promise.all((classes || []).map(async (classItem) => {
      try {
        // Get total students count (use supabaseClient if class_rosters is in main database)
        const { count: totalStudents, error: countError } = await window.supabaseClient
          .from('class_rosters')
          .select('id', { count: 'exact' })
          .eq('class_id', classItem.id);
        
        if (countError) {
          console.warn('Error getting student count for class', classItem.id, countError);
        }
        
        // Get connected students count
        const { count: connectedStudents, error: connectedError } = await window.supabaseClient
          .from('class_rosters')
          .select('id', { count: 'exact' })
          .eq('class_id', classItem.id)
          .not('student_profile_id', 'is', null);
        
        if (connectedError) {
          console.warn('Error getting connected student count for class', classItem.id, connectedError);
        }
        
        return {
          ...classItem,
          totalStudents: totalStudents || 0,
          connectedStudents: connectedStudents || 0,
          unconnectedStudents: (totalStudents || 0) - (connectedStudents || 0)
        };
      } catch (error) {
        console.warn('Error processing class', classItem.id, error);
        return {
          ...classItem,
          totalStudents: 0,
          connectedStudents: 0,
          unconnectedStudents: 0
        };
      }
    }));
    
    allClasses = classesWithCounts;
    filteredClasses = [...allClasses];
    
    console.log('Loaded', allClasses.length, 'classes');
  } catch (error) {
    console.error('Error loading classes:', error);
    throw error;
  }
}

// Load filter options
async function loadFilterOptions() {
  try {
    console.log('Loading filter options from', allClasses.length, 'classes');
    
    // Get unique professors
    const professors = [...new Set(allClasses.map(c => c.professor_email).filter(Boolean))];
    const professorFilter = document.getElementById('professorFilter');
    if (professorFilter) {
      professorFilter.innerHTML = '<option value="">All Professors</option>' + 
        professors.map(prof => `<option value="${prof}">${prof}</option>`).join('');
      console.log('Loaded', professors.length, 'professors');
    }
    
    // Get unique colleges
    const colleges = [...new Set(allClasses.map(c => c.college_name).filter(Boolean))];
    const collegeFilter = document.getElementById('collegeFilter');
    if (collegeFilter) {
      collegeFilter.innerHTML = '<option value="">All Colleges</option>' + 
        colleges.map(college => `<option value="${college}">${college}</option>`).join('');
      console.log('Loaded', colleges.length, 'colleges');
    }
    
    // Get unique branches
    const branches = [...new Set(allClasses.map(c => c.branch_name).filter(Boolean))];
    const branchFilter = document.getElementById('branchFilter');
    if (branchFilter) {
      branchFilter.innerHTML = '<option value="">All Branches</option>' + 
        branches.map(branch => `<option value="${branch}">${branch}</option>`).join('');
      console.log('Loaded', branches.length, 'branches');
    }
    
    // Get unique semesters
    const semesters = [...new Set(allClasses.map(c => c.semester_name).filter(Boolean))];
    const semesterFilter = document.getElementById('semesterFilter');
    if (semesterFilter) {
      semesterFilter.innerHTML = '<option value="">All Semesters</option>' + 
        semesters.map(semester => `<option value="${semester}">${semester}</option>`).join('');
      console.log('Loaded', semesters.length, 'semesters');
    }
    
  } catch (error) {
    console.error('Error loading filter options:', error);
  }
}

// Setup event listeners
function setupEventListeners() {
  // Filter change listeners with error handling
  const professorFilter = document.getElementById('professorFilter');
  const collegeFilter = document.getElementById('collegeFilter');
  const branchFilter = document.getElementById('branchFilter');
  const semesterFilter = document.getElementById('semesterFilter');
  const subjectFilter = document.getElementById('subjectFilter');
  
  if (professorFilter) {
    professorFilter.addEventListener('change', function() {
      console.log('Professor filter changed:', this.value);
      applyFilters();
    });
  }
  
  if (collegeFilter) {
    collegeFilter.addEventListener('change', function() {
      console.log('College filter changed:', this.value);
      applyFilters();
    });
  }
  
  if (branchFilter) {
    branchFilter.addEventListener('change', function() {
      console.log('Branch filter changed:', this.value);
      applyFilters();
    });
  }
  
  if (semesterFilter) {
    semesterFilter.addEventListener('change', function() {
      console.log('Semester filter changed:', this.value);
      applyFilters();
    });
  }
  
  if (subjectFilter) {
    subjectFilter.addEventListener('input', debounce(function() {
      console.log('Subject filter changed:', this.value);
      applyFilters();
    }, 300));
  }
  
  // Modal close on backdrop click
  const studentModal = document.getElementById('studentModal');
  if (studentModal) {
    studentModal.addEventListener('click', function(e) {
      if (e.target === this) {
        closeStudentModal();
      }
    });
  }
}

// Apply filters to classes
function applyFilters() {
  const professorFilter = document.getElementById('professorFilter').value;
  const collegeFilter = document.getElementById('collegeFilter').value;
  const branchFilter = document.getElementById('branchFilter').value;
  const semesterFilter = document.getElementById('semesterFilter').value;
  const subjectFilter = document.getElementById('subjectFilter').value.toLowerCase();
  
  console.log('Applying filters:', { professorFilter, collegeFilter, branchFilter, semesterFilter, subjectFilter });
  
  filteredClasses = allClasses.filter(classItem => {
    // Exact match for dropdowns, partial match for text input
    const matchesProfessor = !professorFilter || 
      (classItem.professor_email === professorFilter);
    
    const matchesCollege = !collegeFilter || 
      (classItem.college_name === collegeFilter);
    
    const matchesBranch = !branchFilter || 
      (classItem.branch_name === branchFilter);
    
    const matchesSemester = !semesterFilter || 
      (classItem.semester_name === semesterFilter);
    
    const matchesSubject = !subjectFilter || 
      (classItem.subject_name && classItem.subject_name.toLowerCase().includes(subjectFilter));
    
    return matchesProfessor && matchesCollege && matchesBranch && matchesSemester && matchesSubject;
  });
  
  console.log('Filtered classes:', filteredClasses.length, 'out of', allClasses.length);
  renderClasses();
  updateStatistics();
}

// Clear all filters
function clearFilters() {
  document.getElementById('professorFilter').value = '';
  document.getElementById('collegeFilter').value = '';
  document.getElementById('branchFilter').value = '';
  document.getElementById('semesterFilter').value = '';
  document.getElementById('subjectFilter').value = '';
  applyFilters();
}

// Render classes grid
function renderClasses() {
  const container = document.getElementById('classesContainer');
  
  if (filteredClasses.length === 0) {
    container.innerHTML = `
      <div class="empty-state">
        <div class="empty-state-icon">📚</div>
        <h3>No Classes Found</h3>
        <p>No classes match the current filters or no classes have been created yet.</p>
      </div>
    `;
    return;
  }
  
  container.innerHTML = `
    <div class="classes-grid">
      ${filteredClasses.map(classItem => `
        <div class="class-card">
          <div class="class-header">
            <div class="class-title">${classItem.subject_name || classItem.class_name || 'Unnamed Class'}</div>
            <div class="class-info">
              <div><strong>Professor:</strong> ${classItem.professor_email || 'Unknown'}</div>
              <div><strong>College:</strong> ${classItem.college_name || 'N/A'}</div>
              <div><strong>Branch:</strong> ${classItem.branch_name || 'N/A'}</div>
              <div><strong>Semester:</strong> ${classItem.semester_name || 'N/A'}</div>
            </div>
          </div>
          <div class="class-body">
            <div class="roster-stats">
              <div class="roster-stat">
                <div class="roster-stat-number">${classItem.totalStudents}</div>
                <div class="roster-stat-label">Total Students</div>
              </div>
              <div class="roster-stat">
                <div class="roster-stat-number">${classItem.connectedStudents}</div>
                <div class="roster-stat-label">Connected</div>
              </div>
              <div class="roster-stat">
                <div class="roster-stat-number">${classItem.unconnectedStudents}</div>
                <div class="roster-stat-label">Not Connected</div>
              </div>
            </div>
            <div class="class-actions">
              <button class="action-btn primary" onclick="viewStudents('${classItem.id}')">
                👥 View Students
              </button>
              <button class="action-btn danger" onclick="deleteClass('${classItem.id}')">
                🗑️ Delete
              </button>
            </div>
          </div>
        </div>
      `).join('')}
    </div>
  `;
}

// Update statistics
function updateStatistics() {
  const totalClasses = filteredClasses.length;
  const totalStudents = filteredClasses.reduce((sum, c) => sum + c.totalStudents, 0);
  const connectedStudents = filteredClasses.reduce((sum, c) => sum + c.connectedStudents, 0);
  const professors = new Set(filteredClasses.map(c => c.professor_email)).size;
  
  document.getElementById('totalClasses').textContent = totalClasses;
  document.getElementById('totalStudents').textContent = totalStudents;
  document.getElementById('connectedStudents').textContent = connectedStudents;
  document.getElementById('totalProfessors').textContent = professors;
}

// View students in a class - redirect to dedicated page
function viewStudents(classId) {
  window.location.href = `manage_class_roster.html?classId=${classId}`;
}

// Render students in modal
function renderStudentsModal() {
  const modalContent = document.getElementById('modalContent');
  
  if (currentStudents.length === 0) {
    modalContent.innerHTML = `
      <div style="text-align: center; padding: 2rem; color: #64748b;">
        <div style="font-size: 3rem; margin-bottom: 1rem;">📚</div>
        <h3>No Students in Roster</h3>
        <p>This class doesn't have any students yet.</p>
      </div>
    `;
    return;
  }
  
  const connectedCount = currentStudents.filter(s => s.student_profile_id).length;
  const unconnectedCount = currentStudents.length - connectedCount;
  
  modalContent.innerHTML = `
    <div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 1rem; margin-bottom: 2rem;">
      <div style="text-align: center; padding: 1rem; background: #f8fafc; border-radius: 8px;">
        <div style="font-size: 1.5rem; font-weight: 700; color: #667eea;">${currentStudents.length}</div>
        <div style="font-size: 0.8rem; color: #64748b;">Total Students</div>
      </div>
      <div style="text-align: center; padding: 1rem; background: #dcfce7; border-radius: 8px;">
        <div style="font-size: 1.5rem; font-weight: 700; color: #166534;">${connectedCount}</div>
        <div style="font-size: 0.8rem; color: #64748b;">App Connected</div>
      </div>
      <div style="text-align: center; padding: 1rem; background: #fef3c7; border-radius: 8px;">
        <div style="font-size: 1.5rem; font-weight: 700; color: #92400e;">${unconnectedCount}</div>
        <div style="font-size: 0.8rem; color: #64748b;">Not Connected</div>
      </div>
    </div>
    
    <table class="students-table">
      <thead>
        <tr>
          <th>Roll Number</th>
          <th>Student Name</th>
          <th>Email</th>
          <th>App Status</th>
          <th>Actions</th>
        </tr>
      </thead>
      <tbody>
        ${currentStudents.map(student => `
          <tr>
            <td><strong>${student.roll_number}</strong></td>
            <td>
              <div>${student.student_name}</div>
              ${student.profiles && student.profiles.full_name ? 
                `<small style="color: #64748b;">App: ${student.profiles.full_name}</small>` : ''}
            </td>
            <td>
              ${student.student_email || 'Not provided'}<br>
              ${student.profiles && student.profiles.email ? 
                `<small style="color: #64748b;">App: ${student.profiles.email}</small>` : ''}
            </td>
            <td>
              <span class="status-badge ${student.student_profile_id ? 'connected' : 'not-connected'}">
                ${student.student_profile_id ? '✓ Connected' : '⚠ Not Connected'}
              </span>
            </td>
            <td>
              <button class="action-btn ${student.student_profile_id ? 'danger' : 'primary'}" 
                      onclick="${student.student_profile_id ? `unlinkStudent('${student.id}')` : `linkStudent('${student.id}')`}"
                      style="font-size: 0.8rem; padding: 0.5rem 0.75rem; min-width: 80px;">
                ${student.student_profile_id ? 'Unlink' : 'Link'}
              </button>
              <button class="action-btn danger" 
                      onclick="removeStudent('${student.id}')"
                      style="font-size: 0.8rem; padding: 0.5rem 0.75rem; min-width: 80px; margin-left: 0.5rem;">
                Remove
              </button>
            </td>
          </tr>
        `).join('')}
      </tbody>
    </table>
  `;
}


// Link student to app profile
async function linkStudent(studentId) {
  const student = currentStudents.find(s => s.id === studentId);
  if (!student) return;

  if (!confirm(`Link student ${student.student_name} (${student.roll_number}) to their app profile?`)) return;

  try {
    showLoading('Linking student profile...');
    
    // Search for user profile with matching student_id (roll number) - profiles are in main database
    const { data: profileData, error: profileError } = await window.supabaseClient
      .from('profiles')
      .select('id, full_name, email, student_id')
      .eq('student_id', student.roll_number)
      .single();
    
    if (profileError && profileError.code !== 'PGRST116') {
      throw profileError;
    }
    
    if (!profileData) {
      showMessage(`No app profile found with roll number ${student.roll_number}. Student needs to register in the app first.`, true);
      hideLoading();
      return;
    }
    
    // Update class_rosters with the profile ID - class_rosters are in main database
    const { error: updateError } = await window.supabaseClient
      .from('class_rosters')
      .update({ 
        student_profile_id: profileData.id,
        is_verified: true,
        student_name: profileData.full_name || student.student_name,
        student_email: profileData.email || student.student_email
      })
      .eq('id', studentId);
    
    if (updateError) throw updateError;
    
    // Debug print before update
    console.log('Syncing email to class_assignment_marks:', {
      student_email: student.student_email,
      class_id: currentClass.id,
      student_id: student.roll_number
    });
    const { data, error } = await window.supabaseClient
      .from('class_assignment_marks')
      .update({ student_email: student.student_email })
      .eq('class_id', currentClass.id)
      .eq('student_id', student.roll_number)
      .or('student_email.is.null,student_email.eq.');
    // Debug print after update
    console.log('class_assignment_marks update result:', { data, error });
    
    showMessage(`Successfully linked ${profileData.full_name} (${student.roll_number}) to their app profile!`, false);
    
    // Refresh the view
    await viewStudents(currentClass.id);
    await loadAllClasses();
    applyFilters();
    
    hideLoading();
  } catch (error) {
    console.error('Error linking student profile:', error);
    showMessage('Error linking student profile: ' + error.message, true);
    hideLoading();
  }
}

// Unlink student from app profile
async function unlinkStudent(studentId) {
  const student = currentStudents.find(s => s.id === studentId);
  if (!student) return;
  
  if (!confirm(`Unlink student ${student.student_name} from their app profile? This will not delete their app account.`)) {
    return;
  }
  
  try {
    showLoading('Unlinking student profile...');
    
    const { error } = await window.supabaseClient
      .from('class_rosters')
      .update({ 
        student_profile_id: null,
        is_verified: false
      })
      .eq('id', studentId);
    
    if (error) throw error;
    
    showMessage('Student profile unlinked successfully!', false);
    
    // Refresh the view
    await viewStudents(currentClass.id);
    await loadAllClasses();
    applyFilters();
    
    hideLoading();
  } catch (error) {
    console.error('Error unlinking student profile:', error);
    showMessage('Error unlinking student profile: ' + error.message, true);
    hideLoading();
  }
}

// Remove student from class roster
async function removeStudent(studentId) {
  const student = currentStudents.find(s => s.id === studentId);
  if (!student) return;
  
  if (!confirm(`Are you sure you want to remove ${student.student_name} (${student.roll_number}) from the class roster? This cannot be undone.`)) {
    return;
  }
  
  try {
    showLoading('Removing student...');
    
    const { error } = await window.supabaseClient
      .from('class_rosters')
      .delete()
      .eq('id', studentId);
    
    if (error) throw error;
    
    showMessage('Student removed successfully!', false);
    
    // Refresh the view
    await viewStudents(currentClass.id);
    await loadAllClasses();
    applyFilters();
    
    hideLoading();
  } catch (error) {
    console.error('Error removing student:', error);
    showMessage('Error removing student: ' + error.message, true);
    hideLoading();
  }
}

// Delete entire class
async function deleteClass(classId) {
  const classItem = allClasses.find(c => c.id === classId);
  if (!classItem) return;
  
  const className = classItem.subject_name || classItem.class_name || 'Unnamed Class';
  
  if (!confirm(`Are you sure you want to delete the entire class "${className}"? This will remove all students and attendance records. This cannot be undone.`)) {
    return;
  }
  
  // Double confirmation for destructive action
  if (!confirm(`FINAL CONFIRMATION: Delete class "${className}" and ALL its data?`)) {
    return;
  }
  
  try {
    showLoading('Deleting class...');
    
    // Delete all related data (use appropriate clients for each table)
    await Promise.all([
      // Delete attendance records (in main database)
      window.supabaseClient.from('attendance').delete().eq('class_id', classId),
      // Delete class roster (in main database)
      window.supabaseClient.from('class_rosters').delete().eq('class_id', classId),
      // Delete the class itself (in main database)
      window.supabaseClient.from('professor_classes').delete().eq('id', classId)
    ]);
    
    showMessage(`Class "${className}" deleted successfully!`, false);
    
    // Refresh the view
    await loadAllClasses();
    await loadFilterOptions();
    applyFilters();
    
    hideLoading();
  } catch (error) {
    console.error('Error deleting class:', error);
    showMessage('Error deleting class: ' + error.message, true);
    hideLoading();
  }
}

// Close student modal
function closeStudentModal() {
  document.getElementById('studentModal').classList.add('hidden');
  currentClass = null;
  currentStudents = [];
}

// Utility function for debouncing
function debounce(func, wait) {
  let timeout;
  return function executedFunction(...args) {
    const later = () => {
      clearTimeout(timeout);
      func(...args);
    };
    clearTimeout(timeout);
    timeout = setTimeout(later, wait);
  };
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

// Show message
function showMessage(message, isError = false) {
  const messageDisplay = document.getElementById('messageDisplay');
  if (!messageDisplay) return;
  
  messageDisplay.textContent = message;
  messageDisplay.className = `message ${isError ? 'error' : 'success'}`;
  
  // Auto-hide after 5 seconds
  setTimeout(() => {
    messageDisplay.className = 'message';
  }, 5000);
}
