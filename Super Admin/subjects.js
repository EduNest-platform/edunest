// Subject Management JavaScript

// Global variable to store semester data for hierarchy display
let semesterData = [];

// Store all subjects for search functionality
let allSubjects = [];

// --- Syllabus & Timetable Upload Logic ---
let currentSyllabus = null;
let currentTimetable = null;

// Check authentication on page load
document.addEventListener('DOMContentLoaded', function() {
  if (!sessionStorage.getItem('adminLoggedIn')) {
    window.location.href = 'index.html';
    return;
  }
  
  // Try to get selected semester, but allow for no selection
  let selectedSemester = null;
  try {
    selectedSemester = sessionStorage.getItem('selectedSemester') ? JSON.parse(sessionStorage.getItem('selectedSemester')) : null;
  } catch (e) {
    selectedSemester = null;
  }
  
  // Update context UI
  const collegeElem = document.getElementById('contextCollege');
  const branchElem = document.getElementById('contextBranch');
  const semesterElem = document.getElementById('contextSemester');
  if (selectedSemester) {
    if (collegeElem) collegeElem.textContent = selectedSemester.college_name;
    if (branchElem) branchElem.textContent = selectedSemester.branch_name;
    if (semesterElem) semesterElem.textContent = selectedSemester.name;
    const selectedSemesterDisplay = document.getElementById('selectedSemesterDisplay');
    if (selectedSemesterDisplay) selectedSemesterDisplay.textContent = `${selectedSemester.name} (${selectedSemester.branch_name} - ${selectedSemester.college_name})`;
  } else {
    if (collegeElem) collegeElem.textContent = 'All Colleges';
    if (branchElem) branchElem.textContent = 'All Branches';
    if (semesterElem) semesterElem.textContent = 'All Semesters';
    const selectedSemesterDisplay = document.getElementById('selectedSemesterDisplay');
    if (selectedSemesterDisplay) selectedSemesterDisplay.textContent = 'All Semesters';
  }
  
  loadSubjects();
  
  // Add search functionality
  const searchInput = document.getElementById('subjectSearchInput');
  if (searchInput) {
    searchInput.addEventListener('input', function() {
      filterSubjects(this.value);
    });
  }
  
  loadSyllabusTimetable();
  
  // Add Syllabus & Timetable button if semester is selected
  const btnContainer = document.getElementById('syllabusTimetableBtnContainer');
  if (btnContainer) {
    if (selectedSemester) {
      btnContainer.innerHTML = `<button class="submit-btn" style="background:linear-gradient(135deg,#6366f1 0%,#818cf8 100%);margin-top:0;" onclick="window.location.href='syllabus_timetable.html'">
        <span class="btn-icon">📚</span>Manage Syllabus & Timetable
      </button>`;
    } else {
      btnContainer.innerHTML = '';
    }
  }
});

// Utility Functions
function showMessage(message, isError = false) {
  // Create popup element
  const popup = document.createElement('div');
  popup.className = `popup-message ${isError ? 'error' : 'success'}`;
  popup.textContent = message;
  popup.style.cssText = `
    position: fixed;
    top: 20px;
    left: 50%;
    transform: translateX(-50%);
    background: ${isError ? '#ef4444' : '#10b981'};
    color: white;
    padding: 12px 24px;
    border-radius: 8px;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
    z-index: 1000;
    font-weight: 500;
    max-width: 90vw;
    text-align: center;
    animation: slideDown 0.3s ease-out;
  `;
  
  // Add animation styles
  const style = document.createElement('style');
  style.textContent = `
    @keyframes slideDown {
      from { transform: translateX(-50%) translateY(-100%); opacity: 0; }
      to { transform: translateX(-50%) translateY(0); opacity: 1; }
    }
    @keyframes slideUp {
      from { transform: translateX(-50%) translateY(0); opacity: 1; }
      to { transform: translateX(-50%) translateY(-100%); opacity: 0; }
    }
  `;
  document.head.appendChild(style);
  
  document.body.appendChild(popup);
  
  // Remove popup after 3 seconds
  setTimeout(() => {
    popup.style.animation = 'slideUp 0.3s ease-out';
    setTimeout(() => {
      if (popup.parentNode) {
        popup.parentNode.removeChild(popup);
      }
    }, 300);
  }, 3000);
}

function showLoading() {
  document.getElementById('loadingOverlay').classList.remove('hidden');
}

function hideLoading() {
  document.getElementById('loadingOverlay').classList.add('hidden');
}

function clearForm() {
  document.getElementById('subjectName').value = '';
  document.getElementById('subjectCode').value = '';
  document.getElementById('subjectDescription').value = '';
  // Don't clear the semester display since it's always the selected semester
}

// Hierarchy Display Functions
function updateHierarchyDisplay() {
  const semesterSelect = document.getElementById('subjectSemesterSelect');
  const selectedSemesterId = semesterSelect.value;
  
  if (!selectedSemesterId) {
    hideHierarchyDisplay();
    return;
  }
  
  const selectedSemester = semesterData.find(semester => semester.id === selectedSemesterId);
  if (selectedSemester) {
    showHierarchyDisplay(selectedSemester);
  }
}

function showHierarchyDisplay(semester) {
  const hierarchyDisplay = document.getElementById('hierarchyDisplay');
  const selectedCollege = document.getElementById('selectedCollege');
  const selectedBranch = document.getElementById('selectedBranch');
  const selectedSemester = document.getElementById('selectedSemester');
  
  const collegeName = semester.branches && semester.branches.colleges ? 
    semester.branches.colleges.name : 'Unknown College';
  const branchName = semester.branches ? semester.branches.name : 'Unknown Branch';
  const semesterName = semester.name;
  
  selectedCollege.textContent = collegeName;
  selectedBranch.textContent = branchName;
  selectedSemester.textContent = semesterName;
  
  hierarchyDisplay.classList.remove('hidden');
}

function hideHierarchyDisplay() {
  const hierarchyDisplay = document.getElementById('hierarchyDisplay');
  hierarchyDisplay.classList.add('hidden');
}

// Load semesters for dropdown
async function loadSemestersForDropdown() {
  const select = document.getElementById('subjectSemesterSelect');
  select.innerHTML = '<option value="">Select Semester</option>';
  try {
    const { data: semesters, error } = await window.supabaseClient
      .from('semesters')
      .select('id, name, branches (id, name, colleges (id, name))')
      .order('name');
    if (error) throw error;
    
    // Store semester data globally for hierarchy display
    semesterData = semesters || [];
    
    semesterData.forEach(semester => {
      const opt = document.createElement('option');
      opt.value = semester.id;
      const branchName = semester.branches ? semester.branches.name : 'Unknown Branch';
      const collegeName = semester.branches && semester.branches.colleges ? semester.branches.colleges.name : 'Unknown College';
      opt.textContent = `${semester.name} (${branchName} - ${collegeName})`;
      select.appendChild(opt);
    });
  } catch (error) {
    showMessage('Error loading semesters for dropdown.', true);
  }
}

// CRUD Operations
async function addSubject() {
  if (!window.supabaseClient) {
    showMessage('Database connection not available. Please refresh the page.', true);
    return;
  }
  
  const name = document.getElementById('subjectName').value.trim();
  const code = document.getElementById('subjectCode').value.trim();
  const description = document.getElementById('subjectDescription').value.trim();
  
  // Get semester ID from sessionStorage
  let semesterId = null;
  const selectedSemester = sessionStorage.getItem('selectedSemester');
  if (selectedSemester) {
    try {
      const semesterData = JSON.parse(selectedSemester);
      semesterId = semesterData.id;
    } catch (error) {
      console.error('Error parsing selected semester:', error);
    }
  }
  
  if (!semesterId) {
    showMessage('No semester selected. Please go back and select a semester.', true);
    return;
  }
  if (!name) {
    showMessage('Please enter a subject name.', true);
    document.getElementById('subjectName').focus();
    return;
  }
  if (name.length < 2) {
    showMessage('Subject name must be at least 2 characters long.', true);
    document.getElementById('subjectName').focus();
    return;
  }
  
  const submitBtn = document.querySelector('.submit-btn');
  submitBtn.disabled = true;
  submitBtn.innerHTML = '<span class="btn-icon">⏳</span>Adding...';
  
  try {
    const subjectData = { 
      name, 
      semester_id: semesterId,
      code: code || null,
      description: description || null
    };
    const { data, error } = await window.supabaseClient
      .from('subjects')
      .insert([subjectData])
      .select();
    if (error) throw error;
    showMessage('Subject added successfully!');
    clearForm();
    loadSubjects();
  } catch (error) {
    let errorMessage = 'Error adding subject. Please try again.';
    if (error.message) {
      if (error.message.includes('duplicate')) {
        errorMessage = 'A subject with this name already exists in this semester.';
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
    submitBtn.innerHTML = '<span class="btn-icon">➕</span>Add Subject';
  }
}

async function deleteSubject(id) {
  if (!confirm('Are you sure you want to delete this subject? This action cannot be undone.')) return;
  
  try {
    const { error } = await window.supabaseClient
      .from('subjects')
      .delete()
      .eq('id', id);
    if (error) throw error;
    showMessage('Subject deleted successfully!');
    loadSubjects();
  } catch (error) {
    showMessage('Error deleting subject. Please try again.', true);
  }
}

async function editSubject(id) {
  const newName = prompt('Enter new subject name:');
  if (!newName || newName.trim() === '') return;
  
  const newCode = prompt('Enter new subject code (optional):');
  const newDescription = prompt('Enter new description (optional):');
  
  try {
    const updateData = { name: newName.trim() };
    if (newCode !== null) updateData.code = newCode.trim() || null;
    if (newDescription !== null) updateData.description = newDescription.trim() || null;
    
    const { error } = await window.supabaseClient
      .from('subjects')
      .update(updateData)
      .eq('id', id);
    if (error) throw error;
    showMessage('Subject updated successfully!');
    loadSubjects();
  } catch (error) {
    showMessage('Error updating subject. Please try again.', true);
  }
}

async function loadSubjects() {
  showLoading();
  try {
    let query = window.supabaseClient
      .from('subjects')
      .select('*, semesters (id, name, branches (id, name, colleges (id, name)))')
      .order('name');

    // Only filter if a semester is selected
    let selectedSemester = null;
    try {
      selectedSemester = sessionStorage.getItem('selectedSemester') ? JSON.parse(sessionStorage.getItem('selectedSemester')) : null;
    } catch (e) {
      selectedSemester = null;
    }
    if (selectedSemester) {
      query = query.eq('semester_id', selectedSemester.id);
    }

    const { data: subjects, error } = await query;
    if (error) throw error;

    allSubjects = subjects || [];
    displaySubjects(allSubjects);
  } catch (error) {
    showMessage('Error loading subjects. Please refresh the page.', true);
    allSubjects = [];
    displaySubjects([]);
  } finally {
    hideLoading();
  }
}

function filterSubjects(query) {
  query = query.trim().toLowerCase();
  if (!query) {
    displaySubjects(allSubjects);
    return;
  }
  const filtered = allSubjects.filter(subject =>
    (subject.name || '').toLowerCase().includes(query) ||
    (subject.code || '').toLowerCase().includes(query)
  );
  displaySubjects(filtered);
}

function displaySubjects(subjects) {
  const subjectList = document.getElementById('subjectList');
  const emptyState = document.getElementById('emptyState');
  const subjectCount = document.getElementById('subjectCount');
  if (subjectCount) {
    subjectCount.textContent = subjects.length;
  } else {
    console.warn('subjectCount element not found in DOM');
  }
  if (!subjectList) {
    console.warn('subjectList element not found in DOM');
    return;
  }
  if (!emptyState) {
    console.warn('emptyState element not found in DOM');
    return;
  }
  if (subjects.length === 0) {
    subjectList.innerHTML = '';
    emptyState.classList.remove('hidden');
    // Update empty state message based on whether we're filtering
    const selectedSemester = sessionStorage.getItem('selectedSemester');
    if (selectedSemester) {
      try {
        const semesterData = JSON.parse(selectedSemester);
        emptyState.innerHTML = `
          <div class="empty-icon">📖</div>
          <h3>No Subjects Found</h3>
          <p>No subjects found for ${semesterData.name}. Start by adding your first subject above.</p>
        `;
      } catch (error) {
        console.error('Error parsing selected semester:', error);
      }
    }
    return;
  }
  emptyState.classList.add('hidden');
  subjectList.innerHTML = subjects.map(subject => {
    const semesterName = subject.semesters ? subject.semesters.name : 'Unknown Semester';
    const branchName = subject.semesters && subject.semesters.branches ? subject.semesters.branches.name : 'Unknown Branch';
    const collegeName = subject.semesters && subject.semesters.branches && subject.semesters.branches.colleges ? 
      subject.semesters.branches.colleges.name : 'Unknown College';
    return `
      <div class="subject-card">
        <div class="subject-header">
          <div>
            <div class="subject-name">${escapeHtml(subject.name)}</div>
            <div class="subject-id">ID: ${subject.id}</div>
          </div>
        </div>
        ${subject.code ? `<div class="subject-code">📋 ${escapeHtml(subject.code)}</div>` : ''}
        ${subject.description ? `<div class="subject-description">${escapeHtml(subject.description)}</div>` : ''}
        <div class="subject-hierarchy">
          <div class="hierarchy-item">
            📚 ${escapeHtml(semesterName)}
          </div>
          <div class="hierarchy-item">
            🏢 ${escapeHtml(branchName)}
          </div>
          <div class="hierarchy-item">
            🏫 ${escapeHtml(collegeName)}
          </div>
        </div>
        <div class="subject-actions">
          <button class="action-btn view-btn" onclick="manageFiles('${subject.id}', '${escapeHtml(subject.name)}', '${subject.semesters ? subject.semesters.id : 'null'}', '${escapeHtml(subject.semesters ? subject.semesters.name : 'Unknown')}', '${subject.semesters && subject.semesters.branches ? subject.semesters.branches.id : 'null'}', '${escapeHtml(subject.semesters && subject.semesters.branches ? subject.semesters.branches.name : 'Unknown')}', '${subject.semesters && subject.semesters.branches && subject.semesters.branches.colleges ? subject.semesters.branches.colleges.id : 'null'}', '${escapeHtml(subject.semesters && subject.semesters.branches && subject.semesters.branches.colleges ? subject.semesters.branches.colleges.name : 'Unknown')}')">
            📁 Manage Files
          </button>
          <button class="action-btn edit-btn" onclick="editSubject(${subject.id})">
            ✏️ Edit
          </button>
          <button class="action-btn delete-btn" onclick="deleteSubject(${subject.id})">
            🗑️ Delete
          </button>
        </div>
      </div>
    `;
  }).join('');
}

function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

// Manage files for a specific subject
function manageFiles(subjectId, subjectName, semesterId, semesterName, branchId, branchName, collegeId, collegeName) {
  // Store subject, semester, branch, and college info in sessionStorage for the files page
  const subjectData = {
    id: subjectId,
    name: subjectName,
    semester_id: semesterId,
    semester_name: semesterName,
    branch_id: branchId,
    branch_name: branchName,
    college_id: collegeId,
    college_name: collegeName,
    // Add additional context for the files page
    college: collegeName,
    branch: branchName,
    semester: semesterName
  };
  
  sessionStorage.setItem('selectedSubject', JSON.stringify(subjectData));
  
  // Navigate to files page
  window.location.href = 'files.html';
}

function logout() {
  sessionStorage.removeItem('adminLoggedIn');
  window.location.href = 'index.html';
}

window.addSubject = addSubject;
window.deleteSubject = deleteSubject;
window.editSubject = editSubject;
window.manageFiles = manageFiles;
window.logout = logout;
window.updateHierarchyDisplay = updateHierarchyDisplay;

// --- Syllabus & Timetable Upload Logic ---
// SQL to create the new table in Supabase:
//
// create table syllabus_timetable (
//   id uuid primary key default uuid_generate_v4(),
//   college_id uuid references colleges(id),
//   branch_id uuid references branches(id),
//   semester_id uuid references semesters(id),
//   type text check (type in ('syllabus', 'timetable')),
//   name text,
//   description text,
//   file_url text,
//   file_size integer,
//   mime_type text,
//   storage_key text,
//   uploaded_by text,
//   created_at timestamp with time zone default timezone('utc'::text, now())
// );

// Utility to format file size
function formatFileSize(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
}

// Fetch and display current syllabus/timetable for selected semester
async function loadSyllabusTimetable() {
  const selectedSemester = sessionStorage.getItem('selectedSemester');
  if (!selectedSemester) return;
  const semesterData = JSON.parse(selectedSemester);
  const semesterId = semesterData.id;
  // Syllabus
  try {
    const { data: syllabus, error: syllabusError } = await window.supabaseClient
      .from('syllabus_timetable')
      .select('*')
      .eq('type', 'syllabus')
      .eq('semester_id', semesterId)
      .maybeSingle();
    if (syllabusError) throw syllabusError;
    currentSyllabus = syllabus;
    renderSyllabusInfo();
  } catch (e) {
    currentSyllabus = null;
    renderSyllabusInfo();
  }
  // Timetable
  try {
    const { data: timetable, error: timetableError } = await window.supabaseClient
      .from('syllabus_timetable')
      .select('*')
      .eq('type', 'timetable')
      .eq('semester_id', semesterId)
      .maybeSingle();
    if (timetableError) throw timetableError;
    currentTimetable = timetable;
    renderTimetableInfo();
  } catch (e) {
    currentTimetable = null;
    renderTimetableInfo();
  }
}

function renderSyllabusInfo() {
  const infoDiv = document.getElementById('syllabusFileInfo');
  const formDiv = document.getElementById('syllabusUploadFormContainer');
  if (!infoDiv) return; // Prevent error if element is missing
  if (currentSyllabus) {
    infoDiv.style.display = '';
    if (formDiv) formDiv.style.display = 'none';
    infoDiv.innerHTML = `
      <div class="file-info-card">
        <div class="file-info-header">
          <span class="file-info-icon">📄</span>
          <div>
            <span class="file-info-title">Current Syllabus</span><br>
            <a class="file-info-link" href="${currentSyllabus.file_url}" target="_blank">${currentSyllabus.name}</a>
          </div>
        </div>
        <div class="file-info-meta">
          <span>${formatFileSize(currentSyllabus.file_size)}</span>
          <span class="file-info-sep">•</span>
          <span>${currentSyllabus.mime_type}</span>
        </div>
        ${currentSyllabus.description ? `<div class="file-info-desc">${currentSyllabus.description}</div>` : ''}
        <button type="button" class="submit-btn file-info-replace-btn" onclick="showSyllabusReplaceForm()"><span class="btn-icon">♻️</span>Replace Syllabus</button>
      </div>
    `;
  } else {
    infoDiv.style.display = 'none';
    if (formDiv) formDiv.style.display = '';
  }
}

function renderTimetableInfo() {
  const infoDiv = document.getElementById('timetableFileInfo');
  if (currentTimetable) {
    infoDiv.innerHTML = `
      <div class="file-info-card">
        <div class="file-info-header">
          <span class="file-info-icon">🕒</span>
          <div>
            <span class="file-info-title">Current Timetable</span><br>
            <a class="file-info-link" href="${currentTimetable.file_url}" target="_blank">${currentTimetable.name}</a>
          </div>
        </div>
        <div class="file-info-meta">
          <span>${formatFileSize(currentTimetable.file_size)}</span>
          <span class="file-info-sep">•</span>
          <span>${currentTimetable.mime_type}</span>
        </div>
        ${currentTimetable.description ? `<div class="file-info-desc">${currentTimetable.description}</div>` : ''}
        <button type="button" class="submit-btn file-info-replace-btn" onclick="showTimetableReplaceForm()"><span class="btn-icon">♻️</span>Replace Timetable</button>
      </div>
    `;
  } else {
    infoDiv.innerHTML = '';
  }
}

window.showSyllabusReplaceForm = function() {
  // Hide info card, show upload form, clear inputs
  const infoDiv = document.getElementById('syllabusFileInfo');
  const formDiv = document.getElementById('syllabusUploadFormContainer');
  if (infoDiv) infoDiv.style.display = 'none';
  if (formDiv) formDiv.style.display = '';
  const fileInput = document.getElementById('syllabusFileInput');
  if (fileInput) fileInput.value = '';
};
window.showTimetableReplaceForm = function() {
  document.getElementById('timetableFileInput').value = '';
};

// After successful upload, reload info
async function uploadSyllabus() {
  const selectedSemester = sessionStorage.getItem('selectedSemester');
  if (!selectedSemester) {
    showMessage('No semester selected. Please select a semester.', true);
    return;
  }
  const semesterData = JSON.parse(selectedSemester);
  const semesterId = semesterData.id;
  const collegeId = semesterData.college_id;
  const branchId = semesterData.branch_id;
  const fileName = document.getElementById('syllabusFileName').value.trim();
  const description = document.getElementById('syllabusDescription').value.trim();
  const fileInput = document.getElementById('syllabusFileInput');
  if (!fileName || !fileInput.files[0]) {
    showMessage('Please provide a file name and select a syllabus file.', true);
    return;
  }
  const file = fileInput.files[0];
  showLoading();
  try {
    // Check for existing syllabus for this semester
    const { data: existing, error: fetchError } = await window.supabaseClient
      .from('syllabus_timetable')
      .select('*')
      .eq('type', 'syllabus')
      .eq('semester_id', semesterId)
      .maybeSingle();
    if (fetchError) throw fetchError;
    if (existing && existing.storage_key) {
      await window.supabaseClient.storage.from('edunest-files').remove([existing.storage_key]);
      await window.supabaseClient.from('syllabus_timetable').delete().eq('id', existing.id);
    }
    // Upload to Supabase Storage
    const storageKey = `syllabus_${semesterId}_${Date.now()}_${file.name}`;
    const { data: uploadData, error: uploadError } = await window.supabaseClient.storage
      .from('edunest-files')
      .upload(storageKey, file);
    if (uploadError) throw uploadError;
    const { data: urlData } = window.supabaseClient.storage
      .from('edunest-files')
      .getPublicUrl(storageKey);
    const fileUrl = urlData.publicUrl;
    // Save to DB
    const insertPayload = {
      college_id: collegeId,
      branch_id: branchId,
      semester_id: semesterId,
      type: 'syllabus',
      name: fileName,
      description,
      file_url: fileUrl,
      file_size: file.size,
      mime_type: file.type,
      storage_key: storageKey,
      uploaded_by: 'Admin'
    };
    const { data: dbData, error: dbError } = await window.supabaseClient
      .from('syllabus_timetable')
      .insert(insertPayload)
      .select()
      .single();
    if (dbError) throw dbError;
    currentSyllabus = dbData;
    showMessage('Syllabus uploaded successfully!');
    renderSyllabusInfo();
  } catch (error) {
    showMessage('Failed to upload syllabus: ' + (error.message || error), true);
  } finally {
    hideLoading();
  }
}

async function uploadTimetable() {
  const selectedSemester = sessionStorage.getItem('selectedSemester');
  if (!selectedSemester) {
    showMessage('No semester selected. Please select a semester.', true);
    return;
  }
  const semesterData = JSON.parse(selectedSemester);
  const semesterId = semesterData.id;
  const collegeId = semesterData.college_id;
  const branchId = semesterData.branch_id;
  const fileName = document.getElementById('timetableFileName').value.trim();
  const description = document.getElementById('timetableDescription').value.trim();
  const fileInput = document.getElementById('timetableFileInput');
  if (!fileName || !fileInput.files[0]) {
    showMessage('Please provide a file name and select a timetable file.', true);
    return;
  }
  const file = fileInput.files[0];
  showLoading();
  try {
    // Check for existing timetable for this semester
    const { data: existing, error: fetchError } = await window.supabaseClient
      .from('syllabus_timetable')
      .select('*')
      .eq('type', 'timetable')
      .eq('semester_id', semesterId)
      .maybeSingle();
    if (fetchError) throw fetchError;
    if (existing && existing.storage_key) {
      await window.supabaseClient.storage.from('edunest-files').remove([existing.storage_key]);
      await window.supabaseClient.from('syllabus_timetable').delete().eq('id', existing.id);
    }
    // Upload to Supabase Storage
    const storageKey = `timetable_${semesterId}_${Date.now()}_${file.name}`;
    const { data: uploadData, error: uploadError } = await window.supabaseClient.storage
      .from('edunest-files')
      .upload(storageKey, file);
    if (uploadError) throw uploadError;
    const { data: urlData } = window.supabaseClient.storage
      .from('edunest-files')
      .getPublicUrl(storageKey);
    const fileUrl = urlData.publicUrl;
    // Save to DB
    const { data: dbData, error: dbError } = await window.supabaseClient
      .from('syllabus_timetable')
      .insert({
        college_id: collegeId,
        branch_id: branchId,
        semester_id: semesterId,
        type: 'timetable',
        name: fileName,
        description,
        file_url: fileUrl,
        file_size: file.size,
        mime_type: file.type,
        storage_key: storageKey,
        uploaded_by: 'Admin'
      })
      .select()
      .single();
    if (dbError) throw dbError;
    currentTimetable = dbData;
    showMessage('Timetable uploaded successfully!');
    renderTimetableInfo();
  } catch (error) {
    showMessage('Failed to upload timetable: ' + (error.message || error), true);
  } finally {
    hideLoading();
  }
}

window.uploadSyllabus = uploadSyllabus;
window.uploadTimetable = uploadTimetable; 