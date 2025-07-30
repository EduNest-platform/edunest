// EduNest Admin Panel Colleges Logic

const supabaseAdmin = window.supabaseAdmin;
const supabaseClient = window.supabaseClient;

async function getCurrentUser() {
  if (!window.supabaseAdmin) {
    console.error('Supabase Admin client not initialized');
    return null;
  }
  const { data, error } = await window.supabaseAdmin.auth.getUser();
  if (error || !data || !data.user) return null;
  return data.user;
}

async function loadAdminProfile() {
  try {
    const user = await getCurrentUser();
    if (!user) {
      document.body.innerHTML = '<div style="color:#d32f2f; font-size:1.2em; text-align:center; margin-top:40px;">Not logged in. Please <a href="index.html">login</a>.</div>';
      return null;
    }

    // Fetch admin role from community_admins table
    let adminRole = 'Administrator';
    try {
      const { data: adminData, error: roleError } = await window.supabaseAdmin
        .from('community_admins')
        .select('role')
        .eq('user_id', user.id)
        .limit(1);
      
      if (!roleError && adminData && adminData.length > 0) {
        const role = adminData[0].role;
        adminRole = role.charAt(0).toUpperCase() + role.slice(1);
      }
    } catch (roleError) {
      console.error('Error fetching admin role:', roleError);
    }

    // Update admin info display
    const adminEmail = document.getElementById('adminEmail');
    const adminRoleElem = document.getElementById('adminRole');
    const adminAvatar = document.getElementById('adminAvatar');

    if (adminEmail) adminEmail.textContent = user.email || 'No email';
    if (adminRoleElem) adminRoleElem.textContent = adminRole;
    if (adminAvatar) adminAvatar.textContent = user.email ? user.email.charAt(0).toUpperCase() : 'A';

    return user;
  } catch (error) {
    console.error('Error loading admin profile:', error);
    return null;
  }
}

async function loadAssignedCollege() {
  if (!window.supabaseAdmin || !window.supabaseClient) {
    console.error('Supabase clients not initialized');
    document.getElementById('collegeDisplay').innerHTML = '<div style="color:#d32f2f; font-size:1.1em; text-align:center; margin-top:40px;">Error: Supabase clients not initialized. Please refresh the page.</div>';
    return;
  }

  const user = await getCurrentUser();
  if (!user) return;

  const userId = user.id;
  
  // Fetch assigned communities for this user (from supabaseAdmin)
  const { data: adminRows, error: adminError } = await window.supabaseAdmin
    .from('community_admins')
    .select('community_id')
    .eq('user_id', userId);
  
  if (adminError || !adminRows || adminRows.length === 0) {
    document.getElementById('collegeDisplay').innerHTML = `
      <div style="text-align: center; padding: 40px; background: #fff; border-radius: 16px; box-shadow: 0 4px 20px rgba(0,0,0,0.08); border: 1px solid #e5e7eb;">
        <div style="font-size: 3em; margin-bottom: 16px;">🏫</div>
        <h3 style="color: #d32f2f; margin-bottom: 8px;">No College Assigned</h3>
        <p style="color: #6b7280;">You are not assigned to any college/community.</p>
      </div>
    `;
    return;
  }

  // Fetch the community names (from supabaseAdmin)
  const communityIds = adminRows.map(row => row.community_id);
  const { data: communities, error: commError } = await window.supabaseAdmin
    .from('communities')
    .select('name')
    .in('id', communityIds);
  
  if (commError || !communities || communities.length === 0) {
    document.getElementById('collegeDisplay').innerHTML = `
      <div style="text-align: center; padding: 40px; background: #fff; border-radius: 16px; box-shadow: 0 4px 20px rgba(0,0,0,0.08); border: 1px solid #e5e7eb;">
        <div style="font-size: 3em; margin-bottom: 16px;">🏫</div>
        <h3 style="color: #d32f2f; margin-bottom: 8px;">No College Details Found</h3>
        <p style="color: #6b7280;">No community/college details found.</p>
      </div>
    `;
    return;
  }

  const allowedNames = communities.map(c => c.name);
  
  // Fetch all colleges (from supabaseClient)
  const { data: colleges, error: collegeError } = await window.supabaseClient
    .from('colleges')
    .select('*');
  
  if (collegeError || !colleges || colleges.length === 0) {
    document.getElementById('collegeDisplay').innerHTML = `
      <div style="text-align: center; padding: 40px; background: #fff; border-radius: 16px; box-shadow: 0 4px 20px rgba(0,0,0,0.08); border: 1px solid #e5e7eb;">
        <div style="font-size: 3em; margin-bottom: 16px;">🏫</div>
        <h3 style="color: #6b7280; margin-bottom: 8px;">No Colleges Found</h3>
        <p style="color: #6b7280;">No colleges found in the system.</p>
      </div>
    `;
    return;
  }

  // Filter colleges by allowed community/college names
  const filteredColleges = colleges.filter(college => allowedNames.includes(college.name));
  
  if (filteredColleges.length === 0) {
    document.getElementById('collegeDisplay').innerHTML = `
      <div style="text-align: center; padding: 40px; background: #fff; border-radius: 16px; box-shadow: 0 4px 20px rgba(0,0,0,0.08); border: 1px solid #e5e7eb;">
        <div style="font-size: 3em; margin-bottom: 16px;">🏫</div>
        <h3 style="color: #6b7280; margin-bottom: 8px;">No Colleges Assigned</h3>
        <p style="color: #6b7280;">No colleges are assigned to you.</p>
      </div>
    `;
    return;
  }

  // Display the assigned college(s) in a better way
  const collegeDisplay = document.getElementById('collegeDisplay');
  collegeDisplay.innerHTML = filteredColleges.map(college => `
    <div style="background: #fff; border-radius: 16px; padding: 32px; box-shadow: 0 4px 20px rgba(0,0,0,0.08); border: 1px solid #e5e7eb; margin-bottom: 20px;">
      <div style="display: flex; align-items: center; gap: 20px; margin-bottom: 24px;">
        <div style="width: 80px; height: 80px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); border-radius: 16px; display: flex; align-items: center; justify-content: center; color: white; font-size: 2.5em;">🏫</div>
        <div style="flex: 1;">
          <h3 style="font-size: 1.8em; font-weight: 700; color: #1f2937; margin: 0 0 8px 0;">${college.name}</h3>
          <div style="color: #6b7280; font-size: 1em; margin-bottom: 12px;">College ID: ${college.id}</div>
          ${college.description ? `<p style="color: #374151; line-height: 1.6; margin: 0;">${college.description}</p>` : ''}
        </div>
      </div>
      
      <div style="display: flex; justify-content: space-between; align-items: center; margin-top: 24px;">
        <div style="background: #f8fafc; padding: 16px; border-radius: 12px; border: 1px solid #e2e8f0;">
          <div style="font-size: 0.9em; color: #64748b; margin-bottom: 4px;">Status</div>
          <div style="font-weight: 600; color: #059669;">Active</div>
        </div>
        <button onclick="window.location.href='branches.html?college=${college.id}'" style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; border: none; border-radius: 12px; padding: 12px 24px; font-weight: 600; font-size: 1em; cursor: pointer; display: flex; align-items: center; gap: 8px; transition: transform 0.2s;" onmouseover="this.style.transform='translateY(-2px)'" onmouseout="this.style.transform='translateY(0)'">
          <span>🏢</span>
          Manage Branches
        </button>
      </div>
    </div>
  `).join('');
}

async function loadPage() {
  await loadAdminProfile();
  await loadAssignedCollege();
}

document.addEventListener('DOMContentLoaded', loadPage); 