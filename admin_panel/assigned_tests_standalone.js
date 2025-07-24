// Assigned Tests Management JavaScript - Standalone Version

// Main Supabase client for colleges/branches/semesters
const SUPABASE_MAIN_URL = 'https://vpjzxhfrqyspcbgmwqjd.supabase.co';
const SUPABASE_MAIN_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZwanp4aGZycXlzcGNiZ213cWpkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTExMDQ5NzIsImV4cCI6MjA2NjY4MDk3Mn0.x9dnZg6gvSUWVfuL4-CB6dKUY6sESE1xyM_v9Wmv4Tc';
const supabaseMain = window.supabaseMain = window.supabase.createClient(SUPABASE_MAIN_URL, SUPABASE_MAIN_KEY, {
  auth: { storageKey: 'supabase.main' }
});

// Questions Supabase client for test data
const SUPABASE_QUESTIONS_URL = 'https://pfuzvpihupvhjshxiofn.supabase.co';
const SUPABASE_QUESTIONS_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBmdXp2cGlodXB2aGpzaHhpb2ZuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE1Mjg1MjIsImV4cCI6MjA2NzEwNDUyMn0.WAPJG6iaxuCAM75yCRu6UOcck37XuilVoDJK3uwyx-k';
const supabaseQuestions = window.supabaseQuestions = window.supabase.createClient(SUPABASE_QUESTIONS_URL, SUPABASE_QUESTIONS_KEY, {
  auth: { storageKey: 'supabase.questions' }
});

// Global variables
let allAssignedTests = [];
let currentFilters = {
  search: '',
  status: '',
  difficulty: ''
};

// Context variables
let selectedCollegeId = null;
let selectedBranchId = null;
let selectedSemesterId = null;
let selectedCollegeName = null;
let selectedBranchName = null;
let selectedSemesterName = null;

// Check if Supabase is loaded and initialize on page load
document.addEventListener('DOMContentLoaded', function() {
  // Wait for Supabase to be available
  if (typeof window.supabase !== 'undefined') {
    initializeApp();
  } else {
    // Retry after a short delay
    setTimeout(() => {
      if (typeof window.supabase !== 'undefined') {
        initializeApp();
      } else {
        showMessage('Failed to load Supabase library. Please refresh the page.', true);
      }
    }, 1000);
  }
});

// Initialize the application
function initializeApp() {
  // Show context modal first
  showContextModal();
  
  // Setup context modal event listeners
  setupContextModal();
}

// Show context selection modal
function showContextModal() {
  const contextModal = document.getElementById('contextModal');
  const mainContent = document.getElementById('mainContent');
  
  contextModal.style.display = 'flex';
  mainContent.style.display = 'none';
  document.body.classList.add('modal-open');
  
  // Populate colleges
  populateColleges();
}

// Setup context modal event listeners
async function setupContextModal() {
  const collegeSelect = document.getElementById('collegeSelect');
  const branchSelect = document.getElementById('branchSelect');
  const semesterSelect = document.getElementById('semesterSelect');
  const contextContinueBtn = document.getElementById('contextContinueBtn');
  
  // College change event
  collegeSelect.addEventListener('change', async function() {
    branchSelect.innerHTML = '<option value="">Select Branch</option>';
    semesterSelect.innerHTML = '<option value="">Select Semester</option>';
    const selectedCollege = collegeSelect.value;
    if (!selectedCollege) return;
    
    try {
      const { data: branches, error: branchError } = await supabaseMain
        .from('branches')
        .select('id, name')
        .eq('college_id', selectedCollege);
      if (branchError) throw branchError;
      
      branches?.forEach(branch => {
        const opt = document.createElement('option');
        opt.value = branch.id;
        opt.textContent = branch.name;
        branchSelect.appendChild(opt);
      });
    } catch (e) {
      showMessage('Failed to load branches', true);
    }
  });
  
  // Branch change event
  branchSelect.addEventListener('change', async function() {
    semesterSelect.innerHTML = '<option value="">Select Semester</option>';
    const selectedBranch = branchSelect.value;
    if (!selectedBranch) return;
    
    try {
      const { data: semesters, error: semesterError } = await supabaseMain
        .from('semesters')
        .select('id, name')
        .eq('branch_id', selectedBranch);
      if (semesterError) throw semesterError;
      
      semesters?.forEach(sem => {
        const opt = document.createElement('option');
        opt.value = sem.id;
        opt.textContent = sem.name;
        semesterSelect.appendChild(opt);
      });
    } catch (e) {
      showMessage('Failed to load semesters', true);
    }
  });
  
  // Continue button event
  contextContinueBtn.onclick = function() {
    const collegeId = collegeSelect.value;
    const branchId = branchSelect.value;
    const semesterId = semesterSelect.value;
    
    if (!collegeId || !branchId || !semesterId) {
      showMessage('Please select college, branch, and semester.', true);
      return;
    }
    
    selectedCollegeId = collegeId;
    selectedBranchId = branchId;
    selectedSemesterId = semesterId;
    selectedCollegeName = collegeSelect.options[collegeSelect.selectedIndex].textContent;
    selectedBranchName = branchSelect.options[branchSelect.selectedIndex].textContent;
    selectedSemesterName = semesterSelect.options[semesterSelect.selectedIndex].textContent;
    
    // Hide modal and show main content
    hideContextModal();
    
    // Update context UI
    updateContextUI();
    
    // Load assigned tests
    loadAssignedTests();
    
    // Add event listeners
    setupEventListeners();
  };
}

// Populate colleges dropdown
async function populateColleges() {
  const collegeSelect = document.getElementById('collegeSelect');
  collegeSelect.innerHTML = '<option value="">Select College</option>';
  
  try {
    const { data: colleges, error: collegeError } = await supabaseMain
      .from('colleges')
      .select('id, name');
    if (collegeError) throw collegeError;
    
    colleges?.forEach(college => {
      const opt = document.createElement('option');
      opt.value = college.id;
      opt.textContent = college.name;
      collegeSelect.appendChild(opt);
    });
  } catch (e) {
    showMessage('Failed to load colleges', true);
  }
}

// Hide context modal
function hideContextModal() {
  const contextModal = document.getElementById('contextModal');
  const mainContent = document.getElementById('mainContent');
  
  contextModal.style.display = 'none';
  mainContent.style.display = 'block';
  document.body.classList.remove('modal-open');
}

// Update context UI based on selected semester
function updateContextUI() {
  const collegeElem = document.getElementById('contextCollege');
  const branchElem = document.getElementById('contextBranch');
  const semesterElem = document.getElementById('contextSemester');
  
  if (selectedCollegeName && selectedBranchName && selectedSemesterName) {
    if (collegeElem) collegeElem.textContent = selectedCollegeName;
    if (branchElem) branchElem.textContent = selectedBranchName;
    if (semesterElem) semesterElem.textContent = selectedSemesterName;
  } else {
    if (collegeElem) collegeElem.textContent = 'College';
    if (branchElem) branchElem.textContent = 'Branch';
    if (semesterElem) semesterElem.textContent = 'Semester';
  }
}

// Setup event listeners
function setupEventListeners() {
  // Search functionality
  const searchInput = document.getElementById('testSearchInput');
  if (searchInput) {
    searchInput.addEventListener('input', function() {
      currentFilters.search = this.value;
      filterTests();
    });
  }
  
  // Status filter
  const statusFilter = document.getElementById('statusFilter');
  if (statusFilter) {
    statusFilter.addEventListener('change', function() {
      currentFilters.status = this.value;
      filterTests();
    });
  }
  
  // Difficulty filter
  const difficultyFilter = document.getElementById('difficultyFilter');
  if (difficultyFilter) {
    difficultyFilter.addEventListener('change', function() {
      currentFilters.difficulty = this.value;
      filterTests();
    });
  }
  
  // Modal close on outside click
  const modal = document.getElementById('attendeesModal');
  if (modal) {
    modal.addEventListener('click', function(e) {
      if (e.target === modal) {
        closeAttendeesModal();
      }
    });
  }
}

// Utility Functions
function showMessage(message, isError = false) {
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

// Load assigned tests from database
async function loadAssignedTests() {
  showLoading();
  
  try {

    
    // Fetch only assigned tests (those with test_title) since RLS is disabled
    const { data: tests, error } = await supabaseMain
      .from('test_results')
      .select('*')
      .not('test_title', 'is', null)
      .neq('test_title', '')
      .order('created_at', { ascending: false });
    

    
    if (error) {
      console.error('Supabase query error:', error);
      throw error;
    }
    

    
    allAssignedTests = tests || [];
    
    // Group test results by test_title to create "assigned tests"
    const testGroups = {};
    allAssignedTests.forEach(test => {
      const testKey = test.test_title; // Use test_title as the key since we filtered for it
      
      if (!testGroups[testKey]) {
        testGroups[testKey] = {
          id: testKey,
          test_title: test.test_title,
          title: test.test_title,
          subject_name: test.subject_name || 'Unknown Subject',
          chapter_name: test.chapter_name || 'Unknown Chapter',
          difficulty: test.difficulty,
          total_questions: test.total_questions,
          attendee_count: 0,
          created_at: test.created_at,
          status: 'completed', // Since these are test results, they're completed
          attendees: []
        };
      }
      testGroups[testKey].attendee_count++;
      testGroups[testKey].attendees.push(test);
    });
    
    allAssignedTests = Object.values(testGroups);
    
    displayTests(allAssignedTests);
    updateStats(allAssignedTests);
    
  } catch (error) {

    showMessage('Error loading assigned tests. Please try again.', true);
  } finally {
    hideLoading();
  }
}

// Filter tests based on current filters
function filterTests() {
  let filteredTests = allAssignedTests;
  
  // Search filter
  if (currentFilters.search) {
    const searchTerm = currentFilters.search.toLowerCase();
    filteredTests = filteredTests.filter(test => 
      test.title.toLowerCase().includes(searchTerm) ||
      test.subject_name.toLowerCase().includes(searchTerm) ||
      test.chapter_name.toLowerCase().includes(searchTerm)
    );
  }
  
  // Status filter
  if (currentFilters.status) {
    filteredTests = filteredTests.filter(test => test.status === currentFilters.status);
  }
  
  // Difficulty filter
  if (currentFilters.difficulty) {
    filteredTests = filteredTests.filter(test => test.difficulty === currentFilters.difficulty);
  }
  
  displayTests(filteredTests);
  updateStats(filteredTests);
}

// Display tests in the grid
function displayTests(tests) {
  const testsList = document.getElementById('assignedTestsList');
  const emptyState = document.getElementById('emptyState');
  
  if (!tests || tests.length === 0) {
    testsList.innerHTML = '';
    emptyState.classList.remove('hidden');
    return;
  }
  
  emptyState.classList.add('hidden');
  
  testsList.innerHTML = tests.map(test => `
    <div class="test-card" onclick="viewTestAttendees('${test.id}', '${escapeHtml(test.title)}')">
      <div class="test-header">
        <div>
          <div class="test-title">${escapeHtml(test.title)}</div>
          <div class="test-subject">${escapeHtml(test.subject_name)} - ${escapeHtml(test.chapter_name)}</div>
        </div>
        <div class="test-status ${test.status}">${test.status}</div>
      </div>
      
      <div class="test-details">
        <div class="detail-item">
          <div class="detail-label">Difficulty</div>
          <div class="detail-value">${getDifficultyLabel(test.difficulty)}</div>
        </div>
        <div class="detail-item">
          <div class="detail-label">Questions</div>
          <div class="detail-value">${test.total_questions}</div>
        </div>
        <div class="detail-item">
          <div class="detail-label">Attendees</div>
          <div class="detail-value">${test.attendee_count}</div>
        </div>
        <div class="detail-item">
          <div class="detail-label">Created</div>
          <div class="detail-value">${formatDate(test.created_at)}</div>
        </div>
      </div>
      
      <div class="test-actions">
        <button class="action-btn view-attendees-btn" onclick="event.stopPropagation(); viewTestAttendees('${test.id}', '${escapeHtml(test.title)}')">
          👥 View Attendees
        </button>
        <button class="action-btn test-info-btn" onclick="event.stopPropagation(); showTestInfo('${test.id}')">
          ℹ️ Test Info
        </button>
      </div>
    </div>
  `).join('');
}

// Update statistics
function updateStats(tests) {
  const totalTests = tests.length;
  const completedTests = tests.filter(test => test.status === 'completed').length;
  const activeTests = tests.filter(test => test.status === 'active').length;
  
  document.getElementById('totalTests').textContent = totalTests;
  document.getElementById('completedTests').textContent = completedTests;
  document.getElementById('activeTests').textContent = activeTests;
  
  document.getElementById('listTotalTests').textContent = totalTests;
}

// View test attendees
async function viewTestAttendees(testId, testTitle) {
  showLoading();
  try {
    // Find the test in our grouped data
    const test = allAssignedTests.find(t => t.id === testId);
    if (!test) {
      throw new Error('Test not found');
    }
    // Fetch all test_results with the same test_title
    const { data: attendees, error } = await supabaseMain
      .from('test_results')
      .select('*')
      .eq('test_title', test.test_title)
      .order('created_at', { ascending: false });
    if (error) throw error;
    // For each attendee, we need to get user profile information
    const attendeesWithProfiles = await Promise.all(
      (attendees || []).map(async (attendee) => {
        try {
          // Get user profile from the main database
          const { data: userProfile, error: profileError } = await supabaseMain
            .from('profiles')
            .select('full_name, email, student_id')
            .eq('id', attendee.user_id)
            .single();
          if (profileError) {
            return {
              ...attendee,
              user_profiles: {
                full_name: 'Unknown User',
                email: 'No email',
                student_id: 'N/A'
              }
            };
          }
          return {
            ...attendee,
            user_profiles: {
              full_name: userProfile?.full_name || 'Unknown User',
              email: userProfile?.email || 'No email',
              student_id: userProfile?.student_id || 'N/A'
            }
          };
        } catch (error) {
          return {
            ...attendee,
            user_profiles: {
              full_name: 'Unknown User',
              email: 'No email',
              student_id: 'N/A'
            }
          };
        }
      })
    );
    showAttendeesModal(testTitle, attendeesWithProfiles);
  } catch (error) {

    showMessage('Error loading attendees. Please try again.', true);
  } finally {
    hideLoading();
  }
}

// Show attendees modal
function showAttendeesModal(testTitle, attendees) {
  const modal = document.getElementById('attendeesModal');
  const modalTitle = document.getElementById('modalTitle');
  const attendeesList = document.getElementById('attendeesList');
  const attendeesEmptyState = document.getElementById('attendeesEmptyState');
  
  modalTitle.textContent = `Attendees - ${testTitle}`;
  
  if (!attendees || attendees.length === 0) {
    attendeesList.innerHTML = '';
    attendeesEmptyState.classList.remove('hidden');
  } else {
    attendeesEmptyState.classList.add('hidden');
    
    attendeesList.innerHTML = attendees.map(attendee => {
      const correctAnswers = attendee.correct_answers || 0;
      const totalQuestions = attendee.total_questions || 1;
      const percentage = Math.round((correctAnswers / totalQuestions) * 100);
      return `
        <div class="attendee-item">
          <div class="attendee-info">
            <div class="attendee-name">${escapeHtml(attendee.user_profiles?.full_name || 'Unknown User')}</div>
            <div class="attendee-email">${escapeHtml(attendee.user_profiles?.email || 'No email')}</div>
            <div class="attendee-roll">Roll No: ${escapeHtml(attendee.user_profiles?.student_id || 'N/A')}</div>
          </div>
          <div class="attendee-score">
            <div class="score-value">${percentage}%</div>
            <div class="score-label">${correctAnswers}/${totalQuestions} correct</div>
          </div>
        </div>
      `;
    }).join('');
  }
  
  modal.classList.remove('hidden');
}

// Close attendees modal
function closeAttendeesModal() {
  document.getElementById('attendeesModal').classList.add('hidden');
}

// Download attendees PDF
function downloadAttendeesPDF() {
  const modalTitle = document.getElementById('modalTitle').textContent;
  const attendeesList = document.getElementById('attendeesList');
  const attendeeItems = attendeesList.querySelectorAll('.attendee-item');
  
  if (attendeeItems.length === 0) {
    showMessage('No attendees to download', true);
    return;
  }
  
  // Create PDF document
  const { jsPDF } = window.jspdf;
  const doc = new jsPDF();
  
  // Set document properties
  doc.setProperties({
    title: 'Test Attendees Report',
    subject: modalTitle,
    author: 'Admin',
    creator: 'Admin Panel'
  });
  
  // Get test title and context information
  const testTitle = modalTitle.replace('Attendees - ', '');
  
      // Calculate total questions from first attendee
    let totalQuestions = 0;
    if (attendeeItems.length > 0) {
      const firstItem = attendeeItems[0];
      const scoreLabel = firstItem.querySelector('.score-label').textContent;
      const scoreMatch = scoreLabel.match(/(\d+)\/(\d+)/);
      totalQuestions = scoreMatch ? parseInt(scoreMatch[2]) : 0;
    }
  
  // Add college, branch, semester information
  doc.setFontSize(12);
  doc.setTextColor(100, 100, 100);
  doc.text(`College: ${selectedCollegeName}`, 20, 20);
  doc.text(`Branch: ${selectedBranchName}`, 20, 27);
  doc.text(`Semester: ${selectedSemesterName}`, 20, 34);
  
  // Add test name in big font
  doc.setFontSize(20);
  doc.setTextColor(0, 0, 0);
  doc.setFont(undefined, 'bold');
  doc.text(testTitle, 20, 50);
  
  // Add total questions information
  doc.setFontSize(12);
  doc.setTextColor(100, 100, 100);
  doc.setFont(undefined, 'normal');
  doc.text(`Total Questions: ${totalQuestions}`, 20, 65);
  
  // Add generation info
  doc.setFontSize(8);
  doc.setTextColor(150, 150, 150);
  doc.text(`Generated on: ${new Date().toLocaleString()}`, 20, 75);
  doc.text(`Total Attendees: ${attendeeItems.length}`, 20, 80);
  
  // Prepare table data without questions column
  const tableData = [];
  let yPosition = 95;
  
  // Add table headers
  tableData.push(['Student ID', 'Name', 'Email', 'Score', 'Percentage']);
  
  // Add attendee data
  attendeeItems.forEach((item, index) => {
    const name = item.querySelector('.attendee-name').textContent;
    const email = item.querySelector('.attendee-email').textContent.replace('📧', '').trim();
    const studentId = item.querySelector('.attendee-roll').textContent.replace('Roll No:', '').trim();
    const scoreValue = item.querySelector('.score-value').textContent;
    const scoreLabel = item.querySelector('.score-label').textContent;
    
    // Extract score from score label (e.g., "5/10 correct")
    const scoreMatch = scoreLabel.match(/(\d+)\/(\d+)/);
    const correctAnswers = scoreMatch ? parseInt(scoreMatch[1]) : 0;
    const percentage = scoreValue.replace('%', '');
    
    tableData.push([
      studentId,
      name,
      email,
      correctAnswers,
      percentage
    ]);
  });
  
  // Create beautiful table
  doc.autoTable({
    startY: yPosition,
    head: [tableData[0]],
    body: tableData.slice(1),
    theme: 'grid',
    headStyles: {
      fillColor: [99, 102, 241],
      textColor: 255,
      fontStyle: 'bold',
      fontSize: 11
    },
    styles: {
      fontSize: 10,
      cellPadding: 6,
      lineColor: [200, 200, 200],
      lineWidth: 0.1
    },
    columnStyles: {
      0: { cellWidth: 30, fontStyle: 'bold' }, // Student ID
      1: { cellWidth: 50 }, // Name
      2: { cellWidth: 60 }, // Email
      3: { cellWidth: 25, halign: 'center' }, // Score
      4: { cellWidth: 30, halign: 'center' }  // Percentage
    },
    didDrawPage: function(data) {
      // Add page number
      const pageCount = doc.internal.getNumberOfPages();
      doc.setFontSize(8);
      doc.setTextColor(150, 150, 150);
      doc.text(`Page ${data.pageNumber} of ${pageCount}`, data.settings.margin.left, doc.internal.pageSize.height - 15);
    }
  });
  
  // Add statistics section
  const finalY = doc.lastAutoTable.finalY + 25;
  if (finalY < doc.internal.pageSize.height - 60) {
    // Add statistics background
    doc.setFillColor(248, 250, 252);
    doc.rect(15, finalY - 5, 180, 35, 'F');
    
    // Add statistics border
    doc.setDrawColor(99, 102, 241);
    doc.setLineWidth(0.5);
    doc.rect(15, finalY - 5, 180, 35, 'S');
    
    doc.setFontSize(12);
    doc.setTextColor(99, 102, 241);
    doc.setFont(undefined, 'bold');
    doc.text('Test Statistics', 20, finalY);
    
    doc.setFontSize(10);
    doc.setTextColor(100, 100, 100);
    doc.setFont(undefined, 'normal');
    
    // Calculate statistics
    const scores = Array.from(attendeeItems).map(item => {
      const scoreLabel = item.querySelector('.score-label').textContent;
      const scoreMatch = scoreLabel.match(/(\d+)\/(\d+)/);
      return scoreMatch ? (parseInt(scoreMatch[1]) / parseInt(scoreMatch[2])) * 100 : 0;
    });
    
    const avgScore = scores.reduce((a, b) => a + b, 0) / scores.length;
    const maxScore = Math.max(...scores);
    const minScore = Math.min(...scores);
    const passCount = scores.filter(score => score >= 60).length;
    
    doc.text(`Average Score: ${avgScore.toFixed(1)}%`, 20, finalY + 10);
    doc.text(`Highest Score: ${maxScore.toFixed(1)}%`, 20, finalY + 16);
    doc.text(`Lowest Score: ${minScore.toFixed(1)}%`, 20, finalY + 22);
    doc.text(`Passing Rate: ${((passCount / scores.length) * 100).toFixed(1)}%`, 20, finalY + 28);
  }
  
  // Add footer
  const footerY = doc.internal.pageSize.height - 25;
  
  // Add footer background
  doc.setFillColor(99, 102, 241);
  doc.rect(0, footerY, 210, 25, 'F');
  
  // Add footer text
  doc.setFontSize(12);
  doc.setTextColor(255, 255, 255);
  doc.setFont(undefined, 'bold');
  doc.text('EduNest', 20, footerY + 8);
  
  // Add contact information
  doc.setFontSize(8);
  doc.setTextColor(255, 255, 255);
  doc.setFont(undefined, 'normal');
  doc.text('For any issues, contact: ranojitdas362@gmail.com', 20, footerY + 16);
  
  // Add copyright
  doc.setFontSize(8);
  doc.setTextColor(255, 255, 255);
  doc.text(`© ${new Date().getFullYear()} EduNest. All rights reserved.`, 20, footerY + 22);
  
  // Generate filename
  const testName = testTitle.replace(/[^a-zA-Z0-9]/g, '_');
  const filename = `${testName}_Attendees_${new Date().toISOString().split('T')[0]}.pdf`;
  
  // Download PDF
  doc.save(filename);
  
  showMessage('PDF downloaded successfully!', false);
}

// Show test information
function showTestInfo(testId) {
  const test = allAssignedTests.find(t => t.id === testId);
  if (!test) {
    showMessage('Test information not found.', true);
    return;
  }
  
  const info = `
Test Information:
- Title: ${test.title}
- Subject: ${test.subject_name}
- Chapter: ${test.chapter_name}
- Difficulty: ${getDifficultyLabel(test.difficulty)}
- Questions: ${test.total_questions}
- Attendees: ${test.attendee_count}
- Status: ${test.status}
- Created: ${formatDate(test.created_at)}
- Context: ${selectedCollegeName} > ${selectedBranchName} > ${selectedSemesterName}
  `;
  
  alert(info);
}

// Utility functions
function getDifficultyLabel(difficulty) {
  const labels = {
    'beginner': 'Easy',
    'intermediate': 'Medium',
    'advanced': 'Hard'
  };
  return labels[difficulty] || difficulty;
}

function formatDate(dateString) {
  if (!dateString) return 'N/A';
  const date = new Date(dateString);
  return date.toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  });
}

function escapeHtml(text) {
  if (!text) return '';
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
} 