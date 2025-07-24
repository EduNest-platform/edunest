// AI Configuration Page JavaScript

// Performance and responsiveness improvements
let isProcessing = false;
let currentRequest = null;

// Check authentication on page load
document.addEventListener('DOMContentLoaded', function() {
  if (!sessionStorage.getItem('adminLoggedIn')) {
    window.location.href = 'index.html';
    return;
  }
  
  // Initialize the page with error handling
  try {
    initAIConfigPage();
  } catch (error) {
    console.error('Error initializing AI Config page:', error);
    showAIConfigMessage('Error initializing page. Please refresh.', true);
  }
});

// Initialize AI Config page
function initAIConfigPage() {
  
  
  // Load AI configuration data with timeout
  setTimeout(() => {
    loadGeminiApiKey();
  }, 100);
  
  // Add fade-in animation with error handling
  const aiSection = document.getElementById('ai-config-section');
  if (aiSection) {
    try {
      aiSection.classList.add('fade-in-anim');
      
      // Add highlight effect
      aiSection.classList.add('highlight-anim');
      setTimeout(() => {
        if (aiSection.classList.contains('highlight-anim')) {
          aiSection.classList.remove('highlight-anim');
        }
      }, 800);
    } catch (error) {
      console.error('Error adding animations:', error);
    }
  }
  
  // Focus on token input after a short delay
  setTimeout(() => {
    const tokenInput = document.getElementById('geminiKeyInput');
    if (tokenInput) {
      try {
        tokenInput.focus();
      } catch (error) {
        console.error('Error focusing input:', error);
      }
    }
  }, 500);
  
  // Add event listeners for better UX
  addEventListeners();
}

// Add event listeners for better user experience
function addEventListeners() {
  try {
    // Enter key on token input with debouncing
    const tokenInput = document.getElementById('geminiKeyInput');
    if (tokenInput) {
      let enterTimeout;
      tokenInput.addEventListener('keypress', function(e) {
        if (e.key === 'Enter') {
          e.preventDefault();
          clearTimeout(enterTimeout);
          enterTimeout = setTimeout(() => {
            if (!isProcessing) {
              saveGeminiApiKey();
            }
          }, 100);
        }
      });
    }
    
    // Prevent form submission on Enter
    document.addEventListener('keypress', function(e) {
      if (e.key === 'Enter' && e.target.tagName !== 'TEXTAREA') {
        e.preventDefault();
      }
    });
    
    // Add click outside to close mobile menu
    document.addEventListener('click', function(e) {
      const mobileNav = document.getElementById('mobileNavContainer');
      const hamburgerBtn = document.querySelector('.hamburger-btn');
      
      if (mobileNav && mobileNav.classList.contains('open') && 
          !mobileNav.contains(e.target) && 
          !hamburgerBtn.contains(e.target)) {
        closeMobileMenu();
      }
    });
    
  } catch (error) {
    console.error('Error adding event listeners:', error);
  }
}

// Load Gemini API key from Supabase
async function loadGeminiApiKey() {
  if (isProcessing) return;
  try {
    isProcessing = true;
    if (!window.supabaseClient) {
      updateGeminiKeyStatus('error', 'Database not connected');
      showAIConfigMessage('Database connection not available. Please refresh the page.', true);
      return;
    }
    const { data: configData, error } = await window.supabaseClient
      .from('ai_config')
      .select('*')
      .single();
    if (error) {
      updateGeminiKeyStatus('error', 'Error loading config');
        showAIConfigMessage('Error loading configuration: ' + error.message, true);
    } else if (configData && configData.gemini_api_key) {
      const keyInput = document.getElementById('geminiKeyInput');
      if (keyInput) keyInput.value = configData.gemini_api_key;
      updateGeminiKeyStatus('success', 'Key configured');
      // Set usage count
      const usageCountElement = document.getElementById('geminiUsageCount');
      if (usageCountElement) usageCountElement.textContent = configData.gemini_usage_count || 0;
    } else {
      updateGeminiKeyStatus('warning', 'No key configured');
      const keyInput = document.getElementById('geminiKeyInput');
      if (keyInput) keyInput.value = '';
      // Set usage count to 0
      const usageCountElement = document.getElementById('geminiUsageCount');
      if (usageCountElement) usageCountElement.textContent = 0;
    }
  } catch (error) {
    updateGeminiKeyStatus('error', 'Error loading config');
    showAIConfigMessage('Error loading configuration: ' + error.message, true);
    // Set usage count to 0
    const usageCountElement = document.getElementById('geminiUsageCount');
    if (usageCountElement) usageCountElement.textContent = 0;
  } finally {
    isProcessing = false;
  }
}

function updateGeminiKeyStatus(type, message) {
  const statusElement = document.getElementById('geminiKeyStatus');
    if (statusElement) {
      statusElement.textContent = message;
      statusElement.className = `status-badge ${type}`;
  }
}

// Save Gemini API key
async function saveGeminiApiKey() {
  if (isProcessing) return;
  const keyInput = document.getElementById('geminiKeyInput');
  if (!keyInput) return;
  const key = keyInput.value.trim();
  if (!key || !key.startsWith('AIza')) {
    showAIConfigMessage('Please enter a valid Gemini API key (starts with "AIza")', true);
    keyInput.focus();
    return;
  }
  try {
    isProcessing = true;
    if (!window.supabaseClient) throw new Error('Supabase client not initialized');
    const { data: existingConfig, error: checkError } = await window.supabaseClient
      .from('ai_config')
      .select('*')
      .single();
    let result;
    if (existingConfig) {
      result = await window.supabaseClient
        .from('ai_config')
        .update({ gemini_api_key: key, updated_at: new Date().toISOString() })
        .eq('id', existingConfig.id);
    } else {
      result = await window.supabaseClient
        .from('ai_config')
        .insert({ id: 1, gemini_api_key: key, created_at: new Date().toISOString(), updated_at: new Date().toISOString() });
    }
    if (result.error) throw result.error;
    updateGeminiKeyStatus('success', 'Key saved successfully');
    showAIConfigMessage('Gemini API key saved successfully!', false);
    // Reload usage count
    await loadGeminiApiKey();
  } catch (error) {
    updateGeminiKeyStatus('error', 'Save failed');
    showAIConfigMessage('Error saving Gemini API key: ' + error.message, true);
    // Set usage count to 0
    const usageCountElement = document.getElementById('geminiUsageCount');
    if (usageCountElement) usageCountElement.textContent = 0;
  } finally {
    isProcessing = false;
  }
}

// Clear Gemini API key
async function clearGeminiApiKey() {
  if (isProcessing) return;
  if (!confirm('Are you sure you want to clear the Gemini API key?')) return;
  try {
    isProcessing = true;
    if (!window.supabaseClient) throw new Error('Supabase client not initialized');
    const { error } = await window.supabaseClient
      .from('ai_config')
      .update({ gemini_api_key: null, updated_at: new Date().toISOString() })
      .eq('id', 1);
    if (error) throw error;
    const keyInput = document.getElementById('geminiKeyInput');
    if (keyInput) keyInput.value = '';
    updateGeminiKeyStatus('warning', 'Key cleared');
    showAIConfigMessage('Gemini API key cleared successfully!', false);
    // Reload usage count
    await loadGeminiApiKey();
  } catch (error) {
    updateGeminiKeyStatus('error', 'Clear failed');
    showAIConfigMessage('Error clearing Gemini API key: ' + error.message, true);
    // Set usage count to 0
    const usageCountElement = document.getElementById('geminiUsageCount');
    if (usageCountElement) usageCountElement.textContent = 0;
  } finally {
    isProcessing = false;
  }
}

// Toggle Gemini key visibility
function toggleGeminiKeyVisibility() {
  const input = document.getElementById('geminiKeyInput');
  const icon = document.getElementById('geminiVisibilityIcon');
  if (!input || !icon) return;
    if (input.type === 'password') {
      input.type = 'text';
      icon.textContent = '🙈';
    } else {
      input.type = 'password';
      icon.textContent = '👁️';
    }
}

// Debug Gemini key input
function debugGeminiKeyInput() {
  const keyInput = document.getElementById('geminiKeyInput');
  
  if (keyInput) {
    try { keyInput.focus(); } catch (e) {}
    try { keyInput.click(); } catch (e) {}
  }
  showAIConfigMessage('Debug info logged to console. Press F12 to view.', false);
}

// Show AI config message with debouncing
let messageTimeout;
function showAIConfigMessage(message, isError = false) {
  try {
    clearTimeout(messageTimeout);
    
    const messageElement = document.getElementById('aiConfigMessage');
    if (messageElement) {
      messageElement.textContent = message;
      messageElement.className = `message ${isError ? 'error' : 'success'}`;
      
      // Scroll to message smoothly
      try {
        messageElement.scrollIntoView({ behavior: 'smooth', block: 'center' });
      } catch (scrollError) {
    
      }
      
      messageTimeout = setTimeout(() => {
        messageElement.textContent = '';
        messageElement.className = 'message';
      }, 5000);
    } else {
      // Fallback to alert if message element not found
      if (isError) {
        alert('Error: ' + message);
      } else {
        alert(message);
      }
    }
  } catch (error) {
    console.error('Error showing message:', error);
  }
}

// Debug function to troubleshoot token input issues
function debugTokenInput() {
  try {
    const tokenInput = document.getElementById('geminiKeyInput');
    const aiSection = document.getElementById('ai-config-section');
    
    showAIConfigMessage('Debug info logged to console. Press F12 to view.', false);
  } catch (error) {
    showAIConfigMessage('Debug function error: ' + error.message, true);
  }
}

// Test function to verify all buttons are working
function testAllButtons() {
  try {
    showAIConfigMessage('Button test completed. Check console for results.', false);
  } catch (error) {
    showAIConfigMessage('Button test error: ' + error.message, true);
  }
}

// Utility functions
function showLoading(text = 'Loading...') {
  try {
    const loadingText = document.getElementById('loadingText');
    const loadingOverlay = document.getElementById('loadingOverlay');
    
    if (loadingText) loadingText.textContent = text;
    if (loadingOverlay) loadingOverlay.classList.remove('hidden');
  } catch (error) {
    console.error('Error showing loading:', error);
  }
}

function hideLoading() {
  try {
    const loadingOverlay = document.getElementById('loadingOverlay');
    if (loadingOverlay) loadingOverlay.classList.add('hidden');
  } catch (error) {
    console.error('Error hiding loading:', error);
  }
}

// Mobile navigation functions with error handling
function toggleMobileMenu() {
  try {
    const container = document.getElementById('mobileNavContainer');
    const hamburgerBtn = document.querySelector('.hamburger-btn');
    const body = document.body;
    
    if (!container || !hamburgerBtn) {
      console.error('Mobile menu elements not found');
      return;
    }
    
    container.classList.toggle('open');
    hamburgerBtn.classList.toggle('active');
    body.classList.toggle('menu-open');
  } catch (error) {
    console.error('Error toggling mobile menu:', error);
  }
}

function closeMobileMenu() {
  try {
    const container = document.getElementById('mobileNavContainer');
    const hamburgerBtn = document.querySelector('.hamburger-btn');
    const body = document.body;
    
    if (!container || !hamburgerBtn) {
      console.error('Mobile menu elements not found');
      return;
    }
    
    container.classList.remove('open');
    hamburgerBtn.classList.remove('active');
    body.classList.remove('menu-open');
  } catch (error) {
    console.error('Error closing mobile menu:', error);
  }
}

// Logout function
function logout() {
  try {
    if (confirm('Are you sure you want to logout?')) {
      sessionStorage.removeItem('adminLoggedIn');
      window.location.href = 'index.html';
    }
  } catch (error) {
    console.error('Error during logout:', error);
    // Force logout on error
    sessionStorage.removeItem('adminLoggedIn');
    window.location.href = 'index.html';
  }
}

// Expose all functions to global scope
window.saveGeminiApiKey = saveGeminiApiKey;
window.clearGeminiApiKey = clearGeminiApiKey;
window.toggleGeminiKeyVisibility = toggleGeminiKeyVisibility;
window.debugGeminiKeyInput = debugGeminiKeyInput;
window.toggleMobileMenu = toggleMobileMenu;
window.closeMobileMenu = closeMobileMenu;
window.logout = logout; 