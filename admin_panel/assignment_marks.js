// Assignment Marks Management - Single Table Approach with Caching
let currentUser = null;
let currentClassId = null;
let currentSubjectName = null;
let assignments = []; // Unique assignments for this class
let students = [];
let allMarksData = []; // All marks data from the table
let cacheEnabled = true; // Enable caching by default

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

    // Get current user - try both admin and regular client
    const user = await window.authManager.getCurrentUser();
    
    // Fallback: use session storage admin info
    if (!user) {
      const adminEmail = sessionStorage.getItem('adminEmail');
      const adminId = sessionStorage.getItem('adminId');
      if (adminEmail && adminId) {
        user = {
          id: adminId,
          email: adminEmail
        };
        console.log('Using fallback admin user from session storage');
      }
    }
    
    if (!user) {
      throw new Error('User not authenticated - please log in again');
    }
    
    currentUser = user;
    console.log('Authenticated user:', currentUser);

  } catch (error) {
    console.error('Error initializing:', error);
    showMessage('Failed to initialize. Please refresh the page.', 'error');
    // Redirect to login if authentication fails
    setTimeout(() => {
      window.location.href = 'index.html';
    }, 2000);
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
    
    // Sync students with existing assignments (fix for new signup accounts)
    await syncStudentsWithAssignments();
    
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
    // Try cache first
    if (cacheEnabled && window.adminCache) {
      const cachedRosters = window.adminCache.getClassRoster(currentClassId);
      if (cachedRosters) {
        console.log('Using cached class roster data');
        await processRosterData(cachedRosters);
        return;
      }
    }

    console.log('Fetching class roster from database');
    const { data: rosters, error } = await window.supabaseClient
      .from('class_rosters')
      .select('*')
      .eq('class_id', currentClassId);

    if (error) throw error;

    // Cache the roster data
    if (cacheEnabled && window.adminCache && rosters) {
      window.adminCache.cacheClassRoster(rosters, currentClassId);
    }

    await processRosterData(rosters || []);
    
  } catch (error) {
    console.error('Error loading students:', error);
    students = [];
  }
}

// Process roster data (extracted for reuse with cache)
async function processRosterData(rosters) {
  try {
    students = [];

    // Process each roster entry
    for (const roster of rosters) {
      let studentData = {
        id: roster.student_profile_id || `manual_${roster.id}`,
        name: roster.student_name || 'Unknown',
        email: roster.student_email || '',
        rollNumber: roster.roll_number || ''
      };

      // If student has student_profile_id, get additional details from profiles
      if (roster.student_profile_id) {
        try {
          // Try cache first for profile data
          let profile = null;
          if (cacheEnabled && window.adminCache) {
            profile = window.adminCache.get('student_profile', { profileId: roster.student_profile_id });
          }

          if (!profile) {
            const { data: profileData, error: profileError } = await window.supabaseClient
              .from('profiles')
              .select('full_name, email')
              .eq('id', roster.student_profile_id)
              .single();

            if (!profileError && profileData) {
              profile = profileData;
              // Cache profile data
              if (cacheEnabled && window.adminCache) {
                window.adminCache.set('student_profile', profile, { profileId: roster.student_profile_id }, 15 * 60 * 1000);
              }
            }
          }

          if (profile) {
            studentData.name = profile.full_name || roster.student_name || 'Unknown';
            studentData.email = profile.email || roster.student_email || '';
          }
        } catch (profileError) {
          console.log('Could not load profile for student:', roster.student_profile_id);
          // Use roster data as fallback
        }
      }

      students.push(studentData);
    }

    // Sort students by roll number
    students.sort((a, b) => {
      const rollA = a.rollNumber || '';
      const rollB = b.rollNumber || '';
      
      // Extract numeric part from roll numbers (e.g., "401/23" -> 401)
      const numA = parseInt(rollA.split('/')[0]) || 0;
      const numB = parseInt(rollB.split('/')[0]) || 0;
      
      return numA - numB;
    });

    // Cache processed students
    if (cacheEnabled && window.adminCache) {
      window.adminCache.cacheStudents(students, currentClassId);
    }

    console.log('Loaded and sorted students:', students.length, students);
    
  } catch (error) {
    console.error('Error processing roster data:', error);
    students = [];
  }
}

// Load assignment marks data
async function loadAssignmentMarks() {
  try {
    console.log('📊 DEBUG: Starting to load assignment marks for class:', currentClassId);
    
    // Always fetch fresh data from database to ensure accuracy
    console.log('📊 DEBUG: Fetching fresh assignment marks from database');
    const { data, error } = await window.supabaseClient
      .from('class_assignment_marks')
      .select('*')
      .eq('class_id', currentClassId)
      .not('assignment_name', 'like', 'Midsem:%') // Exclude midsem marks
      .order('assignment_name', { ascending: true });

    if (error) {
      console.error('📊 DEBUG: Database error loading assignment marks:', error);
      throw error;
    }

    allMarksData = data || [];
    console.log('📊 DEBUG: Loaded assignment marks from database, count:', allMarksData.length);
    
    // Log all records for debugging
    allMarksData.forEach((record, index) => {
      console.log(`📊 DEBUG: Record ${index + 1}:`, {
        id: record.id,
        assignment_name: record.assignment_name,
        student_id: record.student_id,
        student_name: record.student_name,
        student_roll: record.student_roll,
        marks: record.marks,
        marksType: typeof record.marks,
        fullRecord: record // Show complete record
      });
    });
    
    // Cache the marks data
    if (cacheEnabled && window.adminCache && allMarksData.length > 0) {
      window.adminCache.cacheAssignmentMarks(allMarksData, currentClassId);
      console.log('📊 DEBUG: Cached assignment marks data');
    }
    
  } catch (error) {
    console.error('📊 DEBUG: Error loading assignment marks:', error);
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
  console.log('📊 DEBUG: Processed assignments:', assignments.length, assignments);
}

// Combine registered students with manual assignment entries
function combineStudentsWithManualEntries() {
  console.log('🔄 DEBUG: Combining students with manual entries');
  
  const combinedEntries = new Map();
  
  // Add registered students first
  students.forEach(student => {
    const key = student.rollNumber || student.id;
    combinedEntries.set(key, {
      ...student,
      isRegistered: true,
      displayName: student.name,
      source: 'registered'
    });
  });
  
  // Add manual entries that don't have registered counterparts
  allMarksData.forEach(record => {
    const rollKey = record.student_roll;
    const nameKey = record.student_name?.toLowerCase();
    
    // Check if this is a manual entry (student_id starts with 'manual_')
    if (record.student_id?.startsWith('manual_')) {
      // Check if we already have a registered student with same roll number
      const existingByRoll = Array.from(combinedEntries.values()).find(entry => 
        entry.rollNumber === record.student_roll
      );
      
      if (!existingByRoll) {
        // This is a manual entry without a registered counterpart
        const manualKey = `manual_${record.student_roll || record.student_name}`;
        
        if (!combinedEntries.has(manualKey)) {
          combinedEntries.set(manualKey, {
            id: record.student_id,
            name: record.student_name,
            email: record.student_email || '',
            rollNumber: record.student_roll || '',
            isRegistered: false,
            displayName: `${record.student_name} (Manual Entry)`,
            source: 'manual'
          });
          
          console.log('🔄 DEBUG: Added manual entry:', {
            name: record.student_name,
            roll: record.student_roll,
            id: record.student_id
          });
        }
      }
    }
  });
  
  const result = Array.from(combinedEntries.values());
  
  // Sort by roll number, then by name
  result.sort((a, b) => {
    const rollA = a.rollNumber || '';
    const rollB = b.rollNumber || '';
    
    if (rollA && rollB) {
      const numA = parseInt(rollA.split('/')[0]) || 0;
      const numB = parseInt(rollB.split('/')[0]) || 0;
      if (numA !== numB) return numA - numB;
    }
    
    return (a.name || '').localeCompare(b.name || '');
  });
  
  console.log('🔄 DEBUG: Combined entries result:', result.length, result);
  return result;
}

// Sync students with existing assignments (for new signup accounts)
async function syncStudentsWithAssignments() {
  console.log('🔄 DEBUG: Starting sync - assignments:', assignments.length, 'students:', students.length);
  
  if (assignments.length === 0 || students.length === 0) {
    console.log('🔄 DEBUG: Nothing to sync - no assignments or students');
    return; // Nothing to sync
  }

  try {
    const missingRecords = [];
    const updateRecords = [];
    
    // Check each student against each assignment
    for (const student of students) {
      for (const assignment of assignments) {
        // Check if this student has a record for this assignment
        let existingRecord = allMarksData.find(record => 
          record.assignment_name === assignment.name && 
          record.student_id === student.id
        );
        
        // If no direct match, check for records with same roll number but different student_id
        if (!existingRecord) {
          const rollMatchRecord = allMarksData.find(record => 
            record.assignment_name === assignment.name && 
            record.student_roll === student.rollNumber &&
            record.student_id !== student.id
          );
          
          if (rollMatchRecord) {
            console.log('🔄 DEBUG: Found existing record with same roll number but different student_id:', {
              studentName: student.name,
              rollNumber: student.rollNumber,
              newStudentId: student.id,
              oldStudentId: rollMatchRecord.student_id,
              assignmentName: assignment.name,
              marks: rollMatchRecord.marks
            });
            
            // Update the existing record to use the new student_id
            updateRecords.push({
              id: rollMatchRecord.id,
              student_id: student.id,
              student_name: student.name,
              student_email: student.email
            });
            
            // Update local data
            rollMatchRecord.student_id = student.id;
            rollMatchRecord.student_name = student.name;
            rollMatchRecord.student_email = student.email;
            
            existingRecord = rollMatchRecord;
          }
        }
        
        if (!existingRecord) {
          console.log('🔄 DEBUG: Missing record for student:', student.name, 'assignment:', assignment.name);
          // Create missing record
          missingRecords.push({
            class_id: currentClassId,
            assignment_name: assignment.name,
            assignment_description: assignment.description,
            subject_name: currentSubjectName || 'Unknown Subject',
            max_marks: assignment.maxMarks,
            student_id: student.id,
            student_name: student.name,
            student_roll: student.rollNumber,
            student_email: student.email,
            marks: null,
            graded_by: currentUser?.id || 'system',
            created_at: new Date().toISOString()
          });
        }
      }
    }
    
    // Update existing records with new student IDs
    if (updateRecords.length > 0) {
      console.log(`🔄 DEBUG: Updating ${updateRecords.length} existing records with new student IDs`);
      
      for (const updateRecord of updateRecords) {
        const { error } = await window.supabaseClient
          .from('class_assignment_marks')
          .update({
            student_id: updateRecord.student_id,
            student_name: updateRecord.student_name,
            student_email: updateRecord.student_email
          })
          .eq('id', updateRecord.id);
        
        if (error) {
          console.error('🔄 DEBUG: Error updating record:', error);
        }
      }
    }
    
    if (missingRecords.length > 0) {
      console.log(`🔄 DEBUG: Creating ${missingRecords.length} missing assignment records for new students`);
      
      const { error } = await window.supabaseClient
        .from('class_assignment_marks')
        .insert(missingRecords);
      
      if (error) {
        console.error('🔄 DEBUG: Error creating missing records:', error);
      } else {
        // Add to local data
        missingRecords.forEach(record => {
          allMarksData.push(record);
        });
        console.log('🔄 DEBUG: Successfully synced missing assignment records');
      }
    }
    
    if (updateRecords.length > 0 || missingRecords.length > 0) {
      // Update cache with new data
      if (cacheEnabled && window.adminCache) {
        window.adminCache.cacheAssignmentMarks(allMarksData, currentClassId);
        console.log('🔄 DEBUG: Updated cache with synced records');
      }
      console.log('🔄 DEBUG: Sync completed - updated:', updateRecords.length, 'created:', missingRecords.length);
    } else {
      console.log('🔄 DEBUG: No changes needed - all students properly synced');
    }
    
  } catch (error) {
    console.error('🔄 DEBUG: Error syncing students with assignments:', error);
  }
}

// Render the marks table
function renderMarksTable() {
  const assignmentSection = document.getElementById('assignmentSection');
  const noStudentsState = document.getElementById('noStudentsState');
  const marksTableBody = document.getElementById('marksTableBody');

  // Combine registered students with manual entries
  const allStudentEntries = combineStudentsWithManualEntries();

  if (allStudentEntries.length === 0) {
    assignmentSection.classList.add('hidden');
    noStudentsState.classList.remove('hidden');
    return;
  }

  assignmentSection.classList.remove('hidden');
  noStudentsState.classList.add('hidden');

  // Render table header
  renderTableHeader();

  // Render table body
  marksTableBody.innerHTML = allStudentEntries.map(student => {
    console.log('🔍 DEBUG: Rendering student:', student);
    const assignmentCells = assignments.map(assignment => {
      // Find existing marks for this student and assignment
      let existingRecord = allMarksData.find(record => 
        record.assignment_name === assignment.name && 
        record.student_id === student.id
      );
      
      // If no match by student_id, try matching by roll number
      if (!existingRecord && student.rollNumber) {
        existingRecord = allMarksData.find(record => 
          record.assignment_name === assignment.name && 
          record.student_roll === student.rollNumber
        );
      }
      
      // If still no match, try matching by name (case-insensitive)
      if (!existingRecord && student.name) {
        existingRecord = allMarksData.find(record => 
          record.assignment_name === assignment.name && 
          record.student_name?.toLowerCase() === student.name?.toLowerCase()
        );
        if (existingRecord) {
          console.log('🔍 DEBUG: Found record by name match for:', student.name);
        }
      }
      
      // IMPORTANT: For registered students, also check if there's a manual entry with marks
      // This handles cases where teacher gave marks before student signed up
      if (student.isRegistered && student.rollNumber) {
        const manualRecord = allMarksData.find(record => 
          record.assignment_name === assignment.name && 
          record.student_roll === student.rollNumber &&
          record.student_id?.startsWith('manual_') &&
          record.marks !== null && record.marks !== undefined && record.marks !== ''
        );
        
        // If manual entry has marks but current record doesn't, use manual entry
        if (manualRecord && (!existingRecord || !existingRecord.marks)) {
          console.log('🔄 DEBUG: Using manual entry marks for registered student:', {
            student: student.name,
            roll: student.rollNumber,
            manualMarks: manualRecord.marks,
            currentMarks: existingRecord?.marks
          });
          existingRecord = manualRecord;
        }
      }
      
      console.log('🔍 DEBUG: Assignment record search for', student.name, ':', {
        studentId: student.id,
        rollNumber: student.rollNumber,
        assignmentName: assignment.name,
        foundRecord: !!existingRecord,
        recordStudentId: existingRecord?.student_id,
        recordRoll: existingRecord?.student_roll,
        recordName: existingRecord?.student_name,
        marks: existingRecord?.marks,
        marksType: typeof existingRecord?.marks,
        completeRecord: existingRecord
      });
      
      // Ensure marks is properly handled - convert null to empty string, keep numbers as strings
      let marks = '';
      if (existingRecord?.marks !== null && existingRecord?.marks !== undefined) {
        marks = String(existingRecord.marks);
      }
      
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
                 data-max-marks="${assignment.maxMarks}"
                 data-original-value="${marks}"
                 ${!student.isRegistered ? 'style="background-color: #fff3cd; border-color: #ffeaa7;"' : ''}>
        </td>
      `;
    }).join('');

    return `
      <tr ${!student.isRegistered ? 'style="background-color: #fefcf3;"' : ''}>
        <td class="student-cell">
          <div class="student-info">
            <div class="student-name">
              ${student.displayName || student.name}
              ${!student.isRegistered ? '<span style="color: #856404; font-size: 0.8em; margin-left: 8px;">(Not Registered)</span>' : ''}
            </div>
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
    console.log('➕ DEBUG: Starting assignment creation');
    
    const title = document.getElementById('assignmentTitle').value.trim();
    const description = document.getElementById('assignmentDescription').value.trim();
    const maxMarks = parseInt(document.getElementById('maxMarks').value);

    console.log('➕ DEBUG: Assignment details - Title:', title, 'MaxMarks:', maxMarks, 'Students:', students.length);

    if (!title || !maxMarks) {
      console.log('➕ DEBUG: Validation failed - missing required fields');
      showMessage('Please fill in all required fields.', 'error');
      return;
    }

    // Validate currentUser
    if (!currentUser || !currentUser.id) {
      console.error('➕ DEBUG: User authentication error - currentUser:', currentUser);
      showMessage('User authentication error. Please refresh and try again.', 'error');
      return;
    }

    // Check if assignment name already exists
    if (assignments.find(a => a.name === title)) {
      console.log('➕ DEBUG: Assignment name already exists:', title);
      showMessage('Assignment with this name already exists.', 'error');
      return;
    }

    if (students.length === 0) {
      console.log('➕ DEBUG: No students found in class');
      showMessage('No students found in this class. Please add students first.', 'error');
      return;
    }

    // Create assignment records for all students in the class
    const assignmentRecords = students.map(student => ({
      class_id: currentClassId,
      assignment_name: title,
      assignment_description: description || null,
      subject_name: currentSubjectName || 'Unknown Subject',
      max_marks: maxMarks,
      student_id: student.id,
      student_name: student.name,
      student_roll: student.rollNumber,
      student_email: student.email,
      marks: null, // No marks initially
      graded_by: currentUser.id,
      created_at: new Date().toISOString()
    }));

    console.log('➕ DEBUG: Creating assignment records count:', assignmentRecords.length);

    const { error } = await window.supabaseClient
      .from('class_assignment_marks')
      .insert(assignmentRecords);

    if (error) {
      console.error('➕ DEBUG: Database insert error:', error);
      throw error;
    }

    console.log('➕ DEBUG: Assignment records inserted successfully');

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
    
    console.log('➕ DEBUG: Updated local data - assignments:', assignments.length, 'marks data:', allMarksData.length);
    
    // Invalidate cache to force refresh
    if (cacheEnabled && window.adminCache) {
      window.adminCache.invalidateType('assignment_marks');
      window.adminCache.cacheAssignmentMarks(allMarksData, currentClassId);
      console.log('➕ DEBUG: Cache updated with new assignment');
    }
    
    // Re-render table
    renderMarksTable();
    hideAddAssignmentModal();
    
    showMessage('Assignment created successfully!', 'success');
    console.log('➕ DEBUG: Assignment creation completed successfully');

  } catch (error) {
    console.error('➕ DEBUG: Error creating assignment:', error);
    showMessage(`Failed to create assignment: ${error.message}`, 'error');
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
    
    // Invalidate cache to force refresh
    if (cacheEnabled && window.adminCache) {
      window.adminCache.invalidateType('assignment_marks');
      window.adminCache.cacheAssignmentMarks(allMarksData, currentClassId);
    }
    
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
      const originalValue = input.dataset.originalValue;
      
      // Only include if marks have actually changed
      if (marks !== null && marks.toString() !== originalValue) {
        const maxMarks = parseInt(input.dataset.maxMarks);
        
        // Find student info for required fields
        const allStudentEntries = combineStudentsWithManualEntries();
        const student = allStudentEntries.find(s => s.id === studentId);
        const assignment = assignments.find(a => a.name === assignmentName);
        
        updates.push({
          class_id: currentClassId,
          assignment_name: assignmentName,
          student_id: studentId,
          student_name: student?.name || 'Unknown',
          student_roll: student?.rollNumber || '',
          marks: marks,
          max_marks: maxMarks,
          assignment_description: assignment?.description || '',
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

    console.log(`💾 Saving ${updates.length} changed marks...`);

    // Use batch upsert for better performance
    const { error } = await window.supabaseClient
      .from('class_assignment_marks')
      .upsert(updates.map(update => ({
        class_id: update.class_id,
        assignment_name: update.assignment_name,
        student_id: update.student_id,
        student_name: update.student_name,
        student_roll: update.student_roll,
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

    // Update cache with new marks
    if (cacheEnabled && window.adminCache) {
      window.adminCache.cacheAssignmentMarks(allMarksData, currentClassId);
    }

    showMessage(`Saved marks for ${updates.length} entries!`, 'success');
    
    // Update original values and visual feedback for changed inputs only
    updates.forEach(update => {
      const input = document.querySelector(
        `.marks-input[data-assignment-name="${update.assignment_name}"][data-student-id="${update.student_id}"]`
      );
      if (input) {
        input.dataset.originalValue = update.marks.toString();
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

// Keyboard shortcuts
document.addEventListener('keydown', function(event) {
  // Ctrl+R or F5 - Refresh cache
  if ((event.ctrlKey && event.key === 'r') || event.key === 'F5') {
    event.preventDefault();
    refreshCache();
  }
  
  // Ctrl+S - Save marks
  if (event.ctrlKey && event.key === 's') {
    event.preventDefault();
    saveAllMarks();
  }
});

// Auto-refresh cache every 10 minutes
setInterval(() => {
  if (window.adminCache && cacheEnabled) {
    console.log('Auto-refreshing assignment marks cache...');
    window.adminCache.invalidateType('assignment_marks');
  }
}, 10 * 60 * 1000); // 10 minutes

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

// Refresh cache and reload data
async function refreshCache() {
  try {
    showMessage('Refreshing data from server...', 'info');
    
    // Clear all relevant cache entries
    if (window.adminCache) {
      window.adminCache.invalidateType('assignment_marks');
      window.adminCache.invalidateType('class_roster');
      window.adminCache.invalidateType('student_profile');
      window.adminCache.invalidateType('students');
      console.log('🔄 DEBUG: Cache cleared for assignment marks');
    }
    
    // Force fresh database fetch
    console.log('🔄 DEBUG: Force refreshing assignment marks data');
    
    // Reload all data
    await loadPageData();
    
    showMessage('Data refreshed successfully!', 'success');
  } catch (error) {
    console.error('🔄 DEBUG: Error refreshing data:', error);
    showMessage('Failed to refresh data. Please try again.', 'error');
  }
}

// Show cache statistics (for debugging)
function showCacheStats() {
  if (window.adminCache) {
    const stats = window.adminCache.getStats();
    console.log('Cache Statistics:', stats);
    showMessage(`Cache: ${stats.totalEntries} entries, ${stats.expiredEntries} expired`, 'info');
  }
}
