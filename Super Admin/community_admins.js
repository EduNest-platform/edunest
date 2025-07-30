// Community Admins Management JS

document.addEventListener('DOMContentLoaded', () => {
  // Get community_id from query string
  const params = new URLSearchParams(window.location.search);
  const communityId = params.get('community_id');
  const communityNameDiv = document.getElementById('communityName');
  const adminMessageDiv = document.getElementById('adminMessage');
  const adminsListDiv = document.getElementById('adminsList');

  if (!communityId) {
    communityNameDiv.textContent = 'Community: (Invalid or missing)';
    return;
  }

  // Fetch and display community name from DB (use supabaseAdmin)
  async function fetchCommunityName() {
    try {
      if (!window.supabaseAdmin) {
        console.error('[DEBUG] supabaseAdmin is undefined');
        communityNameDiv.textContent = 'Community: (Admin client not initialized)';
        return;
      }
      console.log('[DEBUG] Fetching community name for id:', communityId);
      const { data, error } = await window.supabaseAdmin
        .from('communities')
        .select('name')
        .eq('id', communityId)
        .single();
      console.log('[DEBUG] Supabase response:', { data, error });
      if (error || !data) {
        communityNameDiv.textContent = 'Community: (Not found)';
        if (error) console.error('[DEBUG] Error fetching community name:', error);
      } else {
        communityNameDiv.textContent = 'Community: ' + data.name;
      }
    } catch (err) {
      console.error('[DEBUG] Exception in fetchCommunityName:', err);
      communityNameDiv.textContent = 'Community: (Error fetching name)';
    }
  }
  fetchCommunityName();

  // Load current admins for this community
  async function loadAdmins(communityId) {
    adminsListDiv.innerHTML = '<div>Loading admins...</div>';
    try {
      if (!window.supabaseAdmin) {
        console.error('[DEBUG] supabaseAdmin is undefined');
        adminsListDiv.innerHTML = '<div style="color:#d32f2f;">Admin client not initialized.</div>';
        return;
      }
      console.log('[DEBUG] Loading admins for communityId:', communityId);
      const { data, error } = await window.supabaseAdmin
        .from('community_admins')
        .select('id, user_id, email, role, created_at')
        .eq('community_id', communityId)
        .order('created_at', { ascending: false });
      console.log('[DEBUG] Supabase admins response:', { data, error });
      if (error) {
        adminsListDiv.innerHTML = '<div style="color:#d32f2f;">Failed to load admins.</div>';
        console.error('[DEBUG] Error loading admins:', error);
        return;
      }
      if (!data || data.length === 0) {
        adminsListDiv.innerHTML = '<div style="color:#888;">No admins found for this community.</div>';
        return;
      }
      adminsListDiv.innerHTML = data.map(admin => {
        const email = admin.email || '(no email)';
        const userId = admin.user_id || '(not signed up yet)';
        return `<div class="admin-card" data-admin-id="${admin.id}">
          <div class="admin-info">
            <span class="admin-email">${email}</span>
            <span class="admin-role">[${admin.role}]</span>
            <span class="admin-id">${userId}</span>
          </div>
          <div class="admin-actions">
            <button class="remove-btn" data-admin-id="${admin.id}" data-email="${email}">Remove</button>
            <button class="role-btn" data-admin-id="${admin.id}" data-current-role="${admin.role}">Change Role</button>
          </div>
        </div>`;
      }).join('');

      // Attach event listeners for remove and change role buttons
      document.querySelectorAll('.remove-btn').forEach(btn => {
        btn.addEventListener('click', async (e) => {
          const adminId = btn.getAttribute('data-admin-id');
          const email = btn.getAttribute('data-email');
          if (!confirm(`Are you sure you want to remove admin (${email})?`)) return;
          adminMessageDiv.textContent = '';
          try {
            console.log('[DEBUG] Removing admin id:', adminId, 'email:', email);
            const { error } = await window.supabaseAdmin
              .from('community_admins')
              .delete()
              .eq('id', adminId);
            if (error) {
              adminMessageDiv.textContent = 'Failed to remove admin: ' + error.message;
              adminMessageDiv.className = 'message error show';
              console.error('[DEBUG] Remove admin error:', error);
            } else {
              adminMessageDiv.textContent = 'Admin removed successfully!';
              adminMessageDiv.className = 'message success show';
              console.log('[DEBUG] Admin removed:', adminId);
              loadAdmins(communityId);
            }
          } catch (err) {
            console.error('[DEBUG] Exception in remove admin:', err);
            adminMessageDiv.textContent = 'Error removing admin.';
            adminMessageDiv.className = 'message error show';
          }
        });
      });
      document.querySelectorAll('.role-btn').forEach(btn => {
        btn.addEventListener('click', async (e) => {
          const adminId = btn.getAttribute('data-admin-id');
          const currentRole = btn.getAttribute('data-current-role');
          const newRole = prompt('Enter new role (admin, moderator, professor):', currentRole);
          if (!newRole || !['admin','moderator','professor'].includes(newRole)) {
            alert('Invalid role. Allowed: admin, moderator, professor.');
            return;
          }
          adminMessageDiv.textContent = '';
          try {
            console.log('[DEBUG] Changing role for admin id:', adminId, 'to:', newRole);
            const { error } = await window.supabaseAdmin
              .from('community_admins')
              .update({ role: newRole })
              .eq('id', adminId);
            if (error) {
              adminMessageDiv.textContent = 'Failed to change role: ' + error.message;
              adminMessageDiv.className = 'message error show';
              console.error('[DEBUG] Change role error:', error);
            } else {
              adminMessageDiv.textContent = 'Role updated successfully!';
              adminMessageDiv.className = 'message success show';
              console.log('[DEBUG] Role updated for admin:', adminId);
              loadAdmins(communityId);
            }
          } catch (err) {
            console.error('[DEBUG] Exception in change role:', err);
            adminMessageDiv.textContent = 'Error changing role.';
            adminMessageDiv.className = 'message error show';
          }
        });
      });
    } catch (err) {
      console.error('[DEBUG] Exception in loadAdmins:', err);
      adminsListDiv.innerHTML = '<div style="color:#d32f2f;">Error loading admins.</div>';
    }
  }
  loadAdmins(communityId);

  // Setup add admin form
  document.getElementById('addAdminForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    adminMessageDiv.textContent = '';
    const email = document.getElementById('adminEmail').value.trim().toLowerCase();
    let role = document.getElementById('adminRole').value;
    if (!email || !role) {
      adminMessageDiv.textContent = 'Please enter a valid email and select a role.';
      adminMessageDiv.className = 'message error show';
      return;
    }
    try {
      if (!window.supabaseAdmin) {
        console.error('[DEBUG] supabaseAdmin is undefined');
        adminMessageDiv.textContent = 'Admin client not initialized.';
        adminMessageDiv.className = 'message error show';
        return;
      }
      // Check if email already exists for this community
      const { data: existing, error: existingError } = await window.supabaseAdmin
        .from('community_admins')
        .select('id')
        .eq('community_id', communityId)
        .eq('email', email)
        .maybeSingle();
      if (existing) {
        adminMessageDiv.textContent = 'This email is already an admin for this community.';
        adminMessageDiv.className = 'message error show';
        console.log('[DEBUG] Attempted to add duplicate admin:', email);
        return;
      }
      // Try to find user_id by email
      let userId = null;
      let userError = null;
      const { data: user, error: lookupError } = await window.supabaseAdmin
        .from('auth.users')
        .select('id')
        .eq('email', email)
        .maybeSingle();
      if (user) {
        userId = user.id;
        console.log('[DEBUG] Found user_id for email:', email, userId);
      } else if (lookupError) {
        userError = lookupError;
        console.log('[DEBUG] User lookup error for email:', email, userError);
      } else {
        console.log('[DEBUG] No user found for email:', email);
      }
      // Insert admin (user_id may be null if user not signed up yet)
      const { error: insertError } = await window.supabaseAdmin
        .from('community_admins')
        .insert({ user_id: userId, email, community_id: communityId, role });
      if (insertError) {
        adminMessageDiv.textContent = 'Failed to add admin: ' + insertError.message;
        adminMessageDiv.className = 'message error show';
        console.error('[DEBUG] Add admin error:', insertError);
        return;
      }
      adminMessageDiv.textContent = 'Admin added successfully!';
      adminMessageDiv.className = 'message success show';
      console.log('[DEBUG] Admin added:', email, 'role:', role, 'user_id:', userId);
      // If userId exists, call edge function to ensure linking
      if (userId) {
        console.log('[DEBUG] Calling edge function to link admin:', email, userId);
        try {
          const res = await fetch('https://pfuzvpihupvhjshxiofn.functions.supabase.co/link-community-admin', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ email, user_id: userId })
          });
          const result = await res.json();
          console.log('[DEBUG] Edge function response:', result);
        } catch (err) {
          console.error('[DEBUG] Edge function error:', err);
        }
      }
      document.getElementById('addAdminForm').reset();
      loadAdmins(communityId);
    } catch (err) {
      console.error('[DEBUG] Exception in add admin:', err);
      adminMessageDiv.textContent = 'Error adding admin.';
      adminMessageDiv.className = 'message error show';
    }
  });
}); 