// topics.js - Modern, robust topic management for EduNest Admin

let subjectId = null;
let subjectName = '';

// Utility: Get query param
function getQueryParam(name) {
  const url = new URL(window.location.href);
  return url.searchParams.get(name);
}

window.addEventListener('DOMContentLoaded', async () => {
  subjectId = getQueryParam('subject_id') || sessionStorage.getItem('selectedSubjectId');
  subjectName = getQueryParam('subject_name') || sessionStorage.getItem('selectedSubjectName') || '';
  if (!subjectId) {
    alert('No subject selected.');
    window.location.href = 'subjects.html';
    return;
  }
  sessionStorage.setItem('selectedSubjectId', subjectId);
  if (subjectName) sessionStorage.setItem('selectedSubjectName', subjectName);
  // Set the subject name in the context card
  if (subjectName) {
    const el = document.getElementById('contextSubject');
    if (el) el.textContent = subjectName;
  }
  // Add message area if not present
  if (!document.getElementById('msgArea')) {
    const msgDiv = document.createElement('div');
    msgDiv.id = 'msgArea';
    msgDiv.style = 'margin: 0 auto 18px auto; max-width: 700px; text-align: center; font-weight: 600; font-size: 1.05em;';
    document.body.insertBefore(msgDiv, document.body.querySelector('main'));
  }
  await loadTopics();
  const form = document.getElementById('addTopicForm');
  if (form) form.addEventListener('submit', addTopic);
});

async function loadTopics() {
  showLoading(true);
  const topicsList = document.getElementById('topicsList');
  const emptyState = document.getElementById('emptyState');
  topicsList.innerHTML = '';
  emptyState.classList.add('hidden');
  const topicEmojis = ['📘','📗','📙','📕','📓','📔','📚'];

  // --- Retry logic for Supabase client initialization ---
  let attempts = 0;
  const maxAttempts = 8;
  const attemptLoad = async () => {
    try {
      if (!window.supabaseClient) {
        if (attempts < maxAttempts) {
          attempts++;
          setTimeout(attemptLoad, 400);
          return;
        } else {
          throw new Error('Supabase client not initialized after multiple attempts');
        }
      }
      const { data: topics, error } = await window.supabaseClient
        .from('topics')
        .select('*')
        .eq('subject_id', subjectId)
        .order('created_at');
      if (error) throw error;
      if (!topics || topics.length === 0) {
        emptyState.classList.remove('hidden');
        return;
      }
      topics.forEach((topic, idx) => {
        const emoji = topicEmojis[idx % topicEmojis.length];
        const card = document.createElement('div');
        card.className = 'topic-card';
        card.innerHTML = `
          <div class="topic-card-header-row">
            <span class="topic-card-emoji" aria-label="Topic">${emoji}</span>
            <div class="topic-card-header-texts">
              <div class="topic-card-title">${escapeHtml(topic.name)}</div>
              <div class="topic-card-meta">${topic.created_at ? formatDate(topic.created_at) : ''}</div>
            </div>
          </div>
          <div class="topic-card-actions">
            <button class="add-question-btn" title="Add Question" aria-label="Add Question"><span style="font-size:1.1em;">➕</span> Add Question</button>
            <button class="delete-btn" title="Delete Topic" aria-label="Delete Topic"><span style="font-size:1.1em;">🗑️</span></button>
          </div>
        `;
        card.querySelector('.add-question-btn').onclick = () => editTopic(topic.id, topic.name);
        card.querySelector('.delete-btn').onclick = () => deleteTopic(topic.id, topic.name);
        topicsList.appendChild(card);
      });
    } catch (e) {
      showMsg('Failed to load topics: ' + (e.message || e), 'error', 4000);
    } finally {
      showLoading(false);
    }
  };
  attemptLoad();
}

function showMsg(msg, type = 'info', timeout = 2200) {
  // Remove any existing popup
  let popup = document.getElementById('popupMsgArea');
  if (popup) popup.remove();
  popup = document.createElement('div');
  popup.id = 'popupMsgArea';
  popup.className = `message ${type} show`;
  popup.style.position = 'fixed';
  popup.style.top = '32px';
  popup.style.left = '50%';
  popup.style.transform = 'translateX(-50%)';
  popup.style.zIndex = '9999';
  popup.style.maxWidth = '90vw';
  popup.style.boxShadow = '0 4px 24px rgba(99,102,241,0.13)';
  popup.setAttribute('aria-live', 'polite');
  popup.textContent = msg;
  document.body.appendChild(popup);
  if (type === 'success') {
    popup.classList.add('animated-success');
    setTimeout(() => { popup.classList.remove('animated-success'); }, 800);
  }
  if (timeout) setTimeout(() => { popup.classList.remove('show'); popup.remove(); }, timeout);
}

async function addTopic(e) {
  e.preventDefault();
  const input = document.getElementById('topicNameInput');
  const btn = document.querySelector('#addTopicForm .submit-btn');
  const name = input.value.trim();
  if (!name) {
    showMsg('Please enter a topic name.', 'error', 2000);
    return;
  }
  btn.disabled = true;
  const origText = btn.textContent;
  btn.textContent = 'Adding...';
  try {
    const { error } = await window.supabaseClient
      .from('topics')
      .insert({ subject_id: subjectId, name });
    if (error) throw error;
    input.value = '';
    showMsg('Topic added!', 'success');
    await loadTopics();
  } catch (e) {
    showMsg('Failed to add topic: ' + (e.message || e), 'error', 4000);
  } finally {
    btn.disabled = false;
    btn.textContent = origText;
  }
}

window.editTopic = function(topicId, topicName) {
  sessionStorage.setItem('selectedTopicId', topicId);
  sessionStorage.setItem('selectedTopicName', topicName);
  window.location.href = `topic_edit.html?topic_id=${topicId}`;
};

window.deleteTopic = async function(topicId, topicName) {
  if (!confirm(`Delete topic "${topicName}"? This cannot be undone.`)) return;
  try {
    const { error } = await window.supabaseClient
      .from('topics')
      .delete()
      .eq('id', topicId);
    if (error) throw error;
    showMsg('Topic deleted.', 'success');
    await loadTopics();
  } catch (e) {
    showMsg('Failed to delete topic: ' + (e.message || e), 'error', 4000);
  }
};

function showLoading(show) {
  const overlay = document.getElementById('loadingOverlay');
  if (overlay) overlay.classList.toggle('hidden', !show);
}

function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

// Utility: Format date as YYYY-MM-DD or locale string
function formatDate(dateStr) {
  if (!dateStr) return '';
  const d = new Date(dateStr);
  if (isNaN(d)) return dateStr;
  // You can customize the format as needed
  return d.toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' });
} 