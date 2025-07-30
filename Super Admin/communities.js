// Communities management for Super Admin

// Wait for window.supabaseAdmin to be initialized
async function waitForSupabaseAdmin() {
  let attempts = 0;
  while (!window.supabaseAdmin && attempts < 20) {
    await new Promise(res => setTimeout(res, 100));
    attempts++;
  }
  if (!window.supabaseAdmin) {
    throw new Error('Supabase Admin client failed to initialize.');
  }
}

document.addEventListener('DOMContentLoaded', async () => {
  if (!window.supabaseClient) {
    showMessage('Database connection error', true);
    return;
  }
  await loadCollegesDropdown();
  loadCommunities();
});

async function loadCollegesDropdown() {
  const select = document.getElementById('communityCollege');
  select.innerHTML = '<option value="">Loading colleges...</option>';
  const { data, error } = await window.supabaseClient.from('colleges').select('id, name').order('name');
  if (error || !data) {
    select.innerHTML = '<option value="">Failed to load colleges</option>';
    return;
  }
  select.innerHTML = '<option value="">Select College</option>' +
    data.map(col => `<option value="${col.id}">${col.name}</option>`).join('');
}

async function loadCommunities() {
  await waitForSupabaseAdmin();
  const list = document.getElementById('communitiesList');
  list.innerHTML = 'Loading...';
  const { data, error } = await window.supabaseAdmin
    .from('communities')
    .select('id, name, description')
    .order('id', { ascending: false });
  if (error) {
    list.innerHTML = '<div class="error">Failed to load communities.</div>';
    return;
  }
  if (!data || data.length === 0) {
    list.innerHTML = '<div style="color:#888;">No communities found.</div>';
    return;
  }
  list.innerHTML = data.map(com => `
    <div class="community-card" id="community-${com.id}">
      <div class="community-title">${com.name}</div>
      <div class="community-desc">${com.description || ''}</div>
      <div class="community-actions">
        <button class="edit-btn" onclick="editCommunityPrompt('${com.id}')">✏️ Edit</button>
        <button class="delete-btn" onclick="deleteCommunity('${com.id}')">🗑️ Delete</button>
      </div>
    </div>
  `).join('');
}

async function addCommunity(event) {
  event.preventDefault();
  await waitForSupabaseAdmin();
  const collegeSelect = document.getElementById('communityCollege');
  const collegeId = collegeSelect.value;
  const collegeName = collegeSelect.options[collegeSelect.selectedIndex].textContent.trim();
  const desc = document.getElementById('communityDesc').value.trim();
  if (!collegeId) {
    showMessage('College is required.', true);
    return;
  }
  if (!collegeName) {
    showMessage('Invalid college selected.', true);
    return;
  }
  // Check for duplicate community for this college name
  const { data: existing } = await window.supabaseAdmin
    .from('communities')
    .select('id')
    .eq('name', collegeName);
  if (existing && existing.length > 0) {
    showMessage('A community for this college already exists.', true);
    return;
  }
  const { error } = await window.supabaseAdmin
    .from('communities')
    .insert({ name: collegeName, description: desc });
  if (error) {
    showMessage('Failed to add community.', true);
    return;
  }
  showMessage('Community added!', false);
  collegeSelect.value = '';
  document.getElementById('communityDesc').value = '';
  loadCommunities();
}

function showMessage(msg, isError) {
  const el = document.getElementById('message');
  el.textContent = msg;
  el.className = 'message ' + (isError ? 'error' : 'success');
  setTimeout(() => { el.textContent = ''; }, 4000);
}

window.editCommunityPrompt = async function(id) {
  const card = document.getElementById('community-' + id);
  if (!card) return;
  const title = card.querySelector('.community-title');
  const desc = card.querySelector('.community-desc');
  const oldName = title.textContent;
  const oldDesc = desc.textContent;
  const newName = prompt('Edit community name:', oldName);
  if (newName === null) return;
  const newDesc = prompt('Edit description:', oldDesc);
  if (newDesc === null) return;
  await updateCommunity(id, newName.trim(), newDesc.trim());
}

async function updateCommunity(id, name, description) {
  await waitForSupabaseAdmin();
  if (!name) {
    showMessage('Name is required.', true);
    return;
  }
  // Check for duplicate name (excluding self)
  const { data: existing } = await window.supabaseAdmin
    .from('communities')
    .select('id')
    .eq('name', name)
    .neq('id', id);
  if (existing && existing.length > 0) {
    showMessage('A community with this name already exists.', true);
    return;
  }
  const { error } = await window.supabaseAdmin
    .from('communities')
    .update({ name, description })
    .eq('id', id);
  if (error) {
    showMessage('Failed to update community.', true);
    return;
  }
  showMessage('Community updated!', false);
  loadCommunities();
}

window.deleteCommunity = async function(id) {
  await waitForSupabaseAdmin();
  if (!confirm('Are you sure you want to delete this community? This action cannot be undone.')) return;
  const { error } = await window.supabaseAdmin.from('communities').delete().eq('id', id);
  if (error) {
    showMessage('Failed to delete community.', true);
    return;
  }
  showMessage('Community deleted.', false);
  loadCommunities();
} 