// topic_edit.js - Edit a topic and manage questions in EduNest Admin

let topicId = null;
let topicName = '';

function getQueryParam(name) {
  const url = new URL(window.location.href);
  return url.searchParams.get(name);
}

window.addEventListener('DOMContentLoaded', async () => {
  topicId = getQueryParam('topic_id') || sessionStorage.getItem('selectedTopicId');
  topicName = sessionStorage.getItem('selectedTopicName') || '';
  const subjectName = sessionStorage.getItem('selectedSubjectName') || '';
  if (!topicId) {
    alert('No topic selected.');
    window.location.href = 'topics.html';
    return;
  }
  // Set context card values
  if (subjectName) {
    document.getElementById('contextSubject').textContent = subjectName;
  }
  if (topicName) {
    document.getElementById('contextTopic').textContent = topicName;
    document.getElementById('topicNameDisplay').textContent = topicName;
  }
  // Topic name edit logic
  const editBtn = document.getElementById('editTopicNameBtn');
  const displaySpan = document.getElementById('topicNameDisplay');
  const editArea = document.getElementById('editTopicNameArea');
  const input = document.getElementById('topicNameInput');
  const saveBtn = document.getElementById('saveTopicNameBtn');
  const cancelBtn = document.getElementById('cancelTopicNameBtn');
  editBtn.onclick = () => {
    editArea.style.display = '';
    input.value = displaySpan.textContent;
    displaySpan.style.display = 'none';
    editBtn.style.display = 'none';
    input.focus();
  };
  cancelBtn.onclick = (e) => {
    e.preventDefault();
    editArea.style.display = 'none';
    displaySpan.style.display = '';
    editBtn.style.display = '';
  };
  saveBtn.onclick = async (e) => {
    e.preventDefault();
    const newName = input.value.trim();
    if (!newName) return;
    saveBtn.disabled = true;
    try {
      const { error } = await window.supabaseClient
        .from('topics')
        .update({ name: newName })
        .eq('id', topicId);
      if (error) throw error;
      topicName = newName;
      displaySpan.textContent = newName;
      document.getElementById('contextTopic').textContent = newName;
      sessionStorage.setItem('selectedTopicName', newName);
      showMsg('Topic name updated!', 'success');
      editArea.style.display = 'none';
      displaySpan.style.display = '';
      editBtn.style.display = '';
    } catch (e) {
      showMsg('Failed to update topic name: ' + e.message, 'error', 4000);
    } finally {
      saveBtn.disabled = false;
    }
  };
  // Add message area if not present
  if (!document.getElementById('msgArea')) {
    const msgDiv = document.createElement('div');
    msgDiv.id = 'msgArea';
    msgDiv.style = 'margin: 0 auto 18px auto; max-width: 700px; text-align: center; font-weight: 600; font-size: 1.05em;';
    document.body.insertBefore(msgDiv, document.body.querySelector('main'));
  }
  await loadTopic();
  await loadQuestions();
  document.getElementById('editTopicForm').addEventListener('submit', saveTopic);
  document.getElementById('generateQuestionsBtn').addEventListener('click', generateQuestions);
  document.getElementById('generateAllModesBtn').addEventListener('click', generateAllModes);
  await loadSavedDescriptions();
  await checkAllModesStatus();
});

function showMsg(msg, type = 'info', timeout = 2200) {
  // Remove any existing popup
  let popup = document.getElementById('popupMsgArea');
  if (popup) popup.remove();
  popup = document.createElement('div');
  popup.id = 'popupMsgArea';
  popup.className = `message ${type} show`;
  popup.setAttribute('aria-live', 'polite');
  document.body.appendChild(popup);
  popup.textContent = msg;
  if (type === 'success') {
    popup.classList.add('animated-success');
    setTimeout(() => { popup.classList.remove('animated-success'); }, 800);
  }
  if (timeout) setTimeout(() => { popup.classList.remove('show'); popup.remove(); }, timeout);
}

async function loadTopic() {
  showLoading(true);
  try {
    const { data: topic, error } = await window.supabaseClient
      .from('topics')
      .select('*')
      .eq('id', topicId)
      .single();
    if (error || !topic) throw error || new Error('Topic not found');
    document.getElementById('topicContentInput').value = topic.content || '';
    // Update topic name display if changed in DB
    if (topic.name) {
      document.getElementById('topicNameDisplay').textContent = topic.name;
      document.getElementById('contextTopic').textContent = topic.name;
      sessionStorage.setItem('selectedTopicName', topic.name);
    }
  } catch (e) {
    showMsg('Failed to load topic: ' + e.message, 'error', 4000);
    setTimeout(() => { window.location.href = 'topics.html'; }, 1200);
  } finally {
    showLoading(false);
  }
}

async function saveTopic(e) {
  e.preventDefault();
  const btn = document.querySelector('#editTopicForm .submit-btn');
  const content = document.getElementById('topicContentInput').value.trim();
  btn.disabled = true;
  const origText = btn.textContent;
  btn.textContent = 'Saving...';
  try {
    const { error } = await window.supabaseClient
      .from('topics')
      .update({ content })
      .eq('id', topicId);
    if (error) throw error;
    // Save to history
    if (content) {
      await window.supabaseClient
        .from('topic_description_history')
        .insert({ topic_id: topicId, description: content });
    }
    showMsg('Topic saved!', 'success');
    await loadTopic();
    await loadSavedDescriptions(); // Refresh history
  } catch (e) {
    showMsg('Failed to save topic: ' + e.message, 'error', 4000);
  } finally {
    btn.disabled = false;
    btn.textContent = origText;
  }
}

async function loadQuestions() {
  showLoading(true);
  const questionsCardsContainer = document.getElementById('questionsCardsContainer');
  const emptyState = document.getElementById('questionsEmptyState');
  questionsCardsContainer.innerHTML = '';
  emptyState.classList.add('hidden');
  
  try {
    const { data: questions, error } = await window.supabaseClient
      .from('questions')
      .select('*')
      .eq('topic_id', topicId)
      .order('created_at', { ascending: true });
      
    if (error) {
      throw error;
    }
    
    if (!questions || questions.length === 0) {
      emptyState.classList.remove('hidden');
      return;
    }
    
    // Group questions by practice_mode and question_count
    const questionsByGroup = {};
    questions.forEach((q, index) => {
      const practiceMode = q.practice_mode || q.difficulty || 'academic'; // Fallback for migration
      // Convert question_count to number, default to 0 if invalid
      const questionCount = parseInt(q.question_count) || 0;
      const groupKey = `${practiceMode}_${questionCount}`;
      
      if (!questionsByGroup[groupKey]) {
        questionsByGroup[groupKey] = {
          practiceMode,
          questionCount,
          questions: [],
          created_at: q.created_at
        };
      }
      questionsByGroup[groupKey].questions.push(q);
    });
    
    // Create cards for each group
    Object.keys(questionsByGroup).forEach(groupKey => {
      const group = questionsByGroup[groupKey];
      const card = createDifficultyCard(group);
      questionsCardsContainer.appendChild(card);
    });
    
  } catch (e) {
    showMsg('Failed to load questions: ' + e.message, 'error', 4000);
    emptyState.classList.remove('hidden');
  } finally {
    showLoading(false);
  }
}

function createDifficultyCard(group) {
  const card = document.createElement('div');
  card.className = `difficulty-card ${group.practiceMode}`;
  
  const practiceModeIcons = {
    'academic': '📚',
    'competitive': '🎯',
    'career': '💼',
    // Legacy support during migration
    'beginner': '📚',
    'intermediate': '🎯',
    'advanced': '💼',
    'unknown': '❓'
  };
  
  const practiceModeDescriptions = {
    'academic': 'University exam preparation - Core syllabus concepts',
    'competitive': 'GATE prep - Competitive exam style questions',
    'career': 'Interview & practical - Job preparation questions',
    // Legacy support during migration
    'beginner': 'Basic concepts and fundamental knowledge',
    'intermediate': 'Moderate complexity with practical applications',
    'advanced': 'Complex scenarios and deep understanding required',
    'unknown': 'Questions without specified mode'
  };
  
  const displayName = group.practiceMode === 'academic' ? 'Academic Mode' :
                    group.practiceMode === 'competitive' ? 'GATE Prep Mode' :
                    group.practiceMode === 'career' ? 'Career Prep Mode' :
                    group.practiceMode;

  card.innerHTML = `
    <div class="difficulty-card-header">
      <div class="difficulty-title">
        <span class="difficulty-icon">${practiceModeIcons[group.practiceMode]}</span>
        ${displayName}
      </div>
      <div class="question-count">${group.questions.length} Q</div>
    </div>
    <div class="difficulty-card-content">
      ${practiceModeDescriptions[group.practiceMode]}
      <br><small>Generated: ${new Date(group.created_at).toLocaleDateString()}</small>
    </div>
    <div class="difficulty-card-actions" style="margin-top: 12px; display: flex; gap: 8px;">
      <button class="card-action-btn" onclick="openQuestionsModal('${group.practiceMode}', ${group.questionCount})" 
              style="background: #6366f1; color: white; border: none; padding: 8px 12px; border-radius: 6px; cursor: pointer; font-size: 0.9em;">
        View Questions
      </button>
      <button class="card-action-btn" onclick="deleteQuestionGroup('${group.practiceMode}', ${group.questionCount})"
              style="background: #ef4444; color: white; border: none; padding: 8px 12px; border-radius: 6px; cursor: pointer; font-size: 0.9em;">
        Delete All
      </button>
    </div>
  `;
  
  return card;
}

// Modal functionality
window.openQuestionsModal = async function(difficulty, questionCount) {
  // Ensure questionCount is a number
  const questionCountNum = parseInt(questionCount) || 0;
  
  const modal = document.getElementById('questionsModal');
  const modalTitle = document.getElementById('modalTitle');
  const modalQuestionsList = document.getElementById('modalQuestionsList');
  
  modalTitle.textContent = `${difficulty.charAt(0).toUpperCase() + difficulty.slice(1)} Questions (${questionCountNum} Q)`;
  modalQuestionsList.innerHTML = '<div style="text-align: center; padding: 20px;">Loading questions...</div>';
  
  modal.classList.remove('hidden');
  
  try {
    const { data: questions, error } = await window.supabaseClient
      .from('questions')
      .select('*')
      .eq('topic_id', topicId)
      .eq('difficulty', difficulty)
      .eq('question_count', questionCountNum)
      .order('created_at', { ascending: true });
      
    if (error) throw error;
    
    modalQuestionsList.innerHTML = '';
    
    if (!questions || questions.length === 0) {
      modalQuestionsList.innerHTML = '<div style="text-align: center; padding: 20px; color: #6b7280;">No questions found.</div>';
      return;
    }
    
    questions.forEach((q, idx) => {
      const questionCard = document.createElement('div');
      questionCard.className = 'modal-question-card';
      
      // Format options with letters (A, B, C, D)
      let optionsText = 'No options available';
      let optionsArray = [];
      
      if (q.options) {
        if (Array.isArray(q.options)) {
          // Already an array
          optionsArray = q.options;
        } else if (typeof q.options === 'string') {
          // Parse JSON string
          try {
            const parsedOptions = JSON.parse(q.options);
            if (Array.isArray(parsedOptions)) {
              optionsArray = parsedOptions;
            } else {
              optionsText = `Invalid options format`;
            }
          } catch (e) {
            optionsText = `Failed to parse options`;
          }
        } else {
          optionsText = `Unexpected options format`;
        }
        
        // Format the options array if we have one
        if (optionsArray.length > 0) {
          optionsText = optionsArray.map((opt, optIdx) => {
            const letter = String.fromCharCode(65 + optIdx);
            const escaped = escapeHtml(opt);
            return `${letter}. ${escaped}`;
          }).join('<br>');
        }
      }

      // Get correct answer text
      let correctAnswerText = 'Not specified';
      if (typeof q.correctanswer === 'number' && optionsArray.length > 0) {
        if (optionsArray[q.correctanswer]) {
          correctAnswerText = escapeHtml(optionsArray[q.correctanswer]);
        } else {
          correctAnswerText = `Answer index: ${q.correctanswer} (out of range)`;
        }
      } else if (q.correctanswer !== undefined) {
        correctAnswerText = `Answer: ${q.correctanswer} (type: ${typeof q.correctanswer})`;
      }
      
      questionCard.innerHTML = `
        <div class="modal-question-text">
          <strong>Q${idx + 1}:</strong> ${escapeHtml(q.question)}
        </div>
        <div class="modal-question-options" style="margin: 10px 0; padding: 10px; background: #f9fafb; border-radius: 6px;">
          <strong>Options:</strong><br>
          <div style="margin-top: 8px; line-height: 1.6;">
            ${optionsText}
          </div>
        </div>
        <div class="modal-question-answer" style="margin: 10px 0; padding: 8px; background: #ecfdf5; border-radius: 6px;">
          <strong>Correct Answer:</strong> ${correctAnswerText}
        </div>
        <div class="modal-question-actions">
          <button class="modal-edit-btn" onclick="editQuestion('${q.id}')">Edit</button>
          <button class="modal-delete-btn" onclick="deleteQuestion('${q.id}')">Delete</button>
        </div>
      `;
      
      modalQuestionsList.appendChild(questionCard);
    });
    
  } catch (e) {
    modalQuestionsList.innerHTML = '<div style="text-align: center; padding: 20px; color: #dc2626;">Failed to load questions.</div>';
  }
};

// Close modal functionality
document.addEventListener('DOMContentLoaded', function() {
  const modal = document.getElementById('questionsModal');
  const closeBtn = document.getElementById('closeModalBtn');
  const overlay = modal.querySelector('.modal-overlay');
  
  function closeModal() {
    modal.classList.add('hidden');
  }
  
  closeBtn.addEventListener('click', closeModal);
  overlay.addEventListener('click', closeModal);
  
  // Close on Escape key
  document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape' && !modal.classList.contains('hidden')) {
      closeModal();
    }
  });
});

window.deleteQuestionGroup = async function(difficulty, questionCount) {
  // Ensure questionCount is a number
  const questionCountNum = parseInt(questionCount) || 0;
  
  if (!confirm(`Delete all ${difficulty} questions (${questionCountNum} Q)?`)) return;
  
  try {
    // First try with the specific question_count
    let { error } = await window.supabaseClient
      .from('questions')
      .delete()
      .eq('topic_id', topicId)
      .eq('difficulty', difficulty)
      .eq('question_count', questionCountNum);
      
    if (error) {
      // Fallback: delete all questions for this topic and difficulty regardless of question_count
      const { error: fallbackError } = await window.supabaseClient
        .from('questions')
        .delete()
        .eq('topic_id', topicId)
        .eq('difficulty', difficulty);
        
      if (fallbackError) throw fallbackError;
    }
    
    showMsg(`Deleted all ${difficulty} questions.`, 'success');
    await loadQuestions(); // Refresh the cards
    
    // Close modal if open
    const modal = document.getElementById('questionsModal');
    if (!modal.classList.contains('hidden')) {
      modal.classList.add('hidden');
    }
    
  } catch (e) {
    showMsg('Failed to delete questions: ' + e.message, 'error', 4000);
  }
};

window.editQuestion = function(questionId) {
  showMsg('Edit question feature coming soon!', 'info', 2000);
};

window.deleteQuestion = async function(questionId) {
  if (!confirm('Delete this question?')) return;
  try {
    const { error } = await window.supabaseClient
      .from('questions')
      .delete()
      .eq('id', questionId);
    if (error) throw error;
    showMsg('Question deleted.', 'success');
    await loadQuestions(); // Refresh the cards
    
    // If modal is open, refresh the modal content too
    const modal = document.getElementById('questionsModal');
    if (!modal.classList.contains('hidden')) {
      const modalTitle = document.getElementById('modalTitle');
      const titleText = modalTitle.textContent;
      const match = titleText.match(/(\w+)\s+Questions\s+\((\d+)\s+Q\)/);
      if (match) {
        const difficulty = match[1].toLowerCase();
        const questionCount = parseInt(match[2]);
        await openQuestionsModal(difficulty, questionCount);
      }
    }
  } catch (e) {
    showMsg('Failed to delete question: ' + e.message, 'error', 4000);
  }
};

async function generateQuestions() {
  showLoading(true);
  const btn = document.getElementById('generateQuestionsBtn');
  btn.disabled = true;
  try {
    // Get user selections
    const questionCount = parseInt(document.getElementById('questionCountSelect').value);
    const practiceMode = document.getElementById('practiceModeSelect').value;
    
    // Get the topic content first
    const { data: topic, error: topicError } = await window.supabaseClient
      .from('topics')
      .select('content, name')
      .eq('id', topicId)
      .single();
    
    if (topicError || !topic) {
      throw new Error('Failed to load topic content');
    }
    
    if (!topic.content || topic.content.trim().length < 10) {
      showMsg('Please add some content to the topic first (at least 10 characters).', 'error', 4000);
      return;
    }
    
    // Try multiple Edge Function URLs in case of deployment issues
    const edgeFunctionUrls = [
      'https://vpjzxhfrqyspcbgmwqjd.supabase.co/functions/v1/generate-topic-questions',
      'https://vpjzxhfrqyspcbgmwqjd.functions.supabase.co/generate-topic-questions'
    ];
    
    // Get the Supabase key
    const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZwanp4aGZycXlzcGNiZ213cWpkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTExMDQ5NzIsImV4cCI6MjA2NjY4MDk3Mn0.x9dnZg6gvSUWVfuL4-CB6dKUY6sESE1xyM_v9Wmv4Tc';
    
    let response = null;
    let lastError = null;
    
    // Try each URL
    for (const edgeFunctionUrl of edgeFunctionUrls) {
      try {
        response = await fetch(edgeFunctionUrl, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${supabaseKey}`,
            'apikey': supabaseKey
          },
          body: JSON.stringify({ 
            topic_id: topicId,
            topic_content: topic.content,
            topic_name: topic.name,
            question_count: questionCount,
            difficulty_level: 'intermediate', // Keep for AI prompt compatibility
            practice_mode: practiceMode
          })
        });
        
        if (response.ok) {
          break; // Success, exit the loop
        } else {
          const errorText = await response.text();
          lastError = `Status ${response.status}: ${errorText}`;
        }
      } catch (e) {
        lastError = e.message;
        continue; // Try next URL
      }
    }
    
    if (!response || !response.ok) {
      throw new Error(`All Edge Function URLs failed. Last error: ${lastError}`);
    }
    
    const result = await response.json();
    
    if (!result.questions || !Array.isArray(result.questions)) {
      throw new Error('No questions returned by AI or invalid response format');
    }
    
    showGeneratedQuestionsModal(result.questions, result.gate_note);
    const displayName = practiceMode === 'academic' ? 'Academic Mode' :
                       practiceMode === 'competitive' ? 'GATE Prep Mode' :
                       practiceMode === 'career' ? 'Career Prep Mode' : practiceMode;
    showMsg(`AI generated ${result.questions.length} ${displayName} questions! Review and save as needed.`, 'success', 4000);
    
  } catch (e) {
    // Provide more specific error messages
    let errorMessage = 'Failed to generate questions: ';
    if (e.message.includes('Failed to fetch')) {
      errorMessage += 'Network error. The AI service may be temporarily unavailable.';
    } else if (e.message.includes('Edge Function')) {
      errorMessage += 'AI service error. Please try again later.';
    } else if (e.message.includes('CORS')) {
      errorMessage += 'Cross-origin request blocked. Please contact support.';
    } else if (e.message.includes('All Edge Function URLs failed')) {
      errorMessage += 'AI service is currently unavailable. Please try again later.';
    } else {
      errorMessage += e.message;
    }
    
    showMsg(errorMessage, 'error', 5000);
  } finally {
    btn.disabled = false;
    showLoading(false);
  }
}

// Modal to review and insert generated questions
function showGeneratedQuestionsModal(questions, gateNote = null) {
  // Remove existing modal if present
  let modal = document.getElementById('aiQuestionsModal');
  if (modal) modal.remove();
  modal = document.createElement('div');
  modal.id = 'aiQuestionsModal';
  modal.style = 'position:fixed;top:0;left:0;width:100vw;height:100vh;background:rgba(30,41,59,0.18);z-index:20000;display:flex;align-items:center;justify-content:center;padding:20px;';
  modal.innerHTML = `
    <div style="background:#fff;border-radius:16px;box-shadow:0 8px 32px #6366f144;max-width:520px;width:96vw;max-height:90vh;display:flex;flex-direction:column;position:relative;">
      <div style="padding:28px 22px 18px 22px;border-bottom:1px solid #e5e7eb;">
        <h3 style="font-size:1.18em;font-weight:800;color:#6366f1;margin:0;">AI Generated Questions</h3>
        ${gateNote ? `<div style="margin-top:12px;padding:12px;background:#fff3cd;border:1px solid #ffeaa7;border-radius:8px;color:#856404;font-size:0.9em;"><strong>Note:</strong> ${gateNote}</div>` : ''}
      </div>
      <div id="aiQuestionsList" style="flex:1;overflow-y:auto;padding:20px 22px;display:flex;flex-direction:column;gap:18px;max-height:60vh;"></div>
      <div style="padding:18px 22px;border-top:1px solid #e5e7eb;background:#f8fafc;border-bottom-left-radius:16px;border-bottom-right-radius:16px;">
        <div style="display:flex;gap:12px;justify-content:flex-end;">
          <button id="insertAllQuestionsBtn" class="submit-btn" style="padding:8px 18px;">Insert All</button>
          <button id="closeAiQuestionsModal" class="submit-btn" style="background:#e5e7eb;color:#334155;">Close</button>
        </div>
      </div>
    </div>
  `;
  document.body.appendChild(modal);
  
  // Render questions
  const list = modal.querySelector('#aiQuestionsList');
  questions.forEach((q, idx) => {
    const qDiv = document.createElement('div');
    qDiv.style = 'background:#f8fafc;border-radius:10px;padding:14px 14px 10px 14px;box-shadow:0 1px 4px #6366f10a;border:1px solid #e5e7eb;';
    qDiv.innerHTML = `
      <div style="font-weight:700;color:#3730a3;margin-bottom:8px;font-size:1.05em;">Q${idx + 1}: ${escapeHtml(q.question)}</div>
      <div style="margin-bottom:6px;color:#4b5563;">
        <strong>Options:</strong><br>
        ${q.options.map((opt, optIdx) => `${String.fromCharCode(65 + optIdx)}. ${escapeHtml(opt)}`).join('<br>')}
      </div>
      <div style="color:#059669;font-size:0.97em;font-weight:600;">
        <strong>Correct Answer:</strong> ${typeof q.correctAnswer === 'number' ? escapeHtml(q.options[q.correctAnswer]) : 'Not specified'}
      </div>
    `;
    list.appendChild(qDiv);
  });
  
  // Insert all questions
  modal.querySelector('#insertAllQuestionsBtn').onclick = async () => {
    try {
      await insertGeneratedQuestions(questions);
      modal.remove();
      await loadQuestions();
      showMsg('Questions inserted!', 'success', 3000);
    } catch (error) {
      showMsg('Failed to insert questions: ' + error.message, 'error', 5000);
    }
  };
  
  // Close modal
  modal.querySelector('#closeAiQuestionsModal').onclick = () => {
    modal.remove();
  };
  
  // Close modal on background click
  modal.onclick = (e) => {
    if (e.target === modal) {
      modal.remove();
    }
  };
  
  // Close modal on Escape key
  document.addEventListener('keydown', function closeOnEscape(e) {
    if (e.key === 'Escape') {
      modal.remove();
      document.removeEventListener('keydown', closeOnEscape);
    }
  });
}

async function insertGeneratedQuestions(questions) {
  if (!questions || questions.length === 0) {
    showMsg('No questions to insert.', 'error', 3000);
    return;
  }

  // Get the selected question count and difficulty level
  const questionCount = parseInt(document.getElementById('questionCountSelect').value);
  const difficulty = document.getElementById('difficultySelect').value;
  
  // First, let's check the table structure
  try {
    const { data: sampleData, error: structureError } = await window.supabaseClient
      .from('questions')
      .select('*')
      .limit(1);
    
    if (structureError) {
      throw new Error('Cannot access questions table: ' + structureError.message);
    }
  } catch (e) {
    throw e;
  }
  
  // Check if questions with this combination already exist
  try {
    const { count: existingCount, error: countError } = await window.supabaseClient
      .from('questions')
      .select('*', { count: 'exact', head: true })
      .eq('topic_id', topicId)
      .eq('difficulty', difficulty)
      .eq('question_count', questionCount);
    
    if (countError) {
      console.error('[AI] Error checking existing questions:', countError);
    } else {
      // If we already have questions for this difficulty and count, ask user what to do
      if (existingCount > 0) {
        const shouldReplace = confirm(
          `You already have ${existingCount} ${difficulty} questions (${questionCount} Q) for this topic. ` +
          `Do you want to replace them with the new ${questionCount} questions?`
        );
        
        if (shouldReplace) {
          // Delete existing questions for this topic, difficulty, and question count
          const { error: deleteError } = await window.supabaseClient
            .from('questions')
            .delete()
            .eq('topic_id', topicId)
            .eq('difficulty', difficulty)
            .eq('question_count', questionCount);
          
          if (deleteError) {
            console.error('[AI] Error deleting existing questions:', deleteError);
            showMsg('Failed to replace existing questions: ' + deleteError.message, 'error', 4000);
            return;
          }
          
          console.debug('[AI] Deleted existing questions for replacement');
        } else {
          console.debug('[AI] User cancelled replacement');
          return;
        }
      }
    }
  } catch (e) {
    console.error('[AI] Error checking existing questions:', e);
  }
  
  // Prepare all questions for insertion (matching the actual table schema)
  const questionsToInsert = questions.map(q => {
    // Ensure options are stored as a proper array (Supabase will handle JSON serialization)
    let processedOptions = q.options;
    if (typeof q.options === 'string') {
      try {
        processedOptions = JSON.parse(q.options);
      } catch (e) {
        processedOptions = [q.options]; // Fallback to single option
      }
    }
    
    return {
      topic_id: topicId,
      question: q.question,
      options: processedOptions, // Let Supabase handle JSON serialization
      correctanswer: q.correctAnswer, // Match the database column name
      difficulty: difficulty,
      question_count: questionCount, // Store the question count for reference
      created_at: new Date().toISOString()
    };
  });

  try {
    // Insert all questions in a single batch operation
    const { data, error } = await window.supabaseClient
      .from('questions')
      .insert(questionsToInsert)
      .select();

    if (error) {
      throw error;
    }

    showMsg(`Successfully inserted ${questions.length} ${difficulty} questions!`, 'success', 3000);
    
  } catch (e) {
    // Try inserting one by one if batch insert fails
    console.debug('[AI] Trying individual insert as fallback...');
    let successCount = 0;
    
    for (const questionData of questionsToInsert) {
      try {
        const { data: singleData, error: singleError } = await window.supabaseClient
          .from('questions')
          .insert(questionData)
          .select();
        
        if (singleError) {
          console.error('[AI] Failed to insert single question:', singleError);
        } else {
          successCount++;
        }
      } catch (singleE) {
        console.error('[AI] Exception inserting single question:', singleE);
      }
    }
    
    if (successCount > 0) {
      showMsg(`Inserted ${successCount} out of ${questions.length} questions.`, 'warning', 4000);
    } else {
      showMsg('Failed to insert questions: ' + e.message, 'error', 5000);
    }
  }
}

function showLoading(show) {
  document.getElementById('loadingOverlay').classList.toggle('hidden', !show);
}

function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

async function loadSavedDescriptions() {
  const list = document.getElementById('savedDescriptionsList');
  list.innerHTML = '';
  try {
    const { data, error } = await window.supabaseClient
      .from('topic_description_history')
      .select('id, description, saved_at')
      .eq('topic_id', topicId)
      .order('saved_at', { ascending: false });
    if (error) throw error;
    if (!data || data.length === 0) {
      list.innerHTML = '<div style="color:#64748b;">No saved descriptions yet.</div>';
      return;
    }
    data.forEach(entry => {
      const div = document.createElement('div');
      div.className = 'saved-description-entry';
      // Split description into lines
      const lines = entry.description.split(/\r?\n/);
      const previewLines = lines.slice(0, 3).join('\n');
      const isLong = lines.length > 4;
      div.innerHTML = `
        <div class="saved-description-text" style="white-space:pre-line;word-break:break-word;">
          <span class="desc-preview">${escapeHtml(previewLines)}${isLong ? '\n...' : ''}</span>
          <span class="desc-full" style="display:none;">${escapeHtml(entry.description)}</span>
          ${isLong ? '<a href="#" class="desc-toggle" style="color:#6366f1;cursor:pointer;font-size:0.97em;">Show more</a>' : ''}
        </div>
        <div class="saved-description-date">${formatDate(entry.saved_at)}</div>
        <button class="replace-description-btn" type="button">Replace</button>
      `;
      // Toggle show more/less
      if (isLong) {
        const toggle = div.querySelector('.desc-toggle');
        const preview = div.querySelector('.desc-preview');
        const full = div.querySelector('.desc-full');
        let expanded = false;
        toggle.onclick = (e) => {
          e.preventDefault();
          expanded = !expanded;
          if (expanded) {
            preview.style.display = 'none';
            full.style.display = '';
            toggle.textContent = 'Show less';
          } else {
            preview.style.display = '';
            full.style.display = 'none';
            toggle.textContent = 'Show more';
          }
        };
      }
      div.querySelector('.replace-description-btn').onclick = () => {
        document.getElementById('topicContentInput').value = entry.description;
        showMsg('Description replaced. Don\'t forget to save!', 'success');
      };
      list.appendChild(div);
    });
  } catch (e) {
    list.innerHTML = '<div style="color:#dc2626;">Failed to load saved descriptions.</div>';
  }
}

function formatDate(timestamp) {
  const date = new Date(timestamp);
  return date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
}

// Generate 20 questions for all 3 practice modes
async function generateAllModes() {
  const btn = document.getElementById('generateAllModesBtn');
  const btnText = document.getElementById('generateAllModesText');
  const btnSubtext = document.getElementById('generateAllModesSubtext');
  
  btn.disabled = true;
  btnSubtext.style.display = 'none';
  
  const modes = [
    { mode: 'academic', name: 'Academic Mode' },
    { mode: 'competitive', name: 'Competitive Exam Mode' },
    { mode: 'career', name: 'Career Prep Mode' }
  ];
  
  let successCount = 0;
  let totalGenerated = 0;
  
  try {
    // Get the topic content first
    const { data: topic, error: topicError } = await window.supabaseClient
      .from('topics')
      .select('content, name')
      .eq('id', topicId)
      .single();
    
    if (topicError || !topic) {
      throw new Error('Failed to load topic content');
    }
    
    if (!topic.content || topic.content.trim().length < 10) {
      showMsg('Please add some content to the topic first (at least 10 characters).', 'error', 4000);
      return;
    }
    
    for (let i = 0; i < modes.length; i++) {
      const { mode, name } = modes[i];
      
      // Update progress
      btnText.textContent = `Generating ${name}... (${i + 1}/3)`;
      
      try {
        // Try multiple Edge Function URLs
        const edgeFunctionUrls = [
          'https://vpjzxhfrqyspcbgmwqjd.supabase.co/functions/v1/generate-topic-questions',
          'https://vpjzxhfrqyspcbgmwqjd.functions.supabase.co/generate-topic-questions'
        ];
        
        const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZwanp4aGZycXlzcGNiZ213cWpkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTExMDQ5NzIsImV4cCI6MjA2NjY4MDk3Mn0.x9dnZg6gvSUWVfuL4-CB6dKUY6sESE1xyM_v9Wmv4Tc';
        
        let response = null;
        let lastError = null;
        
        for (const edgeFunctionUrl of edgeFunctionUrls) {
          try {
            response = await fetch(edgeFunctionUrl, {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${supabaseKey}`,
                'apikey': supabaseKey
              },
              body: JSON.stringify({
                topic_id: topicId,
                topic_content: topic.content,
                topic_name: topic.name,
                question_count: 20,
                difficulty_level: 'intermediate',
                practice_mode: mode
              })
            });
            
            if (response.ok) {
              break;
            } else {
              const errorText = await response.text();
              lastError = `Status ${response.status}: ${errorText}`;
            }
          } catch (e) {
            lastError = e.message;
            continue;
          }
        }
        
        if (!response || !response.ok) {
          throw new Error(`Failed to generate ${name} questions: ${lastError}`);
        }
        
        const result = await response.json();
        
        if (result.questions && result.questions.length > 0) {
          // Auto-insert the questions
          const questionsToInsert = result.questions.map(q => ({
            topic_id: topicId,
            question: q.question,
            options: q.options,
            correctanswer: q.correctAnswer,
            practice_mode: mode,
            difficulty: 'intermediate',
            question_count: 20,
            created_at: new Date().toISOString()
          }));
          
          const { error: insertError } = await window.supabaseClient
            .from('questions')
            .insert(questionsToInsert);
          
          if (insertError) {
            console.error(`Error inserting ${name} questions:`, insertError);
          } else {
            successCount++;
            totalGenerated += result.questions.length;
          }
        }
      } catch (error) {
        console.error(`Error generating ${name} questions:`, error);
      }
      
      // Small delay between requests
      await new Promise(resolve => setTimeout(resolve, 1000));
    }
    
    // Show final result
    if (successCount === 3) {
      showMsg(`Successfully generated ${totalGenerated} questions across all practice modes!`, 'success', 4000);
      btnText.textContent = 'All Modes Complete!';
      setTimeout(() => {
        btnText.textContent = 'Generate 20 Questions for All Modes';
        btnSubtext.style.display = 'block';
        checkAllModesStatus();
      }, 2000);
    } else if (successCount > 0) {
      showMsg(`Generated questions for ${successCount}/3 modes. Total: ${totalGenerated} questions.`, 'warning', 4000);
      btnText.textContent = `Partial Success (${successCount}/3)`;
      setTimeout(() => {
        btnText.textContent = 'Generate 20 Questions for All Modes';
        btnSubtext.style.display = 'block';
        checkAllModesStatus();
      }, 2000);
    } else {
      showMsg('Failed to generate questions for any mode. Please try again.', 'error', 4000);
      btnText.textContent = 'Generation Failed';
      setTimeout(() => {
        btnText.textContent = 'Generate 20 Questions for All Modes';
        btnSubtext.style.display = 'block';
      }, 2000);
    }
    
    // Reload questions to show new content
    await loadQuestions();
    
  } catch (error) {
    console.error('Error in generateAllModes:', error);
    showMsg('Failed to generate questions: ' + (error.message || error), 'error', 4000);
    btnText.textContent = 'Generation Failed';
    setTimeout(() => {
      btnText.textContent = 'Generate 20 Questions for All Modes';
      btnSubtext.style.display = 'block';
    }, 2000);
  } finally {
    btn.disabled = false;
  }
}

// Check if all modes already have 20 questions and disable button if so
async function checkAllModesStatus() {
  const btn = document.getElementById('generateAllModesBtn');
  const btnText = document.getElementById('generateAllModesText');
  const btnSubtext = document.getElementById('generateAllModesSubtext');
  
  try {
    const modes = ['academic', 'competitive', 'career'];
    const modeCounts = {};
    
    for (const mode of modes) {
      const { count, error } = await window.supabaseClient
        .from('questions')
        .select('*', { count: 'exact', head: true })
        .eq('topic_id', topicId)
        .eq('practice_mode', mode);
      
      if (!error) {
        modeCounts[mode] = count || 0;
      }
    }
    
    const allModesComplete = modes.every(mode => modeCounts[mode] >= 20);
    
    if (allModesComplete) {
      btn.disabled = true;
      btnText.textContent = 'All Modes Complete';
      btnSubtext.textContent = `Academic: ${modeCounts.academic}, Competitive: ${modeCounts.competitive}, Career: ${modeCounts.career}`;
      btn.style.background = 'linear-gradient(135deg, #6b7280 0%, #4b5563 100%)';
    } else {
      btn.disabled = false;
      btnText.textContent = 'Generate 20 Questions for All Modes';
      btnSubtext.textContent = 'Creates 60 questions total (20 per mode)';
      btn.style.background = 'linear-gradient(135deg, #10b981 0%, #059669 100%)';
    }
  } catch (error) {
    console.error('Error checking all modes status:', error);
  }
}