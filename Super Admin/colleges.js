// College Management JavaScript

// Check authentication on page load
document.addEventListener('DOMContentLoaded', function() {
  // Temporarily comment out auth check for debugging
  // if (!sessionStorage.getItem('adminLoggedIn')) {
  //   window.location.href = 'index.html';
  //   return;
  // }
  
  
  
  // Test database connection
  testDatabaseConnection();
  
  // Initialize the page
  loadColleges();

  const searchInput = document.getElementById('collegeSearchInput');
  if (searchInput) {
    searchInput.addEventListener('input', function() {
      filterColleges(this.value);
    });
  }
});

// Test database connection
async function testDatabaseConnection() {
  try {
    if (!window.supabaseClient) {
      console.error('Supabase client not available');
      return;
    }
    
    // Try to select from colleges table to test connection
    const { data, error } = await window.supabaseClient
      .from('colleges')
      .select('id')
      .limit(1);
    
    if (error) {
      console.error('Database connection test failed:', error);
      showMessage('Database connection failed. Please check your setup.', true);
    } else {
  
    }
  } catch (error) {
    console.error('Database connection test error:', error);
  }
}

// Utility Functions
function showMessage(message, isError = false) {
  const msgElement = document.getElementById('collegeMsg');
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
  document.getElementById('collegeName').value = '';
}

// CRUD Operations
async function addCollege() {
  // Check if Supabase client is available
  if (!window.supabaseClient) {
    showMessage('Database connection not available. Please refresh the page.', true);
    return;
  }

  const name = document.getElementById('collegeName').value.trim();
  // Validation
  if (!name) {
    showMessage('Please enter a college name.', true);
    document.getElementById('collegeName').focus();
    return;
  }
  if (name.length < 3) {
    showMessage('College name must be at least 3 characters long.', true);
    document.getElementById('collegeName').focus();
    return;
  }
  // Disable submit button
  const submitBtn = document.querySelector('.submit-btn');
  submitBtn.disabled = true;
  submitBtn.innerHTML = '<span class="btn-icon">⏳</span>Adding...';
  try {
    const collegeData = { name };

    const { data, error } = await window.supabaseClient
      .from('colleges')
      .insert([collegeData])
      .select();
    if (error) {
      console.error('Supabase error:', error);
      throw new Error(error.message || 'Database error occurred');
    }
    
    showMessage('College added successfully!');
    clearForm();
    loadColleges();
  } catch (error) {
    console.error('Error adding college:', error);
    let errorMessage = 'Error adding college. Please try again.';
    if (error.message) {
      if (error.message.includes('duplicate')) {
        errorMessage = 'A college with this name already exists.';
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
    // Re-enable submit button
    submitBtn.disabled = false;
    submitBtn.innerHTML = '<span class="btn-icon">➕</span>Add College';
  }
}

async function deleteCollege(id) {
  if (!confirm('Are you sure you want to delete this college? This action cannot be undone.')) {
    return;
  }
  
  try {
    const { error } = await window.supabaseClient
      .from('colleges')
      .delete()
      .eq('id', id);
    
    if (error) {
      throw error;
    }
    
    showMessage('College deleted successfully!');
    loadColleges();
    
  } catch (error) {
    console.error('Error deleting college:', error);
    showMessage('Error deleting college. Please try again.', true);
  }
}

async function editCollege(id) {
  // For now, we'll use a simple prompt
  // In a full implementation, you might want a modal or separate edit page
  const newName = prompt('Enter new college name:');
  
  if (!newName || newName.trim() === '') {
    return;
  }
  
  try {
    const { error } = await window.supabaseClient
      .from('colleges')
      .update({ name: newName.trim() })
      .eq('id', id);
    
    if (error) {
      throw error;
    }
    
    showMessage('College updated successfully!');
    loadColleges();
    
  } catch (error) {
    console.error('Error updating college:', error);
    showMessage('Error updating college. Please try again.', true);
  }
}

let allColleges = [];

async function loadColleges() {
  showLoading();
  try {
    const { data: colleges, error } = await window.supabaseClient
      .from('colleges')
      .select('*')
      .order('name');
    if (error) {
      throw error;
    }
    allColleges = colleges || [];
    displayColleges(allColleges);
  } catch (error) {
    console.error('Error loading colleges:', error);
    showMessage('Error loading colleges. Please refresh the page.', true);
    allColleges = [];
    displayColleges([]);
  } finally {
    hideLoading();
  }
}

function displayColleges(colleges) {
  
  
  const collegeList = document.getElementById('collegeList');
  const emptyState = document.getElementById('emptyState');
  const collegeCount = document.getElementById('collegeCount');
  
  // Update count
  collegeCount.textContent = colleges.length;
  
  if (colleges.length === 0) {
    collegeList.innerHTML = '';
    emptyState.classList.remove('hidden');
    return;
  }
  
  emptyState.classList.add('hidden');
  
  const collegesHTML = colleges.map(college => {
    const escapedName = escapeHtml(college.name);
    
    
    return `
      <div class="college-card">
        <div class="college-header">
          <div>
            <div class="college-name">${escapedName}</div>
            <div class="college-id">ID: ${college.id}</div>
          </div>
        </div>
        <div class="college-actions">
          <button class="action-btn view-btn" data-college-id="${college.id}" data-college-name="${college.name}">
            🏢 View Branches
          </button>
          <button class="action-btn edit-btn" onclick="editCollege(${college.id})">
            ✏️ Edit
          </button>
          <button class="action-btn delete-btn" onclick="deleteCollege(${college.id})">
            🗑️ Delete
          </button>
        </div>
      </div>
    `;
  }).join('');
  
  
  collegeList.innerHTML = collegesHTML;
  
  // Add event listeners for view buttons using data attributes
  const viewButtons = collegeList.querySelectorAll('.view-btn');
  viewButtons.forEach(button => {
    button.addEventListener('click', function() {
      const collegeId = this.getAttribute('data-college-id');
      const collegeName = this.getAttribute('data-college-name');
  
      viewBranches(collegeId, collegeName);
    });
  });
}

// Utility function to escape HTML
function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

// Logout function
function logout() {
  sessionStorage.removeItem('adminLoggedIn');
  window.location.href = 'index.html';
}

// View branches for a specific college
function viewBranches(collegeId, collegeName) {

  
  try {
    // Store college info in sessionStorage for the branches page
    sessionStorage.setItem('selectedCollege', JSON.stringify({
      id: collegeId,
      name: collegeName
    }));
    
    // Navigate to branches page
    window.location.href = 'branches.html';
  } catch (error) {
    console.error('Error in viewBranches:', error);
    alert('Error navigating to branches page: ' + error.message);
  }
}

// Expose functions to window for HTML access
window.addCollege = addCollege;
window.deleteCollege = deleteCollege;
window.editCollege = editCollege;
window.viewBranches = viewBranches;
window.logout = logout;

// Keyboard shortcuts
document.addEventListener('keydown', function(event) {
  // Ctrl/Cmd + Enter to submit form
  if ((event.ctrlKey || event.metaKey) && event.key === 'Enter') {
    const submitBtn = document.querySelector('.submit-btn');
    if (!submitBtn.disabled) {
      addCollege();
    }
  }
  
  // Escape to clear form
  if (event.key === 'Escape') {
    clearForm();
  }
});

// Form validation
document.getElementById('collegeName').addEventListener('input', function() {
  const submitBtn = document.querySelector('.submit-btn');
  const name = this.value.trim();
  
  if (name.length >= 3) {
    submitBtn.disabled = false;
  } else {
    submitBtn.disabled = true;
  }
});

// Auto-save draft (optional feature)
let autoSaveTimer;
document.getElementById('collegeName').addEventListener('input', function() {
  clearTimeout(autoSaveTimer);
  autoSaveTimer = setTimeout(() => {
    const name = this.value.trim();
    if (name.length > 0) {
      localStorage.setItem('collegeDraft', JSON.stringify({
        name: name,
        timestamp: Date.now()
      }));
    }
  }, 1000);
});

// Load draft on page load
document.addEventListener('DOMContentLoaded', function() {
  const draft = localStorage.getItem('collegeDraft');
  if (draft) {
    try {
      const draftData = JSON.parse(draft);
      const oneHour = 60 * 60 * 1000; // 1 hour in milliseconds
      
      // Only load draft if it's less than 1 hour old
      if (Date.now() - draftData.timestamp < oneHour) {
        document.getElementById('collegeName').value = draftData.name || '';
      } else {
        localStorage.removeItem('collegeDraft');
      }
    } catch (error) {
      localStorage.removeItem('collegeDraft');
    }
  }
});

// Clear draft when form is submitted successfully
function clearDraft() {
  localStorage.removeItem('collegeDraft');
}

function filterColleges(query) {
  query = query.trim().toLowerCase();
  if (!query) {
    displayColleges(allColleges);
    return;
  }
  const filtered = allColleges.filter(college =>
    (college.name || '').toLowerCase().includes(query)
  );
  displayColleges(filtered);
} 
 
 
 