// Midsem Marks Management - Using class_assignment_marks table with assignment_type = 'midsem'
let currentUser = null;
let currentClassId = null;
let currentSubjectName = null;
let midsemExams = []; // Unique midsem exams for this class
let students = [];
let allMarksData = []; // All marks data from the table
let editingMarkData = null;

// Initialize page
document.addEventListener('DOMContentLoaded', async function() {
  // Check authentication
  if (!sessionStorage.getItem('adminLoggedIn')) {
    window.location.href = 'index.html';
    return;
  }

  // Get class context from URL or sessionStorage
  const urlParams = new URLSearchParams(window.location.search);
  currentClassId = urlParams.get('classId') || sessionStorage.getItem('selectedClassId');
  currentSubjectName = urlParams.get('subject') || sessionStorage.getItem('selectedSubjectName');

  if (!currentClassId) {
    showMessage('No class selected. Redirecting...', 'error');
    setTimeout(() => {
      window.location.href = 'attendance.html';
    }, 2000);
    return;
  }

  // Initialize Supabase clients
  await initializeSupabaseClients();
  
  // Load initial data
  await loadPageData();
});

// Initialize Supabase clients
async function initializeSupabaseClients() {
  try {
    // Wait for clients to be initialized
    let attempts = 0;
    while ((!window.supabaseClient || !window.supabaseAdmin) && attempts < 50) {
      await new Promise(resolve => setTimeout(resolve, 100));
      attempts++;
    }

    if (!window.supabaseClient || !window.supabaseAdmin) {
      throw new Error('Supabase clients not initialized');
    }

    // Get current user
    const user = await window.authManager.getCurrentUser();
    if (!user) {
      throw new Error('User not authenticated');
    }
    currentUser = user;

  } catch (error) {
    console.error('Error initializing:', error);
    showMessage('Failed to initialize. Please refresh the page.', 'error');
  }
}

// Load page data
async function loadPageData() {
  try {
    showLoading();
    
    // Update class context
    updateClassContext();
    
    // Load students from class roster
    await loadClassStudents();
    
    // Load midsem marks data
    await loadMidsemMarks();
    
    // Process data and render table
    processMidsemData();
    renderMarksTable();
    
    hideLoading();
    
  } catch (error) {
    console.error('Error loading data:', error);
    showMessage('Failed to load data. Please try again.', 'error');
    hideLoading();
  }
}

// Update class context display
function updateClassContext() {
  const contextElement = document.getElementById('contextClass');
  if (contextElement && currentSubjectName) {
    contextElement.textContent = `${currentSubjectName} - Midsem Marks`;
  }
}

// Load students for the current class
async function loadClassStudents() {
  try {
    const { data, error } = await window.supabaseClient
      .from('class_rosters')
      .select('*')
      .eq('class_id', currentClassId)
      .order('student_name');

    if (error) throw error;

    students = data || [];
    
    // Sort students by roll number
    students.sort((a, b) => {
      const rollA = a.roll_number || '';
      const rollB = b.roll_number || '';
      
      // Extract numeric part from roll numbers (e.g., "401/23" -> 401)
      const numA = parseInt(rollA.split('/')[0]) || 0;
      const numB = parseInt(rollB.split('/')[0]) || 0;
      
      return numA - numB;
    });
    
    console.log(`Loaded and sorted ${students.length} students for class`);

  } catch (error) {
    console.error('Error loading students:', error);
    throw error;
  }
}

// Load midsem marks data
async function loadMidsemMarks() {
  try {
    const { data, error } = await window.supabaseClient
      .from('class_assignment_marks')
      .select('*')
      .eq('class_id', currentClassId)
      .like('assignment_name', 'Midsem:%')
      .order('assignment_name', { ascending: true });

    if (error) throw error;
    allMarksData = data || [];
    
    // Debug: Log fetched midsem data
    console.log('DEBUG: Loaded midsem marks data:', allMarksData.length, 'records');
    if (allMarksData.length > 0) {
      console.log('DEBUG: Sample midsem record:', allMarksData[0]);
      console.log('DEBUG: Assignment names found:', [...new Set(allMarksData.map(r => r.assignment_name))]);
      console.log('DEBUG: Student IDs in marks data:', allMarksData.map(r => r.student_id));
      console.log('DEBUG: Roll numbers in marks data:', allMarksData.map(r => r.roll_number));
    }
    console.log('Loaded midsem marks:', allMarksData.length);
    
  } catch (error) {
    console.error('Error loading midsem marks:', error);
    allMarksData = [];
  }
}

// Process midsem data to get unique exams
function processMidsemData() {
  // Get unique midsem exams
  const uniqueExams = new Map();
  
  allMarksData.forEach(record => {
    if (!uniqueExams.has(record.assignment_name)) {
      uniqueExams.set(record.assignment_name, {
        name: record.assignment_name,
        description: record.assignment_description,
        maxMarks: record.max_marks
      });
    }
  });

  midsemExams = Array.from(uniqueExams.values());
  console.log('Processed midsem exams:', midsemExams.length, midsemExams);
}

// Render the marks table
function renderMarksTable() {
  const midsemSection = document.getElementById('midsemSection');
  const noDataState = document.getElementById('noDataState');
  const marksTableBody = document.getElementById('marksTableBody');

  if (students.length === 0) {
    midsemSection.classList.add('hidden');
    noDataState.classList.remove('hidden');
    return;
  }

  midsemSection.classList.remove('hidden');
  noDataState.classList.add('hidden');

  // Render table header
  renderTableHeader();

  // Render table body
  marksTableBody.innerHTML = students.map(student => {
    console.log('Rendering student:', student);
    const examCells = midsemExams.map(exam => {
      // Find existing marks for this student and exam
      const existingRecord = allMarksData.find(record => 
        record.assignment_name === exam.name && 
        record.student_id === student.student_profile_id
      );
      
      const marks = existingRecord?.marks || '';
      
      // Debug log for first few students
      if (student.roll_number === '100/25' || student.roll_number === '101/25') {
        console.log(`DEBUG: Student ${student.roll_number} - Found record:`, existingRecord);
        console.log(`DEBUG: Marks value: "${marks}"`);
      }
      
      return `
        <td>
          <input type="number" 
                 class="marks-input" 
                 min="0" 
                 max="${exam.maxMarks}" 
                 value="${marks}"
                 placeholder="0"
                 data-assignment-name="${exam.name}"
                 data-student-id="${student.student_profile_id}"
                 data-max-marks="${exam.maxMarks}"
                 data-original-value="${marks}">
        </td>
      `;
    }).join('');

    return `
      <tr>
        <td class="student-cell">
          <div class="student-info">
            <div class="student-name">${student.student_name}</div>
            <div class="student-details">
              ${student.roll_number ? `Roll: ${student.roll_number}` : ''}
              ${student.roll_number && student.student_email ? ' • ' : ''}
              ${student.student_email || ''}
            </div>
          </div>
        </td>
        ${examCells}
      </tr>
    `;
  }).join('');

  // Add event listeners to inputs
  addInputEventListeners();
}

// Render table header
function renderTableHeader() {
  const marksTable = document.getElementById('marksTable');
  const thead = marksTable.querySelector('thead tr');
  const noMidsemHeader = document.getElementById('noMidsemHeader');

  if (midsemExams.length === 0) {
    noMidsemHeader.style.display = 'table-cell';
    // Remove any existing exam headers
    const examHeaders = thead.querySelectorAll('.assignment-column');
    examHeaders.forEach(header => header.remove());
    return;
  }

  noMidsemHeader.style.display = 'none';

  // Remove existing exam headers
  const existingHeaders = thead.querySelectorAll('.assignment-column');
  existingHeaders.forEach(header => header.remove());

  // Add exam headers
  midsemExams.forEach(exam => {
    const th = document.createElement('th');
    th.className = 'assignment-column';
    th.innerHTML = `
      <div class="assignment-header">
        <div class="assignment-title">${exam.name}</div>
        <div class="assignment-max-marks">Max: ${exam.maxMarks}</div>
      </div>
    `;
    thead.appendChild(th);
  });
}

// Add event listeners to mark inputs
function addInputEventListeners() {
  const inputs = document.querySelectorAll('.marks-input');
  inputs.forEach(input => {
    input.addEventListener('change', function() {
      const marks = parseFloat(this.value) || null;
      const maxMarks = parseInt(this.dataset.maxMarks);
      
      if (marks !== null && marks > maxMarks) {
        this.value = maxMarks;
        showMessage(`Marks cannot exceed maximum marks (${maxMarks})`, 'error');
      }
    });
  });
}

// Show add midsem modal
function showAddMidsemModal() {
  document.getElementById('modalTitle').textContent = 'Add Midsem';
  document.getElementById('midsemForm').reset();
  document.getElementById('midsemModal').style.display = 'flex';
}

// Close midsem modal
function closeMidsemModal() {
  document.getElementById('midsemModal').style.display = 'none';
}

// Save midsem exam
async function saveMidsemExam() {
  const examName = document.getElementById('examName').value.trim();
  const examDescription = document.getElementById('examDescription').value.trim();
  const maxMarks = parseInt(document.getElementById('maxMarks').value);

  if (!examName || !maxMarks) {
    showMessage('Please fill in all required fields.', 'error');
    return;
  }

  // Prefix with "Midsem:" to distinguish from regular assignments
  const fullExamName = `Midsem: ${examName}`;
  
  // Debug: Log the exam name being saved
  console.log('DEBUG: Creating midsem exam with name:', fullExamName);
  console.log('DEBUG: Original exam name entered:', examName);

  // Check if exam name already exists
  if (midsemExams.some(exam => exam.name === fullExamName)) {
    showMessage('An exam with this name already exists.', 'error');
    return;
  }

  try {
    // Create placeholder records for all students
    const records = students.map(student => ({
      class_id: currentClassId,
      assignment_name: fullExamName,
      assignment_description: examDescription || null,
      max_marks: maxMarks,
      student_id: student.student_profile_id || student.id, // Use roster ID as fallback
      student_name: student.student_name,
      student_roll: student.roll_number,
      student_email: student.student_email,
      marks: null,
      graded_at: null,
      graded_by: currentUser.id,
      subject_name: currentSubjectName
    }));

    // Debug: Log the records being inserted
    console.log('DEBUG: Inserting midsem records:', records.length, 'records');
    console.log('DEBUG: Sample record:', records[0]);
    
    const { error } = await window.supabaseClient
      .from('class_assignment_marks')
      .insert(records);

    if (error) throw error;
    
    // Debug: Confirm successful insertion
    console.log('DEBUG: Midsem exam created successfully in database');

    showMessage('Midsem exam created successfully!', 'success');
    closeMidsemModal();
    await loadPageData();

  } catch (error) {
    console.error('Error creating midsem exam:', error);
    showMessage('Failed to create midsem exam. Please try again.', 'error');
  }
}

// Save all marks
async function saveAllMarks() {
  // Prevent multiple clicks
  const saveButton = document.querySelector('.save-all-btn');
  if (saveButton.disabled) {
    return;
  }
  
  saveButton.disabled = true;
  saveButton.innerHTML = '<span class="btn-icon">⏳</span>Saving...';
  
  try {
    const inputs = document.querySelectorAll('.marks-input');
    const updates = [];

    inputs.forEach(input => {
      const marks = parseFloat(input.value) || null;
      const examName = input.dataset.assignmentName;
      const studentId = input.dataset.studentId;
      const originalValue = input.dataset.originalValue;
      
      // Only include if marks have actually changed
      if (marks !== null && marks.toString() !== originalValue) {
        const maxMarks = parseInt(input.dataset.maxMarks);
        
        // Find student info for required fields
        const student = students.find(s => s.student_profile_id === studentId);
        const exam = midsemExams.find(e => e.name === examName);
        
        updates.push({
          class_id: currentClassId,
          assignment_name: examName,
          student_id: studentId,
          student_name: student?.student_name || 'Unknown',
          student_roll: student?.roll_number || '',
          student_email: student?.student_email || '',
          marks: marks,
          max_marks: maxMarks,
          assignment_description: exam?.description || '',
          subject_name: currentSubjectName || '',
          graded_at: new Date().toISOString(),
          graded_by: currentUser.id
        });
      }
    });

    if (updates.length === 0) {
      showMessage('No changes to save.', 'info');
      return;
    }

    console.log(` Saving ${updates.length} changed marks...`);

    // Use batch upsert for better performance
    const { error } = await window.supabaseClient
      .from('class_assignment_marks')
      .upsert(updates.map(update => ({
        class_id: update.class_id,
        assignment_name: update.assignment_name,
        student_id: update.student_id,
        student_name: update.student_name,
        student_roll: update.student_roll,
        student_email: update.student_email,
        marks: update.marks,
        max_marks: update.max_marks,
        assignment_description: update.assignment_description,
        subject_name: update.subject_name,
        graded_at: update.graded_at,
        graded_by: update.graded_by
      })), {
        onConflict: 'class_id,assignment_name,student_id'
      });

    if (error) throw error;

    // Update local data
    updates.forEach(update => {
      const existingRecord = allMarksData.find(record => 
        record.assignment_name === update.assignment_name && 
        record.student_id === update.student_id
      );
      if (existingRecord) {
        existingRecord.marks = update.marks;
        existingRecord.graded_at = update.graded_at;
        existingRecord.graded_by = update.graded_by;
      }
    });

    showMessage(`Saved marks for ${updates.length} entries!`, 'success');
    
    // Update input original values and visual feedback
    const inputs2 = document.querySelectorAll('.marks-input');
    inputs2.forEach(input => {
      // Update original value to current value
      input.dataset.originalValue = input.value;
      
      if (input.value) {
        input.style.borderColor = '#10b981';
        setTimeout(() => {
          input.style.borderColor = '#e2e8f0';
        }, 2000);
      }
    });

  } catch (error) {
    console.error('Error saving marks:', error);
    showMessage('Failed to save marks. Please try again.', 'error');
  } finally {
    // Re-enable save button
    saveButton.disabled = false;
    saveButton.innerHTML = '<span class="btn-icon">💾</span>Save All Marks';
  }
}

// Show delete midsem modal
function showDeleteMidsemModal() {
  if (midsemExams.length === 0) {
    showMessage('No midsem exams to delete.', 'error');
    return;
  }
  
  const examOptions = midsemExams.map(exam => 
    `<option value="${exam.name}">${exam.name} (Max: ${exam.maxMarks})</option>`
  ).join('');
  
  const modalHtml = `
    <div class="modal-overlay" id="deleteMidsemModal" style="display: flex; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.5); z-index: 1000; align-items: center; justify-content: center;">
      <div class="modal-content" style="background: white; padding: 2rem; border-radius: 8px; max-width: 500px; width: 90%; max-height: 80vh; overflow-y: auto;">
        <div class="modal-header" style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem;">
          <h3 style="margin: 0;">Delete Midsem Exam</h3>
          <button class="modal-close" onclick="closeDeleteMidsemModal()" style="background: none; border: none; font-size: 1.5rem; cursor: pointer;">&times;</button>
        </div>
        <div class="modal-body" style="margin-bottom: 1.5rem;">
          <label for="deleteMidsemSelect" style="display: block; margin-bottom: 0.5rem;">Select a midsem exam to delete:</label>
          <select id="deleteMidsemSelect" class="form-select" style="width: 100%; padding: 0.5rem; border: 1px solid #ccc; border-radius: 4px;">
            <option value="">Select Midsem Exam</option>
            ${examOptions}
          </select>
          <p class="warning-text" style="color: #ef4444; margin-top: 1rem; font-size: 0.9rem;">⚠️ This will permanently delete all marks for this exam.</p>
        </div>
        <div class="modal-footer" style="display: flex; gap: 1rem; justify-content: flex-end;">
          <button type="button" class="btn btn-secondary" onclick="closeDeleteMidsemModal()" style="padding: 0.5rem 1rem; border: 1px solid #ccc; background: #f8f9fa; cursor: pointer; border-radius: 4px;">Cancel</button>
          <button type="button" class="btn btn-danger" onclick="deleteMidsemExam()" style="padding: 0.5rem 1rem; border: none; background: #dc3545; color: white; cursor: pointer; border-radius: 4px;">Delete Exam</button>
        </div>
      </div>
    </div>
  `;
  
  document.body.insertAdjacentHTML('beforeend', modalHtml);
}

// Close delete midsem modal
function closeDeleteMidsemModal() {
  const modal = document.getElementById('deleteMidsemModal');
  if (modal) {
    modal.remove();
  }
}

// Delete midsem exam
async function deleteMidsemExam() {
  const selectElement = document.getElementById('deleteMidsemSelect');
  const examName = selectElement.value;
  
  if (!examName) {
    showMessage('Please select a midsem exam to delete.', 'error');
    return;
  }
  
  if (!confirm(`Are you sure you want to delete "${examName}" and all its marks?`)) {
    return;
  }
  
  try {
    const { error } = await window.supabaseClient
      .from('class_assignment_marks')
      .delete()
      .eq('class_id', currentClassId)
      .eq('assignment_name', examName);

    if (error) throw error;

    // Remove from local arrays
    midsemExams = midsemExams.filter(e => e.name !== examName);
    allMarksData = allMarksData.filter(record => record.assignment_name !== examName);
    
    // Re-render table
    renderMarksTable();
    
    showMessage('Midsem exam deleted successfully!', 'success');
    closeDeleteMidsemModal();

  } catch (error) {
    console.error('Error deleting midsem exam:', error);
    showMessage('Failed to delete midsem exam. Please try again.', 'error');
  }
}

// Event listeners
document.addEventListener('DOMContentLoaded', function() {
  // Add event listeners after DOM is loaded
  const addBtn = document.getElementById('addMidsemBtn');
  const createFirstBtn = document.getElementById('createFirstMidsemBtn');
  
  if (addBtn) {
    addBtn.addEventListener('click', showAddMidsemModal);
  }
  if (createFirstBtn) {
    createFirstBtn.addEventListener('click', showAddMidsemModal);
  }
});

// Utility functions
function showLoading() {
  document.getElementById('loadingState').classList.remove('hidden');
  document.getElementById('midsemSection').classList.add('hidden');
  document.getElementById('noDataState').classList.add('hidden');
}

function hideLoading() {
  document.getElementById('loadingState').classList.add('hidden');
}

function showMessage(message, type) {
  const messageDiv = document.getElementById('messageDisplay');
  messageDiv.textContent = message;
  messageDiv.className = `message-display ${type}`;
  messageDiv.style.display = 'block';
  
  setTimeout(() => {
    messageDiv.style.display = 'none';
  }, 5000);
}
