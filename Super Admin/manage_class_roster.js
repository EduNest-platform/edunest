// Super Admin Class Roster Management System
let currentClass = null;
let currentStudents = [];
let classId = null;
let duplicateStudents = [];
let rollNumberHistory = new Map(); // Track roll number changes

// Initialize the application
document.addEventListener('DOMContentLoaded', async function() {
  console.log('Super Admin Class Roster Management - Starting initialization...');
  
  try {
    // Get class ID from URL parameters
    const urlParams = new URLSearchParams(window.location.search);
    classId = urlParams.get('classId');
    
    if (!classId) {
      showMessage('No class ID provided. Redirecting to class rosters...', true);
      setTimeout(() => {
        window.location.href = 'class_rosters.html';
      }, 2000);
      return;
    }
    
    await checkAuthStatus();
    await loadClassData();
    await loadStudents();
    await loadStatistics();
  } catch (error) {
    console.error('Initialization error:', error);
    showMessage('Error initializing class roster management: ' + error.message, true);
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

// Load class data
async function loadClassData() {
  try {
    showLoading('Loading class information...');
    
    // Get class details from professor_classes table
    const { data: classData, error } = await window.supabaseClient
      .from('professor_classes')
      .select('*')
      .eq('id', classId)
      .single();
    
    if (error) throw error;
    
    if (!classData) {
      throw new Error('Class not found');
    }
    
    currentClass = classData;
    
    // Update page subtitle
    document.getElementById('pageSubtitle').textContent = 
      `${classData.subject_name || classData.class_name || 'Unnamed Class'} - ${classData.professor_email}`;
    
    // Render class details
    renderClassDetails(classData);
    
    hideLoading();
  } catch (error) {
    console.error('Error loading class data:', error);
    showMessage('Error loading class data: ' + error.message, true);
    hideLoading();
  }
}

// Render class details
function renderClassDetails(classData) {
  const container = document.getElementById('classDetails');
  
  container.innerHTML = `
    <div class="detail-item">
      <div class="detail-label">Subject Name</div>
      <div class="detail-value">${classData.subject_name || 'N/A'}</div>
    </div>
    <div class="detail-item">
      <div class="detail-label">Class Name</div>
      <div class="detail-value">${classData.class_name || 'N/A'}</div>
    </div>
    <div class="detail-item">
      <div class="detail-label">Professor</div>
      <div class="detail-value">${classData.professor_email || 'N/A'}</div>
    </div>
    <div class="detail-item">
      <div class="detail-label">College</div>
      <div class="detail-value">${classData.college_name || 'N/A'}</div>
    </div>
    <div class="detail-item">
      <div class="detail-label">Branch</div>
      <div class="detail-value">${classData.branch_name || 'N/A'}</div>
    </div>
    <div class="detail-item">
      <div class="detail-label">Semester</div>
      <div class="detail-value">${classData.semester_name || 'N/A'}</div>
    </div>
    <div class="detail-item">
      <div class="detail-label">Created</div>
      <div class="detail-value">${new Date(classData.created_at).toLocaleDateString()}</div>
    </div>
    <div class="detail-item">
      <div class="detail-label">Class ID</div>
      <div class="detail-value" style="font-family: monospace; font-size: 0.9rem;">${classData.id}</div>
    </div>
  `;
}

// Load students for the class
async function loadStudents() {
  try {
    showLoading('Loading students...');
    
    // Get students from class_rosters table
    const { data: students, error } = await window.supabaseClient
      .from('class_rosters')
      .select('*')
      .eq('class_id', classId)
      .order('roll_number');
    
    if (error) throw error;
    
    currentStudents = students || [];
    
    // For each student, try to get their profile information
    const studentsWithProfiles = await Promise.all(currentStudents.map(async (student) => {
      if (student.student_profile_id) {
        try {
          const { data: profile, error: profileError } = await window.supabaseClient
            .from('profiles')
            .select('id, full_name, email, student_id')
            .eq('id', student.student_profile_id)
            .single();
          
          if (profileError) {
            console.warn('Error fetching profile for student', student.id, profileError);
          }
          
          return { ...student, profile };
        } catch (error) {
          console.warn('Error fetching profile for student', student.id, error);
          return student;
        }
      }
      return student;
    }));
    
    currentStudents = studentsWithProfiles;
    
    // Detect and handle duplicates
    await detectDuplicateStudents();
    
    renderStudentsTable();
    
    // Show duplicate warning if found
    if (duplicateStudents.length > 0) {
      showDuplicateWarning();
    }
    
    hideLoading();
  } catch (error) {
    console.error('Error loading students:', error);
    showMessage('Error loading students: ' + error.message, true);
    hideLoading();
  }
}

// Render students table
function renderStudentsTable() {
  const container = document.getElementById('studentsContainer');
  
  if (currentStudents.length === 0) {
    container.innerHTML = `
      <div class="empty-state">
        <div class="empty-state-icon">👥</div>
        <h3>No Students in Roster</h3>
        <p>This class doesn't have any students yet. Use the "Add Student" button to add students.</p>
      </div>
    `;
    return;
  }
  
  container.innerHTML = `
    <div class="table-wrapper">
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
            <td><strong>${student.roll_number || 'N/A'}</strong></td>
            <td>
              <div>${student.student_name || 'N/A'}</div>
              ${student.profile?.full_name ? 
                `<small style="color: #64748b;">App: ${student.profile.full_name}</small>` : ''}
            </td>
            <td>
              ${student.student_email || 'Not provided'}<br>
              ${student.profile?.email ? 
                `<small style="color: #64748b;">App: ${student.profile.email}</small>` : ''}
            </td>
            <td>
              <span class="status-badge ${student.student_profile_id ? 'connected' : 'not-connected'}">
                ${student.student_profile_id ? '✓ Connected' : '⚠ Not Connected'}
              </span>
            </td>
            <td>
              <div style="display: flex; gap: 0.5rem; flex-wrap: wrap;">
                <button class="action-btn ${student.student_profile_id ? 'danger' : 'success'}" 
                        onclick="${student.student_profile_id ? `unlinkStudent('${student.id}')` : `linkStudent('${student.id}')`}"
                        style="font-size: 0.8rem; padding: 0.4rem 0.8rem; min-width: 80px;">
                  ${student.student_profile_id ? 'Unlink' : 'Link'}
                </button>
                ${student.student_profile_id ? `
                <button class="action-btn primary" 
                        onclick="replaceStudentAccount('${student.id}')"
                        style="font-size: 0.8rem; padding: 0.4rem 0.8rem; min-width: 80px;"
                        title="Replace with correct account">
                  Replace
                </button>` : ''}
                <button class="action-btn secondary" 
                        onclick="editStudent('${student.id}')"
                        style="font-size: 0.8rem; padding: 0.4rem 0.8rem; min-width: 80px;">
                  Edit
                </button>
                <button class="action-btn danger" 
                        onclick="removeStudent('${student.id}')"
                        style="font-size: 0.8rem; padding: 0.4rem 0.8rem; min-width: 80px;">
                  Remove
                </button>
              </div>
            </td>
          </tr>
        `).join('')}
        </tbody>
      </table>
    </div>
  `;
}

// Load statistics
async function loadStatistics() {
  try {
    const totalStudents = currentStudents.length;
    const connectedStudents = currentStudents.filter(s => s.student_profile_id).length;
    const unconnectedStudents = totalStudents - connectedStudents;
    const verifiedStudents = currentStudents.filter(s => s.is_verified).length;
    
    // Update statistics display
    document.getElementById('totalStudents').textContent = totalStudents;
    document.getElementById('connectedStudents').textContent = connectedStudents;
    document.getElementById('unconnectedStudents').textContent = unconnectedStudents;
    document.getElementById('verifiedStudents').textContent = verifiedStudents;
    
  } catch (error) {
    console.error('Error loading statistics:', error);
  }
}

// Toggle add student form
function toggleAddStudentForm() {
  const form = document.getElementById('addStudentForm');
  form.classList.toggle('show');
  
  if (form.classList.contains('show')) {
    // Clear form
    document.getElementById('rollNumber').value = '';
    document.getElementById('studentName').value = '';
    document.getElementById('studentEmail').value = '';
    
    // Focus on first input
    document.getElementById('rollNumber').focus();
  }
}

// Add student to class roster
async function addStudent(event) {
  event.preventDefault();
  
  const rollNumber = document.getElementById('rollNumber').value.trim();
  const studentName = document.getElementById('studentName').value.trim();
  const studentEmail = document.getElementById('studentEmail').value.trim();
  
  if (!rollNumber || !studentName) {
    showMessage('Roll number and student name are required.', true);
    return;
  }
  
  try {
    showLoading('Adding student...');
    
    // Check if roll number already exists in this class
    const { data: existingStudent, error: checkError } = await window.supabaseClient
      .from('class_rosters')
      .select('id')
      .eq('class_id', classId)
      .eq('roll_number', rollNumber)
      .single();
    
    if (checkError && checkError.code !== 'PGRST116') {
      throw checkError;
    }
    
    if (existingStudent) {
      showMessage('A student with this roll number already exists in the class.', true);
      hideLoading();
      return;
    }
    
    // Add student to class roster
    const { error: insertError } = await window.supabaseClient
      .from('class_rosters')
      .insert({
        class_id: classId,
        roll_number: rollNumber,
        student_name: studentName,
        student_email: studentEmail || null,
        is_verified: false
      });
    
    if (insertError) throw insertError;
    
    showMessage(`Student ${studentName} (${rollNumber}) added successfully!`, false);
    
    // Refresh the view
    await loadStudents();
    await loadStatistics();
    
    // Hide form
    toggleAddStudentForm();
    
    hideLoading();
  } catch (error) {
    console.error('Error adding student:', error);
    showMessage('Error adding student: ' + error.message, true);
    hideLoading();
  }
}

// Link student to app profile
async function linkStudent(studentId) {
  const student = currentStudents.find(s => s.id === studentId);
  if (!student) return;
  
  if (!confirm(`Link student ${student.student_name} (${student.roll_number}) to their app profile?`)) {
    return;
  }
  
  try {
    showLoading('Linking student profile...');
    
    // Search for user profile with matching student_id (roll number)
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
    
    // Update class_rosters with the profile ID (preserve existing name, only update email if not set)
    const { error: updateError } = await window.supabaseClient
      .from('class_rosters')
      .update({ 
        student_profile_id: profileData.id,
        is_verified: true,
        // Only update email if it's not already set in class roster
        student_email: student.student_email || profileData.email
      })
      .eq('id', studentId);
    
    if (updateError) throw updateError;
    
    showMessage(`Successfully linked ${profileData.full_name} (${student.roll_number}) to their app profile!`, false);
    
    // Refresh the view
    await loadStudents();
    await loadStatistics();
    
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
    await loadStudents();
    await loadStatistics();
    
    hideLoading();
  } catch (error) {
    console.error('Error unlinking student profile:', error);
    showMessage('Error unlinking student profile: ' + error.message, true);
    hideLoading();
  }
}

// Edit student information
async function editStudent(studentId) {
  const student = currentStudents.find(s => s.id === studentId);
  if (!student) return;
  
  // Use prompt for inline editing like in admin panel
  const newName = prompt(`Edit student name for ${student.student_name} (Roll: ${student.roll_number}):`, student.student_name);
  
  if (newName === null || newName.trim() === '') {
    return; // User cancelled or entered empty name
  }
  
  if (newName.trim() === student.student_name) {
    showMessage('No changes made.', false);
    return;
  }
  
  try {
    showLoading('Updating student name...');
    
    // Update student name in database
    const { error } = await window.supabaseClient
      .from('class_rosters')
      .update({ student_name: newName.trim() })
      .eq('id', studentId);
    
    if (error) throw error;
    
    showMessage(`Student name updated successfully from "${student.student_name}" to "${newName.trim()}"`, false);
    
    // Refresh the students list
    await loadStudents();
    await loadStatistics();
    
    hideLoading();
  } catch (error) {
    console.error('Error updating student name:', error);
    showMessage('Error updating student name: ' + error.message, true);
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
    await loadStudents();
    await loadStatistics();
    
    hideLoading();
  } catch (error) {
    console.error('Error removing student:', error);
    showMessage('Error removing student: ' + error.message, true);
    hideLoading();
  }
}

// Reset add student form
function resetAddStudentForm() {
  const form = document.querySelector('#addStudentForm form');
  form.onsubmit = addStudent;
  
  const formTitle = document.querySelector('#addStudentForm h4');
  formTitle.textContent = 'Add New Student';
  
  const submitBtn = document.querySelector('#addStudentForm button[type="submit"]');
  submitBtn.textContent = 'Add Student';
  
  toggleAddStudentForm();
}

// Refresh students data
async function refreshStudents() {
  showLoading('Refreshing student data and checking for linkable profiles...');
  
  await loadStudents();
  
  // Attempt to auto-link unlinked students
  await autoLinkUnlinkedStudents();
  
  await loadStatistics();
  hideLoading();
  showMessage('Student data refreshed and auto-linking completed!', false);
}

// Auto-link unlinked students to their profiles
async function autoLinkUnlinkedStudents() {
  try {
    // Find students without linked profiles
    const unlinkedStudents = currentStudents.filter(student => 
      !student.student_profile_id && !student.is_verified
    );
    
    if (unlinkedStudents.length === 0) {
      console.log('No unlinked students found.');
      return;
    }
    
    console.log(`Found ${unlinkedStudents.length} unlinked students. Attempting auto-link...`);
    
    let successCount = 0;
    let notFoundCount = 0;
    let errorCount = 0;
    
    for (const student of unlinkedStudents) {
      try {
        // Search for user profile with matching student_id (roll number)
        const { data: profileData, error: profileError } = await window.supabaseClient
          .from('profiles')
          .select('id, full_name, email, student_id')
          .eq('student_id', student.roll_number)
          .single();
        
        if (profileError && profileError.code !== 'PGRST116') {
          console.error(`Profile search error for ${student.roll_number}:`, profileError);
          errorCount++;
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
          console.error(`Update error for ${student.roll_number}:`, updateError);
          errorCount++;
          continue;
        }
        
        successCount++;
        console.log(`✅ Successfully auto-linked: ${profileData.full_name} (${student.roll_number})`);
        
      } catch (error) {
        console.error(`Error processing ${student.roll_number}:`, error);
        errorCount++;
      }
    }
    
    if (successCount > 0) {
      console.log(`Auto-linking summary: ${successCount} linked, ${notFoundCount} not found, ${errorCount} errors`);
      // Reload students to reflect the updates
      await loadStudents();
    }
    
  } catch (error) {
    console.error('Error in auto-linking process:', error);
  }
}

// Export roster as CSV
function exportRoster() {
  if (currentStudents.length === 0) {
    showMessage('No students to export.', true);
    return;
  }
  
  const headers = ['Roll Number', 'Student Name', 'Email', 'App Connected', 'App Name', 'App Email'];
  const csvContent = [
    headers.join(','),
    ...currentStudents.map(student => [
      student.roll_number || '',
      `"${student.student_name || ''}"`,
      student.student_email || '',
      student.student_profile_id ? 'Yes' : 'No',
      `"${student.profile?.full_name || ''}"`,
      student.profile?.email || ''
    ].join(','))
  ].join('\n');
  
  const blob = new Blob([csvContent], { type: 'text/csv' });
  const url = window.URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `${currentClass?.subject_name || 'class'}_roster_${new Date().toISOString().split('T')[0]}.csv`;
  a.click();
  window.URL.revokeObjectURL(url);
  
  showMessage('Roster exported successfully!', false);
}

// Import preview modal state
let importPreviewData = [];

// Handle file import (CSV and PDF)
function handleCSVImport(event) {
  const file = event.target.files[0];
  if (!file) return;

  const isCSV = file.type === 'text/csv' || file.name.endsWith('.csv');
  const isPDF = file.type === 'application/pdf' || file.name.endsWith('.pdf');

  if (!isCSV && !isPDF) {
    showMessage('Please select a valid CSV or PDF file.', true);
    return;
  }

  if (isCSV) {
    handleCSVFile(file);
  } else if (isPDF) {
    handlePDFFile(file);
  }
  
  // Clear the input
  event.target.value = '';
}

// Handle CSV file processing
function handleCSVFile(file) {
  const reader = new FileReader();
  reader.onload = function(e) {
    try {
      parseCSVAndShowPreview(e.target.result);
    } catch (error) {
      console.error('Error reading CSV file:', error);
      showMessage('Error reading CSV file: ' + error.message, true);
    }
  };
  
  reader.readAsText(file);
}

// Handle PDF file processing
async function handlePDFFile(file) {
  try {
    showLoading('Processing PDF file...');
    
    // Check if PDF.js is available
    if (typeof pdfjsLib === 'undefined') {
      // Load PDF.js dynamically
      await loadPDFJS();
    }
    
    const arrayBuffer = await file.arrayBuffer();
    const pdf = await pdfjsLib.getDocument(arrayBuffer).promise;
    
    let extractedText = '';
    
    // Extract text from all pages
    for (let pageNum = 1; pageNum <= pdf.numPages; pageNum++) {
      const page = await pdf.getPage(pageNum);
      const textContent = await page.getTextContent();
      const pageText = textContent.items.map(item => item.str).join(' ');
      extractedText += pageText + '\n';
    }
    
    // Try to parse the extracted text as tabular data
    const csvData = convertPDFTextToCSV(extractedText);
    
    if (csvData) {
      parseCSVAndShowPreview(csvData);
    } else {
      showMessage('Could not extract student data from PDF. Please ensure the PDF contains a table with roll numbers and student names.', true);
    }
    
    hideLoading();
    
  } catch (error) {
    console.error('Error processing PDF:', error);
    showMessage('Error processing PDF file: ' + error.message, true);
    hideLoading();
  }
}

// Load PDF.js library dynamically
async function loadPDFJS() {
  return new Promise((resolve, reject) => {
    const script = document.createElement('script');
    script.src = 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.min.js';
    script.onload = () => {
      pdfjsLib.GlobalWorkerOptions.workerSrc = 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js';
      resolve();
    };
    script.onerror = reject;
    document.head.appendChild(script);
  });
}

// Convert PDF text to CSV format
function convertPDFTextToCSV(text) {
  try {
    const lines = text.split('\n').filter(line => line.trim().length > 0);
    
    // Look for patterns that might indicate a table
    const potentialStudentLines = [];
    
    for (const line of lines) {
      // Look for lines that might contain roll numbers and names
      // Common patterns: numbers followed by names, or structured data
      if (detectStudentDataPattern(line)) {
        potentialStudentLines.push(line);
      }
    }
    
    if (potentialStudentLines.length === 0) {
      return null;
    }
    
    // Try to create CSV format
    let csvContent = 'Roll Number,Student Name,Email\n';
    
    for (const line of potentialStudentLines) {
      const extracted = extractStudentDataFromLine(line);
      if (extracted) {
        csvContent += `"${extracted.rollNumber}","${extracted.name}","${extracted.email || ''}"\n`;
      }
    }
    
    return csvContent;
    
  } catch (error) {
    console.error('Error converting PDF text to CSV:', error);
    return null;
  }
}

// Detect if a line contains student data
function detectStudentDataPattern(line) {
  const trimmedLine = line.trim();
  
  // Skip empty lines and obvious headers/footers
  if (trimmedLine.length < 10) return false;
  if (trimmedLine.toLowerCase().includes('page') && trimmedLine.length < 20) return false;
  if (trimmedLine.toLowerCase().includes('total') && trimmedLine.length < 30) return false;
  
  // Look for patterns that suggest student data
  const patterns = [
    /^\d+\s+[A-Za-z]/,  // Number followed by letters (roll + name)
    /[A-Z0-9]{3,}\s+[A-Za-z]{2,}/,  // Alphanumeric roll + name
    /^\w+\s+[A-Z][a-z]+\s+[A-Z][a-z]+/,  // Roll + First + Last name
  ];
  
  return patterns.some(pattern => pattern.test(trimmedLine));
}

// Extract student data from a line
function extractStudentDataFromLine(line) {
  const trimmedLine = line.trim();
  
  try {
    // Common patterns for student data extraction
    const patterns = [
      // Pattern 1: Roll Number followed by Name (space separated)
      {
        regex: /^(\w+)\s+([A-Za-z][A-Za-z\s\.]+?)(?:\s+([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}))?(?:\s|$)/,
        rollGroup: 1,
        nameGroup: 2,
        emailGroup: 3
      },
      // Pattern 2: More flexible pattern
      {
        regex: /(\w{2,})\s+([A-Za-z][A-Za-z\s\.']+)(?:\s+([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}))?/,
        rollGroup: 1,
        nameGroup: 2,
        emailGroup: 3
      }
    ];
    
    for (const pattern of patterns) {
      const match = trimmedLine.match(pattern.regex);
      if (match) {
        const rollNumber = normalizeRollNumber(match[pattern.rollGroup]);
        const name = normalizeStudentName(match[pattern.nameGroup]);
        const email = match[pattern.emailGroup] || '';
        
        // Validate extracted data
        if (rollNumber && rollNumber.length >= 2 && name && name.length >= 2) {
          return {
            rollNumber,
            name,
            email: email.trim()
          };
        }
      }
    }
    
    return null;
    
  } catch (error) {
    console.error('Error extracting student data from line:', error);
    return null;
  }
}

// Analyze column content to identify data types
function analyzeColumnContent(lines, headers, headerRowIndex = 0) {
  const analysis = {
    rollNumberIndex: -1,
    nameIndex: -1,
    emailIndex: -1
  };
  
  const dataStartIndex = headerRowIndex + 1;
  if (lines.length <= dataStartIndex) return analysis;
  
  // Analyze first few rows of data
  const sampleSize = Math.min(5, lines.length - dataStartIndex);
  const columnScores = headers.map(() => ({
    rollNumberScore: 0,
    nameScore: 0,
    emailScore: 0,
    serialNumberScore: 0
  }));
  
  for (let i = dataStartIndex; i < dataStartIndex + sampleSize; i++) {
    const row = parseCSVRow(lines[i]);
    
    for (let colIndex = 0; colIndex < Math.min(row.length, headers.length); colIndex++) {
      const cell = (row[colIndex] || '').toString().trim();
      if (!cell) continue;
      
      // Check for serial numbers (pure sequential digits)
      if (/^\d+$/.test(cell) && parseInt(cell) <= 100) {
        columnScores[colIndex].serialNumberScore += 10;
      }
      
      // Check for roll number patterns
      if (/^[A-Za-z0-9\/\-_\.]+$/.test(cell) && cell.length >= 2 && cell.length <= 15) {
        // Good roll number candidate - look for patterns like "401/23", "ABC123", etc.
        if (!/^\d+$/.test(cell) || parseInt(cell) > 100) {
          // Bonus for alphanumeric or large numbers
          if (/\d/.test(cell) && (/[A-Za-z]/.test(cell) || /\//.test(cell) || /\-/.test(cell))) {
            columnScores[colIndex].rollNumberScore += 10; // Strong roll number pattern
          } else {
            columnScores[colIndex].rollNumberScore += 3;
          }
        }
      }
      
      // Check for name patterns
      if (/^[A-Za-z\u00C0-\u017F\u0900-\u097F\s\.\-']+$/.test(cell) && cell.length >= 2) {
        // Contains letters and valid name characters
        const words = cell.trim().split(/\s+/);
        if (words.length >= 1 && words.length <= 5) {
          // Bonus for multiple words (typical names)
          if (words.length >= 2) {
            columnScores[colIndex].nameScore += 10; // Strong name pattern
          } else if (words.length === 1 && cell.length >= 3) {
            columnScores[colIndex].nameScore += 5; // Single name
          }
          
          // Penalty if it looks like a roll number pattern
          if (/\d/.test(cell) && (/\//.test(cell) || /\-/.test(cell))) {
            columnScores[colIndex].nameScore -= 5;
          }
        }
      }
      
      // Check for email patterns
      if (/@/.test(cell) && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(cell)) {
        columnScores[colIndex].emailScore += 10;
      }
    }
  }
  
  // Find best candidates while avoiding serial number columns
  let bestRollNumberScore = 0;
  let bestNameScore = 0;
  let bestEmailScore = 0;
  
  for (let i = 0; i < columnScores.length; i++) {
    const score = columnScores[i];
    
    // Skip columns that look like serial numbers
    if (score.serialNumberScore > score.rollNumberScore && score.serialNumberScore > score.nameScore) {
      console.log(`Column ${i} (${headers[i]}) identified as serial number column`);
      continue;
    }
    
    if (score.rollNumberScore > bestRollNumberScore) {
      bestRollNumberScore = score.rollNumberScore;
      analysis.rollNumberIndex = i;
    }
    
    if (score.nameScore > bestNameScore) {
      bestNameScore = score.nameScore;
      analysis.nameIndex = i;
    }
    
    if (score.emailScore > bestEmailScore) {
      bestEmailScore = score.emailScore;
      analysis.emailIndex = i;
    }
  }
  
  console.log('Content analysis scores:', columnScores);
  console.log('Content analysis result:', analysis);
  
  return analysis;
}

// Parse CSV content and show preview
async function parseCSVAndShowPreview(csvContent) {
  try {
    showLoading('Processing CSV file...');
    
    const lines = csvContent.trim().split('\n');
    if (lines.length < 2) {
      showMessage('CSV file must have at least a header row and one data row.', true);
      hideLoading();
      return;
    }
    
    // Find the actual header row (sometimes first line is empty)
    let headerRowIndex = 0;
    let headers = [];
    
    for (let i = 0; i < Math.min(3, lines.length); i++) {
      const potentialHeaders = parseCSVRow(lines[i]).map(h => h.trim().toLowerCase().replace(/['"]/g, ''));
      console.log(`Line ${i + 1} potential headers:`, potentialHeaders);
      
      // Check if this line contains header-like content
      const hasHeaderContent = potentialHeaders.some(h => 
        h.includes('roll') || h.includes('name') || h.includes('student') || 
        h.includes('sl') || h.includes('serial') || h.includes('email')
      );
      
      if (hasHeaderContent && potentialHeaders.filter(h => h.length > 0).length >= 2) {
        headers = potentialHeaders;
        headerRowIndex = i;
        console.log(`Using line ${i + 1} as headers:`, headers);
        break;
      }
    }
    
    if (headers.length === 0 || headers.filter(h => h.length > 0).length < 2) {
      showMessage('Could not find valid headers in CSV. Please ensure your CSV has proper column headers.', true);
      hideLoading();
      return;
    }
    
    console.log('Raw first line:', lines[0]);
    console.log('Parsed headers:', headers);
    console.log(`Raw data start line (${headerRowIndex + 2}):`, lines[headerRowIndex + 1]);
    if (lines[headerRowIndex + 1]) {
      console.log('Parsed data start line:', parseCSVRow(lines[headerRowIndex + 1]));
    }
    if (lines[headerRowIndex + 2]) {
      console.log(`Raw data line 2 (${headerRowIndex + 3}):`, lines[headerRowIndex + 2]);
      console.log('Parsed data line 2:', parseCSVRow(lines[headerRowIndex + 2]));
    }
    
    // Enhanced column detection with more specific patterns
    const rollNumberPatterns = [
      'roll number', 'roll no', 'rollno', 'roll_number', 'roll_no', 
      'student id', 'student_id', 'studentid', 'reg no', 'reg_no', 
      'registration number', 'registration_number', 'admission no', 'admission_no',
      'enroll', 'enrollment', 'regd no', 'regd_no', 'regno'
    ];
    
    const namePatterns = [
      'student name', 'student_name', 'studentname', 'name', 'full name', 
      'full_name', 'fullname', 'first name', 'fname', 'student', 
      'candidate name', 'candidate_name'
    ];
    
    const emailPatterns = [
      'email', 'email address', 'email_address', 'e-mail', 'e_mail',
      'mail', 'student email', 'student_email'
    ];
    
    // Patterns to exclude (serial numbers, etc.)
    const excludePatterns = [
      'sl no', 'sl.no', 'slno', 'sl_no', 'serial no', 'serial_no', 'serialno',
      's.no', 'sno', 's no', 'serial number', 'serial_number', 'sr no', 'sr.no'
    ];
    
    // Find best matching columns while excluding serial number columns
    const rollNumberIndex = findBestMatchWithExclusion(headers, rollNumberPatterns, excludePatterns);
    const nameIndex = findBestMatchWithExclusion(headers, namePatterns, excludePatterns);
    const emailIndex = findBestMatch(headers, emailPatterns);
    
    // If standard detection failed, try content-based detection
    let finalRollNumberIndex = rollNumberIndex;
    let finalNameIndex = nameIndex;
    let finalEmailIndex = emailIndex;
    
    if (rollNumberIndex === -1 || nameIndex === -1) {
      console.log('Standard column detection failed, trying content-based detection...');
      const contentAnalysis = analyzeColumnContent(lines, headers, headerRowIndex);
      
      if (rollNumberIndex === -1 && contentAnalysis.rollNumberIndex !== -1) {
        finalRollNumberIndex = contentAnalysis.rollNumberIndex;
        console.log('Content-based roll number detection:', headers[finalRollNumberIndex]);
      }
      
      if (nameIndex === -1 && contentAnalysis.nameIndex !== -1) {
        finalNameIndex = contentAnalysis.nameIndex;
        console.log('Content-based name detection:', headers[finalNameIndex]);
      }
      
      if (emailIndex === -1 && contentAnalysis.emailIndex !== -1) {
        finalEmailIndex = contentAnalysis.emailIndex;
        console.log('Content-based email detection:', headers[finalEmailIndex]);
      }
    }
    
    // Debug: Log detected headers
    console.log('All headers:', headers);
    console.log('Roll number index:', finalRollNumberIndex, finalRollNumberIndex !== -1 ? headers[finalRollNumberIndex] : 'Not found');
    console.log('Name index:', finalNameIndex, finalNameIndex !== -1 ? headers[finalNameIndex] : 'Not found');
    console.log('Email index:', finalEmailIndex, finalEmailIndex !== -1 ? headers[finalEmailIndex] : 'Not found');
    
    if (finalRollNumberIndex === -1) {
      showMessage(`Roll number column not found. Please ensure your CSV has a column with one of these headers: ${rollNumberPatterns.slice(0, 5).join(', ')}, etc. Detected headers: ${headers.join(', ')}`, true);
      hideLoading();
      return;
    }
    
    if (finalNameIndex === -1) {
      showMessage(`Student name column not found. Please ensure your CSV has a column with one of these headers: ${namePatterns.slice(0, 5).join(', ')}, etc. Detected headers: ${headers.join(', ')}`, true);
      hideLoading();
      return;
    }
    
    // Validate that the detected roll number column doesn't contain mostly sequential numbers (serial numbers)
    let sampleRollNumbers = [];
    for (let i = headerRowIndex + 1; i < Math.min(headerRowIndex + 6, lines.length); i++) { // Check first 5 data rows
      const row = parseCSVRow(lines[i]);
      if (row.length > finalRollNumberIndex) {
        const rollNumber = (row[finalRollNumberIndex] || '').toString().trim();
        if (rollNumber) sampleRollNumbers.push(rollNumber);
      }
    }
    
    // Check if detected roll numbers are sequential (indicating serial numbers)
    const areSequential = sampleRollNumbers.length >= 3 && 
      sampleRollNumbers.every((num, idx) => {
        if (idx === 0) return true;
        return /^\d+$/.test(num) && parseInt(num) === parseInt(sampleRollNumbers[idx - 1]) + 1;
      });
    
    if (areSequential) {
      showMessage(`Warning: The detected roll number column "${headers[finalRollNumberIndex]}" appears to contain sequential numbers (serial numbers). Please check your CSV structure. If this column contains serial numbers, rename it to "Sl No" or similar, and ensure your actual roll number column has a proper header like "Roll No", "Student ID", etc.`, true);
      hideLoading();
      return;
    }
    
    console.log(`Detected columns - Roll Number: "${headers[finalRollNumberIndex]}", Name: "${headers[finalNameIndex]}", Email: ${finalEmailIndex !== -1 ? `"${headers[finalEmailIndex]}"` : 'Not found'}`);
    console.log('Sample roll numbers:', sampleRollNumbers);
    const students = [];
    const errors = [];
    
    // Parse each data row
    for (let i = headerRowIndex + 1; i < lines.length; i++) {
      try {
        // Enhanced CSV parsing to handle quoted fields and commas within quotes
        const row = parseCSVRow(lines[i]);
        
        if (row.length < Math.max(finalRollNumberIndex, finalNameIndex) + 1) {
          errors.push(`Row ${i + 1}: Insufficient columns (expected at least ${Math.max(finalRollNumberIndex, finalNameIndex) + 1}, got ${row.length})`);
          continue;
        }
        
        let rollNumber = (row[finalRollNumberIndex] || '').toString().trim();
        let studentName = (row[finalNameIndex] || '').toString().trim();
        const studentEmail = finalEmailIndex !== -1 ? (row[finalEmailIndex] || '').toString().trim() : '';
        
        // Debug: Log what we're extracting from each row
        console.log(`Row ${i + 1} raw data:`, row);
        console.log(`  Extracted - Roll: "${rollNumber}" (from index ${finalRollNumberIndex}), Name: "${studentName}" (from index ${finalNameIndex}), Email: "${studentEmail}" (from index ${finalEmailIndex})`);
        
        // Skip header-like data (if somehow header got included in data rows)
        if (rollNumber.toLowerCase().includes('roll') || studentName.toLowerCase().includes('name') || 
            rollNumber.toLowerCase().includes('sl') || studentName.toLowerCase().includes('sl')) {
          console.log(`Skipping row ${i + 1}: Appears to be header data`);
          continue;
        }
        // Skip rows where roll number appears to be a serial number (just digits 1, 2, 3, etc.)
        if (rollNumber && /^\d+$/.test(rollNumber) && parseInt(rollNumber) <= 100) {
          // This might be a serial number, let's check if the name looks valid
          if (!studentName || studentName.length < 3) {
            console.log(`Skipping row ${i + 1}: Appears to be serial number or invalid data`);
            continue;
          }
        }
        
        // Clean and normalize data
        rollNumber = normalizeRollNumber(rollNumber);
        studentName = normalizeStudentName(studentName);
        
        // Skip empty rows
        if (!rollNumber && !studentName) {
          continue;
        }
        
        const student = {
          id: `temp_${i}`,
          rollNumber: rollNumber,
          studentName: studentName,
          email: studentEmail,
          isValid: true,
          errors: []
        };
        
        // Validate student data
        validateStudentData(student, i + 1, errors);
        students.push(student);
        
      } catch (error) {
        errors.push(`Row ${i + 1}: ${error.message}`);
      }
    }
    
    hideLoading();
    
    if (students.length === 0) {
      showMessage('No valid student data found in CSV file.', true);
      return;
    }
    
    // Check for existing students
    const csvRollNumbers = students.map(s => s.rollNumber).filter(r => r);
    if (csvRollNumbers.length > 0) {
      const { data: existingStudents, error: checkError } = await window.supabaseClient
        .from('class_rosters')
        .select('roll_number')
        .eq('class_id', classId)
        .in('roll_number', csvRollNumbers);
      
      if (!checkError && existingStudents && existingStudents.length > 0) {
        const existingRolls = existingStudents.map(s => s.roll_number);
        errors.push(`Students with these roll numbers already exist: ${existingRolls.join(', ')}`);
        
        // Mark conflicting students as invalid
        students.forEach(student => {
          if (existingRolls.includes(student.rollNumber)) {
            student.isValid = false;
            student.errors.push('Roll number already exists in class');
          }
        });
      }
    }
    
    // Show import preview modal
    showImportPreview(students, errors);
    
  } catch (error) {
    console.error('Error processing CSV:', error);
    showMessage('Error processing CSV: ' + error.message, true);
    hideLoading();
  }
}

// Helper function to find best matching column
function findBestMatch(headers, patterns) {
  for (const pattern of patterns) {
    const index = headers.findIndex(h => h === pattern || h.includes(pattern));
    if (index !== -1) return index;
  }
  
  // Fuzzy matching for common variations
  for (const pattern of patterns) {
    const index = headers.findIndex(h => {
      const cleanHeader = h.replace(/[^a-z0-9]/g, '');
      const cleanPattern = pattern.replace(/[^a-z0-9]/g, '');
      return cleanHeader.includes(cleanPattern) || cleanPattern.includes(cleanHeader);
    });
    if (index !== -1) return index;
  }
  
  return -1;
}

// Helper function to find best matching column while excluding certain patterns
function findBestMatchWithExclusion(headers, patterns, excludePatterns) {
  // First check if any header matches exclude patterns
  const excludeIndices = [];
  for (const excludePattern of excludePatterns) {
    const excludeIndex = headers.findIndex(h => 
      h === excludePattern || 
      h.includes(excludePattern) || 
      excludePattern.includes(h.replace(/[^a-z0-9]/g, ''))
    );
    if (excludeIndex !== -1) {
      excludeIndices.push(excludeIndex);
    }
  }
  
  // Find matching patterns while avoiding excluded indices
  for (const pattern of patterns) {
    const index = headers.findIndex((h, idx) => {
      if (excludeIndices.includes(idx)) return false;
      return h === pattern || h.includes(pattern);
    });
    if (index !== -1) return index;
  }
  
  // Fuzzy matching for common variations while avoiding excluded indices
  for (const pattern of patterns) {
    const index = headers.findIndex((h, idx) => {
      if (excludeIndices.includes(idx)) return false;
      const cleanHeader = h.replace(/[^a-z0-9]/g, '');
      const cleanPattern = pattern.replace(/[^a-z0-9]/g, '');
      return cleanHeader.includes(cleanPattern) || cleanPattern.includes(cleanHeader);
    });
    if (index !== -1) return index;
  }
  
  return -1;
}

// Enhanced CSV row parsing to handle quoted fields
function parseCSVRow(row) {
  const result = [];
  let current = '';
  let inQuotes = false;
  
  for (let i = 0; i < row.length; i++) {
    const char = row[i];
    
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

// Normalize roll number (remove extra spaces, handle different formats)
function normalizeRollNumber(rollNumber) {
  if (!rollNumber) return '';
  
  return rollNumber
    .toString()
    .trim()
    .replace(/\s+/g, '') // Remove all spaces
    .toUpperCase(); // Convert to uppercase for consistency
}

// Normalize student name (proper case, remove extra spaces)
function normalizeStudentName(name) {
  if (!name) return '';
  
  return name
    .toString()
    .trim()
    .replace(/\s+/g, ' ') // Replace multiple spaces with single space
    .split(' ')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
    .join(' ');
}

// Validate student data
function validateStudentData(student, rowNumber, globalErrors) {
  student.errors = [];
  
  // Check required fields
  if (!student.rollNumber || student.rollNumber.length === 0) {
    student.errors.push('Roll number is required');
    student.isValid = false;
  } else {
    // Validate roll number format (more flexible)
    if (student.rollNumber.length < 1) {
      student.errors.push('Roll number is required');
      student.isValid = false;
    }
    
    // Check if this looks like a serial number (likely parsing error)
    if (/^\d+$/.test(student.rollNumber) && parseInt(student.rollNumber) <= 100) {
      student.errors.push('Roll number appears to be a serial number - check column mapping');
      student.isValid = false;
    }
    
    // Check for valid characters in roll number
    if (!/^[A-Za-z0-9\-_\.\/\s]+$/.test(student.rollNumber)) {
      student.errors.push('Roll number contains invalid characters');
      student.isValid = false;
    }
  }
  
  if (!student.studentName || student.studentName.length === 0) {
    student.errors.push('Student name is required');
    student.isValid = false;
  } else {
    // Validate name format (basic check)
    if (student.studentName.length < 2) {
      student.errors.push('Student name too short');
      student.isValid = false;
    }
    
    // Check for valid characters in name (more flexible for international names)
    if (!/^[A-Za-z\u00C0-\u017F\u0900-\u097F\s\.\-']+$/.test(student.studentName)) {
      student.errors.push('Student name contains invalid characters');
      student.isValid = false;
    }
  }
  
  // Validate email format if provided
  if (student.email && student.email.length > 0 && !isValidEmail(student.email)) {
    student.errors.push('Invalid email format');
    student.isValid = false;
  }
  
  // Add row-specific errors to global errors
  if (student.errors.length > 0) {
    globalErrors.push(`Row ${rowNumber}: ${student.errors.join(', ')}`);
  }
}

// Helper validation functions
function isValidEmail(email) {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
}

// Show import preview modal
function showImportPreview(students, errors) {
  importPreviewData = students;
  const modal = document.getElementById('importModal');
  
  // Update statistics
  updateImportStats(students);
  
  // Show errors if any
  if (errors.length > 0) {
    showImportErrors(errors);
  } else {
    document.getElementById('importErrors').style.display = 'none';
  }
  
  // Populate import table
  populateImportTable(students);
  
  // Show modal
  modal.classList.add('show');
}

// Update import statistics
function updateImportStats(students) {
  const total = students.length;
  const valid = students.filter(s => s.isValid).length;
  const invalid = total - valid;
  
  const statsContainer = document.getElementById('importStats');
  statsContainer.innerHTML = `
    <div class="import-stat">
      <div class="import-stat-number">${total}</div>
      <div class="import-stat-label">Total Rows</div>
    </div>
    <div class="import-stat">
      <div class="import-stat-number" style="color: #10b981;">${valid}</div>
      <div class="import-stat-label">Valid Students</div>
    </div>
    <div class="import-stat">
      <div class="import-stat-number" style="color: #ef4444;">${invalid}</div>
      <div class="import-stat-label">Invalid Rows</div>
    </div>
    <div class="import-stat">
      <div class="import-stat-number" style="color: #667eea;">${valid}</div>
      <div class="import-stat-label">Ready to Import</div>
    </div>
  `;
  
  // Update footer progress
  document.getElementById('validStudentsCount').textContent = valid;
  
  // Enable/disable import button
  const importBtn = document.getElementById('confirmImportBtn');
  importBtn.disabled = valid === 0;
  if (valid === 0) {
    importBtn.style.opacity = '0.5';
    importBtn.style.cursor = 'not-allowed';
  } else {
    importBtn.style.opacity = '1';
    importBtn.style.cursor = 'pointer';
  }
}

// Show import errors
function showImportErrors(errors) {
  const errorsContainer = document.getElementById('importErrors');
  const errorList = document.getElementById('errorList');
  
  errorList.innerHTML = errors.map(error => 
    `<div class="error-item">⚠️ ${error}</div>`
  ).join('');
  
  errorsContainer.style.display = 'block';
}

// Populate import table
function populateImportTable(students) {
  const tableBody = document.getElementById('importTableBody');
  tableBody.innerHTML = students.map((student, index) => `
    <tr data-student-id="${student.id}">
      <td>
        <div class="row-status ${student.isValid ? 'valid' : 'invalid'}">
          ${student.isValid ? '✅' : '❌'}
        </div>
      </td>
      <td>
        <input type="text" class="import-input ${student.errors.some(e => e.includes('Roll number')) ? 'error' : ''}" 
               value="${student.rollNumber}" 
               data-field="rollNumber" 
               data-index="${index}"
               onchange="updateStudentField(${index}, 'rollNumber', this.value)">
      </td>
      <td>
        <input type="text" class="import-input ${student.errors.some(e => e.includes('Student name')) ? 'error' : ''}" 
               value="${student.studentName}" 
               data-field="studentName" 
               data-index="${index}"
               onchange="updateStudentField(${index}, 'studentName', this.value)">
      </td>
      <td>
        <input type="email" class="import-input ${student.errors.some(e => e.includes('email')) ? 'error' : ''}" 
               value="${student.email}" 
               data-field="email" 
               data-index="${index}"
               onchange="updateStudentField(${index}, 'email', this.value)">
      </td>
      <td>
        <div class="row-actions">
          <button class="row-action-btn delete" onclick="removeStudentFromImport(${index})" title="Remove student">
            🗑️
          </button>
        </div>
      </td>
    </tr>
  `).join('');
}

// Update student field in import preview
function updateStudentField(index, field, value) {
  if (importPreviewData[index]) {
    importPreviewData[index][field] = value;
    
    // Re-validate the student
    const student = importPreviewData[index];
    const errors = [];
    validateStudentData(student, index + 1, errors);
    
    // Update the row status
    const row = document.querySelector(`tr[data-student-id="${student.id}"]`);
    const statusCell = row.querySelector('.row-status');
    statusCell.className = `row-status ${student.isValid ? 'valid' : 'invalid'}`;
    statusCell.textContent = student.isValid ? '✅' : '❌';
    
    // Update input styling
    const input = row.querySelector(`input[data-field="${field}"]`);
    const hasFieldError = student.errors.some(e => e.toLowerCase().includes(field.toLowerCase()));
    if (hasFieldError) {
      input.classList.add('error');
    } else {
      input.classList.remove('error');
    }
    
    // Update statistics
    updateImportStats(importPreviewData);
  }
}

// Remove student from import preview
function removeStudentFromImport(index) {
  if (importPreviewData[index]) {
    importPreviewData.splice(index, 1);
    
    // Re-populate the table
    populateImportTable(importPreviewData);
    
    // Update statistics
    updateImportStats(importPreviewData);
    
    // If no students left, show message
    if (importPreviewData.length === 0) {
      document.getElementById('importTableBody').innerHTML = `
        <tr>
          <td colspan="6" style="text-align: center; padding: 2rem; color: #64748b;">
            No students remaining to import
          </td>
        </tr>
      `;
    }
  }
}

// Close import modal
function closeImportModal() {
  const modal = document.getElementById('importModal');
  modal.classList.remove('show');
  importPreviewData = [];
}

// Link all valid profiles automatically
async function linkAllProfiles() {
  if (!importPreviewData || importPreviewData.length === 0) {
    showMessage('No students available to link.', true);
    return;
  }
  
  const validStudents = importPreviewData.filter(s => s.isValid);
  
  if (validStudents.length === 0) {
    showMessage('No valid students to link profiles for.', true);
    return;
  }
  
  if (!confirm(`Link all ${validStudents.length} valid students to their app profiles automatically? This will search for existing profiles based on roll numbers.`)) {
    return;
  }
  
  showLoading(`Linking ${validStudents.length} student profiles...`);
  
  let successCount = 0;
  let notFoundCount = 0;
  let errorCount = 0;
  const results = [];
  
  try {
    // First, import all students
    const studentsToAdd = validStudents.map(student => ({
      roll_number: student.rollNumber,
      student_name: student.studentName,
      student_email: student.email || null,
      class_id: classId,
      is_verified: false
    }));
    
    const { data: insertedStudents, error: insertError } = await window.supabaseClient
      .from('class_rosters')
      .insert(studentsToAdd)
      .select();
    
    if (insertError) throw insertError;
    
    // Now try to link each imported student
    for (const insertedStudent of insertedStudents) {
      try {
        // Search for user profile with matching student_id (roll number)
        const { data: profileData, error: profileError } = await window.supabaseClient
          .from('profiles')
          .select('id, full_name, email, student_id')
          .eq('student_id', insertedStudent.roll_number)
          .single();
        
        if (profileError && profileError.code !== 'PGRST116') {
          console.error(`Profile search error for ${insertedStudent.roll_number}:`, profileError);
          errorCount++;
          results.push(`❌ ${insertedStudent.student_name} (${insertedStudent.roll_number}): Database error`);
          continue;
        }
        
        if (!profileData) {
          notFoundCount++;
          results.push(`⚠️ ${insertedStudent.student_name} (${insertedStudent.roll_number}): No app profile found`);
          continue;
        }
        
        // Update class_rosters with the profile ID
        const { error: updateError } = await window.supabaseClient
          .from('class_rosters')
          .update({ 
            student_profile_id: profileData.id,
            is_verified: true,
            student_name: profileData.full_name || insertedStudent.student_name,
            student_email: profileData.email || insertedStudent.student_email
          })
          .eq('id', insertedStudent.id);
        
        if (updateError) {
          console.error(`Update error for ${insertedStudent.roll_number}:`, updateError);
          errorCount++;
          results.push(`❌ ${insertedStudent.student_name} (${insertedStudent.roll_number}): Update failed`);
          continue;
        }
        
        successCount++;
        results.push(`✅ ${profileData.full_name} (${insertedStudent.roll_number}): Successfully linked`);
        
      } catch (error) {
        console.error(`Error processing ${insertedStudent.roll_number}:`, error);
        errorCount++;
        results.push(`❌ ${insertedStudent.student_name} (${insertedStudent.roll_number}): ${error.message}`);
      }
    }
    
    // Show comprehensive results
    const summary = `Auto-Link Results:\n✅ Successfully linked: ${successCount}\n⚠️ No app profile found: ${notFoundCount}\n❌ Errors: ${errorCount}`;
    
    if (results.length > 0) {
      console.log('Detailed linking results:', results);
    }
    
    // Close modal and refresh
    closeImportModal();
    
    if (successCount > 0) {
      showMessage(`Auto-linking completed! ${successCount} students linked successfully. ${notFoundCount} students need to register in the app first. ${errorCount > 0 ? `${errorCount} errors occurred.` : ''}`, successCount > 0 ? false : true);
    } else {
      showMessage(`No students could be linked automatically. ${notFoundCount} students need to register in the app first.`, true);
    }
    
    // Refresh the view
    await loadStudents();
    await loadStatistics();
    
  } catch (error) {
    console.error('Error in auto-linking process:', error);
    showMessage('Error during auto-linking: ' + error.message, true);
  }
  
  hideLoading();
}

// Confirm import
async function confirmImport() {
  const validStudents = importPreviewData.filter(s => s.isValid);
  
  if (validStudents.length === 0) {
    showMessage('No valid students to import.', true);
    return;
  }
  
  // Close modal and show loading
  closeImportModal();
  showLoading('Importing students...');
  
  try {
    // Convert to database format
    const studentsToAdd = validStudents.map(student => ({
      roll_number: student.rollNumber,
      student_name: student.studentName,
      student_email: student.email || null,
      class_id: classId,
      is_verified: false
    }));
    
    // Import students
    const { error: insertError } = await window.supabaseClient
      .from('class_rosters')
      .insert(studentsToAdd);
    
    if (insertError) throw insertError;
    
    showMessage(`Successfully imported ${validStudents.length} students!`, false);
    
    // Refresh the view
    await loadStudents();
    await loadStatistics();
    
    hideLoading();
    
  } catch (error) {
    console.error('Error importing students:', error);
    showMessage('Error importing students: ' + error.message, true);
    hideLoading();
  }
}

// Delete entire class
async function deleteClass() {
  if (!currentClass) return;
  
  const className = currentClass.subject_name || currentClass.class_name || 'Unnamed Class';
  
  if (!confirm(`Are you sure you want to delete the entire class "${className}"? This will remove all students and attendance records. This cannot be undone.`)) {
    return;
  }
  
  // Double confirmation for destructive action
  if (!confirm(`FINAL CONFIRMATION: Delete class "${className}" and ALL its data?`)) {
    return;
  }
  
  try {
    showLoading('Deleting class...');
    
    // Delete all related data
    await Promise.all([
      // Delete attendance records
      window.supabaseClient.from('attendance').delete().eq('class_id', classId),
      // Delete class roster
      window.supabaseClient.from('class_rosters').delete().eq('class_id', classId),
      // Delete the class itself
      window.supabaseClient.from('professor_classes').delete().eq('id', classId)
    ]);
    
    showMessage(`Class "${className}" deleted successfully! Redirecting...`, false);
    
    setTimeout(() => {
      window.location.href = 'class_rosters.html';
    }, 2000);
    
  } catch (error) {
    console.error('Error deleting class:', error);
    showMessage('Error deleting class: ' + error.message, true);
    hideLoading();
  }
}

// Utility functions
function showLoading(text = 'Loading...') {
  const overlay = document.getElementById('loadingOverlay');
  const loadingText = document.getElementById('loadingText');
  
  if (overlay) overlay.classList.remove('hidden');
  if (loadingText) loadingText.textContent = text;
}

function hideLoading() {
  const overlay = document.getElementById('loadingOverlay');
  if (overlay) overlay.classList.add('hidden');
}

function showMessage(message, isError = false) {
  const messageDiv = document.getElementById('messageDisplay');
  if (!messageDiv) return;
  
  messageDiv.textContent = message;
  messageDiv.style.color = isError ? '#dc2626' : '#22c55e';
  messageDiv.style.backgroundColor = isError ? '#fee2e2' : '#dcfce7';
  messageDiv.style.borderColor = isError ? '#fecaca' : '#bbf7d0';
  messageDiv.classList.remove('hidden');
  
  setTimeout(() => {
    messageDiv.classList.add('hidden');
  }, 5000);
}

// Detect duplicate students
async function detectDuplicateStudents() {
  duplicateStudents = [];
  const rollNumberGroups = {};
  const nameGroups = {};
  const emailGroups = {};
  
  // Group students by roll number, name, and email
  currentStudents.forEach(student => {
    // Group by roll number
    if (!rollNumberGroups[student.roll_number]) {
      rollNumberGroups[student.roll_number] = [];
    }
    rollNumberGroups[student.roll_number].push(student);
    
    // Group by name (case insensitive)
    const normalizedName = student.student_name.toLowerCase().trim();
    if (!nameGroups[normalizedName]) {
      nameGroups[normalizedName] = [];
    }
    nameGroups[normalizedName].push(student);
    
    // Group by email if exists
    if (student.student_email) {
      const normalizedEmail = student.student_email.toLowerCase().trim();
      if (!emailGroups[normalizedEmail]) {
        emailGroups[normalizedEmail] = [];
      }
      emailGroups[normalizedEmail].push(student);
    }
  });
  
  // Find duplicates
  Object.values(rollNumberGroups).forEach(group => {
    if (group.length > 1) {
      duplicateStudents.push(...group.map(s => ({ ...s, duplicateType: 'roll_number' })));
    }
  });
  
  Object.values(nameGroups).forEach(group => {
    if (group.length > 1) {
      group.forEach(student => {
        if (!duplicateStudents.find(d => d.id === student.id)) {
          duplicateStudents.push({ ...student, duplicateType: 'name' });
        }
      });
    }
  });
  
  Object.values(emailGroups).forEach(group => {
    if (group.length > 1) {
      group.forEach(student => {
        if (!duplicateStudents.find(d => d.id === student.id)) {
          duplicateStudents.push({ ...student, duplicateType: 'email' });
        }
      });
    }
  });
  
  console.log('Duplicate students detected:', duplicateStudents.length);
}

// Show duplicate warning
function showDuplicateWarning() {
  const warningHtml = `
    <div style="background: #fef3c7; border: 1px solid #f59e0b; border-radius: 8px; padding: 1rem; margin: 1rem 0;">
      <h3 style="color: #92400e; margin: 0 0 0.5rem 0;">⚠️ Duplicate Students Detected</h3>
      <p style="color: #92400e; margin: 0 0 1rem 0;">
        Found ${duplicateStudents.length} students with duplicate information. This may cause login issues.
      </p>
      <button class="action-btn primary" onclick="showDuplicateManager()" style="margin-right: 0.5rem;">
        🔧 Manage Duplicates
      </button>
      <button class="action-btn secondary" onclick="hideDuplicateWarning()">
        ✕ Dismiss
      </button>
    </div>
  `;
  
  const container = document.querySelector('.content-wrapper');
  const existingWarning = container.querySelector('.duplicate-warning');
  if (existingWarning) {
    existingWarning.remove();
  }
  
  const warningDiv = document.createElement('div');
  warningDiv.className = 'duplicate-warning';
  warningDiv.innerHTML = warningHtml;
  container.insertBefore(warningDiv, container.firstChild);
}

// Hide duplicate warning
function hideDuplicateWarning() {
  const warning = document.querySelector('.duplicate-warning');
  if (warning) {
    warning.remove();
  }
}

// Group duplicates by roll number
function groupDuplicatesByRollNumber() {
  const groups = {};
  duplicateStudents.forEach(student => {
    if (!groups[student.roll_number]) {
      groups[student.roll_number] = [];
    }
    groups[student.roll_number].push(student);
  });
  return groups;
}

// Show duplicate manager modal
function showDuplicateManager() {
  const duplicateGroups = groupDuplicatesByRollNumber();
  
  let modalHtml = `
    <div class="modal-overlay" id="duplicateModal" style="position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.5); z-index: 1000; display: flex; align-items: center; justify-content: center;">
      <div class="modal-container" style="background: white; border-radius: 12px; max-width: 1200px; width: 90%; max-height: 80vh; overflow-y: auto; box-shadow: 0 20px 60px rgba(0,0,0,0.3);">
        <div class="modal-header" style="padding: 1.5rem; border-bottom: 1px solid #e2e8f0; display: flex; justify-content: space-between; align-items: center;">
          <h2 style="margin: 0; color: #1f2937;">🔧 Duplicate Student Manager</h2>
          <button class="modal-close" onclick="closeDuplicateManager()" style="background: none; border: none; font-size: 1.5rem; cursor: pointer; color: #6b7280;">✕</button>
        </div>
        <div class="modal-content" style="padding: 1.5rem;">
          <div class="preview-stats" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 1rem; margin-bottom: 1.5rem;">
            <div class="stat-item" style="background: #f8fafc; padding: 1rem; border-radius: 8px; text-align: center;">
              <span class="stat-label" style="display: block; font-size: 0.9rem; color: #64748b; margin-bottom: 0.5rem;">Duplicate Groups:</span>
              <span class="stat-value" style="font-size: 1.5rem; font-weight: 700; color: #1f2937;">${Object.keys(duplicateGroups).length}</span>
            </div>
            <div class="stat-item" style="background: #f8fafc; padding: 1rem; border-radius: 8px; text-align: center;">
              <span class="stat-label" style="display: block; font-size: 0.9rem; color: #64748b; margin-bottom: 0.5rem;">Affected Students:</span>
              <span class="stat-value" style="font-size: 1.5rem; font-weight: 700; color: #1f2937;">${duplicateStudents.length}</span>
            </div>
          </div>
          
          <div class="preview-table-container" style="overflow-x: auto;">
            <table class="preview-table" style="width: 100%; border-collapse: collapse; border: 1px solid #e2e8f0;">
              <thead>
                <tr style="background: #f8fafc;">
                  <th style="padding: 0.75rem; text-align: left; border-bottom: 1px solid #e2e8f0; font-weight: 600;">Roll Number</th>
                  <th style="padding: 0.75rem; text-align: left; border-bottom: 1px solid #e2e8f0; font-weight: 600;">Student Name</th>
                  <th style="padding: 0.75rem; text-align: left; border-bottom: 1px solid #e2e8f0; font-weight: 600;">Email</th>
                  <th style="padding: 0.75rem; text-align: left; border-bottom: 1px solid #e2e8f0; font-weight: 600;">Profile Status</th>
                  <th style="padding: 0.75rem; text-align: left; border-bottom: 1px solid #e2e8f0; font-weight: 600;">Actions</th>
                </tr>
              </thead>
              <tbody>
  `;
  
  Object.entries(duplicateGroups).forEach(([rollNumber, group]) => {
    group.forEach((student, index) => {
      const isFirst = index === 0;
      const rowStyle = isFirst ? 'background: #fef3c7;' : '';
      
      modalHtml += `
        <tr style="${rowStyle}">
          <td style="padding: 0.75rem; border-bottom: 1px solid #e2e8f0;"><strong>${student.roll_number}</strong></td>
          <td style="padding: 0.75rem; border-bottom: 1px solid #e2e8f0;">${student.student_name}</td>
          <td style="padding: 0.75rem; border-bottom: 1px solid #e2e8f0;">${student.student_email || 'Not provided'}</td>
          <td style="padding: 0.75rem; border-bottom: 1px solid #e2e8f0;">
            <span style="padding: 0.25rem 0.5rem; border-radius: 4px; font-size: 0.8rem; font-weight: 500; ${student.student_profile_id ? 'background: #dcfce7; color: #166534;' : 'background: #fef3c7; color: #92400e;'}">
              ${student.student_profile_id ? '✓ Linked' : '⚠ Unlinked'}
            </span>
          </td>
          <td style="padding: 0.75rem; border-bottom: 1px solid #e2e8f0;">
            <button onclick="editDuplicateStudent('${student.id}')" style="background: #3b82f6; color: white; border: none; padding: 0.25rem 0.5rem; border-radius: 4px; font-size: 0.8rem; margin-right: 0.5rem; cursor: pointer;">
              ✏️ Edit
            </button>
            ${student.student_profile_id ? `
            <button onclick="replaceStudentAccount('${student.id}')" style="background: #10b981; color: white; border: none; padding: 0.25rem 0.5rem; border-radius: 4px; font-size: 0.8rem; margin-right: 0.5rem; cursor: pointer;" title="Replace with correct account">
              🔄 Replace
            </button>` : ''}
            <button onclick="deleteDuplicateStudent('${student.id}')" style="background: #dc2626; color: white; border: none; padding: 0.25rem 0.5rem; border-radius: 4px; font-size: 0.8rem; cursor: pointer;">
              🗑️ Delete
            </button>
          </td>
        </tr>
      `;
    });
  });
  
  modalHtml += `
              </tbody>
            </table>
          </div>
          
          <div class="modal-actions" style="display: flex; justify-content: flex-end; gap: 1rem; margin-top: 1.5rem; padding-top: 1.5rem; border-top: 1px solid #e2e8f0;">
            <button onclick="closeDuplicateManager()" style="background: #6b7280; color: white; border: none; padding: 0.75rem 1.5rem; border-radius: 6px; cursor: pointer;">
              Cancel
            </button>
            <button onclick="autoResolveDuplicates()" style="background: #059669; color: white; border: none; padding: 0.75rem 1.5rem; border-radius: 6px; cursor: pointer;">
              🤖 Auto-Resolve
            </button>
          </div>
        </div>
      </div>
    </div>
  `;
  
  document.body.insertAdjacentHTML('beforeend', modalHtml);
}

// Close duplicate manager
function closeDuplicateManager() {
  const modal = document.getElementById('duplicateModal');
  if (modal) {
    modal.remove();
  }
}

// Edit duplicate student
function editDuplicateStudent(studentId) {
  const student = currentStudents.find(s => s.id === studentId);
  if (!student) return;
  
  const newRollNumber = prompt('Enter new roll number:', student.roll_number);
  if (!newRollNumber || newRollNumber === student.roll_number) return;
  
  // Validate roll number format
  if (!validateRollNumber(newRollNumber)) {
    alert('Invalid roll number format. Please use formats like: 2021001, 21CSE001, 441/23');
    return;
  }
  
  // Check if new roll number already exists
  const existingStudent = currentStudents.find(s => s.roll_number === newRollNumber && s.id !== studentId);
  if (existingStudent) {
    alert('A student with this roll number already exists.');
    return;
  }
  
  updateStudentRollNumber(studentId, newRollNumber);
}

// Delete duplicate student
function deleteDuplicateStudent(studentId) {
  if (!confirm('Are you sure you want to delete this duplicate student entry?')) {
    return;
  }
  
  removeStudent(studentId);
}

// Auto-resolve duplicates with smart merging
async function autoResolveDuplicates() {
  if (!confirm('Auto-resolve will intelligently merge duplicate entries, keeping the best data from each. Continue?')) {
    return;
  }
  
  try {
    showLoading('Auto-resolving duplicates...');
    
    const duplicateGroups = groupDuplicatesByRollNumber();
    let resolvedCount = 0;
    let mergedCount = 0;
    
    for (const [rollNumber, group] of Object.entries(duplicateGroups)) {
      if (group.length > 1) {
        // Smart merge: prioritize linked profiles and complete data
        const mergedStudent = await smartMergeDuplicates(group);
        
        if (mergedStudent) {
          // Remove all duplicates except the merged one
          const toRemove = group.filter(s => s.id !== mergedStudent.id);
          
          for (const student of toRemove) {
            await removeStudentFromDB(student.id);
            resolvedCount++;
          }
          
          mergedCount++;
        }
      }
    }
    
    showMessage(`Auto-resolved ${resolvedCount} duplicate entries across ${mergedCount} students.`, false);
    closeDuplicateManager();
    await loadStudents(); // Refresh the list
    await loadStatistics();
    
    hideLoading();
    
  } catch (error) {
    console.error('Error auto-resolving duplicates:', error);
    showMessage('Error auto-resolving duplicates: ' + error.message, true);
    hideLoading();
  }
}

// Smart merge duplicates - keeps best data from each duplicate
async function smartMergeDuplicates(duplicateGroup) {
  try {
    // Sort by priority: linked profiles first, then by creation date
    const sortedGroup = duplicateGroup.sort((a, b) => {
      // Prioritize students with linked profiles
      if (a.student_profile_id && !b.student_profile_id) return -1;
      if (!a.student_profile_id && b.student_profile_id) return 1;
      
      // Then by creation date (newer first)
      return new Date(b.created_at || 0) - new Date(a.created_at || 0);
    });
    
    const primaryStudent = sortedGroup[0];
    const otherStudents = sortedGroup.slice(1);
    
    // Merge data from all duplicates into the primary student
    const mergedData = {
      student_name: primaryStudent.student_name,
      student_email: primaryStudent.student_email,
      student_profile_id: primaryStudent.student_profile_id,
      is_verified: primaryStudent.is_verified
    };
    
    // Enhance with data from other duplicates
    for (const student of otherStudents) {
      // Use email from other student if primary doesn't have one
      if (!mergedData.student_email && student.student_email) {
        mergedData.student_email = student.student_email;
      }
      
      // Use profile link if primary doesn't have one
      if (!mergedData.student_profile_id && student.student_profile_id) {
        mergedData.student_profile_id = student.student_profile_id;
        mergedData.is_verified = student.is_verified;
      }
      
      // Use better name if available (longer, more complete names)
      if (student.student_name && student.student_name.length > mergedData.student_name.length) {
        mergedData.student_name = student.student_name;
      }
    }
    
    // Update the primary student with merged data
    const { error } = await window.supabaseClient
      .from('class_rosters')
      .update(mergedData)
      .eq('id', primaryStudent.id);
    
    if (error) throw error;
    
    console.log(`✅ Merged ${duplicateGroup.length} duplicates for roll ${primaryStudent.roll_number}`);
    return primaryStudent;
    
  } catch (error) {
    console.error('Error merging duplicates:', error);
    return null;
  }
}

// Remove student from database (helper function)
async function removeStudentFromDB(studentId) {
  try {
    const { error } = await window.supabaseClient
      .from('class_rosters')
      .delete()
      .eq('id', studentId);
    
    if (error) throw error;
    
  } catch (error) {
    console.error('Error removing student from DB:', error);
    throw error;
  }
}

// Validate roll number format
function validateRollNumber(rollNumber) {
  if (!rollNumber || rollNumber.trim() === '') return false;
  
  const patterns = [
    /^\d{4,7}$/, // Simple numeric: 2021001
    /^\d{2}[A-Z]{2,3}\d{3}$/, // Format like: 21CSE001
    /^\d{3,4}\/\d{2}$/, // Format like: 441/23
    /^[A-Z]{2,3}\d{2,4}$/, // Format like: CSE2021
    /^\d{2}[A-Z]\d{3}$/ // Format like: 21A001
  ];
  
  return patterns.some(pattern => pattern.test(rollNumber.trim()));
}

// Update student roll number
async function updateStudentRollNumber(studentId, newRollNumber) {
  try {
    showLoading('Updating roll number...');
    
    const student = currentStudents.find(s => s.id === studentId);
    const oldRollNumber = student.roll_number;
    
    // Update in database
    const { error } = await window.supabaseClient
      .from('class_rosters')
      .update({ roll_number: newRollNumber })
      .eq('id', studentId);
    
    if (error) throw error;
    
    // Track roll number change history
    if (!rollNumberHistory.has(studentId)) {
      rollNumberHistory.set(studentId, []);
    }
    rollNumberHistory.get(studentId).push({
      from: oldRollNumber,
      to: newRollNumber,
      timestamp: new Date().toISOString(),
      reason: 'Duplicate resolution'
    });
    
    showMessage(`Roll number updated from ${oldRollNumber} to ${newRollNumber}`, false);
    
    // Reload students and re-detect duplicates
    await loadStudents();
    await loadStatistics();
    
    hideLoading();
    
  } catch (error) {
    console.error('Error updating roll number:', error);
    showMessage('Error updating roll number: ' + error.message, true);
    hideLoading();
  }
}

// Clean up duplicate profile links - with interactive dialog
async function cleanupDuplicateProfileLinks() {
  try {
    showLoading('Scanning for duplicate profile links...');
    
    // Get all students in this class with profile links
    const { data: linkedStudents, error } = await window.supabaseClient
      .from('class_rosters')
      .select('*')
      .eq('class_id', classId)
      .not('student_profile_id', 'is', null)
      .order('created_at');
    
    if (error) throw error;
    
    // Group by profile_id to find duplicates
    const profileGroups = {};
    linkedStudents.forEach(student => {
      if (!profileGroups[student.student_profile_id]) {
        profileGroups[student.student_profile_id] = [];
      }
      profileGroups[student.student_profile_id].push(student);
    });
    
    // Find profiles linked to multiple roll numbers
    const duplicateProfiles = Object.entries(profileGroups).filter(([profileId, students]) => students.length > 1);
    
    hideLoading();
    
    if (duplicateProfiles.length === 0) {
      showMessage('No duplicate profile links found. All students are properly linked.', false);
      return;
    }
    
    // Show interactive cleanup dialog
    await showCleanupDialog(duplicateProfiles);
    
  } catch (error) {
    console.error('Error scanning duplicate profile links:', error);
    showMessage('Error scanning duplicate links: ' + error.message, true);
    hideLoading();
  }
}

// Show interactive cleanup dialog
async function showCleanupDialog(duplicateProfiles) {
  try {
    // Get profile details for all duplicates
    const profilesWithDetails = await Promise.all(
      duplicateProfiles.map(async ([profileId, students]) => {
        const { data: profile, error } = await window.supabaseClient
          .from('profiles')
          .select('student_id, full_name, email, created_at')
          .eq('id', profileId)
          .single();
        
        return {
          profileId,
          students,
          profile: profile || { student_id: 'Unknown', full_name: 'Unknown', email: 'Unknown' }
        };
      })
    );
    
    let modalHtml = `
      <div class="modal-overlay" id="cleanupModal" style="position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.6); z-index: 2000; display: flex; align-items: center; justify-content: center; backdrop-filter: blur(4px);">
        <div class="modal-container" style="background: white; border-radius: 16px; max-width: 95vw; width: 1200px; max-height: 90vh; overflow: hidden; box-shadow: 0 25px 50px rgba(0,0,0,0.3);">
          <div class="modal-header" style="background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%); color: white; padding: 2rem; display: flex; justify-content: space-between; align-items: center;">
            <h2 style="margin: 0; font-size: 1.75rem; font-weight: 700;">🔧 Fix Duplicate Profile Links</h2>
            <button class="modal-close" onclick="closeCleanupDialog()" style="background: rgba(255,255,255,0.2); border: none; color: white; width: 2.5rem; height: 2.5rem; border-radius: 50%; font-size: 1.25rem; cursor: pointer;">✕</button>
          </div>
          
          <div class="modal-content" style="padding: 2rem; max-height: calc(90vh - 200px); overflow-y: auto;">
            <div class="cleanup-summary" style="background: #fef3c7; border: 1px solid #f59e0b; border-radius: 12px; padding: 1.5rem; margin-bottom: 2rem;">
              <h3 style="margin: 0 0 1rem 0; color: #92400e;">⚠️ Found ${duplicateProfiles.length} profiles with duplicate links</h3>
              <p style="margin: 0; color: #92400e; line-height: 1.5;">
                Each profile should only be linked to one roll number per class. Review each case below and select which entry to keep linked.
                <br><strong>Tip:</strong> Usually keep the entry that matches the profile's registered roll number.
              </p>
            </div>
            
            <div class="duplicate-groups">
    `;
    
    profilesWithDetails.forEach((item, groupIndex) => {
      const { profileId, students, profile } = item;
      
      modalHtml += `
        <div class="duplicate-group" style="background: white; border: 2px solid #e5e7eb; border-radius: 12px; margin-bottom: 2rem; overflow: hidden;" data-profile-id="${profileId}">
          <div class="group-header" style="background: #f9fafb; padding: 1.5rem; border-bottom: 1px solid #e5e7eb;">
            <h4 style="margin: 0 0 0.5rem 0; color: #1f2937; font-size: 1.2rem;">${profile.full_name}</h4>
            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 1rem; font-size: 0.9rem; color: #6b7280;">
              <div><strong>Email:</strong> ${profile.email}</div>
              <div><strong>Profile Roll:</strong> ${profile.student_id}</div>
              <div><strong>Linked to ${students.length} entries</strong></div>
            </div>
          </div>
          
          <div class="group-entries" style="padding: 1rem;">
            <div style="margin-bottom: 1rem; font-weight: 600; color: #374151;">Select which entry to keep linked (others will be unlinked):</div>
            
            ${students.map((student, studentIndex) => {
              const isProfileMatch = student.roll_number === profile.student_id;
              const isRecommended = isProfileMatch;
              
              return `
                <div class="entry-option" style="display: flex; align-items: center; padding: 1rem; border: 2px solid ${isRecommended ? '#10b981' : '#e5e7eb'}; border-radius: 8px; margin-bottom: 0.75rem; background: ${isRecommended ? '#f0fdf4' : '#ffffff'};">
                  <input type="radio" name="keep_${groupIndex}" value="${student.id}" id="keep_${groupIndex}_${studentIndex}" ${isRecommended ? 'checked' : ''} style="margin-right: 1rem; transform: scale(1.2);">
                  <label for="keep_${groupIndex}_${studentIndex}" style="flex: 1; cursor: pointer;">
                    <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 1rem; align-items: center;">
                      <div>
                        <strong style="color: #1f2937;">Roll: ${student.roll_number}</strong>
                        ${isProfileMatch ? '<span style="background: #10b981; color: white; padding: 0.25rem 0.5rem; border-radius: 4px; font-size: 0.75rem; margin-left: 0.5rem;">MATCHES PROFILE</span>' : ''}
                      </div>
                      <div style="color: #6b7280;">Name: ${student.student_name}</div>
                      <div style="color: #6b7280;">Email: ${student.student_email || 'Not provided'}</div>
                      <div style="color: #6b7280; font-size: 0.85rem;">Added: ${new Date(student.created_at).toLocaleDateString()}</div>
                    </div>
                  </label>
                  <button onclick="unlinkEntry('${student.id}', ${groupIndex})" style="background: #ef4444; color: white; border: none; padding: 0.5rem 1rem; border-radius: 6px; margin-left: 1rem; cursor: pointer; font-size: 0.85rem;">
                    🗑️ Unlink This
                  </button>
                </div>
              `;
            }).join('')}
            
            <div style="margin-top: 1rem; padding: 0.75rem; background: #fef3c7; border-radius: 6px; font-size: 0.9rem; color: #92400e;">
              <strong>💡 Recommendation:</strong> Keep the entry that matches the profile's roll number (${profile.student_id}) if available, or the most recently created entry.
            </div>
          </div>
        </div>
      `;
    });
    
    modalHtml += `
            </div>
          </div>
          
          <div class="modal-footer" style="background: #f9fafb; border-top: 1px solid #e5e7eb; padding: 1.5rem; display: flex; justify-content: space-between; align-items: center;">
            <div style="color: #6b7280; font-size: 0.9rem;">
              <span id="cleanupProgress">Ready to fix ${duplicateProfiles.length} duplicate profiles</span>
            </div>
            <div style="display: flex; gap: 1rem;">
              <button onclick="closeCleanupDialog()" style="background: #6b7280; color: white; border: none; padding: 0.75rem 1.5rem; border-radius: 8px; cursor: pointer;">
                Cancel
              </button>
              <button onclick="executeCleanup()" style="background: #10b981; color: white; border: none; padding: 0.75rem 1.5rem; border-radius: 8px; cursor: pointer; font-weight: 600;">
                🔧 Fix Selected Links
              </button>
            </div>
          </div>
        </div>
      </div>
    `;
    
    document.body.insertAdjacentHTML('beforeend', modalHtml);
    document.body.style.overflow = 'hidden';
    
  } catch (error) {
    console.error('Error showing cleanup dialog:', error);
    showMessage('Error showing cleanup dialog: ' + error.message, true);
  }
}

// Close cleanup dialog
function closeCleanupDialog() {
  const modal = document.getElementById('cleanupModal');
  if (modal) {
    modal.remove();
  }
  document.body.style.overflow = '';
}

// Unlink individual entry from dialog
async function unlinkEntry(studentId, groupIndex) {
  const student = currentStudents.find(s => s.id === studentId);
  if (!student) return;
  
  const shouldClear = confirm(
    `Current entry: ${student.student_name} (Roll: ${student.roll_number})\n\n` +
    'Choose unlinking method:\n\n' +
    'OK = Replace with correct student name\n' +
    'Cancel = Keep current data but unlink profile\n\n' +
    'Click OK to enter the correct student name for this roll number.'
  );
  
  try {
    let updateData = {
      student_profile_id: null,
      is_verified: false
    };
    
    // If user chose to clear data, prompt for correct student name
    if (shouldClear) {
      const correctName = prompt(
        `Enter the CORRECT student name for roll number ${student.roll_number}:`,
        ''
      );
      
      if (!correctName || correctName.trim() === '') {
        showMessage('Operation cancelled - student name is required.', true);
        return;
      }
      
      updateData.student_name = correctName.trim();
      updateData.student_email = null; // Clear email so correct student can add theirs
    }
    
    const { error } = await window.supabaseClient
      .from('class_rosters')
      .update(updateData)
      .eq('id', studentId);
    
    if (error) throw error;
    
    // Remove the entry option from the dialog
    const entryOption = document.querySelector(`input[value="${studentId}"]`).closest('.entry-option');
    if (entryOption) {
      entryOption.style.opacity = '0.5';
      entryOption.style.pointerEvents = 'none';
      const actionText = shouldClear ? 
        `✅ Updated to: ${updateData.student_name} - Ready for linking` : 
        '✅ Unlinked - Profile data preserved';
      entryOption.innerHTML = `<div style="padding: 1rem; text-align: center; color: #6b7280;">${actionText}</div>`;
    }
    
    const message = shouldClear ? 
      `Entry updated with correct name: ${updateData.student_name}. Student can now link their profile.` :
      'Entry unlinked but data preserved!';
    showMessage(message, false);
    
  } catch (error) {
    console.error('Error unlinking entry:', error);
    showMessage('Error unlinking entry: ' + error.message, true);
  }
}

// Execute cleanup based on user selections
async function executeCleanup() {
  try {
    showLoading('Processing cleanup selections...');
    
    const duplicateGroups = document.querySelectorAll('.duplicate-group');
    let processedCount = 0;
    let unlinkedCount = 0;
    
    for (const group of duplicateGroups) {
      const profileId = group.dataset.profileId;
      const selectedRadio = group.querySelector('input[type="radio"]:checked');
      
      if (!selectedRadio) {
        // No selection made for this group, skip
        continue;
      }
      
      const keepStudentId = selectedRadio.value;
      
      // Get all radio buttons in this group to find entries to unlink
      const allRadios = group.querySelectorAll('input[type="radio"]');
      const unlinkPromises = [];
      
      for (const radio of allRadios) {
        if (radio.value !== keepStudentId) {
          // Get the student info for this radio
          const studentToUnlink = currentStudents.find(s => s.id === radio.value);
          if (studentToUnlink) {
            const correctName = prompt(
              `Enter the CORRECT student name for roll number ${studentToUnlink.roll_number}:`,
              ''
            );
            
            if (!correctName || correctName.trim() === '') {
              console.log(`Skipping ${studentToUnlink.roll_number} - no name provided`);
              continue; // Skip this entry if no name provided
            }
            
            // This entry should be unlinked and updated with correct name
            unlinkPromises.push(
              window.supabaseClient
                .from('class_rosters')
                .update({ 
                  student_profile_id: null,
                  is_verified: false,
                  student_name: correctName.trim(),
                  student_email: null
                })
                .eq('id', radio.value)
            );
            unlinkedCount++;
          }
        }
      }
      
      // Execute all unlink operations for this group
      const results = await Promise.all(unlinkPromises);
      
      // Check for errors
      const errors = results.filter(result => result.error);
      if (errors.length > 0) {
        console.error('Some unlink operations failed:', errors);
      } else {
        processedCount++;
      }
    }
    
    hideLoading();
    closeCleanupDialog();
    
    showMessage(`✅ Cleanup completed!\n\nProcessed ${processedCount} duplicate profiles\nUnlinked ${unlinkedCount} incorrect entries\n\nStudents can now login with their correct roll numbers.`, false);
    
    // Refresh the view
    await loadStudents();
    await loadStatistics();
    
  } catch (error) {
    console.error('Error executing cleanup:', error);
    showMessage('Error executing cleanup: ' + error.message, true);
    hideLoading();
  }
}

// Replace student account - handles scenario where student has wrong account linked
async function replaceStudentAccount(studentId) {
  const student = currentStudents.find(s => s.id === studentId);
  if (!student) return;
  
  const newRollNumber = prompt(
    `Replace account for ${student.student_name}\n\n` +
    `Current roll: ${student.roll_number}\n` +
    `Current status: ${student.student_profile_id ? 'Linked to app account' : 'Not linked'}\n\n` +
    `Enter the CORRECT roll number to search for the right app account:`,
    student.roll_number
  );
  
  if (!newRollNumber || newRollNumber === student.roll_number) return;
  
  try {
    showLoading('Searching for correct student account...');
    
    // Search for the correct app profile
    const { data: correctProfile, error: searchError } = await window.supabaseClient
      .from('profiles')
      .select('id, full_name, email, student_id')
      .eq('student_id', newRollNumber)
      .single();
    
    if (searchError && searchError.code !== 'PGRST116') {
      throw searchError;
    }
    
    if (!correctProfile) {
      showMessage(`No app account found with roll number ${newRollNumber}. Student needs to register first.`, true);
      hideLoading();
      return;
    }
    
    // Check if this profile is already linked to another roster entry
    const { data: existingLink, error: linkCheckError } = await window.supabaseClient
      .from('class_rosters')
      .select('id, student_name, roll_number')
      .eq('student_profile_id', correctProfile.id)
      .eq('class_id', classId)
      .single();
    
    if (linkCheckError && linkCheckError.code !== 'PGRST116') {
      throw linkCheckError;
    }
    
    let confirmMessage = `Replace account for ${student.student_name}?\n\n`;
    confirmMessage += `OLD: Roll ${student.roll_number} → ${student.student_profile_id ? 'Linked' : 'Not linked'}\n`;
    confirmMessage += `NEW: Roll ${newRollNumber} → ${correctProfile.full_name} (${correctProfile.email})\n\n`;
    
    if (existingLink) {
      confirmMessage += `⚠️ WARNING: This will unlink ${correctProfile.full_name} from "${existingLink.student_name}" (${existingLink.roll_number}) and link to this student instead.\n\n`;
    }
    
    confirmMessage += `This action will:\n`;
    confirmMessage += `• Update roll number to ${newRollNumber}\n`;
    confirmMessage += `• Link to correct app account (${correctProfile.full_name})\n`;
    confirmMessage += `• Free up the wrong account for the correct student\n\n`;
    confirmMessage += `Continue?`;
    
    if (!confirm(confirmMessage)) {
      hideLoading();
      return;
    }
    
    // If the correct profile is linked elsewhere, unlink it first
    if (existingLink) {
      const { error: unlinkError } = await window.supabaseClient
        .from('class_rosters')
        .update({ 
          student_profile_id: null,
          is_verified: false
        })
        .eq('id', existingLink.id);
      
      if (unlinkError) throw unlinkError;
    }
    
    // Update current student with correct information
    const { error: updateError } = await window.supabaseClient
      .from('class_rosters')
      .update({
        roll_number: newRollNumber,
        student_profile_id: correctProfile.id,
        is_verified: true,
        // Preserve admin-entered name as per memory guidance
        student_email: correctProfile.email
      })
      .eq('id', studentId);
    
    if (updateError) throw updateError;
    
    // Track the replacement in history
    if (!rollNumberHistory.has(studentId)) {
      rollNumberHistory.set(studentId, []);
    }
    rollNumberHistory.get(studentId).push({
      from: student.roll_number,
      to: newRollNumber,
      timestamp: new Date().toISOString(),
      reason: 'Account replacement - wrong account corrected',
      oldProfile: student.student_profile_id,
      newProfile: correctProfile.id
    });
    
    let successMessage = `✅ Successfully replaced account!\n\n`;
    successMessage += `${student.student_name} is now linked to the correct app account:\n`;
    successMessage += `• Roll: ${student.roll_number} → ${newRollNumber}\n`;
    successMessage += `• App: ${correctProfile.full_name} (${correctProfile.email})\n\n`;
    
    if (existingLink) {
      successMessage += `The previous link for "${existingLink.student_name}" has been removed and is now available for the correct student.`;
    }
    
    showMessage(successMessage, false);
    
    // Refresh the view
    await loadStudents();
    await loadStatistics();
    
    hideLoading();
    
  } catch (error) {
    console.error('Error replacing student account:', error);
    showMessage('Error replacing student account: ' + error.message, true);
    hideLoading();
  }
}

// Bulk Student Addition Functions
let parsedStudents = [];

function showAddStudentsModal() {
  const modal = document.getElementById('addStudentsModal');
  modal.classList.add('show');
  
  // Reset to bulk mode by default
  switchToBulkMode();
  
  // Clear any existing data
  clearAddStudentsForm();
  
  // Add a small delay to ensure smooth animation
  setTimeout(() => {
    document.body.style.overflow = 'hidden'; // Prevent background scrolling
  }, 100);
}

function closeAddStudentsModal() {
  const modal = document.getElementById('addStudentsModal');
  modal.classList.remove('show');
  
  // Re-enable background scrolling
  document.body.style.overflow = '';
  
  // Clear all data after animation completes
  setTimeout(() => {
    clearAddStudentsForm();
    parsedStudents = [];
  }, 300);
}

function switchToSingleMode() {
  document.getElementById('singleModeBtn').className = 'import-btn primary';
  document.getElementById('bulkModeBtn').className = 'import-btn secondary';
  
  document.getElementById('singleStudentMode').style.display = 'block';
  document.getElementById('bulkStudentMode').style.display = 'none';
  
  // Hide preview section
  document.getElementById('studentsPreviewSection').style.display = 'none';
  
  // Update progress text
  document.getElementById('addStudentsProgress').innerHTML = `
    <span>👤</span>
    <span>Ready to add a single student</span>
  `;
  
  // Focus on first input
  setTimeout(() => {
    document.getElementById('singleRollNumber').focus();
  }, 100);
}

function switchToBulkMode() {
  document.getElementById('singleModeBtn').className = 'import-btn secondary';
  document.getElementById('bulkModeBtn').className = 'import-btn primary';
  
  document.getElementById('singleStudentMode').style.display = 'none';
  document.getElementById('bulkStudentMode').style.display = 'block';
  
  // Hide preview section initially
  document.getElementById('studentsPreviewSection').style.display = 'none';
  
  // Update progress text
  document.getElementById('addStudentsProgress').innerHTML = `
    <span>👥</span>
    <span>Ready to add multiple students</span>
  `;
  
  // Focus on first input field
  setTimeout(() => {
    const firstRollInput = document.querySelector('.bulk-roll-number[data-index="0"]');
    if (firstRollInput) {
      firstRollInput.focus();
    }
  }, 100);
}

function clearAddStudentsForm() {
  // Clear single student form
  document.getElementById('singleRollNumber').value = '';
  document.getElementById('singleStudentName').value = '';
  document.getElementById('singleStudentEmail').value = '';
  
  // Clear bulk forms - reset to single entry
  resetBulkStudentsContainer();
  
  // Hide preview section
  document.getElementById('studentsPreviewSection').style.display = 'none';
  
  // Clear errors
  document.getElementById('addStudentsErrors').style.display = 'none';
  
  // Reset parsed students
  parsedStudents = [];
}

function resetBulkStudentsContainer() {
  const container = document.getElementById('bulkStudentsContainer');
  bulkStudentCount = 1; // Reset counter
  container.innerHTML = `
    <div class="bulk-student-entry" data-index="0">
      <div class="bulk-entry-header-row">
        <h5 class="bulk-student-title">
          <span class="student-number">1</span>
          <span>Student #1</span>
        </h5>
        <button type="button" class="remove-student-btn" onclick="removeBulkStudent(0)" style="display: none;">
          <span>🗑️</span>
        </button>
      </div>
      
      <div class="form-grid">
        <div class="form-group">
          <label class="form-label">
            Roll Number <span class="required">*</span>
          </label>
          <input type="text" class="form-input bulk-roll-number" placeholder="Enter roll number" required data-field="rollNumber" data-index="0">
        </div>
        <div class="form-group">
          <label class="form-label">
            Student Name <span class="required">*</span>
          </label>
          <input type="text" class="form-input bulk-student-name" placeholder="Enter full name" required data-field="studentName" data-index="0">
        </div>
        <div class="form-group">
          <label class="form-label">Email Address</label>
          <input type="email" class="form-input bulk-student-email" placeholder="student@example.com" data-field="email" data-index="0">
        </div>
      </div>
    </div>
  `;
}

function clearBulkData() {
  // Clear all bulk student form fields
  const bulkInputs = document.querySelectorAll('.bulk-roll-number, .bulk-student-name, .bulk-student-email');
  bulkInputs.forEach(input => input.value = '');
  
  document.getElementById('studentsPreviewSection').style.display = 'none';
  parsedStudents = [];
}

function parseAndPreviewStudents() {
  // Collect data from individual bulk student forms
  const bulkStudentEntries = document.querySelectorAll('.bulk-student-entry');
  parsedStudents = [];
  const errors = [];
  
  bulkStudentEntries.forEach((entry, index) => {
    const rollInput = entry.querySelector('.bulk-roll-number');
    const nameInput = entry.querySelector('.bulk-student-name');
    const emailInput = entry.querySelector('.bulk-student-email');
    
    const rollNumber = rollInput ? rollInput.value.trim() : '';
    const studentName = nameInput ? nameInput.value.trim() : '';
    const email = emailInput ? emailInput.value.trim() : '';
    
    if (rollNumber || studentName) { // Only process if at least roll or name is provided
      const student = {
        id: `bulk_${index}`,
        rollNumber: normalizeRollNumber(rollNumber),
        studentName: normalizeStudentName(studentName),
        email: email,
        isValid: true,
        errors: []
      };
      
      // Validate student data
      validateStudentData(student, index + 1, errors);
      parsedStudents.push(student);
    }
  });
  
  if (parsedStudents.length === 0) {
    showMessage('Please enter at least one student with roll number and name.', true);
    return;
  }
  
  // Show preview
  renderStudentsPreview(parsedStudents, errors);
}

function validateEmail(email) {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
}

function renderStudentsPreview(students, errors) {
  // Show preview section
  document.getElementById('studentsPreviewSection').style.display = 'block';
  
  // Update statistics
  const validStudents = students.filter(s => s.isValid);
  const invalidStudents = students.filter(s => !s.isValid);
  
  const statsHtml = `
    <div class="preview-stat">
      <div class="preview-stat-number total">${students.length}</div>
      <div class="preview-stat-label">Total Entries</div>
    </div>
    <div class="preview-stat">
      <div class="preview-stat-number valid">${validStudents.length}</div>
      <div class="preview-stat-label">Valid Students</div>
    </div>
    <div class="preview-stat">
      <div class="preview-stat-number invalid">${invalidStudents.length}</div>
      <div class="preview-stat-label">Invalid Entries</div>
    </div>
    <div class="preview-stat">
      <div class="preview-stat-number ready">${validStudents.length}</div>
      <div class="preview-stat-label">Ready to Add</div>
    </div>
  `;
  
  document.getElementById('addStudentsStats').innerHTML = statsHtml;
  
  // Show errors if any
  if (errors.length > 0) {
    document.getElementById('addStudentsErrors').style.display = 'block';
    document.getElementById('addStudentsErrorList').innerHTML = 
      errors.map(error => `<div class="preview-error-item"><span>⚠️</span> <span>${error}</span></div>`).join('');
  } else {
    document.getElementById('addStudentsErrors').style.display = 'none';
  }
  
  // Render table
  const tableBody = document.getElementById('addStudentsTableBody');
  tableBody.innerHTML = students.map((student, index) => `
    <tr>
      <td>
        <div class="preview-row-status ${student.isValid ? 'valid' : 'invalid'}">
          <span>${student.isValid ? '✅' : '❌'}</span>
          <span>${student.isValid ? 'Valid' : 'Invalid'}</span>
        </div>
      </td>
      <td>
        <input type="text" class="preview-input ${student.isValid ? '' : 'error'}" 
               value="${student.rollNumber}" 
               onchange="updateParsedStudent(${index}, 'rollNumber', this.value)">
      </td>
      <td>
        <input type="text" class="preview-input ${student.isValid ? '' : 'error'}" 
               value="${student.studentName}" 
               onchange="updateParsedStudent(${index}, 'studentName', this.value)">
      </td>
      <td>
        <input type="email" class="preview-input" 
               value="${student.email}" 
               onchange="updateParsedStudent(${index}, 'email', this.value)">
      </td>
      <td>
        <div class="preview-row-actions">
          <button class="preview-action-btn delete" onclick="removeParsedStudent(${index})" title="Remove student">
            🗑️
          </button>
        </div>
      </td>
    </tr>
  `).join('');
  
  // Update progress text
  document.getElementById('addStudentsProgress').innerHTML = `
    <span>🎯</span>
    <span>${validStudents.length} valid student${validStudents.length !== 1 ? 's' : ''} ready to add</span>
  `;
}

function updateParsedStudent(index, field, value) {
  if (parsedStudents[index]) {
    parsedStudents[index][field] = value;
    
    // Re-validate the student
    const student = parsedStudents[index];
    student.isValid = true;
    student.errors = [];
    
    if (!student.rollNumber || student.rollNumber.trim().length === 0) {
      student.errors.push('Roll number is required');
      student.isValid = false;
    }
    
    if (!student.studentName || student.studentName.trim().length === 0) {
      student.errors.push('Student name is required');
      student.isValid = false;
    }
    
    if (student.email && !validateEmail(student.email)) {
      student.errors.push('Invalid email format');
      student.isValid = false;
    }
    
    // Re-render preview
    renderStudentsPreview(parsedStudents, []);
  }
}

function removeParsedStudent(index) {
  parsedStudents.splice(index, 1);
  renderStudentsPreview(parsedStudents, []);
}

async function addParsedStudents() {
  // Check if we're in single mode or bulk mode
  const isSingleMode = document.getElementById('singleStudentMode').style.display === 'block';
  
  if (isSingleMode) {
    await addSingleStudent();
  } else {
    await addBulkStudents();
  }
}

async function addSingleStudent() {
  const rollNumber = document.getElementById('singleRollNumber').value.trim();
  const studentName = document.getElementById('singleStudentName').value.trim();
  const email = document.getElementById('singleStudentEmail').value.trim();
  
  if (!rollNumber || !studentName) {
    showMessage('Roll number and student name are required.', true);
    return;
  }
  
  try {
    showLoading('Adding student...');
    
    // Check if roll number already exists
    const { data: existingStudent, error: checkError } = await window.supabaseClient
      .from('class_rosters')
      .select('id')
      .eq('class_id', classId)
      .eq('roll_number', rollNumber)
      .single();
    
    if (checkError && checkError.code !== 'PGRST116') {
      throw checkError;
    }
    
    if (existingStudent) {
      showMessage('A student with this roll number already exists in the class.', true);
      hideLoading();
      return;
    }
    
    // Add student
    const { error: insertError } = await window.supabaseClient
      .from('class_rosters')
      .insert({
        class_id: classId,
        roll_number: rollNumber,
        student_name: studentName,
        student_email: email || null,
        is_verified: false
      });
    
    if (insertError) throw insertError;
    
    showMessage(`Student ${studentName} (${rollNumber}) added successfully!`, false);
    
    // Refresh data
    await loadStudents();
    await loadStatistics();
    
    // Close modal
    closeAddStudentsModal();
    
    hideLoading();
  } catch (error) {
    console.error('Error adding student:', error);
    showMessage('Error adding student: ' + error.message, true);
    hideLoading();
  }
}

async function addBulkStudents() {
  const validStudents = parsedStudents.filter(s => s.isValid);
  
  if (validStudents.length === 0) {
    showMessage('No valid students to add. Please check the data and try again.', true);
    return;
  }
  
  try {
    showLoading(`Adding ${validStudents.length} students...`);
    
    // Check for existing roll numbers
    const rollNumbers = validStudents.map(s => s.rollNumber);
    const { data: existingStudents, error: checkError } = await window.supabaseClient
      .from('class_rosters')
      .select('roll_number')
      .eq('class_id', classId)
      .in('roll_number', rollNumbers);
    
    if (checkError) throw checkError;
    
    const existingRollNumbers = (existingStudents || []).map(s => s.roll_number);
    const newStudents = validStudents.filter(s => !existingRollNumbers.includes(s.rollNumber));
    const duplicateStudents = validStudents.filter(s => existingRollNumbers.includes(s.rollNumber));
    
    if (duplicateStudents.length > 0) {
      const duplicateList = duplicateStudents.map(s => s.rollNumber).join(', ');
      showMessage(`Warning: The following roll numbers already exist and will be skipped: ${duplicateList}`, true);
    }
    
    if (newStudents.length === 0) {
      showMessage('All students already exist in this class.', true);
      hideLoading();
      return;
    }
    
    // Prepare data for insertion
    const studentsToInsert = newStudents.map(student => ({
      class_id: classId,
      roll_number: student.rollNumber,
      student_name: student.studentName,
      student_email: student.email || null,
      is_verified: false
    }));
    
    // Insert students in batch
    const { error: insertError } = await window.supabaseClient
      .from('class_rosters')
      .insert(studentsToInsert);
    
    if (insertError) throw insertError;
    
    const successMessage = duplicateStudents.length > 0 
      ? `Successfully added ${newStudents.length} students. ${duplicateStudents.length} duplicates were skipped.`
      : `Successfully added ${newStudents.length} students!`;
    
    showMessage(successMessage, false);
    
    // Refresh data
    await loadStudents();
    await loadStatistics();
    
    // Close modal
    closeAddStudentsModal();
    
    hideLoading();
  } catch (error) {
    console.error('Error adding bulk students:', error);
    showMessage('Error adding students: ' + error.message, true);
    hideLoading();
  }
}

// Bulk Student Management Functions
let bulkStudentCount = 1;

function addAnotherStudent() {
  const container = document.getElementById('bulkStudentsContainer');
  const newIndex = bulkStudentCount;
  bulkStudentCount++;
  
  const studentEntry = document.createElement('div');
  studentEntry.className = 'bulk-student-entry';
  studentEntry.setAttribute('data-index', newIndex);
  
  studentEntry.innerHTML = `
    <div class="bulk-entry-header-row">
      <h5 class="bulk-student-title">
        <span class="student-number">${bulkStudentCount}</span>
        <span>Student #${bulkStudentCount}</span>
      </h5>
      <button type="button" class="remove-student-btn" onclick="removeBulkStudent(${newIndex})">
        <span>🗑️</span>
      </button>
    </div>
    
    <div class="form-grid">
      <div class="form-group">
        <label class="form-label">
          Roll Number <span class="required">*</span>
        </label>
        <input type="text" class="form-input bulk-roll-number" placeholder="Enter roll number" required data-field="rollNumber" data-index="${newIndex}">
      </div>
      <div class="form-group">
        <label class="form-label">
          Student Name <span class="required">*</span>
        </label>
        <input type="text" class="form-input bulk-student-name" placeholder="Enter full name" required data-field="studentName" data-index="${newIndex}">
      </div>
      <div class="form-group">
        <label class="form-label">Email Address</label>
        <input type="email" class="form-input bulk-student-email" placeholder="student@example.com" data-field="email" data-index="${newIndex}">
      </div>
      <div class="form-group">
        <label class="form-label">Phone Number</label>
        <input type="tel" class="form-input bulk-student-phone" placeholder="+1 (555) 123-4567" data-field="phone" data-index="${newIndex}">
      </div>
    </div>
  `;
  
  container.appendChild(studentEntry);
  
  // Show remove button for all entries if there's more than one
  updateRemoveButtonVisibility();
  
  // Focus on the first input of the new entry
  const firstInput = studentEntry.querySelector('.bulk-roll-number');
  if (firstInput) {
    firstInput.focus();
  }
  
  // Add smooth scroll to the new entry
  setTimeout(() => {
    studentEntry.scrollIntoView({ behavior: 'smooth', block: 'center' });
  }, 100);
}

function removeBulkStudent(index) {
  const entry = document.querySelector(`[data-index="${index}"]`);
  if (entry) {
    entry.remove();
    bulkStudentCount--;
    updateRemoveButtonVisibility();
    updateStudentNumbers();
  }
}

function updateRemoveButtonVisibility() {
  const entries = document.querySelectorAll('.bulk-student-entry');
  entries.forEach(entry => {
    const removeBtn = entry.querySelector('.remove-student-btn');
    if (entries.length > 1) {
      removeBtn.style.display = 'flex';
    } else {
      removeBtn.style.display = 'none';
    }
  });
}

function updateStudentNumbers() {
  const entries = document.querySelectorAll('.bulk-student-entry');
  entries.forEach((entry, index) => {
    const numberSpan = entry.querySelector('.student-number');
    const titleSpan = entry.querySelector('.bulk-student-title span:last-child');
    
    if (numberSpan) numberSpan.textContent = index + 1;
    if (titleSpan) titleSpan.textContent = `Student #${index + 1}`;
  });
}

function clearAllBulkStudents() {
  resetBulkStudentsContainer();
  bulkStudentCount = 1;
  document.getElementById('studentsPreviewSection').style.display = 'none';
  parsedStudents = [];
}

function validateAndPreviewBulkStudents() {
  const entries = document.querySelectorAll('.bulk-student-entry');
  parsedStudents = [];
  const errors = [];
  
  entries.forEach((entry, index) => {
    const rollNumberInput = entry.querySelector('[data-field="rollNumber"]');
    const studentNameInput = entry.querySelector('[data-field="studentName"]');
    const emailInput = entry.querySelector('[data-field="email"]');
    const phoneInput = entry.querySelector('[data-field="phone"]');
    
    const rollNumber = rollNumberInput?.value.trim() || '';
    const studentName = studentNameInput?.value.trim() || '';
    const email = emailInput?.value.trim() || '';
    const phone = phoneInput?.value.trim() || '';
    
    // Validation
    let isValid = true;
    const studentErrors = [];
    
    if (!rollNumber) {
      studentErrors.push('Roll number is required');
      isValid = false;
      rollNumberInput?.classList.add('error');
    } else {
      rollNumberInput?.classList.remove('error');
    }
    
    if (!studentName) {
      studentErrors.push('Student name is required');
      isValid = false;
      studentNameInput?.classList.add('error');
    } else {
      studentNameInput?.classList.remove('error');
    }
    
    // Check for duplicate roll numbers in parsed data
    if (rollNumber && parsedStudents.some(s => s.rollNumber === rollNumber)) {
      studentErrors.push('Duplicate roll number');
      isValid = false;
      rollNumberInput?.classList.add('error');
    }
    
    // Email validation if provided
    if (email && !validateEmail(email)) {
      studentErrors.push('Invalid email format');
      isValid = false;
      emailInput?.classList.add('error');
    } else {
      emailInput?.classList.remove('error');
    }
    
    if (!isValid) {
      errors.push(`Student #${index + 1}: ${studentErrors.join(', ')}`);
    }
    
    // Only add non-empty entries
    if (rollNumber || studentName || email || phone) {
      parsedStudents.push({
        rollNumber,
        studentName,
        email,
        phone,
        isValid,
        errors: studentErrors,
        lineNumber: index + 1
      });
    }
  });
  
  if (parsedStudents.length === 0) {
    showMessage('Please fill in at least one student entry.', true);
    return;
  }
  
  // Show preview
  renderStudentsPreview(parsedStudents, errors);
}