// Parse access_token and type from URL
const urlParams = new URLSearchParams(window.location.search);
const accessToken = urlParams.get('access_token');
const type = urlParams.get('type');

// Use window.supabaseClient for all supabase operations
const supabase = window.supabaseClient;

if (type === 'recovery' && accessToken && supabase) {
  // Set the session with the recovery token
  supabase.auth.setSession({
    access_token: accessToken,
    refresh_token: accessToken, // Supabase requires both
  });
}

const emailRow = document.getElementById ? document.getElementById('email-row') : null;

document.addEventListener('DOMContentLoaded', function () {
  // Show email input if no token
  if (!accessToken && emailRow) {
    emailRow.style.display = 'flex';
    document.getElementById('email').setAttribute('required', 'required');
  }
  const form = document.getElementById('change-password-form');
  const messageDiv = document.getElementById('message');
  const submitBtn = form.querySelector('button[type="submit"]');

  form.onsubmit = async (e) => {
    e.preventDefault();
    const email = document.getElementById('email').value;
    const newPassword = document.getElementById('new-password').value;
    const confirmPassword = document.getElementById('confirm-password').value;
    messageDiv.textContent = '';
    messageDiv.className = 'message';

    if (newPassword !== confirmPassword) {
      showError('❌ Passwords do not match. Please try again.');
      return;
    }

    showLoading();
    submitBtn.disabled = true;
    try {
      const response = await fetch('https://edunest-admin-api.onrender.com/manual-password-reset', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, newPassword })
      });
      let result = null;
      try {
        result = await response.json();
      } catch (jsonErr) {
        showError('❌ Server error: Invalid response. Please try again later.');
        submitBtn.disabled = false;
        return;
      }
      if (result && result.success) {
        showSuccess(email);
      } else {
        showError(`❌ ${result && result.message ? result.message : 'Failed to reset password. Please try again.'}`);
        submitBtn.disabled = false;
      }
    } catch (err) {
      showError('❌ Error contacting server. Please check your connection and try again.');
      submitBtn.disabled = false;
    }
  };

  function showLoading() {
    messageDiv.innerHTML = '<span class="spinner"></span> <span style="font-size:1.2em;vertical-align:middle;">Processing your request...</span>';
    messageDiv.className = 'message loading show';
    messageDiv.style.display = 'block';
  }

  function showSuccess(email) {
    let url = 'https://developerik8.github.io/password-success-screen/';
    if (email) {
      url += `?email=${encodeURIComponent(email)}`;
    }
    window.location.href = url;
  }

  function showError(message) {
    messageDiv.innerHTML = `<span style="font-size:2em;vertical-align:middle;">❌</span> <span style="vertical-align:middle;font-size:1.2em;">${message}</span><br><button id="retry-btn" class="action-btn" style="margin-top:18px;background:#d32f2f;font-size:1.1em;padding:12px 28px;">Retry</button>`;
    messageDiv.className = 'message error show';
    messageDiv.style.display = 'block';
    submitBtn.disabled = false;
    document.getElementById('retry-btn').onclick = function() {
      messageDiv.textContent = '';
      messageDiv.className = 'message';
      messageDiv.style.display = 'none';
      form.reset();
    };
  }
});

// Add spinner CSS
const style = document.createElement('style');
style.innerHTML = `
.spinner {
  display: inline-block;
  width: 22px;
  height: 22px;
  border: 3px solid #e0e7ff;
  border-top: 3px solid #667eea;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
  vertical-align: middle;
  margin-right: 8px;
}
@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}
`;
document.head.appendChild(style); 