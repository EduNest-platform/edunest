// Main Supabase client for colleges/branches/semesters
const SUPABASE_MAIN_URL = 'https://vpjzxhfrqyspcbgmwqjd.supabase.co';
const SUPABASE_MAIN_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZwanp4aGZycXlzcGNiZ213cWpkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTExMDQ5NzIsImV4cCI6MjA2NjY4MDk3Mn0.x9dnZg6gvSUWVfuL4-CB6dKUY6sESE1xyM_v9Wmv4Tc';
const supabaseMain = window.supabaseMain = window.supabase.createClient(SUPABASE_MAIN_URL, SUPABASE_MAIN_KEY, {
  auth: { storageKey: 'supabase.main' }
});

// Questions Supabase client (already present)
const SUPABASE_QUESTIONS_URL = 'https://pfuzvpihupvhjshxiofn.supabase.co';
const SUPABASE_QUESTIONS_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBmdXp2cGlodXB2aGpzaHhpb2ZuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE1Mjg1MjIsImV4cCI6MjA2NzEwNDUyMn0.WAPJG6iaxuCAM75yCRu6UOcck37XuilVoDJK3uwyx-k';
const supabaseQuestions = window.supabaseQuestions = window.supabase.createClient(SUPABASE_QUESTIONS_URL, SUPABASE_QUESTIONS_KEY, {
  auth: { storageKey: 'supabase.questions' }
});

let selectedCollegeId = null;
let selectedBranchId = null;
let selectedSemesterId = null;
let selectedCollegeName = null;
let selectedBranchName = null;
let selectedSemesterName = null;
let numQuestions = 0;
let currentQuestionIndex = 0;
let questionsArray = [];
let testName = '';
let testSubject = '';
let testDuration = 30;

function showStep(step) {
  document.getElementById('contextModal').style.display = step === 1 ? 'flex' : 'none';
  document.getElementById('questionSetModal').style.display = step === 2 ? 'flex' : 'none';
  document.getElementById('reviewModal').style.display = step === 4 ? 'flex' : 'none';
  document.getElementById('questionForm').style.display = step === 3 ? 'block' : 'none';
  const progress = document.getElementById('questionSetProgress');
  if (progress) progress.style.display = step === 3 ? 'block' : 'none';
}

function updateProgress() {
  const label = document.getElementById('questionNumberLabel');
  if (label) {
    label.textContent = currentQuestionIndex + 1;
  }
}

function clearForm() {
  document.getElementById('questionText').value = '';
  document.getElementById('optionA').value = '';
  document.getElementById('optionB').value = '';
  document.getElementById('optionC').value = '';
  document.getElementById('optionD').value = '';
  document.querySelectorAll('input[name="correctOption"]').forEach(r => r.checked = false);
}

function fillForm(q) {
  document.getElementById('questionText').value = q.question || '';
  document.getElementById('optionA').value = q.options?.[0] || '';
  document.getElementById('optionB').value = q.options?.[1] || '';
  document.getElementById('optionC').value = q.options?.[2] || '';
  document.getElementById('optionD').value = q.options?.[3] || '';
  if (q.correct) {
    document.getElementById(`option${q.correct}_radio`).checked = true;
  } else {
    document.querySelectorAll('input[name="correctOption"]').forEach(r => r.checked = false);
  }
}

async function populateSubjectDropdown() {

  const subjectSelect = document.getElementById('subjectInput');
  // Remove all except the first option
  while (subjectSelect.options.length > 1) subjectSelect.remove(1);
  if (!selectedSemesterId) return;
  try {
    const { data: subjects, error } = await supabaseMain
      .from('subjects')
      .select('name')
      .eq('semester_id', selectedSemesterId);

    if (error) throw error;
    if (subjects && subjects.length > 0) {
      const uniqueNames = Array.from(new Set(subjects.map(subj => subj.name)));

      uniqueNames.forEach(name => {
        const opt = document.createElement('option');
        opt.value = name;
        opt.textContent = name;
        subjectSelect.appendChild(opt);
      });
    } else {

    }
  } catch (e) {
    console.error('Error fetching subjects:', e);
  }
}

document.addEventListener('DOMContentLoaded', async function() {
  const form = document.getElementById('questionForm');
  const msg = document.getElementById('questionMsg');
  const contextModal = document.getElementById('contextModal');
  const contextContinueBtn = document.getElementById('contextContinueBtn');
  const collegeSelect = document.getElementById('collegeSelect');
  const branchSelect = document.getElementById('branchSelect');
  const semesterSelect = document.getElementById('semesterSelect');

  // Show modal and prevent scroll
  contextModal.style.display = 'flex';
  document.body.classList.add('modal-open');
  form.style.display = 'none';

  // Populate colleges (id, name)
  try {
    const { data: colleges, error: collegeError } = await supabaseMain.from('colleges').select('id, name');
    if (collegeError) throw collegeError;
    colleges?.forEach(college => {
      const opt = document.createElement('option');
      opt.value = college.id;
      opt.textContent = college.name;
      opt.dataset.name = college.name;
      collegeSelect.appendChild(opt);
    });
  } catch (e) {
    showMessage('Failed to load colleges', 'error');
  }

  // Dependent dropdowns logic
  collegeSelect.addEventListener('change', async function() {
    branchSelect.innerHTML = '<option value="">Select Branch</option>';
    semesterSelect.innerHTML = '<option value="">Select Semester</option>';
    const selectedCollege = collegeSelect.value;
    if (!selectedCollege) return;
    // Fetch branches for selected college
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
        opt.dataset.name = branch.name;
        branchSelect.appendChild(opt);
      });
    } catch (e) {
      showMessage('Failed to load branches', 'error');
    }
  });

  branchSelect.addEventListener('change', async function() {
    semesterSelect.innerHTML = '<option value="">Select Semester</option>';
    const selectedBranch = branchSelect.value;
    if (!selectedBranch) return;
    // Fetch semesters for selected branch
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
        opt.dataset.name = sem.name;
        semesterSelect.appendChild(opt);
      });
    } catch (e) {
      showMessage('Failed to load semesters', 'error');
    }
  });

  contextContinueBtn.onclick = function() {
    const collegeId = collegeSelect.value;
    const branchId = branchSelect.value;
    const semesterId = semesterSelect.value;
    if (!collegeId || !branchId || !semesterId) {
      showMessage('Please select college, branch, and semester.', 'error');
      return;
    }
    selectedCollegeId = collegeId;
    selectedBranchId = branchId;
    selectedSemesterId = semesterId;
    selectedCollegeName = collegeSelect.options[collegeSelect.selectedIndex].textContent;
    selectedBranchName = branchSelect.options[branchSelect.selectedIndex].textContent;
    selectedSemesterName = semesterSelect.options[semesterSelect.selectedIndex].textContent;
    updateContextDisplay();
    populateSubjectDropdown();
    showStep(2); // Now go to number of questions
  };

  form.addEventListener('submit', async function(e) {
    e.preventDefault();
    // Use selected context
    const college = selectedCollegeName;
    const branch = selectedBranchName;
    const semester = selectedSemesterName;
    const question = document.getElementById('questionText').value.trim();
    const optionA = document.getElementById('optionA').value.trim();
    const optionB = document.getElementById('optionB').value.trim();
    const optionC = document.getElementById('optionC').value.trim();
    const optionD = document.getElementById('optionD').value.trim();
    const correct = document.querySelector('input[name="correctOption"]:checked');

    // Validate
    if (!college || !branch || !semester || !question || !optionA || !optionB || !optionC || !optionD || !correct) {
      showMessage('Please fill in all fields and select the correct answer.', 'error');
      return;
    }

    // Prepare data
    const data = {
      college,
      branch,
      semester,
      question,
      options: [optionA, optionB, optionC, optionD],
      correct: correct.value
    };
    // Save to Supabase questions project
    const { error } = await supabaseQuestions.from('questions').insert([data]);
    if (error) {
      showMessage('Failed to add question: ' + (error.message || error), 'error');
    } else {
      showMessage('Question added successfully!', 'success');
      form.reset();
    }
  });

  function showMessage(text, type) {
    msg.textContent = text;
    msg.className = 'message ' + type + ' show';
    setTimeout(() => {
      msg.classList.remove('show');
    }, 4000);
  }

  function updateContextDisplay() {
    const collegeSpan = document.getElementById('contextCollege');
    const branchSpan = document.getElementById('contextBranch');
    const semesterSpan = document.getElementById('contextSemester');
    if (selectedCollegeName && selectedBranchName && selectedSemesterName) {
      collegeSpan.textContent = selectedCollegeName;
      branchSpan.textContent = selectedBranchName;
      semesterSpan.textContent = selectedSemesterName;
    } else {
      collegeSpan.textContent = 'College';
      branchSpan.textContent = 'Branch';
      semesterSpan.textContent = 'Semester';
    }
  }

  // Step 2: Set test name and number of questions
  document.getElementById('questionSetContinueBtn').onclick = function() {
    const name = document.getElementById('testNameInput').value.trim();
    const subject = document.getElementById('subjectInput').value;
    const duration = parseInt(document.getElementById('testDurationInput').value, 10);
    if (!name) {
      alert('Please enter a test name.');
      return;
    }
    const n = parseInt(document.getElementById('numQuestionsInput').value, 10);
    if (!n || n < 1 || n > 50) {
      alert('Please enter a valid number of questions (1-50).');
      return;
    }
    if (!duration || duration < 1 || duration > 300) {
      alert('Please enter a valid test duration (1-300 minutes).');
      return;
    }
    testName = name;
    testSubject = subject;
    testDuration = duration;
    numQuestions = n;
    questionsArray = Array(numQuestions).fill(null).map(() => ({
      college: selectedCollegeName,
      branch: selectedBranchName,
      semester: selectedSemesterName,
      subject: testSubject,
      duration_minutes: testDuration,
      question: '', options: ['', '', '', ''], correct: ''
    }));
    currentQuestionIndex = 0;
    fillForm(questionsArray[0]);
    updateProgress();
    showStep(3); // Show first question form
    document.getElementById('questionMsg').textContent = '';
  };

  // Add Next/Previous/Review buttons to form
  let navBtns = document.createElement('div');
  navBtns.id = 'questionNavBtns';
  navBtns.style = 'display:flex;justify-content:space-between;gap:12px;margin:18px 0;';
  navBtns.innerHTML = `
    <button type="button" id="prevQuestionBtn" class="submit-btn" style="background:#e0e7ef;color:#334155;">Previous</button>
    <button type="button" id="nextQuestionBtn" class="submit-btn">Next</button>
    <button type="button" id="reviewBtn" class="submit-btn" style="display:none;">Review</button>
  `;
  form.appendChild(navBtns);

  function saveCurrentForm() {
    const question = document.getElementById('questionText').value.trim();
    const optionA = document.getElementById('optionA').value.trim();
    const optionB = document.getElementById('optionB').value.trim();
    const optionC = document.getElementById('optionC').value.trim();
    const optionD = document.getElementById('optionD').value.trim();
    const correct = document.querySelector('input[name="correctOption"]:checked');
    questionsArray[currentQuestionIndex] = {
      college: selectedCollegeName,
      branch: selectedBranchName,
      semester: selectedSemesterName,
      question,
      options: [optionA, optionB, optionC, optionD],
      correct: correct ? correct.value : ''
    };
  }

  document.getElementById('prevQuestionBtn').onclick = function() {
    saveCurrentForm();
    if (currentQuestionIndex > 0) {
      currentQuestionIndex--;
      fillForm(questionsArray[currentQuestionIndex]);
      updateProgress();
      document.getElementById('nextQuestionBtn').style.display = '';
      document.getElementById('reviewBtn').style.display = 'none';
    }
    if (currentQuestionIndex === 0) {
      this.disabled = true;
    }
    document.getElementById('nextQuestionBtn').disabled = false;
  };
  document.getElementById('nextQuestionBtn').onclick = function() {
    saveCurrentForm();
    if (!validateForm()) return;
    if (numQuestions === 1) {
      showReview();
      return;
    }
    if (currentQuestionIndex < numQuestions - 1) {
      currentQuestionIndex++;
      fillForm(questionsArray[currentQuestionIndex]);
      updateProgress();
      document.getElementById('prevQuestionBtn').disabled = false;
      if (currentQuestionIndex === numQuestions - 1) {
        this.style.display = 'none';
        document.getElementById('reviewBtn').style.display = '';
      }
    }
  };
  document.getElementById('reviewBtn').onclick = function() {
    saveCurrentForm();
    if (!validateForm()) return;
    showReview();
  };
  function validateForm() {
    const question = document.getElementById('questionText').value.trim();
    const optionA = document.getElementById('optionA').value.trim();
    const optionB = document.getElementById('optionB').value.trim();
    const optionC = document.getElementById('optionC').value.trim();
    const optionD = document.getElementById('optionD').value.trim();
    const correct = document.querySelector('input[name="correctOption"]:checked');
    if (!question || !optionA || !optionB || !optionC || !optionD || !correct) {
      showMessage('Please fill in all fields and select the correct answer.', 'error');
      return false;
    }
    return true;
  }
  function showReview() {
    showStep(4);
    // Render review list
    const reviewList = document.getElementById('reviewQuestionsList');
    reviewList.innerHTML = '';
    questionsArray.forEach((q, i) => {
      const div = document.createElement('div');
      div.className = 'review-question-card';
      let optionsHtml = '';
      ['A', 'B', 'C', 'D'].forEach((opt, idx) => {
        const isCorrect = q.correct === opt;
        optionsHtml += `<div class="review-option${isCorrect ? ' review-option-correct' : ''}">${opt}: ${q.options[idx] || ''}${isCorrect ? ' <span class=\'review-correct-check\'>✔</span>' : ''}</div>`;
      });
      div.innerHTML = `
        <div class="review-question-title">Q${i+1}: ${q.question}</div>
        <div class="review-options-list">${optionsHtml}</div>
        <button type="button" class="review-edit-btn editReviewBtn" data-index="${i}">Edit</button>
      `;
      reviewList.appendChild(div);
    });
    // Add edit handlers
    document.querySelectorAll('.editReviewBtn').forEach(btn => {
      btn.onclick = function() {
        const idx = parseInt(this.getAttribute('data-index'), 10);
        currentQuestionIndex = idx;
        fillForm(questionsArray[idx]);
        updateProgress();
        showStep(3);
        document.getElementById('prevQuestionBtn').disabled = idx === 0;
        document.getElementById('nextQuestionBtn').style.display = idx === numQuestions - 1 ? 'none' : '';
        document.getElementById('reviewBtn').style.display = idx === numQuestions - 1 ? '' : 'none';
      };
    });
  }
  document.getElementById('reviewBackBtn').onclick = function() {
    showStep(3);
    fillForm(questionsArray[currentQuestionIndex]);
    updateProgress();
  };
  document.getElementById('submitAllBtn').onclick = async function() {
    // Final validation
    for (let i = 0; i < questionsArray.length; i++) {
      const q = questionsArray[i];
      if (!q.question || !q.options[0] || !q.options[1] || !q.options[2] || !q.options[3] || !q.correct) {
        alert(`Question ${i+1} is incomplete.`);
        return;
      }
    }
    // Add test_name, subject, and duration to each question and insert all
    const questionsToInsert = questionsArray.map(q => ({
      ...q,
      test_name: testName,
      subject: testSubject,
      duration_minutes: testDuration
    }));
    const { error } = await supabaseQuestions.from('questions').insert(questionsToInsert);
    if (error) {
      alert('Failed to add questions: ' + (error.message || error));
    } else {
      alert('All questions added successfully!');
      window.location.href = 'dashboard.html';
    }
  };

  // If only 1 question, after filling and validating, go directly to review
  if (numQuestions === 1) {
    document.getElementById('nextQuestionBtn').style.display = 'none';
    document.getElementById('reviewBtn').style.display = '';
  }

  // Start at step 1
  showStep(1);
}); 