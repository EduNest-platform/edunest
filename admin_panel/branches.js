// Branch Management JavaScript

// Check authentication on page load
document.addEventListener('DOMContentLoaded', async function() {
  if (!sessionStorage.getItem('adminLoggedIn')) {
    window.location.href = 'index.html';
    return;
  }
  
  // Initialize the page asynchronously
  await initializePage();
  
  // Add scroll detection for mobile/tablet navbar
  addScrollDetection();
  
  // Add search functionality
  const searchInput = document.getElementById('branchSearchInput');
  if (searchInput) {
    searchInput.addEventListener('input', function() {
      filterBranches(this.value);
    });
  }
});

// Initialize page with proper async handling
async function initializePage() {
  // Check for college parameter in URL
  const urlParams = new URLSearchParams(window.location.search);
  const collegeId = urlParams.get('college');
  
  if (collegeId) {
    // Load college details and wait for completion
    await loadCollegeDetails(collegeId);
  } else {
    // Check if we have a selected college in sessionStorage
    const selectedCollege = sessionStorage.getItem('selectedCollege');
    if (selectedCollege) {
      try {
        const collegeData = JSON.parse(selectedCollege);
        updatePageForCollege(collegeData);
      } catch (error) {
        console.error('Error parsing selected college:', error);
      }
    }
  }
  
  // Now load branches after college details are set
  await loadBranches();
}

// Load college details by ID and set in sessionStorage
async function loadCollegeDetails(collegeId) {
  try {
    const { data: college, error } = await window.supabaseClient
      .from('colleges')
      .select('id, name')
      .eq('id', collegeId)
      .single();
    
    if (error) throw error;
    
    if (college) {
      // Store in sessionStorage
      sessionStorage.setItem('selectedCollege', JSON.stringify(college));
      updatePageForCollege(college);
    }
  } catch (error) {
    console.error('Error loading college details:', error);
    showMessage('Error loading college details. Please go back and try again.', true);
  }
}

// Update page content for a specific college
function updatePageForCollege(collegeData) {
  document.getElementById('selectedCollegeName').textContent = collegeData.name;
  document.getElementById('selectedCollegeDisplay').textContent = collegeData.name;
  
  // Update page content for filtered view
  document.getElementById('addBranchDescription').textContent = `Create a new branch for ${collegeData.name}`;
  document.getElementById('branchesListTitle').textContent = `${collegeData.name} Branches`;
  document.getElementById('branchesListDescription').textContent = `Manage existing branches for ${collegeData.name}`;
}

// Store all branches for search functionality
let allBranches = [];

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

// Utility Functions
function showMessage(message, isError = false) {
  const msgElement = document.getElementById('branchMsg');
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
  document.getElementById('branchName').value = '';
  // Don't clear the college display since it's always the selected college
}

// Load colleges for dropdown
async function loadCollegesForDropdown() {
  const select = document.getElementById('branchCollegeSelect');
  select.innerHTML = '<option value="">Select College</option>';
  try {
    const { data: colleges, error } = await window.supabaseClient
      .from('colleges')
      .select('id, name')
      .order('name');
    if (error) throw error;
    (colleges || []).forEach(college => {
      const opt = document.createElement('option');
      opt.value = college.id;
      opt.textContent = college.name;
      select.appendChild(opt);
    });
  } catch (error) {
    showMessage('Error loading colleges for dropdown.', true);
  }
}

// CRUD Operations
async function addBranch() {
  if (!window.supabaseClient) {
    showMessage('Database connection not available. Please refresh the page.', true);
    return;
  }
  
  const name = document.getElementById('branchName').value.trim();
  
  // Get college ID from sessionStorage
  let collegeId = null;
  const selectedCollege = sessionStorage.getItem('selectedCollege');
  if (selectedCollege) {
    try {
      const collegeData = JSON.parse(selectedCollege);
      collegeId = collegeData.id;
    } catch (error) {
      console.error('Error parsing selected college:', error);
    }
  }
  
  if (!collegeId) {
    showMessage('No college selected. Please go back and select a college.', true);
    return;
  }
  if (!name) {
    showMessage('Please enter a branch name.', true);
    document.getElementById('branchName').focus();
    return;
  }
  if (name.length < 2) {
    showMessage('Branch name must be at least 2 characters long.', true);
    document.getElementById('branchName').focus();
    return;
  }
  
  const submitBtn = document.querySelector('.submit-btn');
  submitBtn.disabled = true;
  submitBtn.innerHTML = '<span class="btn-icon">⏳</span>Adding...';
  
  try {
    const branchData = { name, college_id: collegeId };
    const { data, error } = await window.supabaseClient
      .from('branches')
      .insert([branchData])
      .select();
    if (error) throw error;
    showMessage('Branch added successfully!');
    clearForm();
    loadBranches();
  } catch (error) {
    let errorMessage = 'Error adding branch. Please try again.';
    if (error.message) {
      if (error.message.includes('duplicate')) {
        errorMessage = 'A branch with this name already exists.';
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
    submitBtn.innerHTML = '<span class="btn-icon">➕</span>Add Branch';
  }
}

async function deleteBranch(id) {
  if (!confirm('Are you sure you want to delete this branch? This action cannot be undone.')) return;
  try {
    const { error } = await window.supabaseClient
      .from('branches')
      .delete()
      .eq('id', id);
    if (error) throw error;
    showMessage('Branch deleted successfully!');
    loadBranches();
  } catch (error) {
    showMessage('Error deleting branch. Please try again.', true);
  }
}

async function editBranch(id) {
  const newName = prompt('Enter new branch name:');
  if (!newName || newName.trim() === '') return;
  try {
    const { error } = await window.supabaseClient
      .from('branches')
      .update({ name: newName.trim() })
      .eq('id', id);
    if (error) throw error;
    showMessage('Branch updated successfully!');
    loadBranches();
  } catch (error) {
    showMessage('Error updating branch. Please try again.', true);
  }
}

async function loadBranches() {
  showLoading();
  try {
    // Check if we have a selected college
    const selectedCollege = sessionStorage.getItem('selectedCollege');
    let query = window.supabaseClient
      .from('branches')
      .select('*, colleges (id, name)')
      .order('name');
    
    if (selectedCollege) {
      try {
        const collegeData = JSON.parse(selectedCollege);
        // Filter by the selected college
        query = query.eq('college_id', collegeData.id);
      } catch (error) {
        console.error('Error parsing selected college:', error);
      }
    }
    
    const { data: branches, error } = await query;
    if (error) throw error;
    
    allBranches = branches || [];
    displayBranches(allBranches);
  } catch (error) {
    showMessage('Error loading branches. Please refresh the page.', true);
    allBranches = [];
    displayBranches([]);
  } finally {
    hideLoading();
  }
}

function filterBranches(query) {
  query = query.trim().toLowerCase();
  if (!query) {
    displayBranches(allBranches);
    return;
  }
  const filtered = allBranches.filter(branch =>
    (branch.name || '').toLowerCase().includes(query)
  );
  displayBranches(filtered);
}

function displayBranches(branches) {
  const branchList = document.getElementById('branchList');
  const emptyState = document.getElementById('emptyState');
  const branchCount = document.getElementById('branchCount');
  
  branchCount.textContent = branches.length;
  
  if (branches.length === 0) {
    branchList.innerHTML = '';
    emptyState.classList.remove('hidden');
    
    // Update empty state message based on whether we're filtering
    const selectedCollege = sessionStorage.getItem('selectedCollege');
    if (selectedCollege) {
      try {
        const collegeData = JSON.parse(selectedCollege);
        emptyState.innerHTML = `
          <div class="empty-icon">🏢</div>
          <h3>No Branches Found</h3>
          <p>No branches found for ${collegeData.name}. Start by adding your first branch above.</p>
        `;
      } catch (error) {
        console.error('Error parsing selected college:', error);
      }
    }
    return;
  }
  
  emptyState.classList.add('hidden');
  
  const branchesHTML = branches.map(branch => {
    const escapedName = escapeHtml(branch.name);
    const escapedCollegeName = branch.colleges ? escapeHtml(branch.colleges.name) : 'Unknown';
    
    return `
      <div class="branch-card">
        <div class="branch-header">
          <div>
            <div class="branch-name">${escapedName}</div>
            <div class="branch-id">ID: ${branch.id}</div>
          </div>
        </div>
        <div class="branch-college">🏫 ${branch.colleges ? escapedCollegeName : 'Unknown College'}</div>
        <div class="branch-actions">
          <button class="action-btn view-btn" 
                  onclick="viewSemesters('${branch.id}', '${escapedName}', '${branch.colleges ? branch.colleges.id : 'null'}', '${escapedCollegeName}')"
                  data-branch-id="${branch.id}" 
                  data-branch-name="${escapedName}" 
                  data-college-id="${branch.colleges ? branch.colleges.id : 'null'}" 
                  data-college-name="${escapedCollegeName}">
            📚 View Semesters
          </button>
          <button class="action-btn edit-btn" onclick="editBranch(${branch.id})">✏️ Edit</button>
          <button class="action-btn delete-btn" onclick="deleteBranch(${branch.id})">🗑️ Delete</button>
        </div>
      </div>
    `;
  }).join('');
  
  branchList.innerHTML = branchesHTML;
  
  // Add event listeners for view buttons using data attributes as fallback
  const viewButtons = branchList.querySelectorAll('.view-btn');
  viewButtons.forEach(button => {
    button.addEventListener('click', function() {
      const branchId = this.getAttribute('data-branch-id');
      const branchName = this.getAttribute('data-branch-name');
      const collegeId = this.getAttribute('data-college-id');
      const collegeName = this.getAttribute('data-college-name');
      viewSemesters(branchId, branchName, collegeId, collegeName);
    });
  });
}

function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

// View semesters for a specific branch
function viewSemesters(branchId, branchName, collegeId, collegeName) {
  try {
    // Store branch and college info in sessionStorage for the semesters page
    sessionStorage.setItem('selectedBranch', JSON.stringify({
      id: branchId,
      name: branchName,
      college_id: collegeId,
      college_name: collegeName
    }));
    
    // Navigate to semesters page
    window.location.href = 'semesters.html';
  } catch (error) {
    alert('Error navigating to semesters page: ' + error.message);
  }
}

function logout() {
  sessionStorage.removeItem('adminLoggedIn');
  window.location.href = 'index.html';
}

window.addBranch = addBranch;
window.deleteBranch = deleteBranch;
window.editBranch = editBranch;
window.viewSemesters = viewSemesters;
window.logout = logout; 
 
 
 