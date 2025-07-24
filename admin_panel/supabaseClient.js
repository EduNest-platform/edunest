// Supabase client initialization (separate file)
const SUPABASE_URL = 'https://vpjzxhfrqyspcbgmwqjd.supabase.co';
const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZwanp4aGZycXlzcGNiZ213cWpkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTExMDQ5NzIsImV4cCI6MjA2NjY4MDk3Mn0.x9dnZg6gvSUWVfuL4-CB6dKUY6sESE1xyM_v9Wmv4Tc';

let initializationAttempts = 0;
const maxAttempts = 10;

// Initialize Supabase client after library is loaded
function initializeSupabase() {
  try {
    if (typeof window.supabase !== 'undefined') {
      window.supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY, {
        auth: { storageKey: 'supabase.storage' }
      });
    } else {
      initializationAttempts++;
      
      if (initializationAttempts < maxAttempts) {
        // Retry after a short delay
        setTimeout(initializeSupabase, 200);
      }
    }
  } catch (error) {
    showConnectionError();
  }
}

// Test the database connection
async function testConnection() {
  try {
    const { data, error } = await window.supabaseClient
      .from('colleges')
      .select('count', { count: 'exact', head: true });
    
    if (error) {
      showConnectionError();
    } else {
      updateConnectionStatus(true);
    }
  } catch (error) {
    showConnectionError();
  }
}

// Show connection error
function showConnectionError() {
  updateConnectionStatus(false);
  
  // Show error message if message display exists
  const messageDisplay = document.getElementById('messageDisplay');
  if (messageDisplay) {
    messageDisplay.textContent = 'Database connection failed. Please check your internet connection and try again.';
    messageDisplay.className = 'message error show';
  }
}

// Update connection status
function updateConnectionStatus(connected) {
  const statusElement = document.getElementById('connectionStatus');
  if (statusElement) {
    if (connected) {
      statusElement.textContent = '🟢 Connected';
      statusElement.style.color = '#059669';
    } else {
      statusElement.textContent = '🔴 Disconnected';
      statusElement.style.color = '#dc2626';
    }
  }
}

// Initialize when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initializeSupabase);
} else {
  initializeSupabase();
}

// Also try to initialize immediately
initializeSupabase();

// For compatibility with app.js
const supabase = window.supabaseClient; 
 
 
 
 