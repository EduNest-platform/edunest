// EduNest Admin Panel Signup Logic

// Wait for supabaseAdmin to be initialized
async function waitForSupabaseAdmin() {
  let tries = 0;
  return new Promise((resolve, reject) => {
    function check() {
      if (window.supabaseAdmin) return resolve(window.supabaseAdmin);
      tries++;
      if (tries > 50) return reject(new Error('supabaseAdmin not initialized'));
      setTimeout(check, 50);
    }
    check();
  });
}

const signupForm = document.getElementById('signupForm');
const signupErrorDiv = document.getElementById('signupError');

// Add loading overlay
function showSignupLoading(show) {
  let overlay = document.getElementById('signupLoadingOverlay');
  if (!overlay) {
    overlay = document.createElement('div');
    overlay.id = 'signupLoadingOverlay';
    overlay.style = 'position:fixed;top:0;left:0;width:100vw;height:100vh;background:rgba(255,255,255,0.7);z-index:2000;display:flex;align-items:center;justify-content:center;';
    overlay.innerHTML = '<div style="display:flex;flex-direction:column;align-items:center;gap:18px;"><div class="loading-spinner" style="border:4px solid #e0e7ff;border-top:4px solid #6366f1;border-radius:50%;width:48px;height:48px;animation:spin 1s linear infinite;"></div><div style="color:#6366f1;font-weight:600;font-size:1.1em;">Signing up...</div></div>';
    document.body.appendChild(overlay);
  }
  overlay.style.display = show ? 'flex' : 'none';
}
// Add spinner keyframes if not present
if (!document.getElementById('signupSpinnerStyle')) {
  const style = document.createElement('style');
  style.id = 'signupSpinnerStyle';
  style.innerHTML = '@keyframes spin{0%{transform:rotate(0deg);}100%{transform:rotate(360deg);}}';
  document.head.appendChild(style);
}

// Helper: Call Edge Function to link user_id to pre-approved admin email
async function linkCommunityAdmin(email, userId) {
  try {
    const res = await fetch('https://pfuzvpihupvhjshxiofn.functions.supabase.co/link-community-admin', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, user_id: userId })
    });
    const result = await res.json();
    if (res.status !== 200) {
      console.error('[Edge Function Error]', result.error || result);
    }
  } catch (err) {
    console.error('[Edge Function Exception]', err);
  }
}

// Helper: Check if user is an admin
async function isUserAdmin(userId) {
  const supabase = await waitForSupabaseAdmin();
  const { data, error } = await supabase
    .from('community_admins')
    .select('*')
    .eq('user_id', userId);
  return data && data.length > 0;
}

// Helper: Check if email is pre-approved
async function isEmailPreApproved(email) {
  const supabase = await waitForSupabaseAdmin();
  const { data, error } = await supabase
    .from('community_admins')
    .select('id')
    .eq('email', email);
  return data && data.length > 0;
}

// Helper: Update all community_admins rows for this email to set user_id
async function updateCommunityAdminsUserId(email, userId) {
  const supabase = await waitForSupabaseAdmin();
  const { data, error } = await supabase
    .from('community_admins')
    .update({ user_id: userId })
    .eq('email', email)
    .is('user_id', null);
  if (error) {
    console.error('[Update community_admins user_id error]', error);
  }
}

// Handle signup form submit
signupForm.onsubmit = async (e) => {
  e.preventDefault();
  signupErrorDiv.textContent = '';
  showSignupLoading(true);
  const email = document.getElementById('signupEmail').value.trim().toLowerCase();
  const password = document.getElementById('signupPassword').value;

  // Check if email is pre-approved
  const preApproved = await isEmailPreApproved(email);
  if (!preApproved) {
    showSignupLoading(false);
    signupErrorDiv.textContent = 'This email is not pre-approved for admin access.';
    return;
  }

  let user = null;
  try {
    const supabase = await waitForSupabaseAdmin();
    const { data, error } = await window.supabaseAdminSignup(email, password);
    if (error) throw error;
    user = data.user;
    if (!user) throw new Error('No user returned after signup.');
    // Update all community_admins rows for this email to set user_id
    await updateCommunityAdminsUserId(email, user.id);
    // Call Edge Function to link admin (optional, for redundancy)
    await linkCommunityAdmin(email, user.id);
    // Add a small delay before showing verify dialog
    setTimeout(() => {
      showSignupLoading(false);
    document.getElementById('signupPage').style.display = 'none';
    const verifyDialog = document.getElementById('verifyDialog');
    verifyDialog.style.display = 'flex';
    document.getElementById('goToLoginBtn').onclick = function() {
      window.location.href = 'index.html';
    };
    }, 1500);
    // Do not check admin status or redirect to dashboard until email is verified
    return;
  } catch (signupErr) {
    showSignupLoading(false);
    signupErrorDiv.textContent = signupErr.message || 'Signup failed.';
  }
}; 