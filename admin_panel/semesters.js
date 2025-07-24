// Semester Management JavaScript

// Check authentication on page load
document.addEventListener('DOMContentLoaded', function() {
  // Check if we have a selected branch
  const selectedBranch = sessionStorage.getItem('selectedBranch');
  
  if (selectedBranch) {
    try {
      const branchData = JSON.parse(selectedBranch);
      document.getElementById('selectedCollegeName').textContent = branchData.college_name;
      document.getElementById('selectedBranchName').textContent = branchData.name;
      document.getElementById('selectedBranchDisplay').textContent = `${branchData.name} (${branchData.college_name})`;
      
      // Update page content for filtered view
      document.getElementById('addSemesterDescription').textContent = `Create a new semester for ${branchData.name} (${branchData.college_name})`;
      document.getElementById('semestersListTitle').textContent = `${branchData.name} Semesters`;
      document.getElementById('semestersListDescription').textContent = `Manage existing semesters for ${branchData.name} (${branchData.college_name})`;
    } catch (error) {
      document.getElementById('semestersListDescription').textContent = 'Manage existing semesters for this branch.';
    }
  }
  
  loadSemesters();
  
  // Add scroll detection
  addScrollDetection();
  
  // Add search functionality
  const searchInput = document.getElementById('semesterSearchInput');
  if (searchInput) {
    searchInput.addEventListener('input', function() {
      filterSemesters(this.value);
    });
  }
});

// Store all semesters for search functionality
let allSemesters = [];

// Utility Functions
function showMessage(message, isError = false) {
  const msgElement = document.getElementById('semesterMsg');
  msgElement.textContent = message;
  msgElement.className = `message ${isError ? 'error' : 'success'} show`;
  setTimeout(() => {
    msgElement.classList.remove('show');
  }, 3000);
}

function showLoading() {
  document.getElementById('loadingOverlay').classList.remove('hidden');
}

function hideLoading() {
  document.getElementById('loadingOverlay').classList.add('hidden');
}

function clearForm() {
  document.getElementById('semesterName').value = '';
  // Don't clear the branch display since it's always the selected branch
}

// Load branches for dropdown
async function loadBranchesForDropdown() {
  const select = document.getElementById('semesterBranchSelect');
  select.innerHTML = '<option value="">Select Branch</option>';
  try {
    const { data: branches, error } = await window.supabaseClient
      .from('branches')
      .select('id, name, colleges (id, name)')
      .order('name');
    if (error) throw error;
    (branches || []).forEach(branch => {
      const opt = document.createElement('option');
      opt.value = branch.id;
      opt.textContent = `${branch.name} (${branch.colleges ? branch.colleges.name : 'Unknown College'})`;
      select.appendChild(opt);
    });
  } catch (error) {
    showMessage('Error loading branches for dropdown.', true);
  }
}

// CRUD Operations
async function addSemester() {
  if (!window.supabaseClient) {
    showMessage('Database connection not available. Please refresh the page.', true);
    return;
  }
  
  const name = document.getElementById('semesterName').value.trim();
  
  // Get branch ID from sessionStorage
  let branchId = null;
  const selectedBranch = sessionStorage.getItem('selectedBranch');
  if (selectedBranch) {
    try {
      const branchData = JSON.parse(selectedBranch);
      branchId = branchData.id;
    } catch (error) {
      console.error('Error parsing selected branch:', error);
    }
  }
  
  if (!branchId) {
    showMessage('No branch selected. Please go back and select a branch.', true);
    return;
  }
  if (!name) {
    showMessage('Please enter a semester name.', true);
    document.getElementById('semesterName').focus();
    return;
  }
  if (name.length < 2) {
    showMessage('Semester name must be at least 2 characters long.', true);
    document.getElementById('semesterName').focus();
    return;
  }
  
  const submitBtn = document.querySelector('.submit-btn');
  submitBtn.disabled = true;
  submitBtn.innerHTML = '<span class="btn-icon">⏳</span>Adding...';
  
  try {
    const semesterData = { name, branch_id: branchId };
    const { data, error } = await window.supabaseClient
      .from('semesters')
      .insert([semesterData])
      .select();
    if (error) throw error;
    showMessage('Semester added successfully!');
    clearForm();
    loadSemesters();
  } catch (error) {
    let errorMessage = 'Error adding semester. Please try again.';
    if (error.message) {
      if (error.message.includes('duplicate')) {
        errorMessage = 'A semester with this name already exists in this branch.';
      } else if (error.message.includes('network')) {
        errorMessage = 'Network error. Please check your connection.';
      } else if (error.message.includes('permission')) {
        errorMessage = 'Permission denied. Please check your credentials.';
      } else {
        errorMessage = error.message;
      }
    }
    showMessage(errorMessage, true);
  } finally {
    submitBtn.disabled = false;
    submitBtn.innerHTML = '<span class="btn-icon">➕</span>Add Semester';
  }
}

async function deleteSemester(id) {
  if (!confirm('Are you sure you want to delete this semester? This action cannot be undone.')) return;
  
  try {
    const { error } = await window.supabaseClient
      .from('semesters')
      .delete()
      .eq('id', id);
    if (error) throw error;
    showMessage('Semester deleted successfully!');
    loadSemesters();
  } catch (error) {
    showMessage('Error deleting semester. Please try again.', true);
  }
}

async function editSemester(id) {
  const newName = prompt('Enter new semester name:');
  if (!newName || newName.trim() === '') return;
  
  try {
    const { error } = await window.supabaseClient
      .from('semesters')
      .update({ name: newName.trim() })
      .eq('id', id);
    if (error) throw error;
    showMessage('Semester updated successfully!');
    loadSemesters();
  } catch (error) {
    showMessage('Error updating semester. Please try again.', true);
  }
}

async function loadSemesters() {
  showLoading();
  try {
    // Check if we have a selected branch
    const selectedBranch = sessionStorage.getItem('selectedBranch');
    let query = window.supabaseClient
      .from('semesters')
      .select('*, branches (id, name, colleges (id, name))')
      .order('name');
    
    if (selectedBranch) {
      try {
        const branchData = JSON.parse(selectedBranch);
        // Filter by the selected branch
        query = query.eq('branch_id', branchData.id);
      } catch (error) {
        console.error('Error parsing selected branch:', error);
      }
    }
    
    const { data: semesters, error } = await query;
    if (error) throw error;
    
    allSemesters = semesters || [];
    displaySemesters(allSemesters);
  } catch (error) {
    showMessage('Error loading semesters. Please refresh the page.', true);
    allSemesters = [];
    displaySemesters([]);
  } finally {
    hideLoading();
  }
}

function displaySemesters(semesters) {
  const semesterList = document.getElementById('semesterList');
  const emptyState = document.getElementById('emptyState');
  const semesterCount = document.getElementById('semesterCount');
  
  semesterCount.textContent = semesters.length;
  
  if (semesters.length === 0) {
    semesterList.innerHTML = '';
    emptyState.classList.remove('hidden');
    
    // Update empty state message based on whether we're filtering
    const selectedBranch = sessionStorage.getItem('selectedBranch');
    if (selectedBranch) {
      try {
        const branchData = JSON.parse(selectedBranch);
        emptyState.innerHTML = `
          <div class="empty-icon">📚</div>
          <h3>No Semesters Found</h3>
          <p>No semesters found for ${branchData.name}. Start by adding your first semester above.</p>
        `;
      } catch (error) {
        console.error('Error parsing selected branch:', error);
      }
    }
    return;
  }
  
  emptyState.classList.add('hidden');
  semesterList.innerHTML = semesters.map(semester => {
    const buttonHtml = `
    <div class="semester-card" data-semester-id="${semester.id}">
      <div class="semester-header">
        <div>
          <div class="semester-name">${escapeHtml(semester.name)}</div>
          <div class="semester-id">ID: ${semester.id}</div>
        </div>
      </div>
      <div class="semester-branch">
        📚 ${semester.branches ? escapeHtml(semester.branches.name) : 'Unknown Branch'}
        ${semester.branches && semester.branches.colleges ? 
          `(${escapeHtml(semester.branches.colleges.name)})` : ''}
      </div>
      <div class="semester-actions">
        <button class="action-btn view-btn" data-semester-id="${semester.id}" data-semester-name="${escapeHtml(semester.name)}" data-branch-id="${semester.branches ? semester.branches.id : 'null'}" data-branch-name="${escapeHtml(semester.branches ? semester.branches.name : 'Unknown')}" data-college-id="${semester.branches && semester.branches.colleges ? semester.branches.colleges.id : 'null'}" data-college-name="${escapeHtml(semester.branches && semester.branches.colleges ? semester.branches.colleges.name : 'Unknown')}">
          📖 View Subjects
        </button>
        <button class="action-btn edit-btn" data-semester-id="${semester.id}">
          ✏️ Edit
        </button>
        <button class="action-btn delete-btn" data-semester-id="${semester.id}">
          🗑️ Delete
        </button>
      </div>
    </div>
    `;
    
    return buttonHtml;
  }).join('');
  
  // Add event listeners after generating HTML
  addEventListeners();
}

function addEventListeners() {
  // Add event listeners for view subjects buttons
  document.querySelectorAll('.view-btn').forEach(button => {
    button.addEventListener('click', function() {
      const semesterId = this.getAttribute('data-semester-id');
      const semesterName = this.getAttribute('data-semester-name');
      const branchId = this.getAttribute('data-branch-id');
      const branchName = this.getAttribute('data-branch-name');
      const collegeId = this.getAttribute('data-college-id');
      const collegeName = this.getAttribute('data-college-name');
      
      viewSubjects(semesterId, semesterName, branchId, branchName, collegeId, collegeName);
    });
  });
  
  // Add event listeners for edit buttons
  document.querySelectorAll('.edit-btn').forEach(button => {
    button.addEventListener('click', function() {
      const semesterId = this.getAttribute('data-semester-id');
      editSemester(semesterId);
    });
  });
  
  // Add event listeners for delete buttons
  document.querySelectorAll('.delete-btn').forEach(button => {
    button.addEventListener('click', function() {
      const semesterId = this.getAttribute('data-semester-id');
      deleteSemester(semesterId);
    });
  });
}

function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

// View subjects for a specific semester
function viewSubjects(semesterId, semesterName, branchId, branchName, collegeId, collegeName) {
  // Store semester, branch, and college info in sessionStorage for the subjects page
  const semesterData = {
    id: semesterId,
    name: semesterName,
    branch_id: branchId,
    branch_name: branchName,
    college_id: collegeId,
    college_name: collegeName
  };
  
  sessionStorage.setItem('selectedSemester', JSON.stringify(semesterData));
  
  // Navigate to subjects page
  window.location.href = 'subjects.html';
}

function logout() {
  sessionStorage.removeItem('adminLoggedIn');
  window.location.href = 'index.html';
}

window.addSemester = addSemester;
window.deleteSemester = deleteSemester;
window.editSemester = editSemester;
window.viewSubjects = viewSubjects;
window.logout = logout;

// Add scroll detection to make navbar smaller when scrolling
function addScrollDetection() {
  const header = document.querySelector('.header');
  let lastScrollTop = 0;
  
  window.addEventListener('scroll', function() {
    const scrollTop = window.pageYOffset || document.documentElement.scrollTop;
    
    // Check if it's mobile or tablet
    const isMobile = window.innerWidth <= 768;
    
    if (isMobile) {
      if (scrollTop > 50) {
        header.classList.add('scrolled');
      } else {
        header.classList.remove('scrolled');
      }
    } else {
      // For desktop, keep normal size
      header.classList.remove('scrolled');
    }
    
    lastScrollTop = scrollTop;
  });
}

function filterSemesters(query) {
  query = query.trim().toLowerCase();
  if (!query) {
    displaySemesters(allSemesters);
    return;
  }
  const filtered = allSemesters.filter(semester =>
    (semester.name || '').toLowerCase().includes(query)
  );
  displaySemesters(filtered);
} 
 
 