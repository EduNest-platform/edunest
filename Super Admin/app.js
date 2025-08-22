// Remove Supabase client initialization from here. It will be imported from supabaseClient.js

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

// Tab navigation
function showTab(tab) {
  document.querySelectorAll('.tab-section').forEach(sec => sec.classList.add('hidden'));
  document.getElementById('tab-' + tab).classList.remove('hidden');
  document.querySelectorAll('.nav-btn').forEach(btn => btn.classList.remove('active'));
  document.querySelector('.nav-btn[data-tab="' + tab + '"]').classList.add('active');
  
  // Update statistics when showing overview
  if (tab === 'overview') {
    updateStatistics();
  }
}

// Update dashboard statistics
async function updateStatistics() {
  try {
    const { data: colleges } = await window.supabaseClient.from('colleges').select('id');
    const { data: branches } = await window.supabaseClient.from('branches').select('id');
    const { data: semesters } = await window.supabaseClient.from('semesters').select('id');
    
    const collegeCount = colleges ? colleges.length : 0;
    const branchCount = branches ? branches.length : 0;
    const semesterCount = semesters ? semesters.length : 0;
    const totalItems = collegeCount + branchCount + semesterCount;
    
    // Animate the numbers
    animateNumber('collegeCount', collegeCount);
    animateNumber('branchCount', branchCount);
    animateNumber('semesterCount', semesterCount);
    animateNumber('totalItems', totalItems);
    
  } catch (error) {
    console.error('Error updating statistics:', error);
  }
}

// Animate number counting
function animateNumber(elementId, finalValue) {
  const element = document.getElementById(elementId);
  if (!element) return;
  
  const startValue = 0;
  const duration = 1000;
  const startTime = performance.now();
  
  function updateNumber(currentTime) {
    const elapsed = currentTime - startTime;
    const progress = Math.min(elapsed / duration, 1);
    
    const currentValue = Math.floor(startValue + (finalValue - startValue) * progress);
    element.textContent = currentValue;
    
    if (progress < 1) {
      requestAnimationFrame(updateNumber);
    }
  }
  
  requestAnimationFrame(updateNumber);
}

// Expand all collapsible items
function expandAll() {
  const headers = document.querySelectorAll('.collapsible-header');
  headers.forEach(header => {
    const content = header.nextElementSibling;
    const icon = header.querySelector('.collapse-icon');
    if (content && content.style.display === 'none') {
      content.style.display = 'block';
      icon.classList.add('open');
    }
  });
}

// Collapse all collapsible items
function collapseAll() {
  const headers = document.querySelectorAll('.collapsible-header');
  headers.forEach(header => {
    const content = header.nextElementSibling;
    const icon = header.querySelector('.collapse-icon');
    if (content) {
      content.style.display = 'none';
      icon.classList.remove('open');
    }
  });
}

// Load colleges for dropdown (used by branches)
async function loadCollegesForDropdown() {
  const { data: colleges } = await window.supabaseClient.from('colleges').select('id, name');
  const branchCollegeSelect = document.getElementById('branchCollegeSelect');
  
  branchCollegeSelect.innerHTML = '<option value="">Select College First</option>';
  if (colleges && colleges.length > 0) {
    colleges.forEach(college => {
      const opt = document.createElement('option');
      opt.value = college.id;
      opt.textContent = college.name;
      branchCollegeSelect.appendChild(opt);
    });
    branchCollegeSelect.disabled = false;
  } else {
    branchCollegeSelect.disabled = true;
  }
}

// CRUD: Branches
async function addBranch() {
  const name = document.getElementById('branchName').value.trim();
  const collegeId = document.getElementById('branchCollegeSelect').value;
  if (!name || !collegeId) {
    showMsg('branchMsg', 'Select a college first!');
    return;
  }
  await window.supabaseClient.from('branches').insert([{ name, college_id: collegeId }]);
  document.getElementById('branchName').value = '';
  showMsg('branchMsg', 'Branch added!');
  loadBranches();
  loadHierarchy();
  updateStatistics();
}
async function deleteBranch(id) {
  await window.supabaseClient.from('branches').delete().eq('id', id);
  loadBranches();
  loadSemesters();
  loadHierarchy();
  updateStatistics();
}
async function loadBranches() {
  // Load colleges for dropdown first
  await loadCollegesForDropdown();
  
  // Then load branches for selected college
  const collegeId = document.getElementById('branchCollegeSelect').value;
  const { data, error } = collegeId ? await window.supabaseClient.from('branches').select().eq('college_id', collegeId) : { data: [] };
  const list = document.getElementById('branchList');
  const semBranchSelect = document.getElementById('semBranchSelect');
  const branchListCount = document.getElementById('branchListCount');
  
  list.innerHTML = '';
  semBranchSelect.innerHTML = '<option value="">Select Branch First</option>';
  
  if (data && data.length > 0) {
    data.forEach(branch => {
      const li = document.createElement('li');
      li.textContent = branch.name;
      const delBtn = document.createElement('button');
      delBtn.textContent = 'Delete';
      delBtn.className = 'delete';
      delBtn.onclick = () => deleteBranch(branch.id);
      li.appendChild(delBtn);
      list.appendChild(li);

      const opt = document.createElement('option');
      opt.value = branch.id;
      opt.textContent = branch.name;
      semBranchSelect.appendChild(opt);
    });
    semBranchSelect.disabled = false;
    branchListCount.textContent = `${data.length} branch${data.length > 1 ? 'es' : ''}`;
  } else {
    if (collegeId) {
      list.innerHTML = '<li style="color:#64748b;">No branches yet for this college. Add branches to create semesters.</li>';
    } else {
      list.innerHTML = '<li style="color:#64748b;">Select a college first to view its branches.</li>';
    }
    semBranchSelect.disabled = true;
    branchListCount.textContent = '0 branches';
  }
  loadSemesters();
}

// CRUD: Semesters
async function addSemester() {
  const name = document.getElementById('semName').value.trim();
  const branchId = document.getElementById('semBranchSelect').value;
  if (!name || !branchId) {
    showMsg('semMsg', 'Select a branch first!');
    return;
  }
  await window.supabaseClient.from('semesters').insert([{ name, branch_id: branchId }]);
  document.getElementById('semName').value = '';
  showMsg('semMsg', 'Semester added!');
  loadSemesters();
  loadHierarchy();
  updateStatistics();
}
async function deleteSemester(id) {
  await window.supabaseClient.from('semesters').delete().eq('id', id);
  loadSemesters();
  loadHierarchy();
}
async function loadSemesters() {
  const branchId = document.getElementById('semBranchSelect').value;
  const { data, error } = branchId ? await window.supabaseClient.from('semesters').select().eq('branch_id', branchId) : { data: [] };
  const list = document.getElementById('semList');
  const semListCount = document.getElementById('semListCount');
  
  list.innerHTML = '';
  
  if (data && data.length > 0) {
    data.forEach(sem => {
      const li = document.createElement('li');
      li.textContent = sem.name;
      const delBtn = document.createElement('button');
      delBtn.textContent = 'Delete';
      delBtn.className = 'delete';
      delBtn.onclick = () => deleteSemester(sem.id);
      li.appendChild(delBtn);
      list.appendChild(li);
    });
    semListCount.textContent = `${data.length} semester${data.length > 1 ? 's' : ''}`;
  } else {
    if (branchId) {
      list.innerHTML = '<li style="color:#64748b;">No semesters yet for this branch.</li>';
    } else {
      list.innerHTML = '<li style="color:#64748b;">Select a branch first to view its semesters.</li>';
    }
    semListCount.textContent = '0 semesters';
  }
}

// Collapsible, interactive hierarchy view
async function loadHierarchy() {
  const view = document.getElementById('hierarchyView');
  
  // Safety check - only run if hierarchyView exists (on dashboard page)
  if (!view) {
    console.log('hierarchyView not found - skipping hierarchy load');
    return;
  }
  
  const { data: colleges } = await window.supabaseClient.from('colleges').select();
  const { data: branches } = await window.supabaseClient.from('branches').select();
  const { data: semesters } = await window.supabaseClient.from('semesters').select();
  
  view.innerHTML = '';
  if (!colleges || colleges.length === 0) {
    view.innerHTML = '<div style="color:#64748b;">No colleges found.</div>';
    return;
  }
  colleges.forEach(college => {
    // College card
    const card = document.createElement('div');
    card.className = 'collapsible-card';
    // Header
    const header = document.createElement('div');
    header.className = 'collapsible-header';
    header.innerHTML = `<span>🏫 ${college.name}</span><span class="collapse-icon">▶</span>`;
    card.appendChild(header);
    // Content (hidden by default)
    const content = document.createElement('div');
    content.className = 'collapsible-content';
    content.style.display = 'none';
    // Add Branch inline form
    const addBranchRow = document.createElement('div');
    addBranchRow.className = 'inline-add-row';
    addBranchRow.innerHTML = `
      <input type="text" placeholder="Add branch..." />
      <button>Add Branch</button>
      <span class="inline-feedback"></span>
    `;
    const branchInput = addBranchRow.querySelector('input');
    const branchBtn = addBranchRow.querySelector('button');
    const branchFeedback = addBranchRow.querySelector('.inline-feedback');
    branchBtn.onclick = async () => {
      const name = branchInput.value.trim();
      if (!name) return;
      await window.supabaseClient.from('branches').insert([{ name, college_id: college.id }]);
      branchInput.value = '';
      branchFeedback.textContent = 'Added!';
      setTimeout(() => branchFeedback.textContent = '', 1500);
      loadHierarchy();
    };
    content.appendChild(addBranchRow);
    // Branches list
    const collegeBranches = branches.filter(b => b.college_id === college.id);
    if (collegeBranches.length === 0) {
      const bDiv = document.createElement('div');
      bDiv.className = 'tree-branch';
      bDiv.textContent = 'No branches';
      content.appendChild(bDiv);
    } else {
      const branchList = document.createElement('ul');
      branchList.className = 'tree-list';
      collegeBranches.forEach(branch => {
        const branchLi = document.createElement('li');
        // Branch header (collapsible)
        const branchHeader = document.createElement('div');
        branchHeader.className = 'collapsible-header';
        branchHeader.style.background = '#f1f5ff';
        branchHeader.style.color = '#6366f1';
        branchHeader.innerHTML = `<span>🏢 ${branch.name}</span><span class="collapse-icon">▶</span>`;
        branchLi.appendChild(branchHeader);
        // Branch content (hidden by default)
        const branchContent = document.createElement('div');
        branchContent.className = 'collapsible-content';
        branchContent.style.display = 'none';
        // Add Semester inline form
        const addSemRow = document.createElement('div');
        addSemRow.className = 'inline-add-row';
        addSemRow.innerHTML = `
          <input type="text" placeholder="Add semester..." />
          <button>Add Semester</button>
          <span class="inline-feedback"></span>
        `;
        const semInput = addSemRow.querySelector('input');
        const semBtn = addSemRow.querySelector('button');
        const semFeedback = addSemRow.querySelector('.inline-feedback');
        semBtn.onclick = async () => {
          const name = semInput.value.trim();
          if (!name) return;
          await window.supabaseClient.from('semesters').insert([{ name, branch_id: branch.id }]);
          semInput.value = '';
          semFeedback.textContent = 'Added!';
          setTimeout(() => semFeedback.textContent = '', 1500);
          loadHierarchy();
        };
        branchContent.appendChild(addSemRow);
        // Semesters list
        const branchSems = semesters.filter(s => s.branch_id === branch.id);
        if (branchSems.length === 0) {
          const sDiv = document.createElement('div');
          sDiv.className = 'tree-sem';
          sDiv.textContent = 'No semesters';
          branchContent.appendChild(sDiv);
        } else {
          const semList = document.createElement('ul');
          semList.className = 'tree-list';
          branchSems.forEach(sem => {
            const semLi = document.createElement('li');
            semLi.className = 'tree-sem';
            semLi.textContent = `📚 ${sem.name}`;
            semList.appendChild(semLi);
          });
          branchContent.appendChild(semList);
        }
        branchLi.appendChild(branchContent);
        // Branch expand/collapse
        branchHeader.onclick = () => {
          const icon = branchHeader.querySelector('.collapse-icon');
          if (branchContent.style.display === 'none') {
            branchContent.style.display = 'block';
            icon.classList.add('open');
          } else {
            branchContent.style.display = 'none';
            icon.classList.remove('open');
          }
        };
        branchList.appendChild(branchLi);
      });
      content.appendChild(branchList);
    }
    // College expand/collapse
    header.onclick = () => {
      const icon = header.querySelector('.collapse-icon');
      if (content.style.display === 'none') {
        content.style.display = 'block';
        icon.classList.add('open');
      } else {
        content.style.display = 'none';
        icon.classList.remove('open');
      }
    };
    card.appendChild(content);
    view.appendChild(card);
  });
}

// Load all on login
function loadAll() {
  loadBranches();
  loadHierarchy();
}

// Initialize dashboard when page loads
function initDashboard() {
  // Simple auth check - redirect to login if accessed directly
  if (!sessionStorage.getItem('adminLoggedIn')) {
    window.location.href = 'index.html';
    return;
  }
  
  loadAll();
  updateStatistics();
  
  // Add event listeners for select elements
  const branchCollegeSelect = document.getElementById('branchCollegeSelect');
  const semBranchSelect = document.getElementById('semBranchSelect');
  
  if (branchCollegeSelect) {
    branchCollegeSelect.addEventListener('change', loadBranches);
  }
  if (semBranchSelect) {
    semBranchSelect.addEventListener('change', loadSemesters);
  }
}

// Initialize dashboard if we're on the dashboard page
if (document.querySelector('.dashboard-layout')) {
  initDashboard();
}

// Interactive Overview Functions
function showCollegeDetails() {
  document.getElementById('overviewContent').classList.add('hidden');
  document.getElementById('collegeDetails').classList.remove('hidden');
  loadCollegeDetails();
}

function showBranchDetails() {
  document.getElementById('overviewContent').classList.add('hidden');
  document.getElementById('branchDetails').classList.remove('hidden');
  loadBranchDetails();
}

function showSemesterDetails() {
  document.getElementById('overviewContent').classList.add('hidden');
  document.getElementById('semesterDetails').classList.remove('hidden');
  loadSemesterDetails();
}

function hideDetails() {
  document.getElementById('collegeDetails').classList.add('hidden');
  document.getElementById('branchDetails').classList.add('hidden');
  document.getElementById('semesterDetails').classList.add('hidden');
  document.getElementById('overviewContent').classList.remove('hidden');
}

async function loadCollegeDetails() {
  try {
    const { data: colleges } = await window.supabaseClient.from('colleges').select('id, name');
    const { data: branches } = await window.supabaseClient.from('branches').select('id, name, college_id');
    
    const list = document.getElementById('collegeDetailsList');
    list.innerHTML = '';
    
    if (colleges && colleges.length > 0) {
      colleges.forEach(college => {
        const collegeBranches = branches.filter(b => b.college_id === college.id);
        const branchCount = collegeBranches.length;
        
        const item = document.createElement('div');
        item.className = 'detail-item';
        item.innerHTML = `
          <div class="detail-header">
            <div class="detail-title">${college.name}</div>
            <div class="detail-count">${branchCount} branch${branchCount !== 1 ? 'es' : ''}</div>
          </div>
          <div class="detail-subtitle">College ID: ${college.id}</div>
          ${branchCount > 0 ? `
            <div class="detail-children">
              <div style="font-weight: 600; margin-bottom: 8px; color: #6366f1;">Branches:</div>
              ${collegeBranches.map(branch => `
                <div class="child-item">
                  <span>🏢 ${branch.name}</span>
                  <span class="child-count">ID: ${branch.id}</span>
                </div>
              `).join('')}
            </div>
          ` : '<div style="color: #64748b; font-style: italic;">No branches yet</div>'}
        `;
        list.appendChild(item);
      });
    } else {
      list.innerHTML = '<div style="color: #64748b; text-align: center; padding: 20px;">No colleges found. Add colleges first!</div>';
    }
  } catch (error) {
    console.error('Error loading college details:', error);
  }
}

async function loadBranchDetails() {
  try {
    const { data: colleges } = await window.supabaseClient.from('colleges').select('id, name');
    const { data: branches } = await window.supabaseClient.from('branches').select('id, name, college_id');
    const { data: semesters } = await window.supabaseClient.from('semesters').select('id, name, branch_id');
    
    const list = document.getElementById('branchDetailsList');
    list.innerHTML = '';
    
    if (branches && branches.length > 0) {
      branches.forEach(branch => {
        const college = colleges.find(c => c.id === branch.college_id);
        const branchSemesters = semesters.filter(s => s.branch_id === branch.id);
        const semesterCount = branchSemesters.length;
        
        const item = document.createElement('div');
        item.className = 'detail-item';
        item.innerHTML = `
          <div class="detail-header">
            <div class="detail-title">🏢 ${branch.name}</div>
            <div class="detail-count">${semesterCount} semester${semesterCount !== 1 ? 's' : ''}</div>
          </div>
          <div class="detail-subtitle">Under: ${college ? college.name : 'Unknown College'} (ID: ${branch.id})</div>
          ${semesterCount > 0 ? `
            <div class="detail-children">
              <div style="font-weight: 600; margin-bottom: 8px; color: #6366f1;">Semesters:</div>
              ${branchSemesters.map(semester => `
                <div class="child-item">
                  <span>📚 ${semester.name}</span>
                  <span class="child-count">ID: ${semester.id}</span>
                </div>
              `).join('')}
            </div>
          ` : '<div style="color: #64748b; font-style: italic;">No semesters yet</div>'}
        `;
        list.appendChild(item);
      });
    } else {
      list.innerHTML = '<div style="color: #64748b; text-align: center; padding: 20px;">No branches found. Add branches first!</div>';
    }
  } catch (error) {
    console.error('Error loading branch details:', error);
  }
}

async function loadSemesterDetails() {
  try {
    const { data: colleges } = await window.supabaseClient.from('colleges').select('id, name');
    const { data: branches } = await window.supabaseClient.from('branches').select('id, name, college_id');
    const { data: semesters } = await window.supabaseClient.from('semesters').select('id, name, branch_id');
    
    const list = document.getElementById('semesterDetailsList');
    list.innerHTML = '';
    
    if (semesters && semesters.length > 0) {
      semesters.forEach(semester => {
        const branch = branches.find(b => b.id === semester.branch_id);
        const college = branch ? colleges.find(c => c.id === branch.college_id) : null;
        
        const item = document.createElement('div');
        item.className = 'detail-item';
        item.innerHTML = `
          <div class="detail-header">
            <div class="detail-title">📚 ${semester.name}</div>
            <div class="detail-count">Semester</div>
          </div>
          <div class="detail-subtitle">
            Under: ${branch ? branch.name : 'Unknown Branch'} 
            ${college ? `(${college.name})` : ''}
          </div>
          <div class="detail-children">
            <div style="font-weight: 600; margin-bottom: 8px; color: #6366f1;">Hierarchy:</div>
            <div class="child-item">
              <span>🏫 ${college ? college.name : 'Unknown College'}</span>
              <span class="child-count">College</span>
            </div>
            <div class="child-item">
              <span>🏢 ${branch ? branch.name : 'Unknown Branch'}</span>
              <span class="child-count">Branch</span>
            </div>
            <div class="child-item">
              <span>📚 ${semester.name}</span>
              <span class="child-count">Semester</span>
            </div>
          </div>
        `;
        list.appendChild(item);
      });
    } else {
      list.innerHTML = '<div style="color: #64748b; text-align: center; padding: 20px;">No semesters found. Add semesters first!</div>';
    }
  } catch (error) {
    console.error('Error loading semester details:', error);
  }
}

// Mobile Navigation Functions
function toggleMobileMenu() {
  const container = document.getElementById('mobileNavContainer');
  const hamburgerBtn = document.querySelector('.hamburger-btn');
  const body = document.body;
  
  container.classList.toggle('open');
  hamburgerBtn.classList.toggle('active');
  body.classList.toggle('menu-open');
}

function closeMobileMenu() {
  const container = document.getElementById('mobileNavContainer');
  const hamburgerBtn = document.querySelector('.hamburger-btn');
  const body = document.body;
  
  container.classList.remove('open');
  hamburgerBtn.classList.remove('active');
  body.classList.remove('menu-open');
}

function showMobileTab(tab) {
  // Close mobile menu first
  closeMobileMenu();
  
  // Show the selected tab
  showTab(tab);
  
  // Update mobile nav active state
  document.querySelectorAll('.mobile-nav-item').forEach(item => {
    item.classList.remove('active');
  });
  document.querySelector(`.mobile-nav-item[data-tab="${tab}"]`).classList.add('active');
}

// Expose functions to window for HTML access
window.addBranch = addBranch;
window.addSemester = addSemester;
window.showTab = showTab;
window.expandAll = expandAll;
window.collapseAll = collapseAll;
window.logout = logout;
window.showCollegeDetails = showCollegeDetails;
window.showBranchDetails = showBranchDetails;
window.showSemesterDetails = showSemesterDetails;
window.hideDetails = hideDetails;
window.toggleMobileMenu = toggleMobileMenu;
window.closeMobileMenu = closeMobileMenu;
window.showMobileTab = showMobileTab;

// Drill-Down Hierarchy Management JavaScript

// Global state
let currentView = 'overview';
let currentCollege = null;
let currentBranch = null;
let currentSemester = null;

// Check authentication on page load
document.addEventListener('DOMContentLoaded', function() {
  if (!sessionStorage.getItem('adminLoggedIn')) {
    window.location.href = 'index.html';
    return;
  }
  loadStats();
  showOverview();
});

// Navigation Functions
function showOverview() {
  currentView = 'overview';
  document.getElementById('overview-section').classList.remove('hidden');
  document.getElementById('hierarchy-section').classList.add('hidden');
  updateNavigation();
}

function showHierarchy() {
  currentView = 'hierarchy';
  document.getElementById('overview-section').classList.add('hidden');
  document.getElementById('hierarchy-section').classList.remove('hidden');
  showColleges();
  updateNavigation();
}

function showColleges() {
  currentView = 'colleges';
  currentCollege = null;
  currentBranch = null;
  currentSemester = null;
  hideAllViews();
  document.getElementById('collegesView').classList.remove('hidden');
  updateBreadcrumbs();
  loadColleges();
}

function showBranches(collegeId = null) {
  if (collegeId) currentCollege = collegeId;
  currentView = 'branches';
  currentBranch = null;
  currentSemester = null;
  hideAllViews();
  document.getElementById('branchesView').classList.remove('hidden');
  updateBreadcrumbs();
  loadBranches();
}

function showSemesters(branchId = null) {
  if (branchId) currentBranch = branchId;
  currentView = 'semesters';
  currentSemester = null;
  hideAllViews();
  document.getElementById('semestersView').classList.remove('hidden');
  updateBreadcrumbs();
  loadSemesters();
}

function showSubjects(semesterId = null) {
  if (semesterId) currentSemester = semesterId;
  currentView = 'subjects';
  hideAllViews();
  document.getElementById('subjectsView').classList.remove('hidden');
  updateBreadcrumbs();
  loadSubjects();
}

function hideAllViews() {
  document.getElementById('collegesView').classList.add('hidden');
  document.getElementById('branchesView').classList.add('hidden');
  document.getElementById('semestersView').classList.add('hidden');
  document.getElementById('subjectsView').classList.add('hidden');
}

function updateNavigation() {
  // Update sidebar navigation
  document.querySelectorAll('.nav-btn').forEach(btn => btn.classList.remove('active'));
  if (currentView === 'overview') {
    document.querySelector('.nav-btn[onclick="showOverview()"]').classList.add('active');
  } else {
    document.querySelector('.nav-btn[onclick="showHierarchy()"]').classList.add('active');
  }
  
  // Update mobile navigation
  document.querySelectorAll('.mobile-nav-item').forEach(item => item.classList.remove('active'));
  if (currentView === 'overview') {
    document.querySelector('.mobile-nav-item[onclick="showOverview()"]').classList.add('active');
  } else {
    document.querySelector('.mobile-nav-item[onclick="showHierarchy()"]').classList.add('active');
  }
}

function updateBreadcrumbs() {
  // Reset all breadcrumbs
  document.getElementById('branchBreadcrumb').style.display = 'none';
  document.getElementById('semesterBreadcrumb').style.display = 'none';
  document.getElementById('subjectBreadcrumb').style.display = 'none';
  document.getElementById('semesterBreadcrumbSeparator').style.display = 'none';
  document.getElementById('subjectBreadcrumbSeparator').style.display = 'none';
  
  // Show relevant breadcrumbs based on current view
  if (currentView === 'branches' || currentView === 'semesters' || currentView === 'subjects') {
    document.getElementById('branchBreadcrumb').style.display = 'flex';
    if (currentCollege) {
      // Update branch breadcrumb text with college name
      // This would need to be populated when loading branches
    }
  }
  
  if (currentView === 'semesters' || currentView === 'subjects') {
    document.getElementById('semesterBreadcrumb').style.display = 'flex';
    document.getElementById('semesterBreadcrumbSeparator').style.display = 'block';
    if (currentBranch) {
      // Update semester breadcrumb text with branch name
    }
  }
  
  if (currentView === 'subjects') {
    document.getElementById('subjectBreadcrumb').style.display = 'flex';
    document.getElementById('subjectBreadcrumbSeparator').style.display = 'block';
    if (currentSemester) {
      // Update subject breadcrumb text with semester name
    }
  }
}

// Stats Loading
async function loadStats() {
  try {
    const [colleges, branches, semesters, subjects] = await Promise.all([
      window.supabaseClient.from('colleges').select('id', { count: 'exact' }),
      window.supabaseClient.from('branches').select('id', { count: 'exact' }),
      window.supabaseClient.from('semesters').select('id', { count: 'exact' }),
      window.supabaseClient.from('subjects').select('id', { count: 'exact' })
    ]);
    
    document.getElementById('collegeCount').textContent = colleges.count || 0;
    document.getElementById('branchCount').textContent = branches.count || 0;
    document.getElementById('semesterCount').textContent = semesters.count || 0;
    document.getElementById('subjectCount').textContent = subjects.count || 0;
  } catch (error) {
    console.error('Error loading stats:', error);
  }
}

// Data Loading Functions
async function loadColleges() {
  showLoading('Loading colleges...');
  
  // Retry mechanism for Supabase client initialization
  let attempts = 0;
  const maxAttempts = 5;
  
  const attemptLoad = async () => {
    try {
      if (!window.supabaseClient) {
        if (attempts < maxAttempts) {
          attempts++;
          setTimeout(attemptLoad, 500);
          return;
        } else {
          throw new Error('Supabase client not initialized after multiple attempts');
        }
      }
      
      const { data: colleges, error } = await window.supabaseClient
        .from('colleges')
        .select('id, name, created_at')
        .order('name');
      
      if (error) {
        throw error;
      }
      
      displayColleges(colleges || []);
    } catch (error) {
      showMessage(`Error loading colleges: ${error.message}`, true);
    } finally {
      hideLoading();
    }
  };
  
  attemptLoad();
}

async function loadBranches() {
  showLoading('Loading branches...');
  try {
    let query = window.supabaseClient
      .from('branches')
      .select('id, name, created_at, colleges (id, name)')
      .order('name');
    
    if (currentCollege) {
      query = query.eq('college_id', currentCollege);
    }
    
    const { data: branches, error } = await query;
    if (error) throw error;
    displayBranches(branches || []);
  } catch (error) {
    showMessage('Error loading branches', true);
  } finally {
    hideLoading();
  }
}

async function loadSemesters() {
  showLoading('Loading semesters...');
  try {
    let query = window.supabaseClient
      .from('semesters')
      .select('id, name, created_at, branches (id, name, colleges (id, name))')
      .order('name');
    
    if (currentBranch) {
      query = query.eq('branch_id', currentBranch);
    }
    
    const { data: semesters, error } = await query;
    if (error) throw error;
    displaySemesters(semesters || []);
  } catch (error) {
    showMessage('Error loading semesters', true);
  } finally {
    hideLoading();
  }
}

async function loadSubjects() {
  showLoading('Loading subjects...');
  try {
    let query = window.supabaseClient
      .from('subjects')
      .select('id, name, code, description, created_at, semesters (id, name, branches (id, name, colleges (id, name)))')
      .order('name');
    
    if (currentSemester) {
      query = query.eq('semester_id', currentSemester);
    }
    
    const { data: subjects, error } = await query;
    if (error) throw error;
    displaySubjects(subjects || []);
  } catch (error) {
    showMessage('Error loading subjects', true);
  } finally {
    hideLoading();
  }
}

// Display Functions
function displayColleges(colleges) {
  const grid = document.getElementById('collegesGrid');
  if (colleges.length === 0) {
    grid.innerHTML = '<div class="empty-state">No colleges found. Add your first college!</div>';
    return;
  }
  
  grid.innerHTML = colleges.map(college => `
    <div class="hierarchy-card" onclick="showBranches('${college.id}')">
      <div class="hierarchy-card-header">
        <div>
          <div class="hierarchy-card-title">${escapeHtml(college.name)}</div>
          <div class="hierarchy-card-id">ID: ${college.id}</div>
        </div>
      </div>
      <div class="hierarchy-card-stats">
        <div class="stat-badge">🏢 Branches: Loading...</div>
      </div>
      <div class="hierarchy-card-actions">
        <button class="action-btn edit-btn" onclick="event.stopPropagation(); editCollege('${college.id}')">
          ✏️ Edit
        </button>
        <button class="action-btn delete-btn" onclick="event.stopPropagation(); deleteCollege('${college.id}')">
          🗑️ Delete
        </button>
      </div>
    </div>
  `).join('');
}

function displayBranches(branches) {
  const grid = document.getElementById('branchesGrid');
  if (branches.length === 0) {
    grid.innerHTML = '<div class="empty-state">No branches found. Add your first branch!</div>';
    return;
  }
  
  grid.innerHTML = branches.map(branch => `
    <div class="hierarchy-card" onclick="showSemesters('${branch.id}')">
      <div class="hierarchy-card-header">
        <div>
          <div class="hierarchy-card-title">${escapeHtml(branch.name)}</div>
          <div class="hierarchy-card-id">ID: ${branch.id}</div>
        </div>
      </div>
      <div class="hierarchy-card-stats">
        <div class="stat-badge">📚 Semesters: Loading...</div>
        <div class="stat-badge">🏫 ${escapeHtml(branch.colleges ? branch.colleges.name : 'Unknown College')}</div>
      </div>
      <div class="hierarchy-card-actions">
        <button class="action-btn edit-btn" onclick="event.stopPropagation(); editBranch('${branch.id}')">
          ✏️ Edit
        </button>
        <button class="action-btn delete-btn" onclick="event.stopPropagation(); deleteBranch('${branch.id}')">
          🗑️ Delete
        </button>
      </div>
    </div>
  `).join('');
}

function displaySemesters(semesters) {
  const grid = document.getElementById('semestersGrid');
  if (semesters.length === 0) {
    grid.innerHTML = '<div class="empty-state">No semesters found. Add your first semester!</div>';
    return;
  }
  
  grid.innerHTML = semesters.map(semester => `
    <div class="hierarchy-card" onclick="showSubjects('${semester.id}')">
      <div class="hierarchy-card-header">
        <div>
          <div class="hierarchy-card-title">${escapeHtml(semester.name)}</div>
          <div class="hierarchy-card-id">ID: ${semester.id}</div>
        </div>
      </div>
      <div class="hierarchy-card-stats">
        <div class="stat-badge">📖 Subjects: Loading...</div>
        <div class="stat-badge">🏢 ${escapeHtml(semester.branches ? semester.branches.name : 'Unknown Branch')}</div>
        <div class="stat-badge">🏫 ${escapeHtml(semester.branches && semester.branches.colleges ? semester.branches.colleges.name : 'Unknown College')}</div>
      </div>
      <div class="hierarchy-card-actions">
        <button class="action-btn edit-btn" onclick="event.stopPropagation(); editSemester('${semester.id}')">
          ✏️ Edit
        </button>
        <button class="action-btn delete-btn" onclick="event.stopPropagation(); deleteSemester('${semester.id}')">
          🗑️ Delete
        </button>
      </div>
    </div>
  `).join('');
}

function displaySubjects(subjects) {
  const grid = document.getElementById('subjectsGrid');
  if (subjects.length === 0) {
    grid.innerHTML = '<div class="empty-state">No subjects found. Add your first subject!</div>';
    return;
  }
  
  grid.innerHTML = subjects.map(subject => `
    <div class="hierarchy-card">
      <div class="hierarchy-card-header">
        <div>
          <div class="hierarchy-card-title">${escapeHtml(subject.name)}</div>
          <div class="hierarchy-card-id">ID: ${subject.id}</div>
        </div>
      </div>
      ${subject.code ? `<div class="subject-code">📋 ${escapeHtml(subject.code)}</div>` : ''}
      ${subject.description ? `<div class="subject-description">${escapeHtml(subject.description)}</div>` : ''}
      <div class="hierarchy-card-stats">
        <div class="stat-badge">📚 ${escapeHtml(subject.semesters ? subject.semesters.name : 'Unknown Semester')}</div>
        <div class="stat-badge">🏢 ${escapeHtml(subject.semesters && subject.semesters.branches ? subject.semesters.branches.name : 'Unknown Branch')}</div>
        <div class="stat-badge">🏫 ${escapeHtml(subject.semesters && subject.semesters.branches && subject.semesters.branches.colleges ? subject.semesters.branches.colleges.name : 'Unknown College')}</div>
      </div>
      <div class="hierarchy-card-actions">
        <button class="action-btn edit-btn" onclick="editSubject('${subject.id}')">
          ✏️ Edit
        </button>
        <button class="action-btn delete-btn" onclick="deleteSubject('${subject.id}')">
          🗑️ Delete
        </button>
      </div>
    </div>
  `).join('');
}

// Form Management
function showAddCollegeForm() {
  document.getElementById('addFormTitle').textContent = 'Add New College';
  document.getElementById('submitBtnText').textContent = 'Add College';
  document.getElementById('addFormContent').innerHTML = `
    <div class="form-group">
      <label for="collegeName">College Name *</label>
      <input type="text" id="collegeName" placeholder="Enter college name..." required>
    </div>
  `;
  document.getElementById('addFormSection').classList.add('show');
}

function showAddBranchForm() {
  document.getElementById('addFormTitle').textContent = 'Add New Branch';
  document.getElementById('submitBtnText').textContent = 'Add Branch';
  document.getElementById('addFormContent').innerHTML = `
    <div class="form-group">
      <label for="branchCollegeSelect">College *</label>
      <select id="branchCollegeSelect" required>
        <option value="">Select College</option>
      </select>
    </div>
    <div class="form-group">
      <label for="branchName">Branch Name *</label>
      <input type="text" id="branchName" placeholder="Enter branch name..." required>
    </div>
  `;
  loadCollegesForDropdown('branchCollegeSelect');
  document.getElementById('addFormSection').classList.add('show');
}

function showAddSemesterForm() {
  document.getElementById('addFormTitle').textContent = 'Add New Semester';
  document.getElementById('submitBtnText').textContent = 'Add Semester';
  document.getElementById('addFormContent').innerHTML = `
    <div class="form-group">
      <label for="semesterBranchSelect">Branch *</label>
      <select id="semesterBranchSelect" required>
        <option value="">Select Branch</option>
      </select>
    </div>
    <div class="form-group">
      <label for="semesterName">Semester Name *</label>
      <input type="text" id="semesterName" placeholder="Enter semester name..." required>
    </div>
  `;
  loadBranchesForDropdown('semesterBranchSelect');
  document.getElementById('addFormSection').classList.add('show');
}

function showAddSubjectForm() {
  document.getElementById('addFormTitle').textContent = 'Add New Subject';
  document.getElementById('submitBtnText').textContent = 'Add Subject';
  document.getElementById('addFormContent').innerHTML = `
    <div class="form-group">
      <label for="subjectSemesterSelect">Semester *</label>
      <select id="subjectSemesterSelect" required>
        <option value="">Select Semester</option>
      </select>
    </div>
    <div class="form-group">
      <label for="subjectName">Subject Name *</label>
      <input type="text" id="subjectName" placeholder="Enter subject name..." required>
    </div>
    <div class="form-group">
      <label for="subjectCode">Subject Code</label>
      <input type="text" id="subjectCode" placeholder="Enter subject code...">
    </div>
    <div class="form-group">
      <label for="subjectDescription">Description</label>
      <textarea id="subjectDescription" placeholder="Enter description..."></textarea>
    </div>
  `;
  loadSemestersForDropdown('subjectSemesterSelect');
  document.getElementById('addFormSection').classList.add('show');
}

function hideAddForm() {
  document.getElementById('addFormSection').classList.remove('show');
}

// Dropdown Loading Functions
async function loadCollegesForDropdown(selectId) {
  const select = document.getElementById(selectId);
  select.innerHTML = '<option value="">Select College</option>';
  try {
    const { data: colleges, error } = await window.supabaseClient
      .from('colleges')
      .select('id, name')
      .order('name');
    if (error) throw error;
    colleges.forEach(college => {
      const opt = document.createElement('option');
      opt.value = college.id;
      opt.textContent = college.name;
      select.appendChild(opt);
    });
  } catch (error) {
    showMessage('Error loading colleges', true);
  }
}

async function loadBranchesForDropdown(selectId) {
  const select = document.getElementById(selectId);
  select.innerHTML = '<option value="">Select Branch</option>';
  try {
    const { data: branches, error } = await window.supabaseClient
      .from('branches')
      .select('id, name, colleges (id, name)')
      .order('name');
    if (error) throw error;
    branches.forEach(branch => {
      const opt = document.createElement('option');
      opt.value = branch.id;
      opt.textContent = `${branch.name} (${branch.colleges ? branch.colleges.name : 'Unknown College'})`;
      select.appendChild(opt);
    });
  } catch (error) {
    showMessage('Error loading branches', true);
  }
}

async function loadSemestersForDropdown(selectId) {
  const select = document.getElementById(selectId);
  select.innerHTML = '<option value="">Select Semester</option>';
  try {
    const { data: semesters, error } = await window.supabaseClient
      .from('semesters')
      .select('id, name, branches (id, name, colleges (id, name))')
      .order('name');
    if (error) throw error;
    semesters.forEach(semester => {
      const opt = document.createElement('option');
      opt.value = semester.id;
      const branchName = semester.branches ? semester.branches.name : 'Unknown Branch';
      const collegeName = semester.branches && semester.branches.colleges ? semester.branches.colleges.name : 'Unknown College';
      opt.textContent = `${semester.name} (${branchName} - ${collegeName})`;
      select.appendChild(opt);
    });
  } catch (error) {
    showMessage('Error loading semesters', true);
  }
}

// Form Handling
async function handleAdd() {
  const formTitle = document.getElementById('addFormTitle').textContent;
  
  if (formTitle.includes('College')) {
    await addCollege();
  } else if (formTitle.includes('Branch')) {
    await addBranch();
  } else if (formTitle.includes('Semester')) {
    await addSemester();
  } else if (formTitle.includes('Subject')) {
    await addSubject();
  }
}

// CRUD Operations
async function addCollege() {
  const name = document.getElementById('collegeName').value.trim();
  if (!name) {
    showMessage('Please enter a college name', true);
    return;
  }
  
  try {
    const { error } = await window.supabaseClient
      .from('colleges')
      .insert([{ name }]);
    if (error) throw error;
    showMessage('College added successfully!');
    hideAddForm();
    loadStats();
    if (currentView === 'colleges') loadColleges();
  } catch (error) {
    showMessage('Error adding college', true);
  }
}

async function addBranch() {
  const name = document.getElementById('branchName').value.trim();
  const collegeId = document.getElementById('branchCollegeSelect').value;
  
  if (!collegeId) {
    showMessage('Please select a college', true);
    return;
  }
  if (!name) {
    showMessage('Please enter a branch name', true);
    return;
  }
  
  try {
    const { error } = await window.supabaseClient
      .from('branches')
      .insert([{ name, college_id: collegeId }]);
    if (error) throw error;
    showMessage('Branch added successfully!');
    hideAddForm();
    loadStats();
    if (currentView === 'branches') loadBranches();
  } catch (error) {
    showMessage('Error adding branch', true);
  }
}

async function addSemester() {
  const name = document.getElementById('semesterName').value.trim();
  const branchId = document.getElementById('semesterBranchSelect').value;
  
  if (!branchId) {
    showMessage('Please select a branch', true);
    return;
  }
  if (!name) {
    showMessage('Please enter a semester name', true);
    return;
  }
  
  try {
    const { error } = await window.supabaseClient
      .from('semesters')
      .insert([{ name, branch_id: branchId }]);
    if (error) throw error;
    showMessage('Semester added successfully!');
    hideAddForm();
    loadStats();
    if (currentView === 'semesters') loadSemesters();
  } catch (error) {
    showMessage('Error adding semester', true);
  }
}

async function addSubject() {
  const name = document.getElementById('subjectName').value.trim();
  const code = document.getElementById('subjectCode').value.trim();
  const description = document.getElementById('subjectDescription').value.trim();
  const semesterId = document.getElementById('subjectSemesterSelect').value;
  
  if (!semesterId) {
    showMessage('Please select a semester', true);
    return;
  }
  if (!name) {
    showMessage('Please enter a subject name', true);
    return;
  }
  
  try {
    const { error } = await window.supabaseClient
      .from('subjects')
      .insert([{ 
        name, 
        semester_id: semesterId,
        code: code || null,
        description: description || null
      }]);
    if (error) throw error;
    showMessage('Subject added successfully!');
    hideAddForm();
    loadStats();
    if (currentView === 'subjects') loadSubjects();
  } catch (error) {
    showMessage('Error adding subject', true);
  }
}

// Edit and Delete functions (simplified for now)
function editCollege(id) {
  const newName = prompt('Enter new college name:');
  if (!newName || newName.trim() === '') return;
  
  // Implementation would go here
  showMessage('Edit functionality coming soon!');
}

function deleteCollege(id) {
  if (!confirm('Are you sure you want to delete this college?')) return;
  
  // Implementation would go here
  showMessage('Delete functionality coming soon!');
}

function editBranch(id) {
  const newName = prompt('Enter new branch name:');
  if (!newName || newName.trim() === '') return;
  
  // Implementation would go here
  showMessage('Edit functionality coming soon!');
}

function deleteBranch(id) {
  if (!confirm('Are you sure you want to delete this branch?')) return;
  
  // Implementation would go here
  showMessage('Delete functionality coming soon!');
}

function editSemester(id) {
  const newName = prompt('Enter new semester name:');
  if (!newName || newName.trim() === '') return;
  
  // Implementation would go here
  showMessage('Edit functionality coming soon!');
}

function deleteSemester(id) {
  if (!confirm('Are you sure you want to delete this semester?')) return;
  
  // Implementation would go here
  showMessage('Delete functionality coming soon!');
}

function editSubject(id) {
  const newName = prompt('Enter new subject name:');
  if (!newName || newName.trim() === '') return;
  
  // Implementation would go here
  showMessage('Edit functionality coming soon!');
}

function deleteSubject(id) {
  if (!confirm('Are you sure you want to delete this subject?')) return;
  
  // Implementation would go here
  showMessage('Delete functionality coming soon!');
}

// Utility Functions
function showMessage(message, isError = false) {
  const msgElement = document.getElementById('messageDisplay');
  msgElement.textContent = message;
  msgElement.className = `message ${isError ? 'error' : 'success'} show`;
  setTimeout(() => {
    msgElement.classList.remove('show');
  }, 3000);
}

function showLoading(text = 'Loading...') {
  document.getElementById('loadingText').textContent = text;
  document.getElementById('loadingOverlay').classList.remove('hidden');
}

function hideLoading() {
  document.getElementById('loadingOverlay').classList.add('hidden');
}

function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

function logout() {
  sessionStorage.removeItem('adminLoggedIn');
  window.location.href = 'index.html';
}

// Mobile Navigation
function toggleMobileMenu() {
  const container = document.getElementById('mobileNavContainer');
  const hamburgerBtn = document.querySelector('.hamburger-btn');
  const body = document.body;
  
  container.classList.toggle('open');
  hamburgerBtn.classList.toggle('active');
  body.classList.toggle('menu-open');
}

function closeMobileMenu() {
  const container = document.getElementById('mobileNavContainer');
  const hamburgerBtn = document.querySelector('.hamburger-btn');
  const body = document.body;
  
  container.classList.remove('open');
  hamburgerBtn.classList.remove('active');
  body.classList.remove('menu-open');
}

// Make functions globally available
window.showOverview = showOverview;
window.showHierarchy = showHierarchy;
window.showColleges = showColleges;
window.showBranches = showBranches;
window.showSemesters = showSemesters;
window.showSubjects = showSubjects;
window.showAddCollegeForm = showAddCollegeForm;
window.showAddBranchForm = showAddBranchForm;
window.showAddSemesterForm = showAddSemesterForm;
window.showAddSubjectForm = showAddSubjectForm;
window.hideAddForm = hideAddForm;
window.handleAdd = handleAdd;
window.editCollege = editCollege;
window.deleteCollege = deleteCollege;
window.editBranch = editBranch;
window.deleteBranch = deleteBranch;
window.editSemester = editSemester;
window.deleteSemester = deleteSemester;
window.editSubject = editSubject;
window.deleteSubject = deleteSubject;
window.logout = logout;
window.toggleMobileMenu = toggleMobileMenu;
window.closeMobileMenu = closeMobileMenu;
window.hideAllViews = hideAllViews;


 
 