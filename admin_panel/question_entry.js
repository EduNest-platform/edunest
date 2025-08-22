// Main Supabase client for colleges/branches/semesters
const SUPABASE_MAIN_URL = 'https://vpjzxhfrqyspcbgmwqjd.supabase.co';
const SUPABASE_MAIN_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZwanp4aGZycXlzcGNiZ213cWpkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTExMDQ5NzIsImV4cCI6MjA2NjY4MDk3Mn0.x9dnZg6gvSUWVfuL4-CB6dKUY6sESE1xyM_v9Wmv4Tc';
const supabaseMain = window.supabaseMain = window.supabase.createClient(SUPABASE_MAIN_URL, SUPABASE_MAIN_KEY, {
  auth: { storageKey: 'supabase.main' }
});

// Questions Supabase 
const SUPABASE_QUESTIONS_URL = 'https://pfuzvpihupvhjshxiofn.supabase.co';
const SUPABASE_QUESTIONS_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBmdXp2cGlodXB2aGpzaHhpb2ZuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE1Mjg1MjIsImV4cCI6MjA2NzEwNDUyMn0.WAPJG6iaxuCAM75yCRu6UOcck37XuilVoDJK3uwyx-k';
const supabaseQuestions = window.supabaseQuestions = window.supabase.createClient(SUPABASE_QUESTIONS_URL, SUPABASE_QUESTIONS_KEY, {
  auth: { storageKey: 'supabase.questions' }
});

// Global variables
let selectedCollegeName = null;
let selectedBranchName = null;
let selectedSemesterName = null;
let testName = '';
let testSubject = '';
let testDuration = 30;
let numQuestions = 0;
let currentQuestionIndex = 0;
let questionsArray = [];

// Class context variables
let isClassContext = false;
let classContextId = null;
let classContextSubject = null;
let classContextSubjectId = null;

// Initialize page
document.addEventListener('DOMContentLoaded', function() {
  initializePage();
  setupEventListeners();
});

function initializePage() {
  checkClassContext();
  populateSubjectDropdown(); // Always populate subjects
  if (isClassContext) {
    updateContextDisplay();
  } else {
    // For non-class context, try to get context from sessionStorage
    selectedCollegeName = sessionStorage.getItem('selectedCollegeName');
    selectedBranchName = sessionStorage.getItem('selectedBranchName');
    selectedSemesterName = sessionStorage.getItem('selectedSemesterName');
    updateContextDisplay();
  }
}

function checkClassContext() {
  const urlParams = new URLSearchParams(window.location.search);
  const classId = urlParams.get('classId');
  const subject = urlParams.get('subject');
  const college = urlParams.get('college');
  const branch = urlParams.get('branch');
  const semester = urlParams.get('semester');
  
  // Also check sessionStorage for complete context
  const sessionClassId = sessionStorage.getItem('selectedClassId');
  const sessionSubject = sessionStorage.getItem('selectedSubjectName');
  const sessionSubjectId = sessionStorage.getItem('selectedSubjectId');
  const sessionCollege = sessionStorage.getItem('selectedCollegeName');
  const sessionBranch = sessionStorage.getItem('selectedBranchName');
  const sessionSemester = sessionStorage.getItem('selectedSemesterName');
  const context = sessionStorage.getItem('questionEntryContext');
  
  if ((classId && subject) || (sessionClassId && context === 'class')) {
    isClassContext = true;
    classContextId = classId || sessionClassId;
    classContextSubject = subject || sessionSubject;
    classContextSubjectId = sessionSubjectId;
    
    // Set complete context from URL parameters or sessionStorage
    selectedCollegeName = college || sessionCollege;
    selectedBranchName = branch || sessionBranch;
    selectedSemesterName = semester || sessionSemester;
    
    // Update UI for class context
    updateUIForClassContext();
  }
}

function updateUIForClassContext() {
  // Update page title
  const headerTitle = document.querySelector('.page-title');
  if (headerTitle && classContextSubject) {
    headerTitle.textContent = `Question Entry - ${classContextSubject}`;
  }
  
  // Update back button
  const backBtn = document.querySelector('.back-btn');
  if (backBtn && isClassContext) {
    backBtn.href = `attendance.html`;
    backBtn.textContent = 'Back to Classes';
  }
}

function setupEventListeners() {
  // Test configuration
  const startBtn = document.getElementById('startQuestionEntry');
  
  // Question entry
  const saveNextBtn = document.getElementById('saveAndNextBtn');
  const finishBtn = document.getElementById('finishTestBtn');
  
  // Review
  const backToQuestionsBtn = document.getElementById('backToQuestionsBtn');
  const submitAllBtn = document.getElementById('submitAllBtn');
  
  if (startBtn) {
    startBtn.addEventListener('click', startQuestionEntry);
  }
  
  if (saveNextBtn) {
    saveNextBtn.addEventListener('click', saveAndNext);
  }
  
  if (finishBtn) {
    finishBtn.addEventListener('click', finishTest);
  }
  
  if (backToQuestionsBtn) {
    backToQuestionsBtn.addEventListener('click', backToQuestions);
  }
  
  if (submitAllBtn) {
    submitAllBtn.addEventListener('click', submitAllQuestions);
  }
}

async function populateSubjectDropdown() {
  const subjectSelect = document.getElementById('subjectInput');
  if (!subjectSelect) return;
  
  // Clear existing options
  subjectSelect.innerHTML = '<option value="">Loading subjects...</option>';
  
  if (isClassContext && classContextSubject) {
    // For class context, set the subject directly
    subjectSelect.innerHTML = `<option value="${classContextSubject}" selected>${classContextSubject}</option>`;
    return;
  }
  
  // For non-class context, provide common subjects or allow manual entry
  subjectSelect.innerHTML = `
    <option value="">Select Subject</option>
    <option value="Mathematics">Mathematics</option>
    <option value="Physics">Physics</option>
    <option value="Chemistry">Chemistry</option>
    <option value="Computer Science">Computer Science</option>
    <option value="English">English</option>
    <option value="Other">Other (Custom)</option>
  `;
  
  // Allow custom subject entry
  subjectSelect.addEventListener('change', function() {
    if (this.value === 'Other') {
      const customSubject = prompt('Enter custom subject name:');
      if (customSubject) {
        const option = document.createElement('option');
        option.value = customSubject;
        option.textContent = customSubject;
        option.selected = true;
        this.appendChild(option);
      }
    }
  });
}

function updateContextDisplay() {
  const collegeSpan = document.getElementById('contextCollege');
  const branchSpan = document.getElementById('contextBranch');
  const semesterSpan = document.getElementById('contextSemester');
  
  if (selectedCollegeName && selectedBranchName && selectedSemesterName) {
    if (collegeSpan) collegeSpan.textContent = selectedCollegeName;
    if (branchSpan) branchSpan.textContent = selectedBranchName;
    if (semesterSpan) semesterSpan.textContent = selectedSemesterName;
  } else {
    // Show placeholder text when context is not available
    if (collegeSpan) collegeSpan.textContent = selectedCollegeName || 'College';
    if (branchSpan) branchSpan.textContent = selectedBranchName || 'Branch';
    if (semesterSpan) semesterSpan.textContent = selectedSemesterName || 'Semester';
  }
}

function startQuestionEntry() {
  // Validate configuration
  const testNameInput = document.getElementById('testNameInput');
  const subjectInput = document.getElementById('subjectInput');
  const numQuestionsInput = document.getElementById('numQuestionsInput');
  const testDurationInput = document.getElementById('testDurationInput');
  
  if (!testNameInput.value.trim()) {
    showMessage('Please enter a test name', 'error');
    return;
  }
  
  if (!subjectInput.value.trim()) {
    showMessage('Please select a subject', 'error');
    return;
  }
  
  if (!numQuestionsInput.value || numQuestionsInput.value < 1) {
    showMessage('Please enter a valid number of questions', 'error');
    return;
  }
  
  if (!testDurationInput.value || testDurationInput.value < 1) {
    showMessage('Please enter a valid test duration', 'error');
    return;
  }
  
  // Store configuration
  testName = testNameInput.value.trim();
  testSubject = subjectInput.value.trim();
  numQuestions = parseInt(numQuestionsInput.value);
  testDuration = parseInt(testDurationInput.value);
  
  // Reset question array and index
  questionsArray = [];
  currentQuestionIndex = 0;
  
  // Show question entry section
  showSection('questionEntry');
  updateQuestionProgress();
  updateButtonVisibility();
}

function updateButtonVisibility() {
  const saveNextBtn = document.getElementById('saveAndNextBtn');
  const finishBtn = document.getElementById('finishTestBtn');
  
  if (saveNextBtn && finishBtn) {
    if (numQuestions === 1) {
      // If only 1 question total, hide save & next, show only review
      saveNextBtn.style.display = 'none';
      finishBtn.style.display = 'inline-block';
      finishBtn.textContent = 'Review & Submit';
    } else if (currentQuestionIndex + 1 === numQuestions) {
      // On the last question, hide save & next, show only review
      saveNextBtn.style.display = 'none';
      finishBtn.style.display = 'inline-block';
      finishBtn.textContent = 'Review & Submit';
    } else {
      // Otherwise show both buttons
      saveNextBtn.style.display = 'inline-block';
      finishBtn.style.display = 'inline-block';
      finishBtn.textContent = 'Review Questions';
    }
  }
}

function saveAndNext() {
  if (!validateCurrentQuestion()) {
    return;
  }
  
  const questionData = getCurrentQuestionData();
  questionsArray[currentQuestionIndex] = questionData;
  
  if (currentQuestionIndex + 1 < numQuestions) {
    currentQuestionIndex++;
    clearQuestionForm();
    updateQuestionProgress();
    updateButtonVisibility();
  }
  
  showMessage('Question saved successfully!', 'success');
}

function finishTest() {
  if (!validateCurrentQuestion()) {
    return;
  }
  
  const questionData = getCurrentQuestionData();
  questionsArray[currentQuestionIndex] = questionData;
  
  showSection('review');
  displayReviewQuestions();
}

function validateCurrentQuestion() {
  const questionText = document.getElementById('questionText').value.trim();
  const optionA = document.getElementById('optionA').value.trim();
  const optionB = document.getElementById('optionB').value.trim();
  const optionC = document.getElementById('optionC').value.trim();
  const optionD = document.getElementById('optionD').value.trim();
  const correct = document.querySelector('input[name="correctOption"]:checked');
  
  if (!questionText) {
    showMessage('Please enter the question text', 'error');
    return false;
  }
  
  if (!optionA || !optionB || !optionC || !optionD) {
    showMessage('Please fill in all options', 'error');
    return false;
  }
  
  if (!correct) {
    showMessage('Please select the correct answer', 'error');
    return false;
  }
  
  return true;
}

function getCurrentQuestionData() {
  return {
    question: document.getElementById('questionText').value.trim(),
    options: [
      document.getElementById('optionA').value.trim(),
      document.getElementById('optionB').value.trim(),
      document.getElementById('optionC').value.trim(),
      document.getElementById('optionD').value.trim()
    ],
    correct: document.querySelector('input[name="correctOption"]:checked').value
  };
}

function clearQuestionForm() {
  document.getElementById('questionText').value = '';
  document.getElementById('optionA').value = '';
  document.getElementById('optionB').value = '';
  document.getElementById('optionC').value = '';
  document.getElementById('optionD').value = '';
  document.querySelectorAll('input[name="correctOption"]').forEach(r => r.checked = false);
}

function updateQuestionProgress() {
  const questionNumberLabel = document.getElementById('questionNumberLabel');
  const totalQuestionsLabel = document.getElementById('totalQuestionsLabel');
  const currentQuestionNum = document.getElementById('currentQuestionNum');
  const totalQuestions = document.getElementById('totalQuestions');
  const progressFill = document.getElementById('progressFill');
  
  const current = currentQuestionIndex + 1;
  
  if (questionNumberLabel) questionNumberLabel.textContent = current;
  if (totalQuestionsLabel) totalQuestionsLabel.textContent = numQuestions;
  if (currentQuestionNum) currentQuestionNum.textContent = current;
  if (totalQuestions) totalQuestions.textContent = numQuestions;
  
  if (progressFill) {
    const percentage = (current / numQuestions) * 100;
    progressFill.style.width = `${percentage}%`;
  }
}

function showSection(section) {
  const configSection = document.querySelector('.test-config-section');
  const questionSection = document.getElementById('questionEntrySection');
  const reviewSection = document.getElementById('reviewSection');
  
  // Hide all sections
  if (configSection) configSection.style.display = 'none';
  if (questionSection) questionSection.style.display = 'none';
  if (reviewSection) reviewSection.style.display = 'none';
  
  // Show selected section
  if (section === 'config') {
    if (configSection) configSection.style.display = 'block';
  } else if (section === 'questionEntry') {
    if (questionSection) questionSection.style.display = 'block';
  } else if (section === 'review') {
    if (reviewSection) reviewSection.style.display = 'block';
  }
}

function displayReviewQuestions() {
  const reviewList = document.getElementById('reviewQuestionsList');
  if (!reviewList) return;
  
  reviewList.innerHTML = '';
  
  questionsArray.forEach((q, index) => {
    const questionDiv = document.createElement('div');
    questionDiv.className = 'review-question-card';
    questionDiv.innerHTML = `
      <div class="review-question-header">
        <h4 class="review-question-title">Question ${index + 1}</h4>
        <span class="review-question-badge">${index + 1}/${questionsArray.length}</span>
      </div>
      <div class="review-question-text">
        <strong>Q:</strong> ${q.question}
      </div>
      <div class="review-options-list">
        <div class="review-option ${q.correct === 'A' ? 'review-option-correct' : ''}">
          <span class="option-label">A)</span> ${q.options[0]}
          ${q.correct === 'A' ? '<span class="review-correct-check">✓</span>' : ''}
        </div>
        <div class="review-option ${q.correct === 'B' ? 'review-option-correct' : ''}">
          <span class="option-label">B)</span> ${q.options[1]}
          ${q.correct === 'B' ? '<span class="review-correct-check">✓</span>' : ''}
        </div>
        <div class="review-option ${q.correct === 'C' ? 'review-option-correct' : ''}">
          <span class="option-label">C)</span> ${q.options[2]}
          ${q.correct === 'C' ? '<span class="review-correct-check">✓</span>' : ''}
        </div>
        <div class="review-option ${q.correct === 'D' ? 'review-option-correct' : ''}">
          <span class="option-label">D)</span> ${q.options[3]}
          ${q.correct === 'D' ? '<span class="review-correct-check">✓</span>' : ''}
        </div>
      </div>
    `;
    reviewList.appendChild(questionDiv);
  });
}

function backToQuestions() {
  showSection('questionEntry');
}

async function submitAllQuestions() {
  try {
    // Validate that we have all required context
    if (!selectedCollegeName || !selectedBranchName || !selectedSemesterName) {
      showMessage('Missing context information. Please try again from the classes page.', 'error');
      return;
    }
    
    if (!questionsArray || questionsArray.length === 0) {
      showMessage('No questions to submit!', 'error');
      return;
    }
    
    const questionsToSubmit = questionsArray.map(q => ({
      college: selectedCollegeName,
      branch: selectedBranchName,
      semester: selectedSemesterName,
      subject: testSubject,
      question: q.question,
      options: q.options,
      correct: q.correct,
      test_name: testName,
      duration_minutes: testDuration
    }));
    
    // Save to questions table (this is where assigned tests are stored)
    const { error } = await supabaseQuestions.from('questions').insert(questionsToSubmit);
    
    if (error) {
      throw error;
    }
    
    showMessage('All questions submitted successfully!', 'success');
    
    // Redirect back after a delay
    setTimeout(() => {
      if (isClassContext) {
        window.location.href = 'attendance.html';
      } else {
        window.location.href = 'dashboard.html';
      }
    }, 2000);
    
  } catch (error) {
    console.error('Error submitting questions:', error);
    showMessage('Failed to submit questions: ' + (error.message || error), 'error');
  }
}

function showMessage(text, type) {
  const msg = document.getElementById('questionMsg');
  if (!msg) {
    // Fallback to alert if message element not found
    alert(text);
    return;
  }
  
  msg.textContent = text;
  msg.className = 'message ' + type + ' show';
  
  setTimeout(() => {
    msg.classList.remove('show');
  }, 4000);
}