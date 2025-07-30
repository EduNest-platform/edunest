// Login function using Supabase Auth
async function login() {
  const email = document.getElementById('email').value.trim();
  const password = document.getElementById('password').value;
  const loginBtn = document.querySelector('#loginPage button');
  const authError = document.getElementById('authError');
  authError.innerText = '';

  if (!email) {
    authError.innerText = 'Please enter your email address.';
    document.getElementById('email').focus();
    return false;
  }
  if (!password) {
    authError.innerText = 'Please enter your password.';
    document.getElementById('password').focus();
    return false;
  }

  loginBtn.textContent = 'Logging in...';
  loginBtn.disabled = true;

  try {
    const { data, error } = await window.supabaseAdmin.auth.signInWithPassword({
      email,
      password
    });

    if (error) {
      authError.innerText = error.message || 'Invalid email or password. Please try again.';
      document.getElementById('password').focus();
      document.getElementById('password').select();
    } else {
      // Success - set session and redirect to dashboard
      sessionStorage.setItem('adminLoggedIn', 'true');
      // Optionally, store the Supabase session/token if you want to use it elsewhere
      window.location.href = 'dashboard.html';
    }
  } catch (err) {
    authError.innerText = 'An error occurred during login. Please try again.';
  } finally {
    loginBtn.textContent = 'Login';
    loginBtn.disabled = false;
  }
  return false;
}

// Handle Enter key press
function handleLoginKeyPress(event) {
  if (event.key === 'Enter') {
    event.preventDefault();
    login();
  }
}

// Check if user is already logged in
function checkAuthStatus() {
  const isLoggedIn = sessionStorage.getItem('adminLoggedIn') === 'true';
  const currentPage = window.location.pathname;
  const isLoginPage = currentPage.includes('index.html') || currentPage.endsWith('/') || currentPage.endsWith('/admin_panel/');
  const isSignupPage = currentPage.includes('signup.html');

  if (sessionStorage.getItem('redirecting') === 'true') {
    return;
  }

  if (isLoggedIn && (isLoginPage || isSignupPage)) {
    sessionStorage.setItem('redirecting', 'true');
    setTimeout(() => {
      window.location.href = 'dashboard.html';
    }, 100);
    return;
  }

  if (!isLoggedIn && !isLoginPage && !isSignupPage && (currentPage.includes('dashboard.html') || 
                      currentPage.includes('colleges.html') || 
                      currentPage.includes('branches.html') || 
                      currentPage.includes('semesters.html') || 
                      currentPage.includes('subjects.html') || 
                      currentPage.includes('files.html'))) {
    sessionStorage.setItem('redirecting', 'true');
    setTimeout(() => {
      window.location.href = 'index.html';
    }, 100);
    return;
  }

  sessionStorage.removeItem('redirecting');
}

// Logout function
function logout() {
  sessionStorage.removeItem('adminLoggedIn');
  sessionStorage.removeItem('redirecting');
  window.location.href = 'index.html';
}

// Initialize when page loads
document.addEventListener('DOMContentLoaded', function() {
  checkAuthStatus();
  const loginForm = document.getElementById('loginForm');
  if (loginForm) {
    loginForm.addEventListener('submit', function(event) {
      event.preventDefault();
      login();
    });
    const emailInput = document.getElementById('email');
    const passwordInput = document.getElementById('password');
    if (emailInput) {
      emailInput.addEventListener('keypress', handleLoginKeyPress);
    }
    if (passwordInput) {
      passwordInput.addEventListener('keypress', handleLoginKeyPress);
    }
  }
}); 