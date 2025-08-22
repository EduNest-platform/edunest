// Assignment Marks Management - Single Table Approach
let currentUser = null;
let currentClassId = null;
let currentSubjectName = null;
let assignments = []; // Unique assignments for this class
let students = [];
let allMarksData = []; // All marks data from the table

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
    const { data: { user }, error } = await window.supabaseAdmin.auth.getUser();
    if (error || !user) {
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
    
    // Load assignment marks data
    await loadAssignmentMarks();
    
    // Process data and render table
    processAssignmentData();
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
    contextElement.textContent = `${currentSubjectName} - Assignment Marks`;
  }
}

// Load students for the current class
async function loadClassStudents() {
  try {
    const { data: rosters, error } = await window.supabaseClient
      .from('class_rosters')
      .select('*')
      .eq('class_id', currentClassId);

    if (error) throw error;

    students = [];

    // Process each roster entry
    for (const roster of rosters || []) {
      let studentData = {
        id: roster.student_profile_id || `manual_${roster.id}`,
        name: roster.student_name || 'Unknown',
        email: roster.student_email || '',
        rollNumber: roster.roll_number || ''
      };

      console.log('Processing roster:', roster);

      // If student has student_profile_id, get additional details from profiles
      if (roster.student_profile_id) {
        try {
          const { data: profile, error: profileError } = await window.supabaseClient
            .from('profiles')
            .select('full_name, email')
            .eq('id', roster.student_profile_id)
            .single();

          if (!profileError && profile) {
            studentData.name = profile.full_name || roster.student_name || 'Unknown';
            studentData.email = profile.email || roster.student_email || '';
          }
        } catch (profileError) {
          console.log('Could not load profile for student:', roster.student_profile_id);
          // Use roster data as fallback
        }
      }

      students.push(studentData);
      console.log('Added student:', studentData);
    }

    console.log('Loaded students:', students.length, students);
    
  } catch (error) {
    console.error('Error loading students:', error);
    students = [];
  }
}

// Load assignment marks data
async function loadAssignmentMarks() {
  try {
    const { data, error } = await window.supabaseClient
      .from('class_assignment_marks')
      .select('*')
      .eq('class_id', currentClassId)
      .order('assignment_name', { ascending: true });

    if (error) throw error;

    allMarksData = data || [];
    console.log('Loaded assignment marks:', allMarksData.length);
    
  } catch (error) {
    console.error('Error loading assignment marks:', error);
    allMarksData = [];
  }
}

// Process assignment data to get unique assignments
function processAssignmentData() {
  // Get unique assignments
  const uniqueAssignments = new Map();
  
  allMarksData.forEach(record => {
    if (!uniqueAssignments.has(record.assignment_name)) {
      uniqueAssignments.set(record.assignment_name, {
        name: record.assignment_name,
        description: record.assignment_description,
        maxMarks: record.max_marks
      });
    }
  });

  assignments = Array.from(uniqueAssignments.values());
  console.log('Processed assignments:', assignments.length, assignments);
}

// Render the marks table
function renderMarksTable() {
  const assignmentSection = document.getElementById('assignmentSection');
  const noStudentsState = document.getElementById('noStudentsState');
  const marksTableBody = document.getElementById('marksTableBody');

  if (students.length === 0) {
    assignmentSection.classList.add('hidden');
    noStudentsState.classList.remove('hidden');
    return;
  }

  assignmentSection.classList.remove('hidden');
  noStudentsState.classList.add('hidden');

  // Render table header
  renderTableHeader();

  // Render table body
  marksTableBody.innerHTML = students.map(student => {
    console.log('Rendering student:', student);
    const assignmentCells = assignments.map(assignment => {
      // Find existing marks for this student and assignment
      const existingRecord = allMarksData.find(record => 
        record.assignment_name === assignment.name && 
        record.student_id === student.id
      );
      
      const marks = existingRecord?.marks || '';
      
      return `
        <td>
          <input type="number" 
                 class="marks-input" 
                 min="0" 
                 max="${assignment.maxMarks}" 
                 value="${marks}"
                 placeholder="0"
                 data-assignment-name="${assignment.name}"
                 data-student-id="${student.id}"
                 data-max-marks="${assignment.maxMarks}">
        </td>
      `;
    }).join('');

    return `
      <tr>
        <td class="student-cell">
          <div class="student-info">
            <div class="student-name">${student.name}</div>
            <div class="student-details">
              ${student.rollNumber ? `Roll: ${student.rollNumber}` : ''}
              ${student.rollNumber && student.email ? ' • ' : ''}
              ${student.email || ''}
            </div>
          </div>
        </td>
        ${assignmentCells}
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
  const noAssignmentsHeader = document.getElementById('noAssignmentsHeader');

  if (assignments.length === 0) {
    noAssignmentsHeader.style.display = 'table-cell';
    // Remove any existing assignment headers
    const assignmentHeaders = thead.querySelectorAll('.assignment-column');
    assignmentHeaders.forEach(header => header.remove());
    return;
  }

  noAssignmentsHeader.style.display = 'none';

  // Remove existing assignment headers
  const existingHeaders = thead.querySelectorAll('.assignment-column');
  existingHeaders.forEach(header => header.remove());

  // Add assignment headers
  assignments.forEach(assignment => {
    const th = document.createElement('th');
    th.className = 'assignment-column';
    th.innerHTML = `
      <div class="assignment-header">
        <div class="assignment-title">${assignment.name}</div>
        <div class="assignment-max-marks">Max: ${assignment.maxMarks}</div>
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
      
      // Validate marks
      if (marks !== null && (marks < 0 || marks > maxMarks)) {
        this.value = '';
        showMessage(`Marks must be between 0 and ${maxMarks}`, 'error');
        return;
      }

      // Visual feedback
      this.style.borderColor = marks !== null ? '#10b981' : '#e2e8f0';
    });
  });
}

// Show add assignment modal
function showAddAssignmentModal() {
  document.getElementById('addAssignmentModal').classList.remove('hidden');
}

// Hide add assignment modal
function hideAddAssignmentModal() {
  document.getElementById('addAssignmentModal').classList.add('hidden');
  document.getElementById('addAssignmentForm').reset();
}

// Create new assignment
async function createAssignment() {
  try {
    const title = document.getElementById('assignmentTitle').value.trim();
    const description = document.getElementById('assignmentDescription').value.trim();
    const maxMarks = parseInt(document.getElementById('maxMarks').value);

    if (!title || !maxMarks) {
      showMessage('Please fill in all required fields.', 'error');
      return;
    }

    // Check if assignment name already exists
    if (assignments.find(a => a.name === title)) {
      showMessage('Assignment with this name already exists.', 'error');
      return;
    }

    // Create assignment records for all students in the class
    const assignmentRecords = students.map(student => ({
      class_id: currentClassId,
      assignment_name: title,
      assignment_description: description || null,
      subject_name: currentSubjectName || 'Unknown Subject', // Add subject name
      max_marks: maxMarks,
      student_id: student.id,
      student_name: student.name,
      student_roll: student.rollNumber,
      student_email: student.email,
      marks: null, // No marks initially
      graded_by: currentUser.id,
      created_at: new Date().toISOString()
    }));

    const { error } = await window.supabaseClient
      .from('class_assignment_marks')
      .insert(assignmentRecords);

    if (error) throw error;

    // Add to local data
    assignments.push({
      name: title,
      description: description,
      maxMarks: maxMarks
    });

    // Add to allMarksData
    assignmentRecords.forEach(record => {
      allMarksData.push(record);
    });
    
    // Re-render table
    renderMarksTable();
    hideAddAssignmentModal();
    
    showMessage('Assignment created successfully!', 'success');

  } catch (error) {
    console.error('Error creating assignment:', error);
    showMessage('Failed to create assignment. Please try again.', 'error');
  }
}
// Delete assignment
async function deleteAssignment(assignmentName) {
  if (!confirm('Are you sure you want to delete this assignment? This will also delete all student marks for this assignment.')) {
    return;
  }

  try {
    // Delete all records for this assignment
    const { error } = await window.supabaseClient
      .from('class_assignment_marks')
      .delete()
      .eq('class_id', currentClassId)
      .eq('assignment_name', assignmentName);

    if (error) throw error;

    // Remove from local arrays
    assignments = assignments.filter(a => a.name !== assignmentName);
    allMarksData = allMarksData.filter(record => record.assignment_name !== assignmentName);
    
    // Re-render table
    renderMarksTable();
    
    showMessage('Assignment deleted successfully!', 'success');

  } catch (error) {
    console.error('Error deleting assignment:', error);
    showMessage('Failed to delete assignment. Please try again.', 'error');
  }
}

// Save all marks
async function saveAllMarks() {
  try {
    const inputs = document.querySelectorAll('.marks-input');
    const updates = [];

    inputs.forEach(input => {
      const marks = parseFloat(input.value) || null;
      const assignmentName = input.dataset.assignmentName;
      const studentId = input.dataset.studentId;
      
      if (marks !== null) {
        updates.push({
          class_id: currentClassId,
          assignment_name: assignmentName,
          student_id: studentId,
          marks: marks,
          graded_at: new Date().toISOString(),
          graded_by: currentUser.id
        });
      }
    });

    if (updates.length === 0) {
      showMessage('No marks to save.', 'error');
      return;
    }

    // Update marks in the database using upsert
    for (const update of updates) {
      const { error } = await window.supabaseClient
        .from('class_assignment_marks')
        .update({
          marks: update.marks,
          graded_at: update.graded_at,
          graded_by: update.graded_by
        })
        .eq('class_id', currentClassId)
        .eq('assignment_name', update.assignment_name)
        .eq('student_id', update.student_id);

      if (error) throw error;
    }

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
    
    // Update input visual feedback
    const inputs2 = document.querySelectorAll('.marks-input');
    inputs2.forEach(input => {
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
  }
}

// Export to CSV
function exportToCSV() {
  if (students.length === 0 || assignments.length === 0) {
    showMessage('No data to export.', 'error');
    return;
  }

  // Create CSV content
  let csv = 'Student Name,Roll Number,Email';
  assignments.forEach(assignment => {
    csv += `,${assignment.name} (Max: ${assignment.maxMarks})`;
  });
  csv += '\n';

  students.forEach(student => {
    let row = `"${student.name}","${student.rollNumber || ''}","${student.email || ''}"`;
    assignments.forEach(assignment => {
      const existingRecord = allMarksData.find(record => 
        record.assignment_name === assignment.name && 
        record.student_id === student.id
      );
      const marks = existingRecord?.marks || '';
      row += `,${marks}`;
    });
    csv += row + '\n';
  });

  // Download CSV
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
  const link = document.createElement('a');
  const url = URL.createObjectURL(blob);
  link.setAttribute('href', url);
  link.setAttribute('download', `${currentSubjectName}_Assignment_Marks_${new Date().toISOString().split('T')[0]}.csv`);
  link.style.visibility = 'hidden';
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  
  showMessage('Assignment marks exported successfully!', 'success');
}

// Utility functions
function showLoading() {
  document.getElementById('loadingState').classList.remove('hidden');
  document.getElementById('assignmentSection').classList.add('hidden');
}

function hideLoading() {
  document.getElementById('loadingState').classList.add('hidden');
}

function showMessage(message, type = 'success') {
  const messageEl = document.getElementById('messageDisplay');
  messageEl.textContent = message;
  messageEl.className = `message ${type} show`;
  
  setTimeout(() => {
    messageEl.classList.remove('show');
  }, 4000);
}

// Close modals when clicking outside
document.addEventListener('click', function(event) {
  if (event.target.classList.contains('modal-overlay')) {
    hideAddAssignmentModal();
    closeDeleteModal();
  }
});

// Delete assignment modal functions
function showDeleteAssignmentModal() {
  if (assignments.length === 0) {
    showMessage('No assignments to delete', 'error');
    return;
  }

  const modal = document.createElement('div');
  modal.className = 'modal-overlay';
  modal.id = 'deleteAssignmentModal';
  modal.innerHTML = `
    <div class="modal-content">
      <h3>Delete Assignment</h3>
      <p>Select an assignment to delete:</p>
      <select id="assignmentToDelete" class="form-input">
        <option value="">Select an assignment...</option>
        ${assignments.map(a => `<option value="${a.name}">${a.name} (Max: ${a.maxMarks})</option>`).join('')}
      </select>
      <div class="modal-buttons">
        <button onclick="closeDeleteModal()" class="btn btn-secondary">Cancel</button>
        <button onclick="confirmDeleteAssignment()" class="btn btn-danger">Delete Assignment</button>
      </div>
    </div>
  `;
  
  document.body.appendChild(modal);
}

function confirmDeleteAssignment() {
  const select = document.getElementById('assignmentToDelete');
  const assignmentName = select.value;
  
  if (!assignmentName) {
    showMessage('Please select an assignment to delete', 'error');
    return;
  }
  
  closeDeleteModal();
  deleteAssignment(assignmentName);
}

function closeDeleteModal() {
  const modal = document.getElementById('deleteAssignmentModal');
  if (modal) {
    modal.remove();
  }
}
