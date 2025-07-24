// Colleges management for Super Admin

document.addEventListener('DOMContentLoaded', () => {
  if (!window.supabaseClient) {
    showMessage('Database connection error', true);
    return;
  }
  loadColleges();
});

async function loadColleges() {
  const list = document.getElementById('collegesList');
  list.innerHTML = 'Loading...';
  const { data, error } = await window.supabaseClient.from('colleges').select('*').order('name');
  if (error) {
    list.innerHTML = '<div class="error">Failed to load colleges.</div>';
    return;
  }
  if (!data || data.length === 0) {
    list.innerHTML = '<div style="color:#888;">No colleges found.</div>';
    return;
  }
  list.innerHTML = data.map(col => `
    <div class="college-card" id="college-${col.id}">
      <div class="college-title">${col.name}</div>
      <div class="college-desc">${col.description || ''}</div>
      <div class="college-actions">
        <button class="edit-btn" onclick="editCollegePrompt('${col.id}')">✏️ Edit</button>
        <button class="delete-btn" onclick="deleteCollege('${col.id}')">🗑️ Delete</button>
      </div>
    </div>
  `).join('');
}

async function addCollege(event) {
  event.preventDefault();
  const name = document.getElementById('collegeName').value.trim();
  const desc = document.getElementById('collegeDesc').value.trim();
  if (!name) {
    showMessage('Name is required.', true);
    return;
  }
  // Check for duplicate name
  const { data: existing } = await window.supabaseClient.from('colleges').select('id').eq('name', name);
  if (existing && existing.length > 0) {
    showMessage('A college with this name already exists.', true);
    return;
  }
  const { error } = await window.supabaseClient.from('colleges').insert({ name, description: desc });
  if (error) {
    showMessage('Failed to add college.', true);
    return;
  }
  showMessage('College added!', false);
  document.getElementById('collegeName').value = '';
  document.getElementById('collegeDesc').value = '';
  loadColleges();
}

function showMessage(msg, isError) {
  const el = document.getElementById('message');
  el.textContent = msg;
  el.className = 'message ' + (isError ? 'error' : 'success');
  setTimeout(() => { el.textContent = ''; }, 4000);
}

function editCollegePrompt(id) {
  const card = document.getElementById('college-' + id);
  if (!card) return;
  const title = card.querySelector('.college-title');
  const desc = card.querySelector('.college-desc');
  const oldName = title.textContent;
  const oldDesc = desc.textContent;
  // Simple prompt UI
  const newName = prompt('Edit college name:', oldName);
  if (newName === null) return;
  const newDesc = prompt('Edit description:', oldDesc);
  if (newDesc === null) return;
  updateCollege(id, newName.trim(), newDesc.trim());
}

async function updateCollege(id, name, description) {
  if (!name) {
    showMessage('Name is required.', true);
    return;
  }
  // Check for duplicate name (excluding self)
  const { data: existing } = await window.supabaseClient.from('colleges').select('id').eq('name', name).neq('id', id);
  if (existing && existing.length > 0) {
    showMessage('A college with this name already exists.', true);
    return;
  }
  const { error } = await window.supabaseClient.from('colleges').update({ name, description }).eq('id', id);
  if (error) {
    showMessage('Failed to update college.', true);
    return;
  }
  showMessage('College updated!', false);
  loadColleges();
}

async function deleteCollege(id) {
  if (!confirm('Are you sure you want to delete this college? This action cannot be undone.')) return;
  const { error } = await window.supabaseClient.from('colleges').delete().eq('id', id);
  if (error) {
    showMessage('Failed to delete college.', true);
    return;
  }
  showMessage('College deleted.', false);
  loadColleges();
} 