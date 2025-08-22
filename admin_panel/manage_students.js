// Student Management System
let currentUser = null;
let selectedClass = null;
let students = [];
let positionModeEnabled = false;

// Initialize the student management system
document.addEventListener('DOMContentLoaded', async function() {
  console.log('Student Management - Starting initialization...');
  console.log('Current URL:', window.location.href);
  console.log('URL params:', new URLSearchParams(window.location.search).toString());
  
  try {
    await checkAuthStatus();
    await loadUserInfo();
    
    // Only proceed if we have a user
    if (currentUser) {
      await loadClassFromURL();
      await loadStudents();
      setupEventListeners();
    }
  } catch (error) {
    console.error('Student Management - Initialization error:', error);
    showMsg('messageDisplay', 'Error initializing student management: ' + error.message, true);
  }
});

// Check authentication status
async function checkAuthStatus() {
  const isLoggedIn = sessionStorage.getItem('adminLoggedIn') === 'true';
  console.log('Student Management - Auth check:', { isLoggedIn, sessionStorage: sessionStorage.getItem('adminLoggedIn') });
  
  if (!isLoggedIn) {
    console.log('Student Management - Not logged in, redirecting to login');
    window.location.href = 'index.html';
    return;
  }
  console.log('Student Management - Auth check passed');
}

// Load user information
async function loadUserInfo() {
  try {
    console.log('Student Management - Loading user info...');
    console.log('Student Management - Supabase clients available:', { 
      supabaseAdmin: !!window.supabaseAdmin, 
      supabaseClient: !!window.supabaseClient 
    });
    
    const { data: { user } } = await window.supabaseAdmin.auth.getUser();
    console.log('Student Management - User data:', user);
    
    if (!user) {
      console.log('Student Management - No user found, redirecting to login');
      window.location.href = 'index.html';
      return;
    }
    currentUser = user;
    console.log('Student Management - User loaded successfully:', currentUser.email);
  } catch (error) {
    console.error('Student Management - Error loading user info:', error);
    window.location.href = 'index.html';
  }
}

// Load class information from URL parameters
async function loadClassFromURL() {
  const urlParams = new URLSearchParams(window.location.search);
  const classId = urlParams.get('classId');
  
  console.log('Student Management - Loading class from URL:', { classId, currentUser: currentUser?.email });
  
  if (!classId) {
    console.log('Student Management - No classId found in URL');
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
    console.error('Student Management - Error loading class:', error);
    showMsg('messageDisplay', 'Error loading class: ' + error.message, true);
    hideLoading();
  }
}

// Update class header with information
function updateClassHeader() {
  if (!selectedClass) return;
  
  const classInfo = document.getElementById('classInfo');
  
  if (classInfo) {
    classInfo.innerHTML = `
      <div class="info-card">
        <h4>📚 Subject</h4>
        <p>${selectedClass.subject}</p>
      </div>
      <div class="info-card">
        <h4>🏢 Branch</h4>
        <p>${selectedClass.branch || 'N/A'}</p>
      </div>
      <div class="info-card">
        <h4>📖 Semester</h4>
        <p>${selectedClass.semester || 'N/A'}</p>
      </div>
      <div class="info-card">
        <h4>👨‍🏫 Professor</h4>
        <p>${selectedClass.professorEmail}</p>
      </div>
    `;
  }
}

// Load students for the class
async function loadStudents() {
  if (!selectedClass) return;
  
  try {
    showLoading('Loading students...');
    
    const { data: studentsData, error } = await window.supabaseClient
      .from('class_rosters')
      .select('*')
      .eq('class_id', selectedClass.id)
      .order('roll_number');

    if (error) throw error;

    students = studentsData || [];
    
    // Sort students by roll number (handle formats like 401/23, 402/23)
    students.sort((a, b) => {
      const rollA = a.roll_number.toString();
      const rollB = b.roll_number.toString();
      
      // Extract numeric parts for proper sorting
      const numA = parseInt(rollA.replace(/\D/g, '')) || 0;
      const numB = parseInt(rollB.replace(/\D/g, '')) || 0;
      
      return numA - numB;
    });
    
    renderStudentsTable();
    updateStudentStats();
    
    // Automatically attempt to link unlinked students
    await autoLinkUnlinkedStudents();
    
    hideLoading();
    
  } catch (error) {
    console.error('Error loading students:', error);
    showMsg('messageDisplay', 'Error loading students: ' + error.message, true);
    hideLoading();
  }
}

// Render students table
function renderStudentsTable() {
  const tableBody = document.getElementById('studentsTableBody');
  if (!tableBody) return;

  const colspanCount = positionModeEnabled ? 7 : 6;
  
  if (students.length === 0) {
    tableBody.innerHTML = `
      <tr>
        <td colspan="${colspanCount}" class="empty-state">
          <div>
            <h3>📚 No Students Added Yet</h3>
            <p>Upload a CSV file or add students manually to get started.</p>
          </div>
        </td>
      </tr>
    `;
    return;
  }

  tableBody.innerHTML = students.map((student, index) => `
    <tr>
      <td class="position-column" style="display: ${positionModeEnabled ? 'table-cell' : 'none'};">
        <div class="position-controls">
          <button class="position-btn" onclick="moveStudentUp(${index})" ${index === 0 ? 'disabled' : ''}>
            ⬆️
          </button>
          <span class="position-number">${index + 1}</span>
          <button class="position-btn" onclick="moveStudentDown(${index})" ${index === students.length - 1 ? 'disabled' : ''}>
            ⬇️
          </button>
        </div>
      </td>
      <td><strong>${student.roll_number}</strong></td>
      <td>
        <div class="student-info">
          <div class="student-name">${student.student_name}</div>
          ${student.student_email ? `<div class="student-email">${student.student_email}</div>` : ''}
        </div>
      </td>
      <td>${student.student_email || 'Not provided'}</td>
      <td>
        <span class="status-badge ${student.student_profile_id ? 'status-verified' : 'status-unverified'}">
          ${student.student_profile_id ? '✓ App Connected' : '⚠ Not Connected'}
        </span>
      </td>
      <td>
        ${!student.student_profile_id ? 
          `<button class="action-btn action-btn-primary" onclick="linkStudentProfile('${student.id}', '${student.roll_number}')">
            🔗 Link Profile
          </button>` : 
          `<button class="action-btn action-btn-success" onclick="unlinkStudentProfile('${student.id}')">
            ✓ Linked
          </button>`
        }
      </td>
      <td>
        <button class="action-btn action-btn-danger" onclick="removeStudent('${student.id}')">
          🗑️ Remove
        </button>
      </td>
    </tr>
  `).join('');
}

// Update student statistics
function updateStudentStats() {
  const totalStudents = document.getElementById('totalStudents');
  const linkedStudents = document.getElementById('linkedStudents');
  const unlinkedStudents = document.getElementById('unlinkedStudents');
  
  const total = students.length;
  const linked = students.filter(s => s.student_profile_id).length;
  const unlinked = total - linked;
  
  if (totalStudents) totalStudents.textContent = total;
  if (linkedStudents) linkedStudents.textContent = linked;
  if (unlinkedStudents) unlinkedStudents.textContent = unlinked;
}

// Setup event listeners
function setupEventListeners() {
  // File input change
  const csvFile = document.getElementById('csvFile');
  if (csvFile) {
    // Remove existing listeners to avoid duplicates
    csvFile.removeEventListener('change', handleFileSelect);
    csvFile.addEventListener('change', handleFileSelect);
    console.log('File input event listener added');
  } else {
    console.warn('CSV file input not found');
  }
  
  // Drag and drop
  const uploadArea = document.getElementById('uploadArea');
  if (uploadArea) {
    // Remove existing listeners to avoid duplicates
    uploadArea.removeEventListener('dragover', handleDragOver);
    uploadArea.removeEventListener('dragleave', handleDragLeave);
    uploadArea.removeEventListener('drop', handleDrop);
    
    uploadArea.addEventListener('dragover', handleDragOver);
    uploadArea.addEventListener('dragleave', handleDragLeave);
    uploadArea.addEventListener('drop', handleDrop);
    console.log('Drag and drop event listeners added');
  } else {
    console.warn('Upload area not found');
  }
}

// Handle file selection
function handleFileSelect(event) {
  console.log('File selected:', event.target.files);
  const file = event.target.files[0];
  if (file) {
    console.log('Selected file:', file.name, file.type, file.size);
    selectedFile = file; // Store globally
    updateUploadArea(file.name);
  } else {
    console.log('No file selected');
    selectedFile = null;
  }
}

// Handle drag over
function handleDragOver(event) {
  event.preventDefault();
  event.currentTarget.classList.add('dragover');
}

// Handle drag leave
function handleDragLeave(event) {
  event.currentTarget.classList.remove('dragover');
}

// Handle drop
function handleDrop(event) {
  event.preventDefault();
  event.currentTarget.classList.remove('dragover');
  
  const files = event.dataTransfer.files;
  if (files.length > 0) {
    const file = files[0];
    const isCSV = file.type === 'text/csv' || file.name.endsWith('.csv');
    const isPDF = file.type === 'application/pdf' || file.name.endsWith('.pdf');
    
    if (isCSV || isPDF) {
      selectedFile = file; // Store globally
      const fileInput = document.getElementById('csvFile');
      if (fileInput) {
        fileInput.files = files;
      }
      updateUploadArea(file.name);
    } else {
      showMsg('messageDisplay', 'Please select a CSV or PDF file.', true);
    }
  }
}

// Update upload area display
function updateUploadArea(fileName) {
  const uploadArea = document.getElementById('uploadArea');
  if (uploadArea) {
    uploadArea.innerHTML = `
      <div class="upload-icon">✅</div>
      <div class="upload-text">File selected: ${fileName}</div>
      <div class="upload-subtext">Ready to upload</div>
      <input type="file" id="csvFile" class="file-input" accept=".csv,.pdf" style="display: none;" />
      <button class="btn btn-primary" onclick="document.getElementById('csvFile').click()">
        📁 Choose Different File
      </button>
    `;
    
    // Re-setup event listeners for the new file input
    setTimeout(() => {
      setupEventListeners();
    }, 100);
  }
}

// Store the selected file globally to prevent loss during DOM updates
let selectedFile = null;
let extractedStudents = [];
let extractionErrors = [];

// Upload CSV file
async function uploadCSV() {
  const fileInput = document.getElementById('csvFile');
  let file = null;
  
  // Try to get file from input first, then from global variable
  if (fileInput && fileInput.files && fileInput.files[0]) {
    file = fileInput.files[0];
    selectedFile = file; // Store globally
  } else if (selectedFile) {
    file = selectedFile; // Use stored file
  }
  
  if (!file) {
    showMsg('messageDisplay', 'Please select a CSV or PDF file first.', true);
    return;
  }
  
  console.log('Processing file:', file.name, file.type, file.size);
  console.log('Selected file from global:', selectedFile);
  console.log('File input element:', fileInput);
  console.log('File input files:', fileInput ? fileInput.files : 'No file input');
  
  try {
    const isCSV = file.type === 'text/csv' || file.name.endsWith('.csv');
    const isPDF = file.type === 'application/pdf' || file.name.endsWith('.pdf');
    
    if (!isCSV && !isPDF) {
      throw new Error('Please select a CSV or PDF file.');
    }
    
    showLoading(`Processing ${isCSV ? 'CSV' : 'PDF'} file...`);
    
    let text = '';
    
    if (isCSV) {
      text = await file.text();
    } else if (isPDF) {
      // For PDF files, we'll ask the user to convert to CSV for now
      // In a production environment, you'd use a PDF parsing library like PDF.js
      throw new Error('PDF parsing is not yet implemented. Please convert your PDF to CSV format and try again. You can use online converters or copy-paste the data into a CSV file.');
    }
    
    const lines = text.split('\n').filter(line => line.trim());
    
    if (lines.length < 2) {
      throw new Error('CSV file must contain at least a header row and one data row.');
    }
    
    // Parse CSV with better handling for quoted fields and different separators
    function parseCSVLine(line) {
      const result = [];
      let current = '';
      let inQuotes = false;
      
      for (let i = 0; i < line.length; i++) {
        const char = line[i];
        
        if (char === '"') {
          inQuotes = !inQuotes;
        } else if (char === ',' && !inQuotes) {
          result.push(current.trim());
          current = '';
        } else {
          current += char;
        }
      }
      result.push(current.trim());
      return result;
    }
    
    // Parse headers with better detection
    const headerLine = parseCSVLine(lines[0]);
    const headers = headerLine.map(h => h.toLowerCase().replace(/['"]/g, ''));
    
    console.log('CSV Headers found:', headers);
    
    // Find column indices with more flexible matching
    const rollIndex = headers.findIndex(h => 
      h.includes('roll') || 
      h.includes('number') || 
      h.includes('id') ||
      h === 'roll_number' ||
      h === 'student_id'
    );
    
    const nameIndex = headers.findIndex(h => 
      h.includes('name') || 
      h.includes('student') ||
      h === 'student_name' ||
      h === 'full_name'
    );
    
    const emailIndex = headers.findIndex(h => 
      h.includes('email') || 
      h.includes('mail') ||
      h === 'student_email' ||
      h === 'email_address'
    );
    
    console.log('Column indices:', { rollIndex, nameIndex, emailIndex });
    
    if (rollIndex === -1) {
      throw new Error('CSV file must contain a "Roll Number" or "ID" column. Found columns: ' + headers.join(', '));
    }
    
    if (nameIndex === -1) {
      throw new Error('CSV file must contain a "Student Name" column. Found columns: ' + headers.join(', '));
    }
    
    // Parse student data with better error handling
    const newStudents = [];
    const errors = [];
    
    for (let i = 1; i < lines.length; i++) {
      try {
        const columns = parseCSVLine(lines[i]);
        
        if (columns.length < Math.max(rollIndex, nameIndex) + 1) {
          errors.push(`Row ${i + 1}: Not enough columns`);
          continue;
        }
        
        const rollNumber = columns[rollIndex]?.replace(/['"]/g, '').trim();
        const studentName = columns[nameIndex]?.replace(/['"]/g, '').trim();
        const studentEmail = emailIndex >= 0 ? columns[emailIndex]?.replace(/['"]/g, '').trim() : null;
        
        if (!rollNumber || !studentName) {
          errors.push(`Row ${i + 1}: Missing roll number or student name`);
          continue;
        }
        
        // Check for duplicates in the CSV itself
        const duplicate = newStudents.find(s => s.roll_number === rollNumber);
        if (duplicate) {
          errors.push(`Row ${i + 1}: Duplicate roll number ${rollNumber}`);
          continue;
        }
        
        newStudents.push({
          class_id: selectedClass.id,
          roll_number: rollNumber,
          student_name: studentName,
          student_email: studentEmail && studentEmail !== '' ? studentEmail : null,
          is_verified: false,
          student_profile_id: null
        });
        
      } catch (error) {
        errors.push(`Row ${i + 1}: ${error.message}`);
      }
    }
    
    console.log('Parsed students:', newStudents);
    console.log('Parsing errors:', errors);
    
    if (newStudents.length === 0 && errors.length === 0) {
      throw new Error('No student data found in the file.');
    }
    
    // Store extracted data globally
    extractedStudents = newStudents;
    extractionErrors = errors;
    
    // Check for existing students in database and mark duplicates
    const existingRollNumbers = students.map(s => s.roll_number);
    extractedStudents.forEach(student => {
      if (existingRollNumbers.includes(student.roll_number)) {
        student.status = 'duplicate';
        student.error = 'Roll number already exists in class';
      } else {
        student.status = 'valid';
      }
      student.selected = student.status === 'valid'; // Auto-select valid students
    });
    
    hideLoading();
    
    // Show preview modal
    showPreviewModal();
    
    // Reset file input and clear selected file
    if (fileInput) fileInput.value = '';
    selectedFile = null;
    resetUploadArea();
    
  } catch (error) {
    console.error('Error uploading CSV:', error);
    showMsg('messageDisplay', 'Error uploading CSV: ' + error.message, true);
    hideLoading();
  }
}

// Reset upload area
function resetUploadArea() {
  const uploadArea = document.getElementById('uploadArea');
  if (uploadArea) {
    uploadArea.innerHTML = `
      <div class="upload-icon">📄</div>
      <div class="upload-text">Drop your CSV or PDF file here or click to browse</div>
      <div class="upload-subtext">Supported formats: CSV or PDF with columns: Roll Number, Student Name, Email (optional)</div>
      <input type="file" id="csvFile" class="file-input" accept=".csv,.pdf" />
      <button class="btn btn-primary" onclick="document.getElementById('csvFile').click()">
        📁 Choose File
      </button>
    `;
    
    // Re-setup event listeners for the new file input
    setTimeout(() => {
      setupEventListeners();
    }, 100);
  }
}

// Add student manually
async function addStudent(event) {
  event.preventDefault();
  
  const rollNumber = document.getElementById('rollNumber').value.trim();
  const studentName = document.getElementById('studentName').value.trim();
  const studentEmail = document.getElementById('studentEmail').value.trim();
  
  if (!rollNumber || !studentName) {
    showMsg('messageDisplay', 'Roll number and student name are required.', true);
    return;
  }
  
  // Check if student already exists
  const existingStudent = students.find(s => s.roll_number === rollNumber);
  if (existingStudent) {
    showMsg('messageDisplay', 'A student with this roll number already exists.', true);
    return;
  }
  
  try {
    showLoading('Adding student...');
    
    const newStudent = {
      class_id: selectedClass.id,
      roll_number: rollNumber,
      student_name: studentName,
      student_email: studentEmail || null,
      is_verified: false,
      student_profile_id: null
    };
    
    const { data: insertedData, error } = await window.supabaseClient
      .from('class_rosters')
      .insert([newStudent])
      .select();
    
    if (error) throw error;
    
    // Try to automatically link the newly added student
    if (insertedData && insertedData[0]) {
      const insertedStudent = insertedData[0];
      await attemptAutoLinkSingleStudent(insertedStudent);
    }
    
    showMsg('messageDisplay', 'Student added successfully!', false);
    
    // Reload students list
    await loadStudents();
    
    // Reset form
    document.getElementById('addStudentForm').reset();
    
    hideLoading();
    
  } catch (error) {
    console.error('Error adding student:', error);
    showMsg('messageDisplay', 'Error adding student: ' + error.message, true);
    hideLoading();
  }
}

// Remove student
async function removeStudent(studentId) {
  if (!confirm('Are you sure you want to remove this student from the class roster?')) {
    return;
  }
  
  try {
    showLoading('Removing student...');
    
    const { error } = await window.supabaseClient
      .from('class_rosters')
      .delete()
      .eq('id', studentId);
    
    if (error) throw error;
    
    showMsg('messageDisplay', 'Student removed successfully!', false);
    
    // Reload students list
    await loadStudents();
    
    hideLoading();
    
  } catch (error) {
    console.error('Error removing student:', error);
    showMsg('messageDisplay', 'Error removing student: ' + error.message, true);
    hideLoading();
  }
}

// Download CSV template
function downloadTemplate() {
  const csvContent = [
    ['Roll Number', 'Student Name', 'Email'],
    ['2021001', 'Alice Johnson', 'alice.johnson@example.com'],
    ['2021002', 'Bob Smith', 'bob.smith@example.com'],
    ['2021003', 'Charlie Brown', 'charlie.brown@example.com'],
    ['2021004', 'Diana Prince', 'diana.prince@example.com'],
    ['2021005', 'Edward Wilson', '']
  ].map(row => row.map(cell => cell.includes(',') ? `"${cell}"` : cell).join(',')).join('\n');

  const blob = new Blob([csvContent], { type: 'text/csv' });
  const url = window.URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = 'student_roster_template.csv';
  a.click();
  window.URL.revokeObjectURL(url);
  
  showMsg('messageDisplay', 'Template downloaded successfully!', false);
}

// Show PDF help
function showPDFHelp() {
  const helpMessage = `
PDF Support Information:

Currently, PDF files are not automatically parsed. To upload student data from a PDF:

1. Open your PDF file
2. Select and copy the student data (Roll Number, Name, Email)
3. Paste into a spreadsheet program (Excel, Google Sheets)
4. Save/Export as CSV format
5. Upload the CSV file here

Alternative: Use online PDF to CSV converters like:
- SmallPDF
- ILovePDF
- PDF24

The CSV should have columns: Roll Number, Student Name, Email
  `;
  
  alert(helpMessage);
}

// Link student profile by matching roll number with student_id in profiles table
async function linkStudentProfile(studentId, rollNumber) {
  if (!confirm(`Link student with roll number ${rollNumber} to their app profile?`)) {
    return;
  }
  
  try {
    showLoading('Searching for student profile...');
    
    // Search for user profile with matching student_id (roll number)
    const { data: profileData, error: profileError } = await window.supabaseClient
      .from('profiles')
      .select('id, full_name, email, student_id')
      .eq('student_id', rollNumber)
      .single();
    
    if (profileError && profileError.code !== 'PGRST116') {
      throw profileError;
    }
    
    if (!profileData) {
      showMsg('messageDisplay', `No app profile found with roll number ${rollNumber}. Student needs to register in the app first.`, true);
      hideLoading();
      return;
    }
    
    // Update class_rosters with the profile ID
    const { error: updateError } = await window.supabaseClient
      .from('class_rosters')
      .update({ 
        student_profile_id: profileData.id,
        is_verified: true,
        // Update name and email if they exist in profile
        student_name: profileData.full_name || students.find(s => s.id === studentId)?.student_name,
        student_email: profileData.email || students.find(s => s.id === studentId)?.student_email
      })
      .eq('id', studentId);
    
    if (updateError) throw updateError;
    
    showMsg('messageDisplay', `Successfully linked ${profileData.full_name} (${rollNumber}) to their app profile!`, false);
    
    // Reload students list
    await loadStudents();
    
    hideLoading();
    
  } catch (error) {
    console.error('Error linking student profile:', error);
    showMsg('messageDisplay', 'Error linking student profile: ' + error.message, true);
    hideLoading();
  }
}

// Unlink student profile
async function unlinkStudentProfile(studentId) {
  if (!confirm('Unlink this student from their app profile? This will not delete their app account.')) {
    return;
  }
  
  try {
    showLoading('Unlinking student profile...');
    
    // Update class_rosters to remove the profile ID
    const { error } = await window.supabaseClient
      .from('class_rosters')
      .update({ 
        student_profile_id: null,
        is_verified: false
      })
      .eq('id', studentId);
    
    if (error) throw error;
    
    showMsg('messageDisplay', 'Student profile unlinked successfully!', false);
    
    // Reload students list
    await loadStudents();
    
    hideLoading();
    
  } catch (error) {
    console.error('Error unlinking student profile:', error);
    showMsg('messageDisplay', 'Error unlinking student profile: ' + error.message, true);
    hideLoading();
  }
}

// Attempt to auto-link a single student
async function attemptAutoLinkSingleStudent(student) {
  try {
    // Search for user profile with matching student_id (roll number)
    const { data: profileData, error: profileError } = await window.supabaseClient
      .from('profiles')
      .select('id, full_name, email, student_id')
      .eq('student_id', student.roll_number)
      .single();
    
    if (profileError && profileError.code !== 'PGRST116') {
      console.warn(`Auto-link single: Error searching for ${student.roll_number}:`, profileError);
      return false;
    }
    
    if (!profileData) {
      return false; // No matching profile found
    }
    
    // Update class_rosters with the profile ID
    const { error: updateError } = await window.supabaseClient
      .from('class_rosters')
      .update({ 
        student_profile_id: profileData.id,
        is_verified: true,
        student_name: profileData.full_name || student.student_name,
        student_email: profileData.email || student.student_email
      })
      .eq('id', student.id);
    
    if (updateError) {
      console.warn(`Auto-link single: Error updating ${student.roll_number}:`, updateError);
      return false;
    }
    
    console.log(`Auto-linked new student: ${profileData.full_name} (${student.roll_number})`);
    return true;
    
  } catch (error) {
    console.warn(`Auto-link single: Error processing ${student.roll_number}:`, error);
    return false;
  }
}

// Automatically link unlinked students (runs silently in background)
async function autoLinkUnlinkedStudents() {
  const unlinkedStudents = students.filter(student => !student.student_profile_id);
  
  if (unlinkedStudents.length === 0) {
    return; // No students to link
  }
  
  console.log(`Auto-linking ${unlinkedStudents.length} unlinked students...`);
  
  let linkedCount = 0;
  
  for (const student of unlinkedStudents) {
    try {
      // Search for user profile with matching student_id (roll number)
      const { data: profileData, error: profileError } = await window.supabaseClient
        .from('profiles')
        .select('id, full_name, email, student_id')
        .eq('student_id', student.roll_number)
        .single();
      
      if (profileError && profileError.code !== 'PGRST116') {
        console.warn(`Auto-link: Error searching for ${student.roll_number}:`, profileError);
        continue;
      }
      
      if (!profileData) {
        continue; // No matching profile found
      }
      
      // Update class_rosters with the profile ID
      const { error: updateError } = await window.supabaseClient
        .from('class_rosters')
        .update({ 
          student_profile_id: profileData.id,
          is_verified: true,
          student_name: profileData.full_name || student.student_name,
          student_email: profileData.email || student.student_email
        })
        .eq('id', student.id);
      
      if (updateError) {
        console.warn(`Auto-link: Error updating ${student.roll_number}:`, updateError);
        continue;
      }
      
      // Update the local student object
      const studentIndex = students.findIndex(s => s.id === student.id);
      if (studentIndex !== -1) {
        students[studentIndex].student_profile_id = profileData.id;
        students[studentIndex].is_verified = true;
        students[studentIndex].student_name = profileData.full_name || student.student_name;
        students[studentIndex].student_email = profileData.email || student.student_email;
      }
      
      linkedCount++;
      
    } catch (error) {
      console.warn(`Auto-link: Error processing ${student.roll_number}:`, error);
    }
  }
  
  if (linkedCount > 0) {
    console.log(`Auto-linked ${linkedCount} students successfully`);
    
    // Update the UI to reflect the changes
    renderStudentsTable();
    updateStudentStats();
    
    // Show a subtle notification
    showMsg('messageDisplay', `🔗 Automatically linked ${linkedCount} student${linkedCount > 1 ? 's' : ''} to their app profiles!`, false);
  }
}

// Move student up in the list
async function moveStudentUp(index) {
  if (index <= 0) return;
  
  try {
    showLoading('Updating student positions...');
    
    // Swap students in the array
    const temp = students[index];
    students[index] = students[index - 1];
    students[index - 1] = temp;
    
    // Update positions in database
    await updateStudentPositions();
    
    renderStudentsTable();
    hideLoading();
    showMsg('messageDisplay', 'Student position updated successfully!', false);
    
  } catch (error) {
    console.error('Error moving student up:', error);
    showMsg('messageDisplay', 'Error updating student position: ' + error.message, true);
    hideLoading();
  }
}

// Move student down in the list
async function moveStudentDown(index) {
  if (index >= students.length - 1) return;
  
  try {
    showLoading('Updating student positions...');
    
    // Swap students in the array
    const temp = students[index];
    students[index] = students[index + 1];
    students[index + 1] = temp;
    
    // Update positions in database
    await updateStudentPositions();
    
    renderStudentsTable();
    hideLoading();
    showMsg('messageDisplay', 'Student position updated successfully!', false);
    
  } catch (error) {
    console.error('Error moving student down:', error);
    showMsg('messageDisplay', 'Error updating student position: ' + error.message, true);
    hideLoading();
  }
}

// Update student positions in database
async function updateStudentPositions() {
  const updates = students.map((student, index) => ({
    id: student.id,
    position: index + 1
  }));
  
  // Note: This would require adding a position column to the database
  // For now, we'll rely on the order being maintained by roll_number
  // In a future update, you could add a position column to class_rosters table
  
  console.log('Student positions updated locally:', updates);
}

// Toggle position mode
function togglePositionMode() {
  positionModeEnabled = !positionModeEnabled;
  
  const toggleBtn = document.getElementById('togglePositionBtn');
  const positionColumns = document.querySelectorAll('.position-column');
  
  if (positionModeEnabled) {
    // Show position columns
    positionColumns.forEach(col => col.style.display = 'table-cell');
    toggleBtn.textContent = '✅ Position Mode';
    toggleBtn.classList.remove('btn-secondary');
    toggleBtn.classList.add('btn-success');
  } else {
    // Hide position columns
    positionColumns.forEach(col => col.style.display = 'none');
    toggleBtn.textContent = '🔄 Change Position';
    toggleBtn.classList.remove('btn-success');
    toggleBtn.classList.add('btn-secondary');
  }
  
  // Re-render table to update position controls
  renderStudentsTable();
}

// Show linking help
function showLinkingHelp() {
  const helpMessage = `
Profile Linking Help:

🔗 What is Profile Linking?
Profile linking connects students in your class roster to their app accounts, enabling:
- Attendance data to appear in the student app
- Automatic verification of student identity
- Better integration between admin panel and student app

📱 How it Works:
1. Students register in the EduNest mobile app with their Roll Number/Student ID
2. System automatically links them when you load the student management page
3. Manual "Auto-Link All Students" button for immediate bulk linking
4. Individual "Link Profile" buttons for specific students

⚠️ Requirements:
- Students must be registered in the app first
- Roll numbers in your roster must exactly match Student IDs in app profiles
- Case-sensitive matching (2021001 ≠ 2021-001)

✅ Benefits of Linking:
- Students can view their attendance in the app
- Verified status shows app connection
- Better data synchronization
- Enhanced student experience
- Automatic linking on page load

🔧 Troubleshooting:
- "Not Connected" means student hasn't registered in app yet
- Check roll number format matches exactly
- Students can update their Student ID in app profile settings
- Auto-linking happens every time you load this page
  `;
  
  alert(helpMessage);
}

// Bulk link all students with matching roll numbers (force re-link)
async function bulkLinkStudentProfiles() {
  if (!confirm('Force re-link all students with matching app profiles? This will check all students, including already linked ones.')) {
    return;
  }
  
  try {
    showLoading('Bulk linking student profiles...');
    
    let linkedCount = 0;
    let notFoundCount = 0;
    
    for (const student of students) {
      // Note: We now check all students, not just unlinked ones (force re-link)
      
      try {
        // Search for user profile with matching student_id (roll number)
        const { data: profileData, error: profileError } = await window.supabaseClient
          .from('profiles')
          .select('id, full_name, email, student_id')
          .eq('student_id', student.roll_number)
          .single();
        
        if (profileError && profileError.code !== 'PGRST116') {
          console.warn(`Error searching for ${student.roll_number}:`, profileError);
          continue;
        }
        
        if (!profileData) {
          notFoundCount++;
          continue;
        }
        
        // Update class_rosters with the profile ID
        const { error: updateError } = await window.supabaseClient
          .from('class_rosters')
          .update({ 
            student_profile_id: profileData.id,
            is_verified: true,
            student_name: profileData.full_name || student.student_name,
            student_email: profileData.email || student.student_email
          })
          .eq('id', student.id);
        
        if (updateError) {
          console.warn(`Error updating ${student.roll_number}:`, updateError);
          continue;
        }
        
        linkedCount++;
        
      } catch (error) {
        console.warn(`Error processing ${student.roll_number}:`, error);
      }
    }
    
    showMsg('messageDisplay', `Bulk linking complete! Linked: ${linkedCount}, Not found: ${notFoundCount}`, false);
    
    // Reload students list
    await loadStudents();
    
    hideLoading();
    
  } catch (error) {
    console.error('Error bulk linking student profiles:', error);
    showMsg('messageDisplay', 'Error bulk linking student profiles: ' + error.message, true);
    hideLoading();
  }
}

// Show preview modal with extracted data
function showPreviewModal() {
  const modal = document.getElementById('previewModal');
  if (!modal) return;
  
  // Update stats
  const totalStudents = extractedStudents.length;
  const validStudents = extractedStudents.filter(s => s.status === 'valid').length;
  const errorCount = extractionErrors.length + extractedStudents.filter(s => s.status !== 'valid').length;
  
  document.getElementById('previewTotal').textContent = totalStudents;
  document.getElementById('previewValid').textContent = validStudents;
  document.getElementById('previewErrors').textContent = errorCount;
  
  // Render preview table
  renderPreviewTable();
  
  // Show/hide error section
  const errorSection = document.getElementById('errorSection');
  const errorList = document.getElementById('errorList');
  
  if (extractionErrors.length > 0) {
    errorSection.style.display = 'block';
    errorList.innerHTML = extractionErrors.map(error => 
      `<div class="error-item">${error}</div>`
    ).join('');
  } else {
    errorSection.style.display = 'none';
  }
  
  // Show modal
  modal.classList.remove('hidden');
  
  // Add keyboard event listener
  document.addEventListener('keydown', handleModalKeydown);
  
  // Force a re-render after a short delay to ensure DOM is ready
  setTimeout(() => {
    renderPreviewTable();
  }, 100);
}

// Render preview table
function renderPreviewTable() {
  const tableBody = document.getElementById('previewTableBody');
  if (!tableBody) {
    console.error('Preview table body not found');
    return;
  }
  
  console.log('Rendering preview table with', extractedStudents.length, 'students');
  console.log('Extracted students data:', extractedStudents);
  
  if (extractedStudents.length === 0) {
    tableBody.innerHTML = `
      <tr>
        <td colspan="6" style="text-align: center; padding: 2rem;">
          <div>No student data to display</div>
        </td>
      </tr>
    `;
    return;
  }
  
  tableBody.innerHTML = extractedStudents.map((student, index) => `
    <tr>
      <td>
        <input type="checkbox" 
               id="student_${index}" 
               ${student.selected ? 'checked' : ''} 
               ${student.status !== 'valid' ? 'disabled' : ''}
               onchange="toggleStudentSelection(${index})">
      </td>
      <td>
        <input type="text" 
               value="${student.roll_number}" 
               onchange="updateStudentData(${index}, 'roll_number', this.value)"
               ${student.status !== 'valid' ? 'disabled' : ''}>
      </td>
      <td>
        <input type="text" 
               value="${student.student_name}" 
               onchange="updateStudentData(${index}, 'student_name', this.value)"
               ${student.status !== 'valid' ? 'disabled' : ''}>
      </td>
      <td>
        <input type="text" 
               value="${student.student_email || ''}" 
               onchange="updateStudentData(${index}, 'student_email', this.value)"
               ${student.status !== 'valid' ? 'disabled' : ''}>
      </td>
      <td>
        <span class="status-${student.status}">
          ${student.status === 'valid' ? '✅ Valid' : 
            student.status === 'duplicate' ? '⚠️ Duplicate' : '❌ Error'}
        </span>
        ${student.error ? `<br><small>${student.error}</small>` : ''}
      </td>
      <td>
        ${student.status !== 'valid' ? 
          `<button class="edit-btn" onclick="fixStudentError(${index})">🔧 Fix</button>` : 
          `<button class="edit-btn" onclick="removeStudentFromPreview(${index})">🗑️ Remove</button>`
        }
      </td>
    </tr>
  `).join('');
}

// Toggle student selection
function toggleStudentSelection(index) {
  if (extractedStudents[index]) {
    extractedStudents[index].selected = !extractedStudents[index].selected;
  }
}

// Update student data
function updateStudentData(index, field, value) {
  if (extractedStudents[index]) {
    extractedStudents[index][field] = value;
    
    // Re-validate the student
    if (field === 'roll_number') {
      const existingRollNumbers = students.map(s => s.roll_number);
      const otherExtractedRolls = extractedStudents
        .filter((s, i) => i !== index)
        .map(s => s.roll_number);
      
      if (existingRollNumbers.includes(value) || otherExtractedRolls.includes(value)) {
        extractedStudents[index].status = 'duplicate';
        extractedStudents[index].error = 'Roll number already exists';
        extractedStudents[index].selected = false;
      } else if (value.trim()) {
        extractedStudents[index].status = 'valid';
        extractedStudents[index].error = null;
        extractedStudents[index].selected = true;
      }
      
      // Re-render the table to update status
      renderPreviewTable();
    }
  }
}

// Fix student error
function fixStudentError(index) {
  const student = extractedStudents[index];
  if (!student) return;
  
  // Enable editing for this student
  student.status = 'valid';
  student.error = null;
  student.selected = true;
  
  renderPreviewTable();
}

// Remove student from preview
function removeStudentFromPreview(index) {
  if (confirm('Remove this student from the upload list?')) {
    extractedStudents.splice(index, 1);
    renderPreviewTable();
    
    // Update stats
    const totalStudents = extractedStudents.length;
    const validStudents = extractedStudents.filter(s => s.status === 'valid').length;
    const errorCount = extractionErrors.length + extractedStudents.filter(s => s.status !== 'valid').length;
    
    document.getElementById('previewTotal').textContent = totalStudents;
    document.getElementById('previewValid').textContent = validStudents;
    document.getElementById('previewErrors').textContent = errorCount;
  }
}

// Select all valid students
function selectAll() {
  extractedStudents.forEach(student => {
    if (student.status === 'valid') {
      student.selected = true;
    }
  });
  renderPreviewTable();
}

// Deselect all students
function deselectAll() {
  extractedStudents.forEach(student => {
    student.selected = false;
  });
  renderPreviewTable();
}

// Handle modal keyboard shortcuts
function handleModalKeydown(event) {
  if (event.key === 'Escape') {
    closePreviewModal();
  }
}

// Close preview modal
function closePreviewModal() {
  const modal = document.getElementById('previewModal');
  if (modal) {
    modal.classList.add('hidden');
    // Remove keyboard event listener
    document.removeEventListener('keydown', handleModalKeydown);
  }
}

// Insert selected students into database
async function insertSelectedStudents() {
  const selectedStudents = extractedStudents.filter(s => s.selected && s.status === 'valid');
  
  if (selectedStudents.length === 0) {
    showMsg('messageDisplay', 'No students selected for insertion.', true);
    return;
  }
  
  try {
    showLoading(`Inserting ${selectedStudents.length} students...`);
    
    // Prepare data for insertion
    const studentsToInsert = selectedStudents.map(student => ({
      class_id: selectedClass.id,
      roll_number: student.roll_number,
      student_name: student.student_name,
      student_email: student.student_email || null,
      is_verified: false,
      student_profile_id: null
    }));
    
    // Insert into database
    const { data: insertedData, error } = await window.supabaseClient
      .from('class_rosters')
      .insert(studentsToInsert)
      .select();
    
    if (error) {
      console.error('Database error:', error);
      throw new Error(`Database error: ${error.message}`);
    }
    
    // Try to automatically link the newly inserted students
    let autoLinkedCount = 0;
    if (insertedData && insertedData.length > 0) {
      for (const insertedStudent of insertedData) {
        const linked = await attemptAutoLinkSingleStudent(insertedStudent);
        if (linked) autoLinkedCount++;
      }
    }
    
    let message = `Successfully inserted ${selectedStudents.length} students!`;
    if (autoLinkedCount > 0) {
      message += ` Auto-linked ${autoLinkedCount} to their app profiles.`;
    }
    
    showMsg('messageDisplay', message, false);
    
    // Close modal
    closePreviewModal();
    
    // Reload students list
    await loadStudents();
    
    hideLoading();
    
  } catch (error) {
    console.error('Error inserting students:', error);
    showMsg('messageDisplay', 'Error inserting students: ' + error.message, true);
    hideLoading();
  }
}

// Show message
function showMsg(id, msg, isError = false) {
  const el = document.getElementById(id);
  if (!el) return;
  
  el.textContent = msg;
  el.style.color = isError ? '#dc2626' : '#22c55e';
  el.style.backgroundColor = isError ? '#fee2e2' : '#dcfce7';
  el.style.borderColor = isError ? '#fecaca' : '#bbf7d0';
  el.classList.remove('hidden');
  
  setTimeout(() => { 
    el.classList.add('hidden');
  }, 5000);
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